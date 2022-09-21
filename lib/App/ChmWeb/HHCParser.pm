use strict;
use warnings;

package App::ChmWeb::HHCParser;

use SGML::Parser::OpenSP;

sub parse_hhc_file
{
	my ($filename) = @_;
	
	my $p = SGML::Parser::OpenSP->new();
	my $h = App::ChmWeb::HHCParser::Handler->new();
	
	$p->catalogs(qw(xhtml.soc));
	$p->warnings(qw(xml valid));
	$p->handler($h);
	
	$p->parse($filename);
	
	_merge_empty_nodes($h->{toc});
	
	return {
		toc => $h->{toc},
	};
}

# Some HHC files close the parent <li> tag before opening the <ul> of the child list, which makes
# OpenSP generate a fake <li> tag to keep the structure valid, but then we wind up with nodes that
# only have sub-lists in them, so we have to flatten them into their previous sibling to avoid
# garbage nodes...

sub _merge_empty_nodes
{
	my ($nodes) = @_;
	
	for(my $i = 0; ($i + 1) < (scalar @$nodes);)
	{
		my @next_keys = keys(%{ $nodes->[$i + 1] });
		
		if((scalar @next_keys) == 1 && $next_keys[0] eq "children")
		{
			$nodes->[$i]->{children} = [
				@{ $nodes->[$i]->{children} // [] },
				@{ $nodes->[$i + 1]->{children} },
			];
			
			splice(@$nodes, $i + 1, 1);
		}
		else{
			++$i;
		}
	}
	
	foreach my $node(@$nodes)
	{
		if(defined $node->{children})
		{
			_merge_empty_nodes($node->{children});
		}
	}
}

package App::ChmWeb::HHCParser::Handler;

sub new
{
	my ($class) = @_;
	
	my $self = bless({}, $class);
	
	$self->{toc} = [];
	$self->{li_node} = undef;
	$self->{stack} = [ $self->{toc} ];
	
	return $self;
}

sub start_element
{
	my ($self, $elem) = @_;
	
	if(lc($elem->{Name}) eq "ul")
	{
		if(defined $self->{li_node})
		{
			$self->{li_node}->{children} //= [];
			push(@{ $self->{stack} }, $self->{li_node}->{children});
		}
	}
	elsif(lc($elem->{Name}) eq "li")
	{
		$self->{li_node} = {};
		push(@{ $self->{stack}->[-1] }, $self->{li_node});
	}
	elsif(lc($elem->{Name}) eq "param")
	{
		if(defined $self->{li_node})
		{
			my $a_name  = $elem->{Attributes}->{NAME}->{CdataChunks}->[0]->{Data};
			my $a_value = $elem->{Attributes}->{VALUE}->{CdataChunks}->[0]->{Data};
			
			$self->{li_node}->{$a_name} = $a_value;
		}
	}
}

sub end_element
{
	my ($self, $elem) = @_;
	
	if(lc($elem->{Name}) eq "ul")
	{
		pop(@{ $self->{stack} });
	}
}

1;
