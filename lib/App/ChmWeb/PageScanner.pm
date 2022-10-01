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

sub scan_page
{
	my ($class, $filename) = @_;
	
	my $p = SGML::Parser::OpenSP->new();
	my $h = App::ChmWeb::PageScanner::Handler->new();
	
	$p->catalogs(qw(xhtml.soc));
	$p->warnings(qw(xml valid));
	$p->handler($h);
	
	$p->parse($filename);
	
	return {
		a_names     => $h->{a_names},
		asset_links => $h->{asset_links},
		page_links  => $h->{page_links},
		title       => $h->{title},
	};
}

package App::ChmWeb::PageScanner::Handler;

sub new
{
	my ($class) = @_;
	
	return bless({
		a_names     => [],
		asset_links => [],
		page_links  => [],
		title       => undef,
		processing_title => 0,
		
	}, $class);
}

sub start_element
{
	my ($self, $elem) = @_;
	
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
}

sub end_element
{
	my ($self, $elem) = @_;
	
	if(fc($elem->{Name}) eq fc("title"))
	{
		$self->{processing_title} = 0;
	}
}

sub data
{
	my ($self, $elem) = @_;
	
	if($self->{processing_title})
	{
		$self->{title} //= "";
		$self->{title} .= $elem->{Data};
	}
}

1;
