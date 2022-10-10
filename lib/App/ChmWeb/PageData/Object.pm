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

package App::ChmWeb::PageData::Object;

=head1 NAME

App::ChmWeb::PageData::Object - Represents a single <OBJECT> element in a page

=head1 METHODS

=cut

use Hash::Util qw(lock_keys);

sub new
{
	my ($class) = @_;
	
	my $self = bless({
		attributes => [],
		parameters => [],
		
		start_offset => undef,
		start_line   => undef,
		total_length => undef,
	}, $class);
	lock_keys(%$self);
	
	return $self;
}

=head2 get_attribute($attribute_name)

Get the value of the named attribute, undef it not set.

=cut

sub get_attribute
{
	my ($self, $attribute_name) = @_;
	
	my ($attribute_value) = map { $_->{value} }
		grep { fc($_->{name}) eq fc($attribute_name) }
		@{ $self->{attributes} };
	
	return $attribute_value;
}

sub add_attribute
{
	my ($self, $attribute_name, $attribute_value) = @_;
	
	push(@{ $self->{attributes} },
		{ name => $attribute_name, value => $attribute_value });
}

=head2 get_parameter($parameter_name)

Get the value of the named <PARAMETER> element within this <OBJECT>, undef if
not set.

=cut

sub get_parameter
{
	my ($self, $parameter_name) = @_;
	
	my ($parameter_value) = map { $_->{value} }
		grep { fc($_->{name}) eq fc($parameter_name) }
		@{ $self->{parameters} };
	
	return $parameter_value;
}

sub add_parameter
{
	my ($self, $parameter_name, $parameter_value) = @_;
	
	push(@{ $self->{parameters} },
		{ name => $parameter_name, value => $parameter_value });
}

=head2 is_hh_activex_control()

Returns true if this element is an instance of the HTML Help ActiveX control.

=cut

sub is_hh_activex_control
{
	my ($self) = @_;
	
	my ($type) = $self->get_attribute("type");
	my ($classid) = $self->get_attribute("classid");
	
	return (defined($type) && $type eq "application/x-oleobject"
		&& defined($classid) && fc($classid) eq fc("clsid:adb880a6-d8ff-11cf-9377-00aa003b7a11"));
}

1;
