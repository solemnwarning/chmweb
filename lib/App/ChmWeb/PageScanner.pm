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

package App::ChmWeb::PageScanner;

use HTML::Entities;
use SGML::Parser::OpenSP;

use App::ChmWeb::PageData;
use App::ChmWeb::PageData::Object;

sub scan_page
{
	my ($class, $filename) = @_;
	
	my $p = SGML::Parser::OpenSP->new();
	my $h = App::ChmWeb::PageScanner::Handler->new($p);
	
	$p->catalogs(qw(xhtml.soc));
	$p->warnings(qw(xml valid));
	$p->handler($h);
	
	$p->parse($filename);
	
	my $data = App::ChmWeb::PageData->new();
	
	   $data->{title}          =    $h->{title};
	@{ $data->{anchor_names} } = @{ $h->{a_names} };
	@{ $data->{asset_links}  } = @{ $h->{asset_links} };
	@{ $data->{page_links}   } = @{ $h->{page_links} };
	@{ $data->{objects}      } = @{ $h->{objects} };
	
	# TODO: Filter dirs/not-pages/etc out of page_links
	
	return $data;
}

package App::ChmWeb::PageScanner::Handler;

use SGML::Parser::OpenSP::Tools;

sub new
{
	my ($class, $parser) = @_;
	
	return bless({
		parser      => $parser,
		a_names     => [],
		asset_links => [],
		page_links  => [],
		title       => undef,
		processing_title => 0,
		processing_script => 0,
		current_object => undef,
		objects     => [],
	}, $class);
}

sub start_element
{
	my ($self, $elem) = @_;
	
	if($self->{processing_script})
	{
		return;
	}
	
	my @attributes = ();
	
	foreach my $attr(sort { $a->{Index} <=> $b->{Index} } values(%{ $elem->{Attributes} }))
	{
		if(SGML::Parser::OpenSP::Tools::defaulted_attribute($attr))
		# if(defined($attr->{Defaulted}) && $attr->{Defaulted} eq "definition")
		{
			# Not set in markup - implied by spec.
			next;
		}
		
# 		if($attr->{Type} eq "cdata")
# 		{
# 			if((scalar @{ $attr->{CdataChunks} }) == 0)
# 			{
# 				push(@attributes, {
# 					name => $attr->{Name},
# 				});
# 			}
# 			else{
# 				push(@attributes, map { {
# 					name => $attr->{Name},
# 					value => $_->{Data},
# 				} } @{ $attr->{CdataChunks} });
# 			}
# 		}
		
		push(@attributes, {
			name => $attr->{Name},
			value => (scalar SGML::Parser::OpenSP::Tools::attribute_value($attr)),
		});
	}
	
	if(fc($elem->{Name}) eq fc("a"))
	{
		my ($name_attr) = grep { fc($_->{name}) eq fc("name") } @attributes;
		if(defined($name_attr) && defined($name_attr->{value}))
		{
			push(@{ $self->{a_names} }, $name_attr->{value});
		}
		
		my ($href_attr) = grep { fc($_->{name}) eq fc("href") } @attributes;
		if(defined($href_attr) && defined($href_attr->{value}))
		{
			push(@{ $self->{page_links} }, $href_attr->{value});
		}
	}
	elsif(fc($elem->{Name}) eq fc("img"))
	{
		my ($src_attr) = grep { fc($_->{name}) eq fc("src") } @attributes;
		if(defined($src_attr) && defined($src_attr->{value}))
		{
			push(@{ $self->{asset_links} }, $src_attr->{value});
		}
	}
	elsif(fc($elem->{Name}) eq fc("title"))
	{
		$self->{processing_title} = 1;
	}
	elsif(fc($elem->{Name}) eq fc("script"))
	{
		$self->{processing_script} = 1;
	}
	elsif(fc($elem->{Name}) eq fc("object"))
	{
		$self->{current_object} = App::ChmWeb::PageData::Object->new();
		
		foreach my $attr(@attributes)
		{
			$self->{current_object}->add_attribute($attr->{name}, $attr->{value});
		}
	}
	elsif(fc($elem->{Name}) eq fc("param"))
	{
		if(defined($self->{current_object}))
		{
			my ($name_attr) = grep { fc($_->{name}) eq fc("name") } @attributes;
			my ($value_attr) = grep { fc($_->{name}) eq fc("value") } @attributes;
			
			if(defined($name_attr) && defined($name_attr->{value}))
			{
				$self->{current_object}->add_parameter($name_attr->{value}, ($value_attr // {})->{value});
			}
			else{
				my $loc = $self->{parser}->get_location();
				warn "Encountered <PARAM> tag with no 'NAME' attribute at ".$loc->{FileName}." line ".$loc->{LineNumber}."\n";
			}
		}
	}
}

sub end_element
{
	my ($self, $elem) = @_;
	
	if(fc($elem->{Name}) eq fc("title"))
	{
		$self->{processing_title} = 0;
	}
	elsif(fc($elem->{Name}) eq fc("script"))
	{
		$self->{processing_script} = 0;
	}
	elsif(fc($elem->{Name}) eq fc("object") && defined($self->{current_object}))
	{
		my $object = $self->{current_object};
		$self->{current_object} = undef;
		
		if($object->is_hh_activex_control())
		{
			# This is a HTML Help ActiveX control.
			
			my ($command_param) = $object->get_parameter("Command");
			my ($command, @command_extra) = split(m/,/, ($command_param // ""));
			
			if($command eq "ALink")
			{
				my $default_topic = $object->get_parameter("Default Topic");
				if(defined $default_topic)
				{
					push(@{ $self->{page_links} }, $default_topic);
				}
			}
		}
		
		push(@{ $self->{objects} }, $object);
	}
}

sub data
{
	my ($self, $elem) = @_;
	
	if($self->{processing_script})
	{
		return;
	}
	
	if($self->{processing_title})
	{
		$self->{title} //= "";
		$self->{title} .= $elem->{Data};
	}
}

1;
