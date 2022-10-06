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

use Test::Spec;

use App::ChmWeb::AKLinkTable;

describe "App::ChmWeb::AKLinkTable" => sub
{
	it "can load a CHI file" => sub
	{
		my $t = App::ChmWeb::AKLinkTable->load_chi("t/win95ui.chi");
		
		cmp_deeply($t->get_all_alinks(), {
			"msdn_win95uititlepage" => [
				{
					Name  => "Programming the Windows 95 User Interface",
					Local => "html/win95uititlepage.htm",
				},
			],
			"msdn_win95uisamples" => [
				{
					Name  => "Sample Source Code for This Book",
					Local => "html/win95uisamples.htm",
				}
			],
		});
		
		cmp_deeply($t->get_all_klinks(), {
			"Programming the Windows 95 User Interface Samples" => [
				{
					Name  => "Sample Source Code for This Book",
					Local => "html/win95uisamples.htm",
				}
			]
		});
	};
};

runtests unless caller;
