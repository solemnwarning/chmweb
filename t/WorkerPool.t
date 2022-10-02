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

use App::ChmWeb::WorkerPool;

describe "App::ChmWeb::WorkerPool" => sub
{
	it "dispatches work" => sub
	{
		my @results = ();
		
		my $add_numbers = sub
		{
			my ($num_a, $num_b) = @_;
			return $num_a + $num_b;
		};
		
		my $pool = App::ChmWeb::WorkerPool->new($add_numbers, 2);
		
		$pool->post([ 1, 1 ], sub { push(@results, "1 + 1 = $_[0]"); });
		$pool->post([ 1, 2 ], sub { push(@results, "1 + 2 = $_[0]"); });
		$pool->post([ 1, 3 ], sub { push(@results, "1 + 3 = $_[0]"); });
		$pool->post([ 1, 4 ], sub { push(@results, "1 + 4 = $_[0]"); });
		$pool->drain();
		
		cmp_bag(\@results, [
			"1 + 1 = 2",
			"1 + 2 = 3",
			"1 + 3 = 4",
			"1 + 4 = 5",
		]);
	};
	
	it "propagates warnings from workers" => sub
	{
		my $raise_warning = sub
		{
			warn "warning in worker process\n";
		};
		
		my $pool = App::ChmWeb::WorkerPool->new($raise_warning, 2);
		
		my @warnings = ();
		local $SIG{__WARN__} = sub
		{
			push(@warnings, $_[0]);
		};
		
		$pool->post([], sub {});
		$pool->post([], sub {});
		$pool->drain();
		
		cmp_bag(\@warnings, [
			"warning in worker process\n",
			"warning in worker process\n",
		]);
	};
	
	it "propagates uncaught exceptions from workers" => sub
	{
		my $die = sub
		{
			die "exception in worker process\n";
		};
		
		my $pool = App::ChmWeb::WorkerPool->new($die, 2);
		
		eval {
			$pool->post([], sub {});
			$pool->post([], sub {});
			$pool->drain();
		};
		
		is($@, "exception in worker process\n");
	};
	
	it "dies if a worker exits unexpectedly" => sub
	{
		my $exit = sub
		{
			exit(0);
		};
		
		my $pool = App::ChmWeb::WorkerPool->new($exit, 2);
		
		eval {
			$pool->post([], sub {});
			$pool->post([], sub {});
			$pool->drain();
		};
		
		like($@, qr/worker exited unexpectedly/);
	};
	
	it "handles no return values from function" => sub
	{
		my $pool = App::ChmWeb::WorkerPool->new(sub
		{
			return;
		});
		
		my @results = ();
		
		$pool->post([], sub { push(@results, \@_); });
		$pool->drain();
		
		cmp_deeply(\@results, [ [] ]);
	};
	
	it "handles multiple return values from function" => sub
	{
		my $pool = App::ChmWeb::WorkerPool->new(sub
		{
			return (1, 2, 3);
		});
		
		my @results = ();
		
		$pool->post([], sub { push(@results, \@_); });
		$pool->drain();
		
		cmp_deeply(\@results, [ [ 1, 2, 3 ] ]);
	};
};

runtests unless caller;
