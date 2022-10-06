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

package App::ChmWeb::AKLinkTable;

=head1 NAME

App::ChmWeb::AKLinkTable - CHI/CHW file loader

=head1 SYNOPSIS

  # Unpack CHI/CHW file and load metadata from it.
  
  my $chi = App::ChmWeb::AKLinkTable->load_chi("/path/to/chi.chi");

  # Load links from (BINARY) buffers in memory
  
  my $btree   = ... # BTree file contents
  my $topics  = ... # #TOPICS file contents
  my $urltbl  = ... # #URLTBL file contents
  my $urlstr  = ... # #URLSTR file contents
  my $strings = ... # #STRINGS file contents
  
  my $chi = App::ChmWeb::AKLinkTable->new(
      "BTree"    => $btree,
      "#TOPICS"  => $topics,
      "#URLTBL"  => $urltbl,
      "#URLSTR"  => $urlstr,
      "#STRINGS" => $strings,
  );

=head1 DESCRIPTION

This class allows processing the "$WWAssociativeLinks" and "$WWKeywordLinks"
BTree files which contain the mappings used for resolving "ALink" and "KLink"
references, respectively.

https://www.nongnu.org/chmspec/latest/Internal.html

=head1 METHODS

=cut

use Carp qw(croak confess);
use Encode qw(decode);
use File::Basename;
use File::Slurp qw(read_file);
use File::Temp;

use App::ChmWeb::Util;

sub new
{
	my ($class, %files) = @_;
	
	my @REQUIRE_FILES = (
		"#TOPICS",
		"#URLTBL",
		"#URLSTR",
		"#STRINGS",
	);
	
	my @missing_files = grep { !defined($files{$_}) } @REQUIRE_FILES;
	croak("Required files/arguments missing: ".join(", ", @missing_files)) if(@missing_files);
	
	my $self = bless({ files => \%files, alinks => {}, klinks => {} }, $class);
	
	my @topics = $self->_load_topics("#TOPICS", "#STRINGS", "#URLTBL", "#URLSTR", "");
	$self->{topics} = [ \@topics ];
	
	if(defined $files{"\$WWAssociativeLinks/BTree"})
	{
		$self->_process_BTree_file($self->{alinks}, "\$WWAssociativeLinks/BTree");
	}
	
	if(defined $files{"\$WWKeywordLinks/BTree"})
	{
		$self->_process_BTree_file($self->{klinks}, "\$WWKeywordLinks/BTree");
	}
	
	# Don't need the files any more.
	delete $self->{files};
	
	return $self;
}

=head2 load_chi($chi_filename)

Loads the $WWAssociativeLinks table from a chi (or compatible) file and returns
a new App::ChmWeb::AKLinkTable object.

Throws on failure.

=cut

sub load_chi
{
	my ($class, $chi_filename) = @_;
	
	my $tempdir = File::Temp->newdir();
	
	system("7z", "x", $chi_filename, "-o${tempdir}", "-aoa", "-bd", "-bso0", "-bsp0")
		and croak("Unable to extract $chi_filename");
	
	my %files = (
		"#TOPICS"  => (scalar read_file("${tempdir}/#TOPICS",  { binmode => ":raw" })),
		"#STRINGS" => (scalar read_file("${tempdir}/#STRINGS", { binmode => ":raw" })),
		"#URLTBL"  => (scalar read_file("${tempdir}/#URLTBL",  { binmode => ":raw" })),
		"#URLSTR"  => (scalar read_file("${tempdir}/#URLSTR",  { binmode => ":raw" })),
	);
	
	if(-e "${tempdir}/\$WWAssociativeLinks/BTree")
	{
		$files{"\$WWAssociativeLinks/BTree"} = (scalar read_file("${tempdir}/\$WWAssociativeLinks/BTree", { binmode => ":raw" }));
	}
	
	if(-e "${tempdir}/\$WWKeywordLinks/BTree")
	{
		$files{"\$WWKeywordLinks/BTree"} = (scalar read_file("${tempdir}/\$WWKeywordLinks/BTree", { binmode => ":raw" }));
	}
	
	return $class->new(%files);
}

sub load_chw
{
	my ($class, $chw_filename) = @_;
	
	my $tempdir = File::Temp->newdir();
	
	system("7z", "x", $chw_filename, "-o${tempdir}", "-aoa", "-bd", "-bso0", "-bsp0")
		and croak("Unable to extract $chw_filename");
	
	my $chw_dirname = dirname($chw_filename);
	
	my $titlemap = read_file("${tempdir}/\$HHTitleMap", { binmode => ":raw" });
	
	my $self = bless({ files => { "\$HHTitleMap" => $titlemap }, alinks => {}, klinks => {}, chx_names => [] }, $class);
	
	my ($num_titles) = $self->_file_unpack("v", "\$HHTitleMap", 0, 2);
	my $title_off = 2;
	
	my @chw_topics = ([]);
	
	for(my $i = 0; $i < $num_titles; ++$i)
	{
		# > Length of the file stem.
		my ($stem_length) = $self->_file_unpack("v", "\$HHTitleMap", $title_off, 2);
		$title_off += 2;
		
		# > File stem. ANSI/UTF-8 string. Not NT.
		my $stem = decode("UTF-8", substr($titlemap, $title_off, $stem_length));
		$title_off += $stem_length;
		
		# > Unknown.
		$title_off += 4;
		
		# > Unknown. Same value as previous DWORD.
		$title_off += 4;
		
		# > LCID of the specified file.
		$title_off += 4;
		
		my $chi_filename = $chw_dirname."/".App::ChmWeb::Util::resolve_mixed_case_path("${stem}.chi", $chw_dirname);
		unless(defined $chi_filename)
		{
			die;
		}
		
		my $chi_tempdir = File::Temp->newdir();
		
		system("7z", "x", $chi_filename, "-o${chi_tempdir}", "-aoa", "-bd", "-bso0", "-bsp0")
			and croak("Unable to extract $chi_filename");
		
		my $topics_file  = "${stem}/#TOPICS";
		my $strings_file = "${stem}/#STRINGS";
		my $urltbl_file  = "${stem}/#URLTBL";
		my $urlstr_file  = "${stem}/#URLSTR";
		
		$self->{files}->{$topics_file}  = read_file("${chi_tempdir}/#TOPICS",  { binmode => ":raw" });
		$self->{files}->{$strings_file} = read_file("${chi_tempdir}/#STRINGS", { binmode => ":raw" });
		$self->{files}->{$urltbl_file}  = read_file("${chi_tempdir}/#URLTBL",  { binmode => ":raw" });
		$self->{files}->{$urlstr_file}  = read_file("${chi_tempdir}/#URLSTR",  { binmode => ":raw" });
		
		my @chi_topics = $self->_load_topics($topics_file, $strings_file, $urltbl_file, $urlstr_file, "${stem}/");
		push(@chw_topics, \@chi_topics);
		
		delete $self->{files}->{$urlstr_file};
		delete $self->{files}->{$urltbl_file};
		delete $self->{files}->{$strings_file};
		delete $self->{files}->{$topics_file};
		
		if(-e "${chi_tempdir}/\$WWAssociativeLinks/BTree")
		{
			my $btree_file = "${stem}/\$WWAssociativeLinks/BTree";
			$self->{files}->{$btree_file} = read_file("${chi_tempdir}/\$WWAssociativeLinks/BTree", { binmode => ":raw" });
			$self->{topics} = [ \@chi_topics ];
			
			$self->_process_BTree_file($self->{alinks}, $btree_file);
			
			delete $self->{files}->{$btree_file};
		}
		
		if(-e "${chi_tempdir}/\$WWKeywordLinks/BTree")
		{
			my $btree_file = "${stem}/\$WWKeywordLinks/BTree";
			$self->{files}->{$btree_file} = read_file("${chi_tempdir}/\$WWKeywordLinks/BTree", { binmode => ":raw" });
			$self->{topics} = [ \@chi_topics ];
			
			$self->_process_BTree_file($self->{klinks}, $btree_file);
			
			delete $self->{files}->{$btree_file};
		}
		
		push(@{ $self->{chx_names} }, $stem);
	}
	
	$self->{topics} = \@chw_topics;
	
	if(-e "${tempdir}/\$WWAssociativeLinks/BTREE")
	{
		my $btree_file = "\$WWAssociativeLinks/BTREE";
		$self->{files}->{$btree_file} = read_file("${tempdir}/\$WWAssociativeLinks/BTREE", { binmode => ":raw" });;
		$self->_process_BTree_file($self->{alinks}, $btree_file);
	}
	
	if(-e "${tempdir}/\$WWKeywordLinks/BTREE")
	{
		my $btree_file = "\$WWKeywordLinks/BTREE";
		$self->{files}->{$btree_file} = read_file("${tempdir}/\$WWKeywordLinks/BTREE", { binmode => ":raw" });;
		$self->_process_BTree_file($self->{klinks}, $btree_file);
	}
	
	# Don't need the files any more.
	delete $self->{files};
	
	return $self;
}

sub _process_BTree_file
{
	my ($self, $table, $btree_file) = @_;
	
	my ($sig1, $sig2) = $self->_file_unpack("CC", $btree_file, 0, 4);
	
	confess("Incorrect signature in BTree file")
		unless($sig1 == 0x3B && $sig2 == 0x29);
	
	my ($num_listing_blocks) = $self->_file_unpack("V", $btree_file, 0x1A, 4);
	++$num_listing_blocks;
	
	for(my $i = 0; $i < $num_listing_blocks; ++$i)
	{
		$self->_process_BTree_block($table, $btree_file, $i);
	}
}

sub _process_BTree_block
{
	my ($self, $table, $btree_file, $block_idx) = @_;
	
	my $block_off = 76 + ($block_idx * 2048);
	
	my $num_entries = $self->_file_unpack("v", $btree_file, ($block_off + 2), 2);
	my $entry_off = $block_off + 12;
	
	for(my $i = 0; $i < $num_entries; ++$i)
	{
		# > Value of the first Name entry from the HHK UTF-16/UCS-2. If this is a
		# > sub-keyword, then this will be all the parent keywords, including this one,
		# > separated by ", ". UTF-16/UCS-2 NT.
		my ($name, $name_size) = $self->_file_read_utf16_string($btree_file, $entry_off);
		$entry_off += $name_size;
		
		# > 2 if this keyword is a See Also keyword, 0 if it is not.
		my ($is_see_also) = $self->_file_unpack("v", $btree_file, $entry_off, 2);
		$entry_off += 2;
		
		# > Depth of this entry into the tree.
		$entry_off += 2;
		
		# > Character index of the last keyword in the ", " separated list.
		my ($last_keyword_chr_offset) = $self->_file_unpack("V", $btree_file, $entry_off, 4);
		$entry_off += 4;
		
		# > 0 (unknown)
		$entry_off += 4;
		
		# > Number of Name, Local pairs
		my ($num_pairs) = $self->_file_unpack("V", $btree_file, $entry_off, 4);
		$entry_off += 4;
		
		# Chop off parents from name list (if any)
		$name = substr($name, $last_keyword_chr_offset);
		
		if($is_see_also == 0)
		{
			# > Index into the #TOPICS file.
			for(my $k = 0; $k < $num_pairs; ++$k)
			{
				my $topic_idx = $self->_file_unpack("V", $btree_file, $entry_off, 4);
				$entry_off += 4;
				
				# So, when reading the BTree from a chi, the index is just that of
				# the slot in the #TOPICS file.
				#
				# However, when reading from a chw, the indexes of the chi topic
				# slots appear to be mapped into the chw in 1M windows, starting
				# at 1M (probably to remove ambiguity).
				
				my $topic = $self->get_topic_by_idx($topic_idx);
				if(defined $topic)
				{
					$table->{$name} //= [];
					push(@{ $table->{$name} }, $topic);
				}
				else{
					warn "Unknown topic in $btree_file: $topic_idx";
				}
			}
		}
		elsif($is_see_also == 2)
		{
			# > The value of the See Also string.
			my ($sa_string, $sa_size) = $self->_file_read_utf16_string($btree_file, $entry_off);
			$entry_off += $sa_size;
			
			$table->{$name} //= [];
			push(@{ $table->{$name} }, {
				SeeAlso => $sa_string,
			});
		}
		else{
			confess("Unexpected \$is_see_also value ($is_see_also)");
		}
		
		# > Mostly 1 (unknown)
		$entry_off += 4;
		
		# > Zero based index of this entry in the file (not block).
		# > Increments by 13 (each entry is 13 more than the last).
		my ($file_entry_idx) = $self->_file_unpack("V", $btree_file, $entry_off, 4);
		$entry_off += 4;
		
		# TODO: Check $file_entry_idx
	}
}

sub _load_topics
{
	my ($self, $topics_file, $strings_file, $urltbl_file, $urlstr_file, $path_prefix) = @_;
	
	my $num_topics = length($self->{files}->{$topics_file}) / 16;
	my @topics = ();
	
	for(my $topics_idx = 0; $topics_idx < $num_topics; ++$topics_idx)
	{
		# == #TOPICS ==
		
		# > Offset in #STRINGS file of the contents of the title tag or the
		# > Name param of the file in question. -1 = no title.
		my ($strings_offset) = $self->_file_unpack("V", $topics_file, (16 * $topics_idx) + 4, 4);
		
		my $strings_string = undef;
		if($strings_offset != 0xFFFFFFFF)
		{
			($strings_string) = $self->_file_read_utf8_string($strings_file, $strings_offset);
		}
		
		# > Offset in #URLTBL of entry containing offset to #URLSTR entry
		# > containing the URL.
		my ($urltbl_offset) = $self->_file_unpack("V", $topics_file, (16 * $topics_idx) + 8, 4);
		
		# == #URLTBL ==
		
		# > Index of entry in #TOPICS file.
		my ($urltbl_topics_idx) = $self->_file_unpack("V", $urltbl_file, $urltbl_offset + 4, 4);
		
		confess("Unexpected value $urltbl_topics_idx at $urltbl_file offset ".($urltbl_offset + 4)." (expected $topics_idx)")
			unless($urltbl_topics_idx == $topics_idx);
		
		# > Offset in #URLSTR file of entry containing filename.
		my ($urlstr_offset) = $self->_file_unpack("V", $urltbl_file, $urltbl_offset + 8, 4);
		
		# == #URLSTR ==
		
		# > Offset of the URL for this topic.
		# > Offset of the FrameName for this topic.
		my ($urlstr_url_offset, $urlstr_frame_offset) = $self->_file_unpack("VV", $urlstr_file, $urlstr_offset, 8);
		
		if($urlstr_url_offset == 0 && $urlstr_frame_offset == 0)
		{
			# > ANSI/UTF-8 NT string that is the Local for this topic.
			my ($urlstr_string) = $self->_file_read_utf8_string($urlstr_file, $urlstr_offset + 8);
			
			push(@topics, {
				Name  => $strings_string,
				Local => $path_prefix.$urlstr_string,
			});
		}
		else{
			# TODO: I don't think these are right...
			
			my ($urlstr_url) = $self->_file_read_utf8_string($urlstr_file, $urlstr_url_offset);
			my ($urlstr_frame) = $self->_file_read_utf8_string($urlstr_file, $urlstr_frame_offset);
			
			push(@topics, {
				Name      => $strings_string,
				URL       => $urlstr_url,
				FrameName => $urlstr_frame,
			});
		}
	}
	
	return @topics;
}

sub _file_unpack
{
	my ($self, $template, $filename, $offset, $length) = @_;
	
	confess("Overflow when reading $filename (offset = $offset, length = $length)")
		unless(length($self->{files}->{$filename}) >= ($offset + $length));
	
	my $data = substr($self->{files}->{$filename}, $offset, $length);
	return unpack($template, $data);
}

sub _file_read_utf8_string
{
	my ($self, $filename, $offset) = @_;
	
	my $len = 0;
	while(1)
	{
		my ($word) = $self->_file_unpack("C", $filename, ($offset + $len), 1);
		if($word == 0)
		{
			last;
		}
		
		++$len;
	}
	
	my $string_data = substr($self->{files}->{$filename}, $offset, $len);
	my $string = decode("UTF-8", $string_data);
	
	return $string, ($len + 1);
}

sub _file_read_utf16_string
{
	my ($self, $filename, $offset) = @_;
	
	my $len = 0;
	while(1)
	{
		my ($word) = $self->_file_unpack("v", $filename, ($offset + (2 * $len)), 2);
		if($word == 0)
		{
			last;
		}
		
		++$len;
	}
	
	my $string_data = substr($self->{files}->{$filename}, $offset, ($len * 2));
	my $string = decode("UTF-16LE", $string_data);
	
	return $string, (($len + 1) * 2);
}

=head2 get_all_topics()

Returns a list of all topics defined.

Each topic is a HASH reference in one of the following formats:

  # File in chm
  {
      Name  => "Topic Title", # optional
      Local => "path/to/file.htm",
  }

  # URL
  {
      Name      => "Topic Title", # optional
      URL       => "...",
      FrameName => "...",
  }

=cut

sub get_all_topics
{
	my ($self) = @_;
	
	return map { @$_ } @{ $self->{topics} };
}

=head2 get_topic_by_idx($topic_idx)

Returns a topic HASH reference by index, as referenced in BTree files.

Returns undef if the topic doesn't exist.

=cut

sub get_topic_by_idx
{
	my ($self, $topic_idx) = @_;
	
	# So, when reading the BTree from a chi, the index is just that of the
	# slot in the included #TOPICS file.
	#
	# However, when reading from a chw, the indexes of the chi topic slots
	# appear to be mapped into the chw in 1M windows, starting at 1M
	# (probably to remove ambiguity between chi/chm indexes).
	#
	# When we hold a chi, our slots member contains an array which then has
	# a single nested array reference to the topics list.
	#
	# When we hold a chw, our slots member contains an array which has
	# references to each chi file starting at the 1 index.
	
	my $idx_a = int($topic_idx / 1_048_576);
	my $idx_b = $topic_idx % 1_048_576;
	
	if($idx_a < (scalar @{ $self->{topics} }) && $idx_b < (scalar @{ $self->{topics}->[$idx_a] }))
	{
		return $self->{topics}->[$idx_a]->[$idx_b];
	}
	else{
		return undef;
	}
}

=head2 get_all_alinks()

Returns a HASH reference mapping each ALink name to an ARRAY reference of
topics as returned by the get_all_topics() method.

=cut

sub get_all_alinks
{
	my ($self) = @_;
	
	return $self->{alinks};
}

=head2 get_alink_by_key($key)

Returns a list of any topics for the named ALink.

=cut

sub get_alink_by_key
{
	my ($self, $key) = @_;
	
	return @{ $self->{alinks}->{$key} // [] };
}

=head2 get_all_klinks()

Returns a HASH reference mapping each KLink name to an ARRAY reference of
topics as returned by the get_all_topics() method.

=cut

sub get_all_klinks
{
	my ($self) = @_;
	
	return $self->{klinks};
}

=head2 get_klink_by_key($key)

Returns a list of any topics for the named KLink.

=cut

sub get_klink_by_key
{
	my ($self, $key) = @_;
	
	return @{ $self->{klinks}->{$key} // [] };
}

=head2 get_chx_names()

Returns the "stem" of any chm/chi files referenced by this chw file.

TODO: Split chw handling into a subclass.

=cut

sub get_chx_names
{
	my ($self) = @_;
	
	carp("Not loaded from a .chw file") unless(defined $self->{chx_names});
	
	return @{ $self->{chx_names} };
}

1;
