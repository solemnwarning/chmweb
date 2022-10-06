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
				my $replace_tag = 0;
				
				if(defined($href_attr) && defined($href_attr->{value}))
				{
					my $old_href = $href_attr->{value};
					my $fixed_href = $self->_resolve_link($old_href, $location);
					
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
					my $fixed_src = $self->_resolve_link($old_src, $location);
					
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
	my ($self, $link, $location) = @_;
	
	my $page_path = $self->{filename};
	
	if($link =~ m/^JavaScript:(\w+)\.Click()/)
	{
		# This is probably a link using the HTML Help ActiveX control.
		# We need to resolve it to a plain link...
		
		my $object_id = $1;
		my ($object) = grep { ($_->get_attribute("id") // "") eq $object_id } $self->{page_data}->objects();
		
		if(defined($object) && $object->is_hh_activex_control())
		{
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
						$link = "${rel_target_path}#${alink_name}";
					}
					else{
						warn "Not a local topic '$alink_name' for ALink $object_id at ".$self->{filename}." line ".$location->{LineNumber}."\n";
						$link = $fallback_link if(defined $fallback_link);
					}
				}
				elsif((scalar @topics) == 0)
				{
					# No matches for this ALink, use the fallback URL.
					
					warn "Couldn't find ALink '$alink_name' in '$chm_name' for $object_id at ".$self->{filename}." line ".$location->{LineNumber}."\n";
					$link = $fallback_link if(defined $fallback_link);
				}
				else{
					# There are multiple topics for this ALink, go to a page
					# listing them. TODO: JS-spawned iframe at cursor...
					
					if(defined $self->{tree_data}->{alink_page_map}->{$alink_name})
					{
						$link = $self->{tree_data}->{alink_page_map}->{$alink_name};
						$link = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($link, $self->{filename});
						
						return $link;
					}
					
					$link = $fallback_link if(defined $fallback_link);
				}
			}
			else{
				warn "Unimplemented Command '$command' in $object_id at ".$self->{filename}." line ".$location->{LineNumber}."\n";
			}
		}
		else{
			warn "'$link' refers to unknown ActiveX object at ".$self->{filename}." line ".$location->{LineNumber}."\n";
		}
	}
	
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
	my $anchor = "";
	if($link =~ m/(#.*)$/s)
	{
		$anchor = $1;
		$link =~ s/#.*$//s;
	}
	
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
			my $doc_relative_link = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($resolved_link, $self->{filename});
			return $doc_relative_link.$anchor;
		}
		else{
			warn "'$link' appears to be broken at ".$self->{filename}." line ".$location->{LineNumber}."\n";
			return "#";
		}
	}
	else{
		warn "'$link' is outside of tree at ".$self->{filename}." line ".$location->{LineNumber}."\n";
		return "#";
	}
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
