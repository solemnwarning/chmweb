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

# This plugin deletes internal metadata files originally used by HTML Help.

use strict;
use warnings;

package App::ChmWeb::PostProcessor::StripMetadata;

use App::ChmWeb::Util;

sub new
{
	my ($class) = @_;
	
	my $self = bless({}, $class);
	return $self;
}

sub postprocess_directory
{
	my ($self, $output_dir, $tree_data) = @_;
	
	foreach my $subdir($tree_data->{toc}->all_chm_subdirs())
	{
		no warnings qw(qw);
		
		my @files_to_delete = qw(
			#IDXHDR
			#ITBITS
			#IVB
			#STRINGS
			#SUBSETS
			#SYSTEM
			#TOPICS
			#TOCIDX
			#URLSTR
			#URLTBL
			#WINDOWS
			
			$FIftiMain
			$OBJINST
			
			$WWAssociativeLinks/BTree
			$WWAssociativeLinks/Data
			$WWAssociativeLinks/Map
			$WWAssociativeLinks/Property
			$WWAssociativeLinks
			
			$WWKeywordLinks/BTree
			$WWKeywordLinks/Data
			$WWKeywordLinks/Map
			$WWKeywordLinks/Property
			$WWKeywordLinks
		);
		
		my $hhc = App::ChmWeb::Util::find_hhc_in("${output_dir}/${subdir}");
		my $hhk = App::ChmWeb::Util::resolve_mixed_case_path(($hhc =~ s/\.hhc$/.hhk/ir), "${output_dir}/${subdir}");
		
		push(@files_to_delete, $hhc);
		push(@files_to_delete, $hhk) if(defined $hhk);
		
		foreach my $file(@files_to_delete)
		{
			if(-d "${output_dir}/${subdir}${file}")
			{
				rmdir("${output_dir}/${subdir}${file}")
					or warn "Unable to delete ${output_dir}/${subdir}${file}: $!\n";
			}
			elsif(-e "${output_dir}/${subdir}${file}")
			{
				unlink("${output_dir}/${subdir}${file}")
					or warn "Unable to delete ${output_dir}/${subdir}${file}: $!\n";
			}
		}
	}
}

1;
