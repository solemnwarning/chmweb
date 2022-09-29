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

package App::ChmWeb::WorkerPool;

use IO::Select;
use JSON qw(encode_json decode_json);
use Sys::Info::Device::CPU;

sub new
{
	my ($class, $func, $num_workers) = @_;
	
	$num_workers //= Sys::Info::Device::CPU->new()->count();
	
	my $self = bless({}, $class);
	
	$self->{workers}     = [];
	$self->{next_worker} = 0;
	$self->{select}      = IO::Select->new();
	
	for(my $i = 0; $i < $num_workers; ++$i)
	{
		# Spawn child processes to dispatch work.
		
		pipe(my $from_parent, my $to_child) or die "pipe: $!\n";
		pipe(my $from_child, my $to_parent) or die "pipe: $!\n";
		
		binmode($from_parent);
		binmode($to_child);
		binmode($from_child);
		binmode($to_parent);
		
		my $pid = fork() // die "fork: $!\n";
		
		if($pid == 0)
		{
			# We are in the child process.
			
			# Close our handles to the other end of our pipes.
			close($from_child);
			close($to_child);
			
			# Discard and close our handles to the other worker processes.
			$self->{workers} = undef;
			
			# Read jobs from the parent process.
			while(defined(my $line = <$from_parent>))
			{
				my $args = decode_json($line);
				my $result;
				
				eval {
					local $SIG{__WARN__} = sub
					{
						print {$to_parent} encode_json({ warning => $_[0] }), "\n";
						$to_parent->flush();
					};
					
					$result = $func->(@$args);
				};
				
				if($@ ne "")
				{
					print {$to_parent} encode_json({ error => $@ }), "\n";
					$to_parent->flush();
					
					exit(1);
				}
				
				print {$to_parent} encode_json({ result => $result }), "\n";
				$to_parent->flush();
			}
			
			# We're done. Exit.
			exit(0);
		}
		else{
			# We are in the parent process.
			
			close($from_parent);
			close($to_parent);
			
			push(@{ $self->{workers} }, {
				pid        => $pid,
				to_child   => $to_child,
				from_child => $from_child,
				read_buf   => "",
				queue      => [],
			});
			
			$self->{select}->add($from_child);
		}
	}
	
	return $self;
}

sub post
{
	my ($self, $func_args, $callback) = @_;
	
	# Pump data from workers.
	while($self->pump(0)) {}
	
	# Select next worker.
	my $worker = $self->{workers}->[ $self->{next_worker} ];
	
	++($self->{next_worker});
	if($self->{next_worker} >= (scalar @{ $self->{workers} }))
	{
		$self->{next_worker} = 0;
	}
	
	# Add callback to queue.
	push(@{ $worker->{queue} }, { callback => $callback });
	
	# Dispatch work to worker.
	print { $worker->{to_child} } encode_json([ @$func_args ]), "\n";
	$worker->{to_child}->flush();
}

sub pump
{
	my ($self, $timeout) = @_;
	
	my @can_read = $self->{select}->can_read($timeout);
	
	foreach my $handle(@can_read)
	{
		# Find the worker associated with this from_child handle.
		my ($worker) = grep { $_->{from_child}->fileno() == $handle->fileno() } @{ $self->{workers} };
		
		my $r = $worker->{from_child}->sysread($worker->{read_buf}, 1024, length($worker->{read_buf}))
			// die "read: $!";
		
		# Process any complete lines (JSON strings) in the buffer
		while($worker->{read_buf} =~ m/^(.*\n)/)
		{
			my $line = $1;
			$worker->{read_buf} =~ s/^(.*\n)//;
			
			my $data = decode_json($line);
			
			if(defined $data->{result})
			{
				my $queue_front = shift(@{ $worker->{queue} });
				$queue_front->{callback}->($data->{result});
			}
			elsif(defined $data->{warning})
			{
				warn $data->{warning};
			}
			elsif(defined $data->{error})
			{
				die $data->{error};
			}
		}
		
		if($r == 0)
		{
			die "worker exited unexpectedly";
		}
	}
	
	return (scalar @can_read) > 0;
}

sub drain
{
	my ($self) = @_;
	
	# Pump data from the workers until the queues are empty.
	while(grep { (scalar @{ $_->{queue} }) > 0 } @{ $self->{workers} })
	{
		$self->pump();
	}
}

sub DESTROY
{
	my ($self) = @_;
	
	foreach my $worker(@{ $self->{workers} })
	{
		close($worker->{to_child});
		close($worker->{from_child});
		waitpid($worker->{pid}, 0);
	}
}

1;
