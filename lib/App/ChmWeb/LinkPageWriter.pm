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

sub write_link_pages
{
	my ($output_dir, $links) = @_;
	
	my %link_file_map = ();
	
	foreach my $link_name(sort keys %$links)
	{
		my $s_link_name = _sanitise_name($link_name);
		my $output_name = "${s_link_name}.html";
		
		for(my $i = 1; -e "${output_dir}/${output_name}"; ++$i)
		{
			$output_name = "${s_link_name}.${i}.html";
		}
		
		open(my $fh, ">", "${output_dir}/${output_name}")
			or die "Cannot open ${output_dir}/${output_name}: $!";
		
		print {$fh} <<EOF;
<html>
<head>
<title>Topics</title>
</head>
<body>
<ul class="chmweb-links">
EOF
		
		foreach my $topic(@{ $links->{$link_name} })
		{
			if(defined $topic->{Local})
			{
				print {$fh} "<li><a href=\"", encode_entities($topic->{Local}), "\" target=\"_top\">", encode_entities($topic->{Name} // basename($topic->{Local})), "</a></li>\n";
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
		
		$link_file_map{ fc($link_name) } = $output_name;
	}
	
	return \%link_file_map;
}

sub _sanitise_name
{
	my ($name) = @_;
	
	$name =~ s/[^a-z0-9]+/_/ig;
	$name =~ tr/A-Z/a-z/;
	
	return $name;
}

1;
