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

use Test::Spec;

use File::Temp;

use App::ChmWeb::FilesystemCache;

describe "App::ChmWeb::FilesystemCache" => sub
{
	my $tempfile;
	my $tempdir;
	my $cache;
	
	before each => sub
	{
		$tempfile = File::Temp->new();
		$tempdir  = File::Temp->newdir();
		
		$cache = App::ChmWeb::FilesystemCache->new();
	};
	
	describe "e()" => sub
	{
		it "returns true for a file that exists" => sub
		{
			ok($cache->e("$tempfile"));
		};
		
		it "returns true for a directory that exists" => sub
		{
			ok($cache->e("$tempdir"));
		};
		
		it "returns false for a path that doesn't exist" => sub
		{
			ok(!$cache->e("${tempdir}/foo"));
		};
		
		it "caches existence of file" => sub
		{
			my $tempfile_name = "$tempfile";
			
			$cache->e($tempfile_name);
			
			$tempfile = undef; # Will unlink file
			
			ok($cache->e($tempfile_name));
		};
		
		it "caches non-existence of file" => sub
		{
			$cache->e("${tempdir}/foo");
			
			{ open(my $fh, ">", "${tempdir}/foo") or die $!; }
			
			ok(!$cache->e("${tempdir}/foo"));
		};
	};
	
	describe "d()" => sub
	{
		it "returns false for a file that exists" => sub
		{
			ok(!$cache->d("$tempfile"));
		};
		
		it "returns true for a directory that exists" => sub
		{
			ok($cache->d("$tempdir"));
		};
		
		it "returns false for a path that doesn't exist" => sub
		{
			ok(!$cache->d("${tempdir}/foo"));
		};
		
		it "caches existence of directory" => sub
		{
			my $tempdir_name = "$tempdir";
			
			$cache->d($tempdir_name);
			
			$tempdir = undef; # Will delete dir
			
			ok($cache->d($tempdir_name));
		};
		
		it "caches non-existence of directory" => sub
		{
			$cache->d("${tempdir}/foo");
			
			{ mkdir("${tempdir}/foo/") or die $!; }
			
			ok(!$cache->d("${tempdir}/foo"));
		};
	};
	
	describe "dir_children_fc()" => sub
	{
		it "returns files with correct names" => sub
		{
			{ open(my $fh, ">", "${tempdir}/HELLO") or die $!; }
			{ open(my $fh, ">", "${tempdir}/world") or die $!; }
			{ open(my $fh, ">", "${tempdir}/FoObAr") or die $!; }
			{ open(my $fh, ">", "${tempdir}/baz123") or die $!; }
			
			cmp_deeply(
				$cache->dir_children_fc("$tempdir"),
				{
					fc("hello")  => "HELLO",
					fc("WORLD")  => "world",
					fc("foobar") => "FoObAr",
					fc("BAZ123") => "baz123",
					fc(".")      => ".",
					fc("..")     => "..",
				});
		};
		
		it "caches results" => sub
		{
			{ open(my $fh, ">", "${tempdir}/HELLO") or die $!; }
			{ open(my $fh, ">", "${tempdir}/world") or die $!; }
			{ open(my $fh, ">", "${tempdir}/FoObAr") or die $!; }
			{ open(my $fh, ">", "${tempdir}/baz123") or die $!; }
			
			$cache->dir_children_fc("$tempdir");
			
			unlink("${tempdir}/HELLO") or die $!;
			
			cmp_deeply(
				$cache->dir_children_fc("$tempdir"),
				{
					fc("hello")  => "HELLO",
					fc("WORLD")  => "world",
					fc("foobar") => "FoObAr",
					fc("BAZ123") => "baz123",
					fc(".")      => ".",
					fc("..")     => "..",
				});
		};
	};
};

runtests unless caller;
