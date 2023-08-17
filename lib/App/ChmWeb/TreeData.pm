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

package App::ChmWeb::TreeData;

=head1 NAME

App::ChmWeb::TreeData - Accumulated data from CHM files

=head1 DESCRIPTION

Holds all metadata gathered from one or more CHM files by the
App::ChmWeb::TreeScanner class.

=head1 METHODS

=cut

use Hash::Util qw(lock_keys);

sub new
{
	my ($class) = @_;
	
	my $self = bless({
			asset_links => undef,
			page_links  => undef,
			
			# PageData objects keyed by page path
			pages => undef,
			
			toc => undef,
			chi => undef,
			
			alink_page_map => undef,
			klink_page_map => undef,
		}, $class);
	
	lock_keys(%$self);
	
	return $self;
}

=head2 get_pages()

Get the App::ChmWeb::PageData object for all pages in the output directory.

=cut

sub get_pages
{
	my ($self) = @_;
	
	return values(%{ $self->{pages} });
}

=head2 get_page_paths()

Returns the path of each page in the output directory.

=cut

sub get_page_paths
{
	my ($self) = @_;
	
	my @page_paths = keys(%{ $self->{pages} });
	return @page_paths;
}

=head2 get_page_data($page_path)

Get the App::ChmWeb::PageData object for the page in the output directory.

=cut

sub get_page_data
{
	my ($self, $page_path) = @_;
	return $self->{pages}->{$page_path};
}

1;
