package Smokeping::probes::HPing;

=head1 301 Moved Permanently

This is a Smokeping probe module. Please use the command 

C<smokeping -man Smokeping::probes::HPing>

to view the documentation or the command

C<smokeping -makepod Smokeping::probes::Hping>

to generate the POD document.

=cut

use strict;
use Data::Dumper;
use base qw(Smokeping::probes::basefork); 
use Carp;

my $DEFAULTBIN = "/usr/sbin/hping3";

sub pod_hash {
	return {
		name => <<DOC,
Smokeping::probes::HPing - HPING Probe for SmokePing
DOC
		description => <<DOC,
Integrate HPING probes into smokeping.  

Point variable B<binary> to your copy of hping.

Can use hping for tcp, udp or icmp based pings.  Can also enable traceroute
mode to function to use ICMP Exceed In Transit responses for measuring 
network latency. 

You must give hping3 special permission for open_sockraw operation, eg:
setcap cap_net_raw=pe /usr/sbin/hping3

Example configurations:

+ Test1

host = <host>
pings = 20
protocol = tcp
port = 22

+ Test2

host = <host>
pings = 20
protocol = udp
port = 53
datasize = 33

+ Test3

host = <host>
pings = 20
protocol = icmp

To enable traceroute in a test:

+ Test4

host = <end system>
pings = 20
protocol = icmp
traceroute_hop = <#>  #define the TTL

Add the following to enable the probe to your Probes config file:

+ HPing

binary = /usr/sbin/hping3
pings = 5
port = 80


DOC
		authors => <<'DOC',
Henry Potgieter <hpotgieter@techtutoring.ca>
DOC
	};
}

my $featurehash = {
	port => "-p",
	datasize => "-d",
	ipproto => "-H",
	mtu => "-m",
	tos => "-o",
	icmptype => "-C",
};

sub features {
	my $self = shift;
	my $newval = shift;
	$featurehash = $newval if defined $newval;
	return $featurehash;
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    $self->_init if $self->can('_init');
    $self->{pingfactor} = 1000;

    return $self;
}

sub ProbeDesc($) {
	return "TCP, UDP or ICMP pings using Hping3";
}

sub make_host {
	my $self = shift;
	my $target = shift;
	return $target->{addr};
}

sub make_args {
	my $self = shift;
	my $target = shift;
	my @args;
	my %arghash = %{$self->features};

	for (keys %arghash) {
		my $val = $target->{vars}{$_};
		push @args, ($arghash{$_}, $val) if defined $val;
	}

	return @args;
}

sub count_args {
	my $self = shift;
	my $count = shift;

	$count = $self->pings() unless defined $count;
	return ("-c", $count);
}

sub make_commandline {
	my $self = shift;
	my $target = shift;
	my $count = shift;
    
	# If we're doing ICMP, strip out the default port for this target
	if ($target->{vars}{protocol} eq "icmp")
	{
		delete $target->{vars}{port};
	}

	#$self->do_debug(Dumper($target->{vars}));

	$count |= $self->pings($target);

	my $host = $self->make_host($target);
	my @args = $self->make_args($target);
	push @args, $self->count_args($count);
        if ($target->{vars}{protocol} eq "tcp")
        {
		unshift @args, "-S";

        }
        elsif ($target->{vars}{protocol} eq "udp")
        {
		unshift @args, "-2";
        }
        elsif ($target->{vars}{protocol} eq "icmp")
        {
		unshift @args, "-1";
        }

        if ($target->{vars}{traceroute_hop})
        {
    	    push @args, "-T --tr-keep-ttl --ttl", $target->{vars}{traceroute_hop};
        }
	
	return ($self->{properties}{binary}, @args, $host);
}

sub make_host {
	my $self = shift;
	my $target = shift;
	return $target->{addr};
}

sub pingone {
    my $self = shift;
    my $target = shift;

    my @cmd = $self->make_commandline($target);

    #$self->do_debug(Dumper($target->{vars}));

    my $cmd = join(" ", @cmd);

    $self->do_debug("executing cmd $cmd");

    my @times;

    open(P, "$cmd 2>&1 |") or carp("fork: $!");

    my @output;
    while (<P>) {
            chomp;
            push @output, $_;
	    # For Traceroute ICMP Time Exceed Returns
	    /^hop=\d+ hoprtt=(\d+\.\d+) ms/ and push @times, $1;
	    # For TCP Pings	
            /^len=\d+ ip=.+ ttl=\d+ DF id=\d+ sport=\d+ flags=.+ seq=\d+ win=\d+ rtt=(\d+\.\d+) ms/ and push @times, $1;
	    # For UDP Pings
	    /^len=\d+ ip=.+ ttl=\d+ DF id=\d+ seq=\d+ rtt=(\d+\.\d+) ms/ and push @times, $1;
	    # For ICMP Pings
	    /^len=\d+ ip=.+ ttl=\d+ id=\d+ icmp_seq=\d+ rtt=(\d+\.\d+) ms/ and push @times, $1;
    }
    close P;
    @times = map {sprintf "%.10e", $_ / $self->{pingfactor}} sort {$a <=> $b} @times;

    return @times;
}


sub probevars {
        my $class = shift;
        my $h = $class->SUPER::probevars;
	#delete $h->{timeout};
        return $class->_makevars($h, {
		_mandatory => [ 'binary' ],
		binary => { 
			_doc => "The location of your pingpong binary.",
			_example => '/usr/sbin/hping3',
			_default => $DEFAULTBIN,
			_sub => sub { 
				my $val = shift;
                                -x $val or return "ERROR: binary '$val' is not executable";
				return undef;
			},
		},
	});
}

sub targetvars {
	my $class = shift;
	return $class->_makevars($class->SUPER::targetvars, {
		ipproto => {
			_doc => "The IP Protocol fo raw IP mode",
			_example => '17',
		},
		mtu => {
			_doc => "The MTU to define for the packet",
			_example => '1280',
		},
		tos => {
			_doc => "The QoS/TOS bit value",
			_example => '10',
		},
		icmptype => {
			_doc => "Set the ICMP type, following are supported: 0, 3, 4, 5, 8, 11, 13, 14, 17 & 18",
			_example => '13'
		},
		timeout => {
			_doc => "The timeout for the query.",
			_example => '60',
			_default => '60',
		},
		port => {
			_doc => "The TCP/UDP port the probe should target.",
			_example => '80',
			_sub => sub {
				my $val = shift;

				return "ERROR: HPING3 port must be between 0 and 65535"
					if $val and ( $val < 0 or $val > 65535 );

				return undef;
			},
		},
		datasize => {
			_doc => "The size in bytes to send, recommended when doing udp pings.",
			_example => '50',
		},
		traceroute_hop => {
			_doc => "Set to enable traceroute and to specify specific ttl/hop to expire at.",
			_example => '5',
		},
		protocol => {
			_doc => "The protocol to connect with, enter tcp, udp or icmp",
			_example => 'tcp',
			_sub => sub {
				my $val = shift;

				return "ERROR: HPING3 protocol must be tcp, udp or icmp"
					if $val and ( $val != 'tcp' or $val != 'udp' or $val != 'icmp' );

				return undef;
			},
		},
		pings => {
			_doc => "The number of packets to send, from 1 to 40",
			_example => '5',
			_sub => sub {
				my $val = shift;

				return "ERROR: Invalid packet count, must be between 1 and 40"
					if $val and ( $val < 1 or $val > 40 );

				return undef;
			},
		},
	});
}

1;

