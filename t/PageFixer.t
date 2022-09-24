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

use App::ChmWeb::PageFixer;

describe "App::ChmWeb::PageFixer" => sub
{
	describe "fix_image_paths" => sub
	{
		it "resolves images with an absolute path" => sub
		{
			my $INPUT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="/html/fig6-2.gif" width="595" height="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="/html/fig6-3.gif" width="429" height="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			my $pf = App::ChmWeb::PageFixer->new();
			$pf->set_content($INPUT, "html/chpt06-02.htm", "t/win95ui");
			
			$pf->fix_image_paths();
			
			my $OUTPUT = $pf->get_content();
			
			my $EXPECT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="fig6-2.gif" WIDTH="595" HEIGHT="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="fig6-3.gif" WIDTH="429" HEIGHT="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			
			is($OUTPUT, $EXPECT);
		};
		
		it "doesn't touch images with relative paths" => sub
		{
			my $INPUT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="fig6-2.gif" width="595" height="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="fig6-3.gif" width="429" height="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			my $pf = App::ChmWeb::PageFixer->new();
			$pf->set_content($INPUT, "html/chpt06-02.htm", "t/win95ui");
			
			$pf->fix_image_paths();
			
			my $OUTPUT = $pf->get_content();
			
			my $EXPECT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="fig6-2.gif" width="595" height="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="fig6-3.gif" width="429" height="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			
			is($OUTPUT, $EXPECT);
		};
		
		it "resolves images with an incorrectly-cased absolute path" => sub
		{
			my $INPUT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="/HTML/fig6-2.gif" width="595" height="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="/html/Fig6-3.gif" width="429" height="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			my $pf = App::ChmWeb::PageFixer->new();
			$pf->set_content($INPUT, "html/chpt06-02.htm", "t/win95ui");
			
			$pf->fix_image_paths();
			
			my $OUTPUT = $pf->get_content();
			
			my $EXPECT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="fig6-2.gif" WIDTH="595" HEIGHT="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="fig6-3.gif" WIDTH="429" HEIGHT="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			
			is($OUTPUT, $EXPECT);
		};
		
		it "resolves images with an incorrectly-cased relative path" => sub
		{
			my $INPUT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="fig6-2.giF" width="595" height="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="Fig6-3.gif" width="429" height="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			my $pf = App::ChmWeb::PageFixer->new();
			$pf->set_content($INPUT, "html/chpt06-02.htm", "t/win95ui");
			
			$pf->fix_image_paths();
			
			my $OUTPUT = $pf->get_content();
			
			my $EXPECT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="fig6-2.gif" WIDTH="595" HEIGHT="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="fig6-3.gif" WIDTH="429" HEIGHT="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			
			is($OUTPUT, $EXPECT);
		};
		
		it "resolves images with an absolute path in another directory" => sub
		{
			my $INPUT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="/html/fig6-2.gif" width="595" height="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="/html/fig6-3.gif" width="429" height="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			my $pf = App::ChmWeb::PageFixer->new();
			$pf->set_content($INPUT, "html2/html3/chpt06-02.htm", "t/win95ui");
			
			$pf->fix_image_paths();
			
			my $OUTPUT = $pf->get_content();
			
			my $EXPECT = <<EOF;
			<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
			<html>
			
			<head>
			
			<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=iso8859-1">
			<meta name="MS.LOCALE" content="EN-US">
			<meta name="DESCRIPTION" content="This page is from the Programming the Windows 95 User Interface book in the Books section of the MSDN Online Library.">
			
			<meta name="GENERATOR" content="Microsoft FrontPage 2.0">
			<title>Opening and Saving Files with Common Dialog Boxes</title>
			<!--CSS_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_header.js'></script>
			<!--CSS_END-->
			</HEAD>
			
			<BODY bgcolor="#FFFFFF" link=#003399 vlink=#996699>
			
			<P>
			
			<h1>Opening and Saving Files with Common Dialog
			Boxes</h1>
			
			<p>The most frequently used common dialog boxes are those that
			open files and save files. As you can see in the example shown in
			Figure 6-2, these dia-log boxes support long filenames and
			contain a list view control, which graphically represents the
			contents of the current folder.</p>
			
			<p><b>Figure 6-2.</b> </p>
			
			<p><IMG SRC="../../html/fig6-2.gif" WIDTH="595" HEIGHT="446"></p>
			
			<p><b>Figure 6-3.</b></p>
			
			<p><IMG SRC="../../html/fig6-3.gif" WIDTH="429" HEIGHT="288"></p>
			
			<h4><i>A Save As common dialog box in details view.</i> </h4>
			</FONT>
			
			<!--FOOTER_START-->
			<script language="JavaScript" src='MS-ITS:dsmsdn.chm::/html/msdn_footer.js'></script>
			<!--FOOTER_END-->
			</body>
			</html>
EOF
			
			is($OUTPUT, $EXPECT);
		};
	};
};

runtests unless caller;
