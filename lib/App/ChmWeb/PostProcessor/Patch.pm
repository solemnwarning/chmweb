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

# This plugin applies patches to any known-broken files after processing a help
# file. Patches are loaded from the @INC/App/ChmWeb/patches/ directory.

use strict;
use warnings;

package App::ChmWeb::PostProcessor::Patch;

use Digest::SHA qw(sha256_hex);
use File::Basename;
use File::Slurp qw(read_file write_file);
use Text::Patch;

sub new
{
	my ($class) = @_;
	
	my $self = bless({
		patches => [ _load_patches() ],
	}, $class);
	
	return $self;
}

sub _load_patches
{
	my @patches = ();
	
	foreach my $libdir(@INC)
	{
		my $patchdir = "${libdir}/App/ChmWeb/patches";
		
		next unless(-e $patchdir);
		
		if(opendir(my $d, $patchdir))
		{
			my @names = readdir($d);
			
			foreach my $name(@names)
			{
				next if($name eq "." || $name eq "..");
				
				my $patchfile = "${patchdir}/${name}";
				
				my $patch_raw = eval { read_file($patchfile, { binmode => ":raw" }) };
				if($@)
				{
					warn $@;
					next;
				}
				
				my %metadata = ();
				
				# Extract any patch metadata
				
				my @lines = split(m/\n/, $patch_raw);
				foreach my $line(@lines)
				{
					$line =~ s/\r?$//;
					
					if($line =~ m/^(---|\+\+\+)/)
					{
						last;
					}
					
					my ($metakey, $metaval) = ($line =~ m/^(.*)\s*:\s*(.*)$/);
					if(defined $metaval)
					{
						$metadata{$metakey} = $metaval;
					}
				}
				
				unless(defined $metadata{filename})
				{
					warn "Missing \"filename\" field in $patchfile";
					next;
				}
				
				unless(defined $metadata{checksum})
				{
					warn "Missing \"checksum\" field in $patchfile";
					next;
				}
				
				push(@patches, {
					%metadata,
					patch => $patch_raw,
				});
			}
		}
		else{
			warn "Unable to open $patchdir: $!";
		}
	}
	
	return @patches;
}

sub postprocess_directory
{
	my ($self, $filename) = @_;
	
	opendir(my $d, $filename) or die "Unable to open $filename: $!";
	my @names = readdir($d);
	$d = undef;
	
	foreach my $name(@names)
	{
		next if($name eq "." || $name eq "..");
		
		if(-d "${filename}/${name}")
		{
			$self->postprocess_directory("${filename}/${name}");
		}
		else{
			$self->postprocess_file("${filename}/${name}");
		}
	}
}

sub postprocess_file
{
	my ($self, $filename) = @_;
	
	my $basename = basename($filename);
	
	my $content;
	my $sha256sum;
	
	foreach my $patch(@{ $self->{patches} })
	{
		next unless(lc($patch->{filename}) eq lc($basename));
		
		$content //= read_file($filename, { binmode => ":raw" });
		$sha256sum //= sha256_hex($content);
		
		if(lc($sha256sum) eq lc($patch->{checksum}))
		{
			print STDERR "Patching file $filename...\n";
			
			my $patched_content = patch($content, $patch->{patch}, STYLE => "Unified");
			write_file($filename, { binmode => ":raw" }, $patched_content);
		}
	}
}

1;
