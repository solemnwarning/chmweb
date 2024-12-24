# App::ChmWeb - Generate browsable web pages from CHM files
# Copyright (C) 2022-2024 Daniel Collins <solemnwarning@solemnwarning.net>
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
			anchor_ids   => [],
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

sub anchor_ids
{
	my ($self) = @_;
	return @{ $self->{anchor_ids} };
}

sub has_anchor
{
	my ($self, $name_or_id) = @_;
	
	return !!(grep { $_ eq $name_or_id } $self->anchor_ids());
}

=head2 objects()

Returns a list of any <OBJECT> elements in the page (as App::ChmWeb::PageData::Object objects).

=cut

sub objects
{
	my ($self) = @_;
	return @{ $self->{objects} };
}

=head2 alink_refs()

Returns a list of ALinks referenced by this page, each being a string in this format:

  "target.chm:target-alink"
  "target.chm:target-alink-1;target-alink-2"

=cut

sub alink_refs
{
	my ($self) = @_;
	
	my @alink_refs = ();
	
	foreach my $object(@{ $self->{objects} })
	{
		next unless($object->is_hh_activex_control());
		
		my $command = $object->get_parameter("Command") // "<UNSET>";
		
		if($command =~ m/^ALink(,.*)?/)
		{
			my $chm_name    = $object->get_parameter("ITEM1") || $self->chm_name();
			my $alink_names = $object->get_parameter("ITEM2");
			
			push(@alink_refs, "${chm_name}:${alink_names}");
		}
	}
	
	return @alink_refs;
}

=head2 klink_refs()

Returns a list of KLinks referenced by this page, each being a string in this format:

  "target.chm:target-klink"
  "target.chm:target-klink-1;target-klink-2"

=cut

sub klink_refs
{
	my ($self) = @_;
	
	my @klink_refs = ();
	
	foreach my $object(@{ $self->{objects} })
	{
		next unless($object->is_hh_activex_control());
		
		my $command = $object->get_parameter("Command") // "<UNSET>";
		
		if($command =~ m/^KLink(,.*)?/)
		{
			my $chm_name    = $object->get_parameter("ITEM1") || $self->chm_name();
			my $klink_names = $object->get_parameter("ITEM2");
			
			push(@klink_refs, "${chm_name}:${klink_names}");
		}
	}
	
	return @klink_refs;
}

1;
