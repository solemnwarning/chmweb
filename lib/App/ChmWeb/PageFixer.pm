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
	my ($self, $content, $filename) = @_;
	
	$self->{content} = $content;
	$self->{filename} = $filename;
}

sub get_content
{
	my ($self) = @_;
	return $self->{content};
}

sub fix_absolute_image_paths
{
	my ($self) = @_;
	
	my @replacements = ();
	
	$self->_parse_content(
		start_element => sub
		{
			my ($elem_name, $elem_attributes, $location) = @_;
			
			if(lc($elem_name) eq "img")
			{
				my ($src_attrib_name) = grep { lc($_) eq "src" }
					keys(%$elem_attributes);
				
				if(defined $src_attrib_name
					&& defined($elem_attributes->{$src_attrib_name})
					&& $elem_attributes->{$src_attrib_name} =~ m/^\//)
				{
					# Need to fix this up
					
					my %new_attribs = %$elem_attributes;
					$new_attribs{$src_attrib_name} = App::ChmWeb::Util::resolve_link($self->{filename}, $elem_attributes->{src});
					
					push(@replacements, $self->_tag_replacement($elem_name, \%new_attribs, $location));
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
				my ($href_attrib_name) = grep { lc($_) eq "href" }
					keys(%$elem_attributes);
				
				if(defined $href_attrib_name
					&& defined($elem_attributes->{$href_attrib_name})
					&& $elem_attributes->{$href_attrib_name} =~ m/^\//)
				{
					# Need to fix this up
					
					my %new_attribs = %$elem_attributes;
					$new_attribs{$href_attrib_name} = App::ChmWeb::Util::resolve_link($self->{filename}, $elem_attributes->{href});
					
					push(@replacements, $self->_tag_replacement($elem_name, \%new_attribs, $location));
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
				my ($target_attrib_name) = grep { lc($_) eq "target" }
					keys(%$elem_attributes);
				
				unless(defined $target_attrib_name)
				{
					my %new_attribs = %$elem_attributes;
					$new_attribs{target} = $link_target;
					
					push(@replacements, $self->_tag_replacement($elem_name, \%new_attribs, $location));
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
	return join(" ", "<${elem_name}", map { "$_=\"".encode_entities($elem_attributes->{$_})."\"" } keys(%$elem_attributes)).">";
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
		my %attributes = ();
		
		foreach my $attr(values(%{ $elem->{Attributes} }))
		{
			if($attr->{Type} eq "cdata" && (scalar @{ $attr->{CdataChunks} }) == 0)
			{
				$attributes{ $attr->{Name} } = undef;
			}
			elsif($attr->{Type} eq "cdata" && (scalar @{ $attr->{CdataChunks} }) == 1)
			{
				$attributes{ $attr->{Name} } = $attr->{CdataChunks}->[0]->{Data};
			}
		}
		
		$self->{callbacks}->{start_element}->($elem->{Name}, \%attributes, $self->{parser}->get_location());
	}
}

1;
