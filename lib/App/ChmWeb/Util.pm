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

package App::ChmWeb::Util;

use File::Basename;

sub resolve_link
{
	my ($local_document, $link) = @_;
	
	if($link =~ m/^#/)
	{
		# Link points to an anchor in this document.
		# TODO: Prevent target rewrite in this case...
		return $link;
	}
	
	if($link =~ m/^\w+:/)
	{
		# Link points at some other site (it starts with a protocol).
		return $link;
	}
	
	my $orig_link = $link;
	
	my $anchor = ($link =~ m/(#.*)$/);
	$link =~ s/(#.*)$//;
	
	if($link =~ m/^\//)
	{
		# Link is absolute - convert to be relative to current document
		
		my @local_dir = grep { $_ ne "" } split(m/\//, $local_document);
		pop(@local_dir);
		
		my @link_dir = grep { $_ ne "" } split(m/\//, $link);
		my $link_file = pop(@link_dir);
		
		my @new_link_dir = ();
		
		# Walk up from current directory until reaching a common ancestor with link
		
		for(my ($i, $flag) = (0, 0); $i < (scalar @local_dir); ++$i)
		{
			if($flag || $i > $#link_dir || $local_dir[$i] ne $link_dir[$i])
			{
				push(@new_link_dir, "..");
				$flag = 1;
			}
		}
		
		# Walk down from common ancestor into link directory
		
		for(my ($i, $flag) = (0, 0); $i < (scalar @link_dir); ++$i)
		{
			if($flag || $i > $#local_dir || $local_dir[$i] ne $link_dir[$i])
			{
				push(@new_link_dir, $link_dir[$i]);
				$flag = 1;
			}
		}
		
		$link = join("/", @new_link_dir, $link_file);
	}
	
	# Resolve mismatched case in local links
	my $resolved_link = resolve_mixed_case_path($link, dirname($local_document));
	if($resolved_link)
	{
		$link = $resolved_link;
	}
	else{
		warn "WARNING: Link '$orig_link' in $local_document appears to be broken\n";
	}
	
	# Re-instate anchor (if present).
	$link .= $anchor;
	
	return $link;
}

sub resolve_mixed_case_path
{
	my ($path, $prefix) = @_;
	
	if(-e $path)
	{
		# Path exists and is already cased correctly.
		return $path;
	}
	
	if(defined $prefix)
	{
		$prefix .= "/";
	}
	else{
		$prefix = "";
	}
	
	my @in_parts = split(m/\//, $path);
	
	my @resolved_parts = ();
	
	P: foreach my $p(@in_parts)
	{
		my $p_parent = $prefix.join("/", @resolved_parts);
		my $p_path = $prefix.join("/", @resolved_parts, $p);
		
		if(-e $p_path)
		{
			push(@resolved_parts, $p);
		}
		else{
			if(opendir(my $d, $p_parent))
			{
				foreach my $sibling_name(readdir($d))
				{
					if(lc($sibling_name) eq lc($p))
					{
						push(@resolved_parts, $sibling_name);
						next P;
					}
				}
			}
			else{
				warn "$p_parent: $!\n";
			}
			
			return undef;
		}
	}
	
	return join("/", @resolved_parts);
}

sub find_hhc_in
{
	my ($path) = @_;
	
	opendir(my $d, $path) or die "$path: $!";
	my @hhc_names = grep { $_ =~ m/\.hhc$/i && -f "$path/$_" } readdir($d);
	
	if((scalar @hhc_names) == 1)
	{
		return $hhc_names[0];
	}
	else{
		die "Unable to find HHC file in $path\n";
	}
}

1;
