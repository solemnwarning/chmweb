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

package App::ChmWeb::ToC::Node::Page;
use base qw(App::ChmWeb::ToC::Node::Container);

sub new
{
	my ($class, $title, $filename) = @_;
	
	return $class->SUPER::new(
		title    => $title,
		filename => $filename,
	);
}

sub title
{
	my ($self) = @_;
	
	return $self->{title};
}

sub filename
{
	my ($self) = @_;
	return $self->{filename};
}

1;
