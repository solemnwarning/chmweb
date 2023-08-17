# App::ChmWeb - Generate browsable web pages from CHM files
# Copyright (C) 2023 Daniel Collins <solemnwarning@solemnwarning.net>
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

package App::ChmWeb::ToC::Node::Container;
use base qw(App::ChmWeb::ToC::Node);

use Carp qw(confess croak);
use Scalar::Util qw(blessed refaddr);

sub new
{
	my ($class, %fields) = @_;
	
	return $class->SUPER::new(
		children => [],
		%fields,
	);
}

=head2 children()

Returns the direct children of this node.

=cut

sub children
{
	my ($self) = @_;
	
	confess("wat") unless(defined $self->{children} );
	
	return @{ $self->{children} };
}

=head2 add_child($child)

Appends a child to this node.

=cut

sub add_child
{
	my ($self, $child) = @_;
	
	confess("Expected an App::ChmWeb::ToC::Node object")
		unless(blessed($child) && $child->isa("App::ChmWeb::ToC::Node"));
	
	confess("Node has already been inserted into a ToC")
		if(defined $child->{parent});
	
	push(@{ $self->{children} }, $child);
	$child->{parent} = $self;
	
	return $child;
}

=head2 remove_child($child)

Removes a child from this node.

=cut

sub remove_child
{
	my ($self, $child) = @_;
	
	$self->replace_child($child);
}

=head2 replace_child($child, @replacements)

Replaces a child of this node with zero or more replacement Node objects.

=cut

sub replace_child
{
	my ($self, $child, @replacements) = @_;
	
	confess("Expected an App::ChmWeb::ToC::Node object")
			unless(blessed($child) && $child->isa("App::ChmWeb::ToC::Node"));
	
	foreach my $replacement(@replacements)
	{
		confess("Expected an App::ChmWeb::ToC::Node object")
			unless(blessed($replacement) && $replacement->isa("App::ChmWeb::ToC::Node"));
		
		confess("Node has already been inserted into a ToC")
			if(defined $replacement->{parent});
	}
	
	my ($child_idx) = grep { refaddr($self->{children}->[$_]) eq refaddr($child) } (0 .. $#{ $self->{children} });
	
	croak("Specified child node not found")
		unless(defined $child_idx);
	
	splice(@{ $self->{children} }, $child_idx, 1, @replacements);
	
	foreach my $replacement(@replacements)
	{
		$replacement->{parent} = $self;
	}
}

=head2 depth_first_search($func)

Performs a depth-first search of any children under this node.

The C<$func> function will be called with each node object in turn and any nodes for which C<$func>
returns a true value will be returned.

=cut

sub depth_first_search
{
	my ($self, $func) = @_;
	
	my @matches = ();
	
	foreach my $child($self->children())
	{
		if($func->($child))
		{
			push(@matches, $child);
		}
		
		if($child->isa("App::ChmWeb::ToC::Node::Container"))
		{
			push(@matches, $child->depth_first_search($func));
		}
	}
	
	return @matches;
}

sub _index_of_child
{
	my ($self, $child) = @_;
	
	my ($child_idx) = grep { refaddr($self->{children}->[$_]) eq refaddr($child) } (0 .. $#{ $self->{children} });
	return $child_idx;
}

1;
