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

package App::ChmWeb::ToC::Node::CHM;
use base qw(App::ChmWeb::ToC::Node);

sub new
{
	my ($class, $chm_stem) = @_;
	
	return $class->SUPER::new(
		title    => "$chm_stem.chm (placeholder)",
		chm_stem => $chm_stem,
	);
}

sub chm_stem
{
	my ($self) = @_;
	return $self->{chm_stem};
}

sub title
{
	my ($self) = @_;
	return $self->{title};
}

1;
