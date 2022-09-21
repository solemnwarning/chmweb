use strict;
use warnings;

package App::ChmWeb::Util;

sub resolve_link
{
	my ($local_document, $link) = @_;
	
	if($link =~ m/^\//)
	{
		# Link is absolute - convert to be relative to current document
		
		my @local_dir = grep { $_ ne "" } split(m/\//, $local_document);
		pop(@local_dir);
		
		my @link_dir = grep { $_ ne "" } split(m/\//, $link);
		my $link_file = pop(@link_dir);
		
		my @new_link_dir = ();
		
		# Walk up from current directory until reaching a common ancestor with link
		
		for(my ($i, $flag) = (0, 0); $i < (scalar @local_dir); ++$i)
		{
			if($flag || $i > $#link_dir || $local_dir[$i] ne $link_dir[$i])
			{
				push(@new_link_dir, "..");
				$flag = 1;
			}
		}
		
		# Walk down from common ancestor into link directory
		
		for(my ($i, $flag) = (0, 0); $i < (scalar @link_dir); ++$i)
		{
			if($flag || $i > $#local_dir || $local_dir[$i] ne $link_dir[$i])
			{
				push(@new_link_dir, $link_dir[$i]);
				$flag = 1;
			}
		}
		
		my $new_link = join("/", @new_link_dir, $link_file);
		return $new_link;
	}
	else{
		# Link is relative (or to a different domain) - return as-is
		return $link;
	}
}

sub find_hhc_in
{
	my ($path) = @_;
	
	opendir(my $d, $path) or die "$path: $!";
	my @hhc_names = grep { $_ =~ m/\.hhc$/i && -f "$path/$_" } readdir($d);
	
	if((scalar @hhc_names) == 1)
	{
		return $hhc_names[0];
	}
	else{
		die "Unable to find HHC file in $path\n";
	}
}

1;
