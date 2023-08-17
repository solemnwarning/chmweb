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

use Test::Exception;
use Test::Spec;

use App::ChmWeb::ToC;
use App::ChmWeb::ToC::Node::Folder;

describe "App::ChmWeb::ToC" => sub
{
	describe "root()" => sub
	{
		it "returns nodes at root level" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			
			cmp_deeply(
				[ $toc->root() ],
				[ map { shallow($_) } ($a_page, $b_page, $c_dir) ]);
		};
	};
	
	describe "nodes_at()" => sub
	{
		it "returns nodes from specified path" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			
			cmp_deeply(
				[ $toc->nodes_at([]) ],
				[ map { shallow($_) } ($a_page, $b_page, $c_dir) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 0 ]) ],
				[]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 1 ]) ],
				[ map { shallow($_) } ($b1_page, $b2_page) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 1, 0 ]) ],
				[ map { shallow($_) } ($b1a_page, $b1b_page) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 2 ]) ],
				[ map { shallow($_) } ($c1_page) ]);
		};
		
		it "returns an empty list for missing paths" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			
			cmp_deeply(
				[ $toc->nodes_at([ 3 ]) ],
				[]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 3, 4, 5 ]) ],
				[]);
		};
	};
	
	describe "replace_chm()" => sub
	{
		it "replaces a top-level CHM node" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			my $a_chm_a_dir   = App::ChmWeb::ToC::Node::Folder->new("Folder A");
			my $a_chm_a1_page = $a_chm_a_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder A / Page 1", "fap1.html"));
			my $a_chm_a2_page = $a_chm_a_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder A / Page 2", "fap2.html"));
			
			my $a_chm_b_dir   = App::ChmWeb::ToC::Node::Folder->new("Folder B");
			my $a_chm_b1_page = $a_chm_b_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder B / Page 1", "fbp1.html"));
			my $a_chm_b2_page = $a_chm_b_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder B / Page 2", "fbp2.html"));
			
			$toc->replace_chm($a_chm, $a_chm_a_dir, $a_chm_b_dir);
			
			cmp_deeply(
				[ $toc->root() ],
				[ map { shallow($_) } ($a_chm_a_dir, $a_chm_b_dir, $b_chm, $c_dir) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 0 ]) ],
				[ map { shallow($_) } ($a_chm_a1_page, $a_chm_a2_page) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 1 ]) ],
				[ map { shallow($_) } ($a_chm_b1_page, $a_chm_b2_page) ]);
		};
		
		it "replaces a nested CHM node" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			my $c1_chm_a_dir   = App::ChmWeb::ToC::Node::Folder->new("Folder A");
			my $c1_chm_a1_page = $c1_chm_a_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder A / Page 1", "fap1.html"));
			my $c1_chm_a2_page = $c1_chm_a_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder A / Page 2", "fap2.html"));
			
			my $c1_chm_b_dir   = App::ChmWeb::ToC::Node::Folder->new("Folder B");
			my $c1_chm_b1_page = $c1_chm_b_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder B / Page 1", "fbp1.html"));
			my $c1_chm_b2_page = $c1_chm_b_dir->add_child(App::ChmWeb::ToC::Node::Page->new("Folder B / Page 2", "fbp2.html"));
			
			$toc->replace_chm($c1_chm, $c1_chm_a_dir, $c1_chm_b_dir);
			
			cmp_deeply(
				[ $toc->root() ],
				[ map { shallow($_) } ($a_chm, $b_chm, $c_dir) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 2 ]) ],
				[ map { shallow($_) } ($c1_chm_a_dir, $c1_chm_b_dir) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 2, 0 ]) ],
				[ map { shallow($_) } ($c1_chm_a1_page, $c1_chm_a2_page) ]);
			
			cmp_deeply(
				[ $toc->nodes_at([ 2, 1 ]) ],
				[ map { shallow($_) } ($c1_chm_b1_page, $c1_chm_b2_page) ]);
		};
	};
	
	describe "chm_subdir_by_stem()" => sub
	{
		it "returns the correct directory for registered CHMs" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			is($toc->chm_subdir_by_stem("HelpFile1"), "help1/");
			is($toc->chm_subdir_by_stem("HELPFILE1"), "help1/");
			is($toc->chm_subdir_by_stem("helpfile1"), "help1/");
			
			is($toc->chm_subdir_by_stem("HelpFile2"), "help2/");
			is($toc->chm_subdir_by_stem("HELPFILE2"), "help2/");
			is($toc->chm_subdir_by_stem("helpfile2"), "help2/");
			
			is($toc->chm_subdir_by_stem("HelpFile3"), "help3/");
			is($toc->chm_subdir_by_stem("HELPFILE3"), "help3/");
			is($toc->chm_subdir_by_stem("helpfile3"), "help3/");
		};
		
		it "returns undef for unknown CHMs" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			is($toc->chm_subdir_by_stem("helpfileX"), undef);
		};
	};
	
	describe "chm_subdir_by_chX()" => sub
	{
		it "returns the correct directory for registered CHMs" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			is($toc->chm_subdir_by_chX("HelpFile1.chm"), "help1/");
			is($toc->chm_subdir_by_chX("HELPFILE1.CHI"), "help1/");
			is($toc->chm_subdir_by_chX("helpfile1.chw"), "help1/");
			
			is($toc->chm_subdir_by_chX("HelpFile2.CHM"), "help2/");
			is($toc->chm_subdir_by_chX("HELPFILE2.chi"), "help2/");
			is($toc->chm_subdir_by_chX("helpfile2.cHW"), "help2/");
		};
		
		it "returns undef for unknown CHMs" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			is($toc->chm_subdir_by_chX("helpfileX.chm"), undef);
			is($toc->chm_subdir_by_chX("helpfileX.chi"), undef);
			is($toc->chm_subdir_by_chX("helpfileX.chw"), undef);
		};
	};
	
	describe "chm_stem_by_path()" => sub
	{
		it "returns the correct stem for files under a registered subdirectory" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			is($toc->chm_stem_by_path("help1/page.htm"), "helpfile1");
			is($toc->chm_stem_by_path("help1/long/path/help2/page.htm"), "helpfile1");
			
			is($toc->chm_stem_by_path("help3/page.htm"), "helpfile3");
			is($toc->chm_stem_by_path("help3/long/path/help2/page.htm"), "helpfile3");
		};
		
		it "returns undef for unknown paths" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm   ("HelpFile1", "help1/");
			my $b_chm  = $toc->add_chm   ("HELPFILE2", "help2/");
			my $c_dir  = $toc->add_folder("Folder C");
			my $c1_chm = $toc->add_chm   ("helpfile3", "help3/", $c_dir);
			
			is($toc->chm_stem_by_path("page.htm"), undef);
			is($toc->chm_stem_by_path("long/path/help2/page.htm"), undef);
		};
		
		it "returns the stem when the registered subdirectory is blank" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_chm  = $toc->add_chm("HelpFile1", "");
			
			is($toc->chm_stem_by_path("page.htm"), "helpfile1");
			is($toc->chm_stem_by_path("long/path/help2/page.htm"), "helpfile1");
		};
	};
	
	describe "depth_first_search()" => sub
	{
		it "visits nodes in the correct order" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			my $c2_chm   = $toc->add_chm   ("helpfile3",  "help3/",      $c_dir);
			
			my @visited_nodes = ();
			
			$toc->depth_first_search(sub
			{
				my ($node) = @_;
				
				push(@visited_nodes, $node);
				return;
			});
			
			cmp_deeply(
				\@visited_nodes,
				[ map { shallow($_) } ($a_page, $b_page, $b1_page, $b1a_page, $b1b_page, $b2_page, $c_dir, $c1_page, $c2_chm) ]);
		};
		
		it "returns matched nodes only" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			my $c2_chm   = $toc->add_chm   ("helpfile3",  "help3/",      $c_dir);
			
			my @matched_nodes = $toc->depth_first_search(sub
			{
				my ($node) = @_;
				
				return ($node eq $b_page || $node eq $c2_chm);
			});
			
			cmp_deeply(
				\@matched_nodes,
				[ map { shallow($_) } ($b_page, $c2_chm) ]);
		};
	};
};

describe "App::ChmWeb::ToC::Node" => sub
{
	describe "path()" => sub
	{
		it "returns the correct path within the containing ToC" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			
			cmp_deeply([ $a_page->path() ],   [ 0 ]);
			cmp_deeply([ $b_page->path() ],   [ 1 ]);
			cmp_deeply([ $b1_page->path() ],  [ 1, 0 ]);
			cmp_deeply([ $b1a_page->path() ], [ 1, 0, 0 ]);
			cmp_deeply([ $b1b_page->path() ], [ 1, 0, 1 ]);
			cmp_deeply([ $b2_page->path() ],  [ 1, 1 ]);
			cmp_deeply([ $c_dir->path() ],    [ 2 ]);
			cmp_deeply([ $c1_page->path() ],  [ 2, 0 ]);
		};
		
		it "dies if called on a node which has not been inserted into a ToC" => sub
		{
			my $node = App::ChmWeb::ToC::Node::Folder->new("Folder");
			
			throws_ok(sub { $node->path() }, qr/Node has not been inserted into a ToC/);
		};
	};
	
	describe "parent()" => sub
	{
		it "returns the parent element of child nodes" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			
			is($b1_page->parent(),  $b_page);
			is($b1a_page->parent(), $b1_page);
			is($b1b_page->parent(), $b1_page);
			is($b2_page->parent(),  $b_page);
			is($c1_page->parent(),  $c_dir);
		};
		
		it "returns the undef on top-level nodes" => sub
		{
			my $toc = App::ChmWeb::ToC->new();
			
			my $a_page   = $toc->add_page  ("Page A",     "pagea.html");
			my $b_page   = $toc->add_page  ("Page B",     "pageb.html");
			my $b1_page  = $toc->add_page  ("Page B/1",   "pageb1.html",  $b_page);
			my $b1a_page = $toc->add_page  ("Page B/1/A", "pageb1a.html", $b1_page);
			my $b1b_page = $toc->add_page  ("Page B/1/B", "pageb1b.html", $b1_page);
			my $b2_page  = $toc->add_page  ("Page B/2",   "pageb2.html",  $b_page);
			my $c_dir    = $toc->add_folder("Folder C");
			my $c1_page  = $toc->add_page  ("Page C/1",   "pagec1.html", $c_dir);
			
			is($a_page->parent(), undef);
			is($b_page->parent(), undef);
			is($c_dir->parent(),  undef);
		};
		
		it "dies if called on a node which has not been inserted into a ToC" => sub
		{
			my $node = App::ChmWeb::ToC::Node::Folder->new("Folder");
			
			throws_ok(sub { $node->parent() }, qr/Node has not been inserted into a ToC/);
		};
	};
};

runtests unless caller;
