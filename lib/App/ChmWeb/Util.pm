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

=head1 NAME

App::ChmWeb::Util

=head1 METHODS

=cut

use strict;
use warnings;

use feature qw(fc);

package App::ChmWeb::Util;

use File::Basename;

sub doc_relative_path_to_root_relative_path
{
	my ($rel_path, $doc_path) = @_;
	
	my @rel_dir = grep { $_ ne "." && $_ ne "" } split(m/\//, $rel_path);
	my $rel_name = pop(@rel_dir);
	
	my @doc_dir = grep { $_ ne "." && $_ ne "" } split(m/\//, $doc_path);
	my $doc_name = pop(@doc_dir);
	
	my @out_path = (@doc_dir);
	
	foreach my $rel_dir_elem(@rel_dir)
	{
		if($rel_dir_elem eq "..")
		{
			if(@out_path)
			{
				pop(@out_path);
			}
			else{
				# Path escapes from root directory.
				return undef;
			}
		}
		else{
			push(@out_path, $rel_dir_elem);
		}
	}
	
	push(@out_path, $rel_name);
	
	if(grep { !defined($_) } @out_path)
	{
		die "doc_relative_path_to_root_relative_path('$rel_path', '$doc_path'";
	}
	
	return join("/", @out_path);
}

sub root_relative_path_to_doc_relative_path
{
	my ($rel_path, $doc_path) = @_;
	
	my @rel_dir = grep { $_ ne "." && $_ ne "" } split(m/\//, $rel_path);
	my $rel_name = pop(@rel_dir);
	
	my @doc_dir = grep { $_ ne "." && $_ ne "" } split(m/\//, $doc_path);
	my $doc_name = pop(@doc_dir);
	
	while(@doc_dir && @rel_dir && $doc_dir[0] eq $rel_dir[0])
	{
		shift(@rel_dir);
		shift(@doc_dir);
	}
	
	my @out_path = (
		(map { ".." } @doc_dir),
		@rel_dir,
		$rel_name);
	
	return join("/", @out_path);
}

=head2 resolve_mixed_case_path($path, $prefix)

Canonicalises a mixed-case path to match the case of the filename that actually
exists on the filesystem.

$prefix is tacked on the front of the path for all filesystem operations, but
will not be canonicalised or included in the returned path.

Returns undef if the target path cannot be found.

=cut

sub resolve_mixed_case_path
{
	my ($path, $prefix) = @_;
	
	if(defined $prefix)
	{
		$prefix .= "/";
	}
	else{
		$prefix = "";
	}
	
	if(-e $prefix.$path)
	{
		# Path exists and is already cased correctly.
		return $path;
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
			if(!-d $p_parent)
			{
				return undef;
			}
			
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
