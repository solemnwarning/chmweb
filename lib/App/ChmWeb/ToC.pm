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

use feature qw(fc);

package App::ChmWeb::ToC;

=head1 NAME

App::ChmWeb::ToC

=head1 DESCRIPTION

App::ChmWeb::ToC holds the tree of folders and pages to be compiled into the final help collection.

=head1 METHODS

=cut

use Carp qw(confess croak);
use Scalar::Util qw(blessed);
use SGML::Parser::OpenSP;

use App::ChmWeb::ToC::Node::CHM;
use App::ChmWeb::ToC::Node::Folder;
use App::ChmWeb::ToC::Node::Page;
use App::ChmWeb::ToC::Node::Root;

=head2 new()

Constructs a new empty ToC.

=cut

sub new
{
	my ($class) = @_;
	
	return bless({
		root => App::ChmWeb::ToC::Node::Root->new(),
		chm_stem_to_subdir => {},
	}, $class);
}

=head2 load_col_file($filename)

Constructs a new ToC from a HTML Help .col file.

Does not descend into .chm files - CHM placeholder nodes are inserted to be processed later by
L<App::ChmWeb::TreeScanner>.

=cut

sub load_col_file
{
	my ($class, $filename) = @_;
	
	my $p = SGML::Parser::OpenSP->new();
	my $h = App::ChmWeb::ToC::Handler->new();
	
	$p->catalogs(qw(xhtml.soc));
	$p->warnings(qw(xml valid));
	$p->handler($h);
	
	$p->parse($filename);
	
	my $self = $class->new();
	
	$self->_process_col_folders($self->{root}, $h->{folders});
	
	return $self;
}

sub _process_col_folders
{
	my ($self, $toc_parent_node, $col_folders) = @_;
	
	foreach my $folder(sort { $a->{order} <=> $b->{order} } @$col_folders)
	{
		if($folder->{title} =~ m/^=(.+)$/)
		{
			$self->add_chm($1, "$1/", $toc_parent_node);
		}
		else{
			my $toc_folder_node = $self->add_folder($folder->{title}, $toc_parent_node);
			$self->_process_col_folders($toc_folder_node, $folder->{folders});
		}
	}
}

=head2 add_folder($title, $parent)

Adds a new folder node to the collection and returns the L<App::ChmWeb::ToC::Node::Folder> object.

If C<$parent> is defined, it must be a L<App::ChmWeb::ToC::Container> object, if undefined, the
node will be appended to the root of the collection.

=cut

sub add_folder
{
	my ($self, $title, $parent) = @_;
	
	if(defined $parent)
	{
		confess("Expected an App::ChmWeb::ToC::Node::Container object")
			unless(blessed($parent) && $parent->isa("App::ChmWeb::ToC::Node::Container"));
	}
	else{
		$parent = $self->{root};
	}
	
	return $parent->add_child(
		App::ChmWeb::ToC::Node::Folder->new($title));
}

=head2 add_chm($chm_stem, $subdir, $parernt)

Adds a new CHM placeholder to the collection and returns the L<App::ChmWeb::ToC::Node::CHM> object.

Each C<$chm_stem> may only exist in a collection at a single point, trying to add it again will
raise an exception.

The C<$subdir> is the subdirectory under the output directory where the chm has been unpacked,
which will usually be either an empty string (for single CHM runs), or "${chm_stem}/" in the case
of multi-chm runs.

If C<$parent> is defined, it must be a L<App::ChmWeb::ToC::Container> object, if undefined, the
node will be appended to the root of the collection.

=cut

sub add_chm
{
	my ($self, $chm_stem, $subdir, $parent) = @_;
	
	if(defined $parent)
	{
		confess("Expected an App::ChmWeb::ToC::Node::Container object")
			unless(blessed($parent) && $parent->isa("App::ChmWeb::ToC::Node::Container"));
	}
	else{
		$parent = $self->{root};
	}
	
	if(defined $self->{chm_stem_to_subdir}->{ fc($chm_stem) })
	{
		croak("Duplicate CHM: $chm_stem");
	}
	
	$self->{chm_stem_to_subdir}->{ fc($chm_stem) } = $subdir;
	
	return $parent->add_child(
		App::ChmWeb::ToC::Node::CHM->new($chm_stem));
}

=head2 replace_chm($chm_node, @replacements)

Replaces a CHM placeholder node previously inserted using the C<add_chm> method with the actual
nodes loaded from the CHM.

=cut

sub replace_chm
{
	my ($self, $chm_node, @replacements) = @_;
	
	confess("Expected an App::ChmWeb::ToC::Node::CHM object")
		unless(blessed($chm_node) && $chm_node->isa("App::ChmWeb::ToC::Node::CHM"));
	
	$chm_node->{parent}->replace_child($chm_node, @replacements);
}

=head2 add_page($title, $filename, $parernt)

Adds a new page reference to the collection and returns the L<App::ChmWeb::ToC::Node::Page> object.

The C<$filename> argument should be the complete path to the page relative to the output directory
(including the relevant chm subdir).

If C<$parent> is defined, it must be a L<App::ChmWeb::ToC::Container> object, if undefined, the
node will be appended to the root of the collection.

=cut

sub add_page
{
	my ($self, $title, $filename, $parent) = @_;
	
	if(defined $parent)
	{
		confess("Expected an App::ChmWeb::ToC::Node::Container object")
			unless(blessed($parent) && $parent->isa("App::ChmWeb::ToC::Node::Container"));
	}
	else{
		$parent = $self->{root};
	}
	
	return $parent->add_child(
		App::ChmWeb::ToC::Node::Page->new($title, $filename));
}

=head2 root()

Returns the C<App::ChmWeb::Toc::Node> objects at the root level of the ToC.

=cut

sub root
{
	my ($self) = @_;
	return $self->{root}->children();
}

=head2 root()

Returns the C<App::ChmWeb::Toc::Node> objects directly under the given C<$toc_path>.

=cut

sub nodes_at
{
	my ($self, $toc_path) = @_;
	
	my $container = $self->{root};
	
	for(my $i = 0; $i < (scalar @$toc_path) && defined($container); ++$i)
	{
		return unless($container->isa("App::ChmWeb::ToC::Node::Container"));
		
		my @container_children = $container->children();
		$container = $container_children[ $toc_path->[$i] ];
	}
	
	return unless(defined($container) && $container->isa("App::ChmWeb::ToC::Node::Container"));
	return $container->children();
}

=head2 chm_subdir_by_stem($chm_stem)

Fetches the registered subdirectory relative to the output directory for the named "stem"
(e.g. "help" for "help.chm").

Returns undef if the stem is not registered.

=cut

sub chm_subdir_by_stem
{
	my ($self, $chm_stem) = @_;
	
	return $self->{chm_stem_to_subdir}->{ fc($chm_stem) };
}

=head2 chm_subdir_by_chX($chX_file)

Fetches the registered subdirectory relative to the output directory for the named chm/chi/etc file
(specified without leading path).

Returns undef if the stem is not registered.

=cut

sub chm_subdir_by_chX
{
	my ($self, $chX_file) = @_;
	
	$chX_file =~ s/\.(chw|chi|chm)$//i;
	
	return $self->chm_subdir_by_stem($chX_file);
}

=head2 chm_stem_by_path($path)

Fetches the stem of the CHM whose subdirectory contains C<$path>.

Returns undef if the path doesn't match any registered CHMs.

=cut

sub chm_stem_by_path
{
	my ($self, $path) = @_;
	
	my ($stem) =
		grep { my $subdir = $self->{chm_stem_to_subdir}->{$_}; $path =~ m/^\Q$subdir\E/ }
		keys(%{ $self->{chm_stem_to_subdir} });
	
	return $stem;
}

=head2 depth_first_search($func)

Performs a depth-first search of every node in the ToC.

The C<$func> function will be called with each node object in turn and any nodes for which C<$func>
returns a true value will be returned.

=cut

sub depth_first_search
{
	my ($self, $func) = @_;
	return $self->{root}->depth_first_search($func);
}

package App::ChmWeb::ToC::Handler;

sub new
{
	my ($class) = @_;
	
	my $self = bless({}, $class);
	
	$self->{folders} = [];
	$self->{folder_stack} = [];
	
	return $self;
}

sub start_element
{
	my ($self, $elem) = @_;
	
	if(fc($elem->{Name}) eq fc("Folder"))
	{
		my $parent_folders = @{ $self->{folder_stack} }
			? $self->{folder_stack}->[-1]->{folders}
			: $self->{folders};
		
		my $new_folder = {
			title => "Untitled Folder",
			order => (scalar @$parent_folders),
			
			folders => [],
		};
		
		push(@$parent_folders, $new_folder);
		push(@{ $self->{folder_stack} }, $new_folder);
	}
	elsif(fc($elem->{Name}) eq fc("TitleString"))
	{
		$self->{folder_stack}->[-1]->{title} = $elem->{Attributes}->{VALUE}->{CdataChunks}->[0]->{Data};
	}
	elsif(fc($elem->{Name}) eq fc("FolderOrder"))
	{
		$self->{folder_stack}->[-1]->{order} = $elem->{Attributes}->{VALUE}->{CdataChunks}->[0]->{Data};
	}
}

sub end_element
{
	my ($self, $elem) = @_;
	
	if(fc($elem->{Name}) eq fc("Folder"))
	{
		pop(@{ $self->{folder_stack} });
	}
}

1;
