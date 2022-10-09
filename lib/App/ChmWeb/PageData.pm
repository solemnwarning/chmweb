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

package App::ChmWeb::PageData;

=head1 NAME

App::ChmWeb::PageData - Metadata for a single page

=head1 DESCRIPTION

Metadata for a single scanned page.

Instances of this class are returned by App::ChmWeb::PageScanner and inside the
App::ChmWeb::TreeData object returned by App::ChmWeb::TreeScanner.

=head1 METHODS

=cut

use Hash::Util qw(lock_keys);

sub new
{
	my ($class) = @_;
	
	my $self = bless({
			chm_name  => undef, # "foo.chm"
			page_path => undef, # "foo/html/bar.htm"
			toc_path  => undef, # [ 0, 1, 2 ]
			
			asset_links  => [],
			page_links   => [],
			title        => undef,
			objects      => [],
		}, $class);
	
	lock_keys(%$self);
	
	return $self;
}

=head2 chm_name()

Returns the (base)name of the CHM file this page was found in.

=cut

sub chm_name
{
	my ($self) = @_;
	return $self->{chm_name};
}

=head2 page_path()

Returns the path to this page relative to the output directory.

=cut

sub page_path
{
	my ($self) = @_;
	return $self->{page_path};
}

=head2 toc_path()

Returns the path to this page in the ToC as a list of indices.

Returns empty list if not in the ToC.

=cut

sub toc_path
{
	my ($self) = @_;
	
	return @{ $self->{toc_path} // [] };
}

=head2 title()

Returns the page title (undef if none set).

=cut

sub title
{
	my ($self) = @_;
	return $self->{title};
}

=head2 objects()

Returns a list of any <OBJECT> elements in the page (as App::ChmWeb::PageData::Object objects).

=cut

sub objects
{
	my ($self) = @_;
	return @{ $self->{objects} };
}

1;
