# App::ChmWeb - Generate browsable web pages from CHM files
# Copyright (C) 2022-2023 Daniel Collins <solemnwarning@solemnwarning.net>
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
	my ($class, $link_map, $chm_root, $tree_data, $page_data) = @_;
	
	my $self = bless({
		link_map => $link_map,
		chm_root => $chm_root,
		tree_data => $tree_data,
		page_data => $page_data,
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
				my ($target_attr) = grep { fc($_->{name}) eq fc("target") } @$elem_attributes;
				my ($class_attr) = grep { fc($_->{name}) eq fc("class") } @$elem_attributes;
				
				my $replace_tag = 0;
				
				if(defined($href_attr) && defined($href_attr->{value}))
				{
					my $old_href = $href_attr->{value};
					my ($fixed_href, $link_target, $link_class) = $self->_resolve_link($old_href, $location->{LineNumber});
					$fixed_href //= "#";
					
					if($old_href ne $fixed_href)
					{
						$href_attr->{value} = $fixed_href;
						$replace_tag = 1;
					}
					
					if(defined $link_target)
					{
						if(defined $target_attr)
						{
							$target_attr->{value} = $link_target;
						}
						else{
							push(@$elem_attributes, {
								name => "TARGET",
								value => $link_target,
							});
						}
						
						$replace_tag = 1;
					}
					
					if(defined $link_class)
					{
						if(defined $class_attr)
						{
							$class_attr->{value} .= " ".$link_class;
						}
						else{
							push(@$elem_attributes, {
								name => "CLASS",
								value => $link_class,
							});
						}
						
						$replace_tag = 1;
					}
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
					my ($fixed_src) = $self->_resolve_link($old_src, $location->{LineNumber});
					$fixed_src //= ""; # TODO: Placeholder/replace tag?
					
					if($fixed_src ne $old_src)
					{
						$src_attr->{value} = $fixed_src;
						push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
					}
				}
			}
			elsif(fc($elem_name) eq fc("link"))
			{
				my ($href_attr) = grep { fc($_->{name}) eq fc("href") } @$elem_attributes;
				if(defined($href_attr) && defined($href_attr->{value}))
				{
					my $old_href = $href_attr->{value};
					my ($fixed_href) = $self->_resolve_link($old_href, $location->{LineNumber});
					$fixed_href //= ""; # TODO: Placeholder/replace tag?
					
					if($fixed_href ne $old_href)
					{
						$href_attr->{value} = $fixed_href;
						push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
					}
				}
			}
			elsif(fc($elem_name) eq fc("script"))
			{
				my ($src_attr) = grep { fc($_->{name}) eq fc("src") } @$elem_attributes;
				if(defined($src_attr) && defined($src_attr->{value}))
				{
					my $old_src = $src_attr->{value};
					my ($fixed_src) = $self->_resolve_link($old_src, $location->{LineNumber});
					$fixed_src //= ""; # TODO: Placeholder/replace tag?
					
					if($fixed_src ne $old_src)
					{
						$src_attr->{value} = $fixed_src;
						push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
					}
				}
			}
		});
	
	# Each ActiveX object in the page should either be
	#
	# a) Replaced with a link/button/etc if it has the parameters that
	#    would make the chm viewer display one.
	#
	# b) Removed if it is only used by other links (which will be updated
	#    to not rely on it).
	
	foreach my $object($self->{page_data}->objects())
	{
		next unless($object->is_hh_activex_control());
		
		my $old_content = substr($self->{content}, $object->{start_offset}, $object->{total_length});
		my $new_content = "";
		
		if(defined(my $button = $object->get_parameter("Button")))
		{
			if($button =~ m/^Text:\s*(.+)$/i)
			{
				# Button with a text label.
			}
			elsif($button =~ m/^\s*$/)
			{
				# "Chiclet" button.
			}
			elsif($button =~ m/^Bitmap:\s*shortcut$/i)
			{
				# Button with a shortcut icon.
			}
			elsif($button =~ m/^Bitmap:\s*(.+)$/i)
			{
				# Button with a bitmap image.
			}
			elsif($button =~ m/^Icon:\s*(.+)$/i)
			{
				# Button with an icon.
			}
			else{
				warn "Unrecognised Button parameter \"$button\" in ".$self->{filename}."\n";
			}
		}
		elsif(defined(my $text = $object->get_parameter("Text")))
		{
			$text =~ s/^Text:\s*//i;
			
			# TODO: Handle "Font" parameter
			
			my ($link_href, $link_target, $link_class) = $self->_resolve_link_for_object($object);
			
			if(defined $link_href)
			{
				my @a_attributes = (
					{
						name  => "HREF",
						value => $link_href,
					},
				);
				
				if(defined $link_target)
				{
					push(@a_attributes, {
						name  => "TARGET",
						value => $link_target,
					});
				}
				
				if(defined $link_class)
				{
					push(@a_attributes, {
						name  => "CLASS",
						value => $link_class,
					});
				}
				
				$new_content = _encode_tag("A", \@a_attributes).encode_entities($text)."</A>";
			}
			else{
				warn "Unable to resolve link for object at ".$self->{filename}." line ".$object->{start_line}."\n";
			}
		}
		
		push(@replacements, {
			offset      => $object->{start_offset},
			old_content => $old_content,
			new_content => encode("UTF-8", $new_content),
		});
	}
	
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
	my ($self, $link, $line_num) = @_;
	
	my $page_path = $self->{filename};
	
	if($link =~ m/^JavaScript:(\w+)\.Click()/)
	{
		# This is probably a link using the HTML Help ActiveX control.
		# We need to resolve it to a plain link...
		
		my $object_id = $1;
		my ($object) = grep { ($_->get_attribute("id") // "") eq $object_id } $self->{page_data}->objects();
		
		if(defined($object) && $object->is_hh_activex_control())
		{
			my ($link, $link_target, $link_class) = $self->_resolve_link_for_object($object);
			return ($link, $link_target, $link_class);
		}
		else{
			warn "'$link' refers to unknown ActiveX object at ".$self->{filename}." line $line_num\n";
		}
	}
	
	if($link =~ m/^\w+:/)
	{
		# Link starts with a protocol, return as-is.
		return ($link, undef, undef);
	}
	
	if($link =~ m/^#/)
	{
		# Link is to an anchor on the current page, return as-is.
		return ($link, undef, undef);
	}
	
	# Remove anchor (if present)
	my $anchor = "";
	if($link =~ m/(#.*)$/s)
	{
		$anchor = $1;
		$link =~ s/#.*$//s;
	}
	
	# MS-ITS:dsmsdn.chm::/html/msdn_footer.js
	
	if($link =~ m/^ms-its:([^:]+)::([^>]+)(?:>(.+))?$/si)
	{
		my $chm_name = $1;
		my $chm_url = $2;
		my $window_name = $3;
		
		if(defined $window_name)
		{
			# Not supported at this time.
			warn "Window name specified in URL $link";
		}
		
		my $chm_subdir = $self->{tree_data}->{chm_subdirs}->{ lc($chm_name) };
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
		$link = $self->{chm_root}.$link;
		
		$page_path = "ROOT";
	}
	
	my $root_relative_path = App::ChmWeb::Util::doc_relative_path_to_root_relative_path($link, $page_path);
	if(defined $root_relative_path)
	{
		# Links extracted from the original HTML are mapped via link_map to resolve any
		# differences in case between the document/filesystem, links generated internally
		# (e.g. to ALink/KLink multi-choice pages) are already correctly-cased and will
		# not in link_map, so bypass this.
		
		my $resolved_link = $self->{link_map}->{$root_relative_path};
		
		if(defined $resolved_link)
		{
			my $link_target = undef;
			my $link_class = undef;
			
			my $link_page_data = $self->{tree_data}->get_page_data($resolved_link);
			if(defined $link_page_data)
			{
				# If the link points to a PAGE in the collection, then we have
				# some extra special-ness to apply...
				#
				# - If the page exists in the ToC, the target is set to _top so
				#   that the wrapper page replaces the current wrapper page.
				#
				# - If the page ISN'T in the ToC, then we keep the target in the
				#   content iframe and redirect the URL to the content page.
				
				my @link_toc_path = $link_page_data->toc_path();
				if(@link_toc_path)
				{
					$link_target = "_top";
				}
				else{
					$resolved_link =~ s/\.(\w+)$/.content.$1/;
				}
			}
			
			my $doc_relative_link = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($resolved_link, $self->{filename});
			return ($doc_relative_link.$anchor, $link_target, $link_class);
		}
		else{
			warn "'$link' appears to be broken at ".$self->{filename}." line $line_num\n";
			return (undef, undef, undef);
		}
	}
	else{
		warn "'$link' is outside of tree at ".$self->{filename}." line $line_num\n";
		return (undef, undef, undef);
	}
}

sub _resolve_link_for_object
{
	my ($self, $object) = @_;
	
	my $link;
	
	my $command = $object->get_parameter("Command") // "<UNSET>";
	
	if($command =~ m/^ALink(,.*)?/)
	{
		my $fallback_link = $object->get_parameter("DEFAULTTOPIC");
		my $chm_name      = $object->get_parameter("ITEM1") || $self->{page_data}->chm_name();
		my $alink_name    = $object->get_parameter("ITEM2");
		
		my @topics = $self->{tree_data}->{chi}->get_alink_by_key($alink_name);
		
		if((scalar @topics) == 1)
		{
			# There is one topic for this ALink, jump straight to it.
			
			if(defined $topics[0]->{Local})
			{
				my $rel_target_path = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($topics[0]->{Local}, $self->{filename});
				$link = $rel_target_path;
			}
			elsif(defined $topics[0]->{URL})
			{
				$link = $topics[0]->{URL};
			}
			else{
				warn "Not a local topic '$alink_name' for ALink object at ".$self->{filename}." line ".$object->{start_line}."\n";
				$link = $fallback_link if(defined $fallback_link);
			}
		}
		elsif((scalar @topics) == 0)
		{
			# No matches for this ALink, use the fallback URL.
			
			warn "Couldn't find ALink '$alink_name' in '$chm_name' for object at ".$self->{filename}." line ".$object->{start_line}."\n";
			$link = $fallback_link if(defined $fallback_link);
		}
		else{
			# There are multiple topics for this ALink, go to a page
			
			if(defined $self->{tree_data}->{alink_page_map}->{$alink_name})
			{
				$link = $self->{tree_data}->{alink_page_map}->{$alink_name};
				$link = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($link, $self->{filename});
				
				return ($link, undef, "chmweb-multi-link");
			}
			else{
				$link = $fallback_link if(defined $fallback_link);
			}
		}
	}
	else{
		warn "Unimplemented Command '$command' in object at ".$self->{filename}." line ".$object->{start_line}."\n";
	}
	
	my $link_target = undef;
	my $link_class = undef;
	
	if(defined $link)
	{
		($link, $link_target, $link_class) = $self->_resolve_link($link, $object->{start_line});
	}
	
	return ($link, $link_target, $link_class);
}

package App::ChmWeb::ContentPageWriter::Handler;

sub new
{
	my ($class, $callbacks, $parser) = @_;
	
	my $self = bless({ callbacks => $callbacks, parser => $parser, processing_script => 0 }, $class);
	return $self;
}

sub start_element
{
	my ($self, $elem) = @_;
	
	if($self->{processing_script})
	{
		return;
	}
	
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
	
	if(fc($elem->{Name}) eq fc("script"))
	{
		$self->{processing_script} = 1;
	}
}

sub end_element
{
	my ($self, $elem) = @_;
	
	if(fc($elem->{Name}) eq fc("script"))
	{
		$self->{processing_script} = 0;
	}
}

1;
