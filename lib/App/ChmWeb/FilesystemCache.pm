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
	return bless({ e => {}, d => {}, dir_children_fc => {} }, $class);
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
	$self->{dir_children_fc} = {};
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
	
	my ($path_dir, $path_name) = ($path =~ m/^(.*)\/([^\/]+)$/);
	if(defined $path_name)
	{
		if(defined $self->{dir_children_fc}->{$path_dir})
		{
			# dir_children_fc() has been called on the parent directory at some point,
			# we may be able to find the answer in its cache rather than doing a stat
			# call through the -e operator...
			
			my $dir_fc_child = $self->{dir_children_fc}->{$path_dir}->{ fc($path_name) };
			if(defined $dir_fc_child)
			{
				if($dir_fc_child eq $path_name)
				{
					return $self->{e}->{$path} = 1;
				}
				else{
					# There is a differently-cased version of the requested
					# name in the parent directory. Fall back to -e operator.
				}
			}
			else{
				return $self->{e}->{$path} = 0;
			}
		}
	}
	
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

=head2 dir_children_fc($path)

Returns a hashref containing the case-folded names of all files/directories
in the given directory.

The hash key is the case folded name and the value is the real name, this is to
allow resolving case-insensitive paths on a case-sensitive filesystem. If there
are multiple cases of the name in the same directory any ONE will be returned.

The hash is returned directly from the cache for performance - do not modify it!

If the directory isn't accessible, undef is returned.

=cut

sub dir_children_fc
{
	my ($self, $dir) = @_;
	
	$self = $instance unless(ref $self);
	
	my $d_hash = $self->{dir_children_fc}->{$dir};
	
	unless(defined $d_hash)
	{
		if(opendir(my $d, $dir))
		{
			$d_hash = $self->{dir_children_fc}->{$dir} = { map { fc($_) => $_ } readdir($d) };
		}
		else{
			warn "$dir: $!";
		}
	}
	
	return $d_hash;
}
