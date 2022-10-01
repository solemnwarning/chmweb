# App::ChmWeb - Generate browsable web pages from CHM files
# Copyright (C) 2022 Daniel Collins <solemnwarning@solemnwarning.net>
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

package App::ChmWeb::ContentPageWriter;

use Encode;
use HTML::Entities;
use SGML::Parser::OpenSP;

use App::ChmWeb::Util;

sub new
{
	my ($class, $link_map, $chm_root) = @_;
	
	my $self = bless({
		link_map => $link_map,
		chm_root => $chm_root,
	}, $class);
	
	return $self;
}

sub load_content
{
	my ($self, $filename, $root_directory) = @_;
	
	open(my $file, "<", "${root_directory}${filename}") or die "${root_directory}${filename}: $!";
	binmode($file);
	
	$self->{content} = do { local $/; <$file>; };
	$self->{filename} = $filename;
}

sub write_content
{
	my ($self, $filename) = @_;
	
	open(my $file, ">", $filename) or die "$filename: $!";
	binmode($file);
	
	print {$file} $self->{content};
	
	close($file);
}

sub set_content
{
	my ($self, $content, $filename) = @_;
	
	$self->{content} = $content;
	$self->{filename} = $filename;
}

sub get_content
{
	my ($self) = @_;
	return $self->{content};
}

sub modify_content
{
	my ($self) = @_;
	
	my @replacements = ();
	
	$self->_parse_content(
		start_element => sub
		{
			my ($elem_name, $elem_attributes, $location) = @_;
			
			if(fc($elem_name) eq fc("a"))
			{
				my ($href_attr) = grep { fc($_->{name}) eq fc("href") } @$elem_attributes;
				my $replace_tag = 0;
				
				if(defined($href_attr) && defined($href_attr->{value}))
				{
					my $old_href = $href_attr->{value};
					my $fixed_href = $self->_resolve_link($old_href);
					
					if($old_href ne $fixed_href)
					{
						$href_attr->{value} = $fixed_href;
						$replace_tag = 1;
					}
				}
				
				my ($target_attr) = grep { fc($_->{name}) eq fc("target") } @$elem_attributes;
				unless(defined($target_attr))
				{
					push(@$elem_attributes, {
						name => "TARGET",
						value => "_top",
					});
					
					$replace_tag = 1;
				}
				
				if($replace_tag)
				{
					push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
				}
			}
			elsif(fc($elem_name) eq fc("img"))
			{
				my ($src_attr) = grep { fc($_->{name}) eq fc("src") } @$elem_attributes;
				if(defined($src_attr) && defined($src_attr->{value}))
				{
					my $old_src = $src_attr->{value};
					my $fixed_src = $self->_resolve_link($old_src);
					
					if($fixed_src ne $old_src)
					{
						$src_attr->{value} = $fixed_src;
						push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
					}
				}
			}
		});
	
	$self->_do_content_replacements(\@replacements);
}

sub _parse_content
{
	my ($self, %callbacks) = @_;
	
	my $p = SGML::Parser::OpenSP->new();
	my $h = App::ChmWeb::ContentPageWriter::Handler->new(\%callbacks, $p);
	
	$p->catalogs(qw(xhtml.soc));
	$p->warnings(qw(xml valid));
	$p->handler($h);
	
	$p->parse_string($self->{content});
}

sub _encode_tag
{
	my ($elem_name, $elem_attributes) = @_;
	return join(" ", "<${elem_name}", map {
		defined($_->{value})
			? ($_->{name}."=\"".encode_entities($_->{value})."\"")
			: $_->{name}
		} @$elem_attributes).">";
}

sub _tag_replacement
{
	my ($self, $elem_name, $new_elem_attributes, $location) = @_;
	
	my $old_content = substr($self->{content}, $location->{ByteOffset});
	$old_content =~ s/>.*$/>/s;
	
	if($old_content !~ m/<\Q$elem_name\E(\s+.*)?>/si)
	{
		die "Unexpected text at offset ".$location->{ByteOffset}." ($old_content) (expected \"$elem_name\" tag)";
	}
	
	return {
		offset => $location->{ByteOffset},
		old_content => $old_content,
		new_content => _encode_tag($elem_name, $new_elem_attributes),
	};
}

sub _do_content_replacements
{
	my ($self, $replacements) = @_;
	
	my @s_replacements = sort { $a->{offset} <=> $b->{offset} } @$replacements;
	
	my $offset_adj = 0;
	
	foreach my $replacement(@s_replacements)
	{
		my $offset      = $replacement->{offset} + $offset_adj;
		my $old_content = $replacement->{old_content};
		my $new_content = encode("UTF-8", $replacement->{new_content});
		
		my $before = substr($self->{content}, 0, $offset);
		my $at = substr($self->{content}, $offset, length($old_content));
		my $after = substr($self->{content}, $offset + length($old_content));
		
		if($at ne $old_content)
		{
			die "Unexpected text at offset $offset (\"$old_content\") (expected \"$new_content\")";
		}
		
		$self->{content} = $before.$new_content.$after;
		$offset_adj += length($new_content) - length($old_content);
		
		# print $replacement->{old_content}, " => ", $replacement->{new_content}, "\n";
	}
}

sub _resolve_link
{
	my ($self, $link) = @_;
	
	my $page_path = $self->{filename};
	
	if($link =~ m/^\w+:/)
	{
		# Link starts with a protocol, return as-is.
		return $link;
	}
	
	if($link =~ m/^#/)
	{
		# Link is to an anchor on the current page, return as-is.
		# TODO: Change target of these links(?).
		return $link;
	}
	
	# Remove anchor (if present)
	$link =~ s/(#.*)$//s;
	my $anchor = $1 // "";
	
	if($link =~ m/^\//)
	{
		$link =~ s/^\/+//;
		$link = $self->{chm_root}.$link;
		
		$page_path = "ROOT";
	}
	
	my $root_relative_path = App::ChmWeb::Util::doc_relative_path_to_root_relative_path($link, $page_path);
	if(defined $root_relative_path)
	{
		my $resolved_link = $self->{link_map}->{$root_relative_path};
		if($resolved_link)
		{
			my $doc_relative_link = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($resolved_link, $page_path);
			return $doc_relative_link.$anchor;
		}
		else{
			# TODO: Warn about broken link
			return "#";
		}
	}
	else{
		# TODO: Log about path escaping from root
		return "#";
	}
}

package App::ChmWeb::ContentPageWriter::Handler;

sub new
{
	my ($class, $callbacks, $parser) = @_;
	
	my $self = bless({ callbacks => $callbacks, parser => $parser }, $class);
	return $self;
}

sub start_element
{
	my ($self, $elem) = @_;
	
	if(defined $self->{callbacks}->{start_element})
	{
		my @attributes = ();
		
		foreach my $attr(sort { $a->{Index} <=> $b->{Index} } values(%{ $elem->{Attributes} }))
		{
			if(defined($attr->{Defaulted}) && $attr->{Defaulted} eq "definition")
			{
				# Not set in markup - implied by spec.
				next;
			}
			
			if($attr->{Type} eq "cdata")
			{
				if((scalar @{ $attr->{CdataChunks} }) == 0)
				{
					push(@attributes, {
						name => $attr->{Name},
					});
				}
				else{
					push(@attributes, map { {
						name => $attr->{Name},
						value => $_->{Data},
					} } @{ $attr->{CdataChunks} });
				}
			}
		}
		
		$self->{callbacks}->{start_element}->($elem->{Name}, \@attributes, $self->{parser}->get_location());
	}
}

1;
