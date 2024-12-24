# App::ChmWeb - Generate browsable web pages from CHM files
# Copyright (C) 2022-2024 Daniel Collins <solemnwarning@solemnwarning.net>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;

use feature qw(fc);

package App::ChmWeb::TreeScanner;

use HTML::Entities;
use SGML::Parser::OpenSP;

use App::ChmWeb::AKLinkTable;
use App::ChmWeb::PageScanner;
use App::ChmWeb::Util;
use App::ChmWeb::TreeData;
use App::ChmWeb::WorkerPool;

sub scan_tree
{
	my ($class, $output_dir, $toc, $chi, $verbosity) = @_;
	
	$verbosity //= 0;
	
	my $self = bless({
		page_links_to_scan => [], # Paths relative to $output_dir
		
		asset_links     => {},
		page_links      => {},
		
		toc => $toc,
	}, $class);
	
	# Add any pages referenced in the ALink/KLink maps to the queue of pages to be scanned.
	foreach my $item(map { @$_ } (values(%{ $chi->get_all_alinks() }), values(%{ $chi->get_all_klinks() })))
	{
		if(defined $item->{Local})
		{
			my $page_link_path = $self->_get_link_path($item->{Local}, "ROOT", "");
			if(defined $page_link_path)
			{
				if(!$self->{page_links}->{$page_link_path})
				{
					$self->{page_links}->{$page_link_path} = 1;
					push(@{ $self->{page_links_to_scan} }, $page_link_path);
				}
			}
			else{
				warn $item->{Local};
			}
		}
	}
	
	# First, we scan the HHCs to build the TOC and find any linked pages...
	
	if($verbosity >= 1)
	{
		print STDERR "Scanning contents...";
	}
	
	my @chm_nodes = $toc->depth_first_search(sub { return $_[0]->isa("App::ChmWeb::ToC::Node::CHM"); });
	
	my $hhc_scanner = App::ChmWeb::WorkerPool->new(\&App::ChmWeb::HHCParser::parse_hhc_file);
	my $hhc_scanned_count = 0;
	
	foreach my $chm_node(@chm_nodes)
	{
		my $chm_stem = $chm_node->chm_stem();
		my $chm_subdir = $toc->chm_subdir_by_stem($chm_stem);
		
		my $hhc_name = App::ChmWeb::Util::find_hhc_in("${output_dir}${chm_subdir}");
		
		$hhc_scanner->post([ "${output_dir}${chm_subdir}${hhc_name}" ], sub
		{
			my ($hhc) = @_;
			
			my @chm_toc_nodes = _walk_hhc_level($self, $output_dir, $chm_subdir, $hhc->{toc});
			$toc->replace_chm($chm_node, @chm_toc_nodes);
			
			++$hhc_scanned_count;
			if($verbosity >= 1)
			{
				print STDERR "\rScanning contents... ($hhc_scanned_count / ", (scalar @chm_nodes), ")";
			}
		});
	}
	
	$hhc_scanner->drain();
	$hhc_scanner = undef;
	
	# Then, we loop over all the pages, scanning them for links to assets which need to be
	# resolved, further pages to scan, etc, until there are no pages left.
	
	if($verbosity >= 1)
	{
		print STDERR "\nScanning pages...";
	}
	
	my $page_scanner = App::ChmWeb::WorkerPool->new(\&App::ChmWeb::PageScanner::scan_page);
	my %pages_queued_for_scan = ();
	my $pages_total_count = 0;
	my $pages_scanned_count = 0;
	my %pages = ();
	
	while(1)
	{
		my %pages_to_scan =
			map { $_ => 1 }
			grep { defined($_) && !$pages_queued_for_scan{$_} }
			map { App::ChmWeb::Util::resolve_mixed_case_path($_, $output_dir) }
			@{ $self->{page_links_to_scan} };
		
		$self->{page_links_to_scan} = [];
		
		if(!%pages_to_scan)
		{
			last;
		}
		
		$pages_total_count += (scalar keys(%pages_to_scan));
		
		foreach my $page_path(keys(%pages_to_scan))
		{
			$pages_queued_for_scan{$page_path} = 1;
			
			$page_scanner->post([ "App::ChmWeb::PageScanner", "${output_dir}${page_path}" ], sub
			{
				my ($page_data) = @_;
				
				my $chm_stem = $toc->chm_stem_by_path($page_path);
				my $chm_subdir = $toc->chm_subdir_by_stem($chm_stem);
				
				# $page_data->{chm_name} = $chm_name;
				$page_data->{chm_name} = "${chm_stem}.chm";
				$page_data->{page_path} = $page_path;
				
				foreach my $asset_link(@{ $page_data->{asset_links} })
				{
					my $link_path = $self->_get_link_path($asset_link, $page_path, $chm_subdir);
					if(defined $link_path)
					{
						$self->{asset_links}->{$link_path} = 1;
					}
				}
				
				foreach my $page_link(@{ $page_data->{page_links} })
				{
					my $link_path = $self->_get_link_path($page_link, $page_path, $chm_subdir);
					if(defined $link_path)
					{
						if(!$self->{page_links}->{$link_path})
						{
							$self->{page_links}->{$link_path} = 1;
							push(@{ $self->{page_links_to_scan} }, $link_path);
						}
					}
				}
				
				$pages{$page_path} = $page_data;
				
				++$pages_scanned_count;
				if($verbosity >= 1 && (($pages_scanned_count % 100) == 0 || $pages_scanned_count == $pages_total_count))
				{
					print STDERR "\rScanning pages... ($pages_scanned_count / $pages_total_count)";
				}
			});
		}
		
		$page_scanner->drain();
	}
	
	$page_scanner = undef;
	
	if($verbosity >= 1)
	{
		print STDERR "\nScanned ", (scalar keys(%pages_queued_for_scan)), " pages, found ", (scalar keys(%{ $self->{page_links} })), " unique page links and ", (scalar keys(%{ $self->{asset_links} })), " unique asset links\n";
	}
	
	my $td_o = App::ChmWeb::TreeData->new();
	
	$td_o->{asset_links} = [ sort keys(%{ $self->{asset_links} }) ];
	$td_o->{page_links}  = [ sort keys(%{ $self->{page_links}  }) ];
	
	$td_o->{pages} = \%pages;
	
	$td_o->{toc} = $toc;
	$td_o->{chi} = $chi;
	
	# Set the toc_path of the PageData object for each page referenced by the ToC.
	$toc->depth_first_search(sub
	{
		my ($toc_node) = @_;
		
		if($toc_node->isa("App::ChmWeb::ToC::Node::Page"))
		{
			my $page_path = App::ChmWeb::Util::resolve_mixed_case_path($toc_node->filename(), $output_dir);
			if(defined $page_path)
			{
				my $page_data = $td_o->{pages}->{$page_path};
				
				if(defined $page_data)
				{
					$page_data->{toc_path} //= [ $toc_node->path() ];
				}
				else{
					warn "Missing page in App::ChmWeb::TreeData::pages: $page_path";
				}
			}
		}
		
		return;
	});
	
	return $td_o;
}

sub _walk_hhc_level
{
	my ($self, $output_dir, $chm_subdir, $hhc_nodes) = @_;
	
	my @toc_nodes = ();
	
	foreach my $node(@$hhc_nodes)
	{
		my $toc_node = undef;
		
		if(defined $node->{Local})
		{
			# There's a page here...
			
			my $page_link_path = $self->_get_link_path($chm_subdir.$node->{Local}, "ROOT", $chm_subdir);
			if(defined $page_link_path)
			{
				if(!$self->{page_links}->{$page_link_path})
				{
					$self->{page_links}->{$page_link_path} = 1;
					push(@{ $self->{page_links_to_scan} }, $page_link_path);
				}
				
				# $out_node->{page_link} = $node->{Local};
				# $out_node->{page_path} = $page_link_path;
				
				my ($anchor) = ($node->{Local} =~ m/#(.+)$/);
				$toc_node = App::ChmWeb::ToC::Node::Page->new($node->{Name}, $page_link_path, $anchor);
			}
			else{
				# TODO: warn about hhc referencing external files...
			}
		}
		
		$toc_node //= App::ChmWeb::ToC::Node::Folder->new($node->{Name});
		
		if(defined $node->{children})
		{
			my @children = _walk_hhc_level($self, $output_dir, $chm_subdir, $node->{children});
			
			foreach my $child(@children)
			{
				$toc_node->add_child($child);
			}
		}
		
		push(@toc_nodes, $toc_node);
	}
	
	return @toc_nodes;
}

sub _get_link_path
{
	my ($self, $link, $page_path, $chm_root) = @_;
	
	if($link =~ m/^\w+:/ && $link !~ m/^mk:\@MSITStore:/i)
	{
		# Link starts with a protocol, discard it.
		return undef;
	}
	
	if($link =~ m/^#/)
	{
		# Link is to an anchor on the current page, discard it.
		return undef;
	}
	
	# Remove anchor (if present)
	$link =~ s/#.*$//s;
	
	# MS-ITS:dsmsdn.chm::/html/msdn_footer.js
	# mk:@MSITStore:techart.chm::/html/jangrayhood.htm
	
	if($link =~ m/^(?:ms-its|mk:\@MSITStore):([^:]+)::([^>]+)/si)
	{
		my $chm_name = $1;
		my $chm_url = $2;
		
		my $chm_subdir = $self->{toc}->chm_subdir_by_chX($chm_name);
		if(defined $chm_subdir)
		{
			$chm_url =~ s/^\/+//;
			$link = "${chm_subdir}${chm_url}";
			
			$page_path = "ROOT";
		}
	}
	elsif($link =~ m/^\//)
	{
		$link =~ s/^\/+//;
		$link = "${chm_root}${link}";
		
		$page_path = "ROOT";
	}
	
	my $root_relative_path = App::ChmWeb::Util::doc_relative_path_to_root_relative_path($link, $page_path);
	if(defined $root_relative_path)
	{
		return $root_relative_path;
	}
	else{
		# TODO: Log about path escaping from root
		return undef;
	}
}

1;
