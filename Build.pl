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

use Module::Build;

my $build = Module::Build->new
(
	module_name => "App::ChmWeb",
	dist_abstract => "Generate browsable web pages from CHM files",
	license  => "gpl",
	requires => {
		"File::Basename" => 0,
		"HTML::Entities" => 0,
		"SGML::Parser::OpenSP" => 0,
	},
	test_requires => {
		"Test::Spec" => 0,
	},
);

$build->create_build_script();
