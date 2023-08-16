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
			
			chm_subdirs => undef,
		}, $class);
	
	lock_keys(%$self);
	
	return $self;
}

=head2 visit_toc_nodes($func)

Helper for iterating over the table of contents. The $func callback is called
for every node in the tree with a reference to the node and its path within the
tree.

=cut

sub visit_toc_nodes
{
	my ($self, $func) = @_;
	
	my $f = sub
	{
		my ($f, $nodes, $path) = @_;
		
		for(my $i = 0; $i < (scalar @$nodes); ++$i)
		{
			my $node = $nodes->[$i];
			
			$func->($node, [ @$path, $i ]);
			
			$f->($f, $node->{children}, [ @$path, $i ])
				if(defined $node->{children});
		}
	};
	
	$f->($f, $self->{toc}, []);
}

sub get_toc_nodes_at
{
	my ($self, $path) = @_;
	
	my $node = $self->{toc};
	
	for(my $i = 0; $i < (scalar @$path); ++$i)
	{
		if($path->[$i] >= (scalar @$node))
		{
			return undef;
		}
		
		$node = $node->[ $path->[$i] ]->{children} // [];
	}
	
	return @$node;
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
