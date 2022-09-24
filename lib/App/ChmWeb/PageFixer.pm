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

package App::ChmWeb::PageFixer;

use HTML::Entities;
use SGML::Parser::OpenSP;

use App::ChmWeb::Util;

sub new
{
	my ($class) = @_;
	
	my $self = bless({
		content => undef,
		filename => undef,
	}, $class);
	
	return $self;
}

sub load_content
{
	my ($self, $filename) = @_;
	
	open(my $file, "<", $filename) or die "$filename: $!\n";
	binmode($file);
	
	$self->{content} = do { local $/; <$file>; };
	$self->{filename} = $filename;
	$self->{root_directory} = "";
}

sub write_content
{
	my ($self, $filename) = @_;
	
	open(my $file, ">", $filename) or die "$filename: $!\n";
	binmode($file);
	
	print {$file} $self->{content};
	
	close($file);
}

sub set_content
{
	my ($self, $content, $filename, $root_directory) = @_;
	
	$self->{content} = $content;
	$self->{filename} = $filename;
	
	if(defined $root_directory)
	{
		if($root_directory !~ m/\/$/)
		{
			$root_directory .= "/";
		}
		
		$self->{root_directory} = $root_directory;
	}
	else{
		$self->{root_directory} = "";
	}
}

sub get_content
{
	my ($self) = @_;
	return $self->{content};
}

sub fix_image_paths
{
	my ($self) = @_;
	
	my @replacements = ();
	
	$self->_parse_content(
		start_element => sub
		{
			my ($elem_name, $elem_attributes, $location) = @_;
			
			if(lc($elem_name) eq "img")
			{
				my ($src_attrib) = grep { lc($_->{name}) eq "src" } @$elem_attributes;
				
				if(defined $src_attrib && defined $src_attrib->{value})
				{
					my $old_src = $src_attrib->{value};
					my $fixed_src = App::ChmWeb::Util::resolve_link($self->{root_directory}, $self->{filename}, $old_src);
					
					if($fixed_src ne $old_src)
					{
						# Need to fix this up
						
						$src_attrib->{value} = $fixed_src;
						
						push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
					}
				}
			}
		});
	
	$self->_do_content_replacements(\@replacements);
}

sub fix_absolute_links
{
	my ($self) = @_;
	
	my @replacements = ();
	
	$self->_parse_content(
		start_element => sub
		{
			my ($elem_name, $elem_attributes, $location) = @_;
			
			if(lc($elem_name) eq "a")
			{
				my ($href_attrib) = grep { lc($_->{name}) eq "href" } @$elem_attributes;
				
				if(defined $href_attrib && defined $href_attrib->{value})
				{
					my $old_href = $href_attrib->{value};
					my $fixed_href = App::ChmWeb::Util::resolve_link($self->{root_directory}, $self->{filename}, $old_href);
					
					if($old_href ne $fixed_href)
					{
						# Need to fix this up
						
						$href_attrib->{value} = $fixed_href;
						
						push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
					}
				}
			}
		});
	
	$self->_do_content_replacements(\@replacements);
}

sub set_default_link_target
{
	my ($self, $link_target) = @_;
	
	my @replacements = ();
	
	$self->_parse_content(
		start_element => sub
		{
			my ($elem_name, $elem_attributes, $location) = @_;
			
			if(lc($elem_name) eq "a")
			{
				my ($href_attrib) = grep { lc($_->{name}) eq "href" } @$elem_attributes;
				my ($target_attrib) = grep { lc($_->{name}) eq "target" } @$elem_attributes;
				
				if(defined($href_attrib) && !defined($target_attrib))
				{
					push(@$elem_attributes, {
						name => "TARGET",
						value => $link_target,
					});
					
					push(@replacements, $self->_tag_replacement($elem_name, $elem_attributes, $location));
				}
			}
		});
	
	$self->_do_content_replacements(\@replacements);
}

sub _parse_content
{
	my ($self, %callbacks) = @_;
	
	my $p = SGML::Parser::OpenSP->new();
	my $h = App::ChmWeb::PageFixer::Handler->new(\%callbacks, $p);
	
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
		my $new_content = $replacement->{new_content};
		
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

package App::ChmWeb::PageFixer::Handler;

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
