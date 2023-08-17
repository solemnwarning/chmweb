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

package App::ChmWeb::FilesystemCache;

=head1 NAME

App::ChmWeb::FilesystemCache - Cached filesystem operations

=head1 DESCRIPTION

The methods in this class allow caching the result of repeated filesystem
operations such as checking for a file or reading a directory's contents.

Unless otherwise stated, methods can be called as class methods to use a
singleton cache, or as instance methods to use an internal cache.

The caches here last indefinitely - if the filesystem changes after a cache is
initialised you must clear the cache manually.

=head1 METHODS

=cut

# Singleton instance used when methods are invoked as class methods.
my $instance = App::ChmWeb::FilesystemCache->new();

=head2 new()

Constructs a new FilesystemCache instance.

=cut

sub new
{
	my ($class) = @_;
	return bless({ e => {}, d => {}, dir_children => {}, insensitive_children => {} }, $class);
}

=head2 reset()

Clears any caches from this instance (or the singleton).

=cut

sub reset
{
	my ($self) = @_;
	
	$self = $instance unless(ref $self);
	
	$self->{e} = {};
	$self->{d} = {};
	$self->{dir_children} = {};
	$self->{insensitive_children} = {};
}

=head2 e($path)

Returns true if the given path exists (like the -e operator).

=cut

sub e
{
	my ($self, $path) = @_;
	
	$self = $instance unless(ref $self);
	
	if(defined $self->{e}->{$path})
	{
		return $self->{e}->{$path};
	}
	
# 	my ($path_dir, $path_name) = ($path =~ m/^(.*)\/([^\/]+)$/);
# 	if(defined $path_name)
# 	{
# 		if(defined $self->{dir_children_fc}->{$path_dir})
# 		{
# 			# dir_children_fc() has been called on the parent directory at some point,
# 			# we may be able to find the answer in its cache rather than doing a stat
# 			# call through the -e operator...
# 			
# 			my $dir_fc_child = $self->{dir_children_fc}->{$path_dir}->{ fc($path_name) };
# 			if(defined $dir_fc_child)
# 			{
# 				if($dir_fc_child eq $path_name)
# 				{
# 					return $self->{e}->{$path} = 1;
# 				}
# 				else{
# 					# There is a differently-cased version of the requested
# 					# name in the parent directory. Fall back to -e operator.
# 				}
# 			}
# 			else{
# 				return $self->{e}->{$path} = 0;
# 			}
# 		}
# 	}
	
	return $self->{e}->{$path} //= !!(-e $path);
}

=head2 d($path)

Returns true if the given path exists and is a directory (like the -d operator).

=cut

sub d
{
	my ($self, $path) = @_;
	
	$self = $instance unless(ref $self);
	
	return $self->{d}->{$path} //= !!(-d $path);
}

=head2 dir_children($dir)

Returns the names of any child files/directories under C<$dir>, excluding
the C<.> and C<..> special directories.

=cut

sub dir_children
{
	my ($self, $dir) = @_;
	
	$self = $instance unless(ref $self);
	
	my $children = $self->{dir_children}->{$dir};
	
	unless(defined $children)
	{
		if(opendir(my $d, $dir))
		{
			$children = $self->{dir_children}->{$dir} = [ grep { $_ ne "." && $_ ne ".." } readdir($d) ];
		}
		else{
			warn "$dir: $!";
			return;
		}
	}
	
	return @$children;
}

=head2 insensitive_children($dir, $name)

Returns the names of any child files/directories under C<$dir> whose names
case-insensitively match C<$name>.

=cut

sub insensitive_children
{
	my ($self, $dir, $name) = @_;
	
	$self = $instance unless(ref $self);
	
	my $cache_key = "${dir}\0".fc($name);
	my $children = $self->{insensitive_children}->{$cache_key};
	
	unless(defined $children)
	{
		$children = $self->{insensitive_children}->{$cache_key} = [
			grep { fc($_) eq fc($name) } $self->dir_children($dir)
		];
	}
	
	return @$children;
}
