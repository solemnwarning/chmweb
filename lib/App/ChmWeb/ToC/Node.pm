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

package App::ChmWeb::ToC::Node;

=head1 NAME

App::ChmWeb::Toc::Node - Base class for nodes in the ToC.

=head1 DESCRIPTION

This is the base class for all node objects inserted into a L<App::ChmWeb::Toc>
instance.

=head1 METHODS

=cut

use Carp qw(confess);

sub new
{
	my ($class, %fields) = @_;
	
	return bless({
		parent => undef,
		%fields,
	}, $class);
}

=head2 parent()

Returns the L<Node|App::ChmWeb::ToC::Node> object this node is a direct child
of, or undef if it is at the top level of the L<ToC|App::ChmWeb::ToC> object.

=cut

sub parent
{
	my ($self) = @_;
	
	confess("Node has not been inserted into a ToC")
		unless(defined $self->{parent});
	
	if($self->{parent}->isa("App::ChmWeb::ToC::Node::Root"))
	{
		return undef;
	}
	else{
		return $self->{parent};
	}
}

=head2 parent()

Returns the "path" to this object within the L<ToC|App::ChmWeb::ToC> object.

The path is an array of indices at each level, for example:

  + Page 1                            => (0)
  |   + Page 1 / Child 1              => (0, 0)
  |   + Page 1 / Child 2              => (0, 1)
  + Page 2                            => (1)
  |   + Page 2 / Child 1              => (1, 0)
  |   |   Page 2 / Child 1 / Child 1  => (1, 0, 0)
  |   | Page 2 / Child 2              => (1, 1)

=cut

sub path
{
	my ($self) = @_;
	
	confess("Node has not been inserted into a ToC")
		unless(defined $self->{parent});
	
	my @path = ();
	my $node = $self;
	
	until($node->isa("App::ChmWeb::ToC::Node::Root"))
	{
		unshift(@path, $node->{parent}->_index_of_child($node));
		$node = $node->{parent};
	}
	
	return @path;
}

1;
