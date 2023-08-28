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

package App::ChmWeb::LinkPageWriter;

use Carp qw(confess);
use File::Basename;
use HTML::Entities;

use App::ChmWeb::Util;

sub new
{
	my ($class, $output_dir, $page_prefix, $links) = @_;
	
	return bless({
		output_dir  => $output_dir,
		page_prefix => $page_prefix,
		links       => $links,
		pages       => {},
	}, $class);
}

sub get_link_page
{
	my ($self, $link_names) = @_;
	
	my @known_link_names = sort grep { defined($self->{links}->{$_}) } map { fc($_) } @$link_names;
	return unless(@known_link_names);
	
	my $page_key = join(";", @known_link_names);
	
	unless(defined $self->{pages}->{$page_key})
	{
		# Make a sanitised name for the page and clamp it to a sensible length.
		my $s_link_name = join("-", map { _sanitise_name($_) } @known_link_names);
		$s_link_name = substr($s_link_name, 0, 48);
		
		my $page_name = $self->{page_prefix}."${s_link_name}.html";
		
		for(my $i = 1; -e $self->{output_dir}."/${page_name}"; ++$i)
		{
			$page_name = $self->{page_prefix}."${s_link_name}.${i}.html";
		}
		
		my @topics = map { @{ $self->{links}->{ fc($_) } } }
			@known_link_names;
		
		$self->_write_link_page($page_name, \@topics);
		
		$self->{pages}->{$page_key} = $page_name;
	}
	
	return $self->{pages}->{$page_key};
}

sub _write_link_page
{
	my ($self, $page_name, $topics) = @_;
	
	open(my $fh, ">", $self->{output_dir}."/${page_name}")
		or die "Cannot open ".$self->{output_dir}."/${page_name}: $!";
	
	print {$fh} <<EOF;
<html>
<head>
<title>Topics</title>
</head>
<body>
<ul class="chmweb-links">
EOF
		
		foreach my $topic(@$topics)
		{
			if(defined $topic->{Local})
			{
				my $rel_path = App::ChmWeb::Util::root_relative_path_to_doc_relative_path($topic->{Local}, $page_name);
				print {$fh} "<li><a href=\"", encode_entities($rel_path), "\" target=\"_top\">", encode_entities($topic->{Name} // basename($topic->{Local})), "</a></li>\n";
			}
			else{
				print {$fh} "<li><a href=\"", encode_entities($topic->{URL}), "\" target=\"_top\">", encode_entities($topic->{Name} // $topic->{URL}), "</a></li>\n";
			}
		}
		
		print {$fh} <<EOF;
</ul>
</body>
</html>
EOF
}

sub _sanitise_name
{
	my ($name) = @_;
	
	$name =~ s/[^a-z0-9]+/_/ig;
	$name =~ tr/A-Z/a-z/;
	
	return $name;
}

1;
