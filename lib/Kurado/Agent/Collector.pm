package Kurado::Agent::Collector;

use strict;
use warnings;
use Kurado::Util;

our @FUNC = qw/memory loadavg uptime sys_version processors cpu_usage tcp_established disk_usage disk_io swaps traffic/;

sub new {
    my ($class, $plugins) = @_;
    bless {
        plugins => $plugins
    }, $class;
}

sub metrics {
    my $self = shift;
    return $self->{metrics};
}

sub meta {
    my $self = shift;
    return $self->{meta};
}

sub collect {
    my ($self,$self_ip) = @_;
    $self->{metrics} = {};
    $self->{meta} = {};
    my %warn;
    my %result;
    for my $func (@FUNC){
        eval {
            $self->$func();
        };
        if ( $@ ) {
            $warn{$func} = $@;;
            $warn{$func} =~ s!(?:\n|\r)!!g;
        }
    }
    my $body;
    my $time = time();
    $body .= "$self_ip\tbase.metrics.$_\t".$self->{metrics}->{$_}."\t$time\n" for sort keys %{$self->{metrics}};
    $body .= "$self_ip\tbase.meta.$_\t".$self->{meta}->{$_}."\t$time\n" for sort keys %{$self->{meta}};
    $body .= "$self_ip\tbase.warn.$_\t".$warn{$_}."\t$time\n" for sort keys %warn;
    $body;
}

sub collect_plugins {
    my ($self,$self_ip) = @_;
    my $body = '';
    my $time = time;
    for my $plugin_key ( keys %{$self->{plugins}} ){
        eval {
            my ($result, $exit_code) = cap_cmd([$self->{plugins}->{$plugin_key}]);
            die "failed to exec plugin:$plugin_key: exit_code: $exit_code\n" if $exit_code != 0;
            for my $ret (split /\n/, $result) {
                chomp($ret);
                my @ret = split /\t/,$ret;
                if ( $ret[0] !~ m!^(?:metrics|meta)\.! ) {
                    $ret[0] = "metrics.$ret[0]";
                }
                if ( $ret[0] !~ m!\.(?:gauge|counter|derive|absolute)$! ) {
                    $ret[0] = "$ret[0].gauge";
                }
                $ret[0] = "$plugin_key.$ret[0]";
                $ret[2] ||= $time;
                $body .= join("\t", $self_ip, @ret[0,1,2])."\n";
            }
        };
        if ( $@ ) {
            my $warn = $@;
            $warn =~ s!(?:\n|\r)!!g;
            $body .= "$self_ip\t$plugin_key.warn.command\t$warn\t$time\n";
        }
    }
    $body;
}

sub memory {
    my $self = shift;
    my %MEMORY_ITEM = (
        'MemTotal'  => 'memory-total.gauge',
        'MemFree'   => 'memory-free.gauge',
        'Buffers'   => 'memory-buffers.gauge',
        'Cached'    => 'memory-cached.gauge',
        'SwapTotal' => 'memory-swap-total.gauge',
        'SwapFree'  => 'memory-swap-free.gauge',
    );

    open my $fh, '<:utf8', '/proc/meminfo' or die "$!\n";
    my %meminfo;
    while (<$fh>) {
        chomp;chomp;
        my($key, $val) = split /[\s:]+/, $_, 2;
        next unless $key;
        $meminfo{$key} = to_byte($val);
    }
    close $fh;

    my $metrics = $self->metrics;
    for my $k ( keys %MEMORY_ITEM ) {
        $metrics->{$MEMORY_ITEM{$k}} = int( defined $meminfo{$k} ? $meminfo{$k} :  0);
    }

    $metrics->{'memory-used.gauge'} = $metrics->{'memory-total.gauge'}
        - $metrics->{'memory-free.gauge'}
        - $metrics->{'memory-buffers.gauge'}
        - $metrics->{'memory-cached.gauge'};
    $metrics->{'memory-swap-used.gauge'} = $metrics->{'memory-swap-total.gauge'} - $metrics->{'memory-swap-free.gauge'};
    delete $metrics->{'memory-swap-free.gauge'}
}


sub loadavg {
    my $self = shift;
    open my $fh, '<', '/proc/loadavg' or die "$!\n";
    while (<$fh>) {
        if (my @e = split /\s+/) {
            $self->metrics->{'loadavg-1.gauge'}  = $e[0];
            $self->metrics->{'loadavg-5.gauge'}  = $e[1];
            $self->metrics->{'loadavg-15.gauge'} = $e[2];
            last;
        }
    }
    close $fh;
}

sub uptime {
    my $self = shift;
    open my $fh, '<', '/proc/uptime' or die "$!\n";
    while (<$fh>) {
        if (my @e = split /\s+/) {
            $self->meta->{'uptime'}  = int($e[0]);
            last;
        }
    }
    close $fh;
}

sub sys_version {
    my $self = shift;
    open my $fh, '<', '/proc/version' or die "$!\n";
    $self->meta->{'version'} = <$fh>;
    chomp $self->meta->{'version'};
    close $fh;
}


sub processors {
    my $self = shift;
    open my $fh, '<', '/proc/cpuinfo' or die "$!\n";
    while (<$fh>) {
        $self->metrics->{'processors.gauge'}++ if m!^processor\s*:!
    }
    close $fh;
}


sub cpu_usage {
    my $self = shift;
    open my $fh, '<', '/proc/stat' or die "$!\n";
    my @keys = qw(cpu-user cpu-nice cpu-system cpu-idle cpu-iowait cpu-irq cpu-softirq cpu-steal cpu-guest cpu-guest-nice);
    while (<$fh>) {
        if (/^cpu\s+/) {
            chomp;
            my(undef, @t) = split /\s+/;
            for my $k (@keys) {
                my $v = shift @t;
                $self->metrics->{"$k.derive"} = int(defined $v ? $v : 0);
            }
            last;
        }
    }
    close $fh;
}

sub tcp_established {
    my $self = shift;
    open my $fh, '<', '/proc/net/snmp' or die "$!\n";
    my $index;
    while (<$fh>) {
        if (/^Tcp:/) {
            my @vals = split /\s+/, $_;
            if (!$index) {
                for my $label (@vals) {
                    last if $label eq 'CurrEstab';
                    $index++;
                }
            }
            else {
                $self->metrics->{'tcp-established.gauge'} = $vals[$index];
                last;
            }
        }
    }
}



sub disk_usage {
    my $self = shift;
    open my $fh, '<', '/proc/mounts' or die "$!\n";
    my @mount_points;
    my %mount_points;
    while (<$fh>) {
        if ( m!^/dev/(.+?) (/.*?) ! ) {
            next if $2 eq '/boot'; # not required
            push @mount_points, $2;
            $mount_points{$2} = $1;
            $mount_points{$2} =~ s![^A-Za-z0-9_-]!_!g;
        }
    }
    return unless @mount_points;
    my ($result, $exit_code) = cap_cmd(['df',@mount_points]);
    die "failed to exec df\n" if $exit_code != 0;
    my @devices;
    for ( split /\n/, $result ) {
        chomp;chomp;
        my @d = split /\s+/, $_;
        next unless exists $mount_points{$d[5]};
        $self->metrics->{"disk-usage-".$mount_points{$d[5]}."-used.gauge"} = $d[2];
        $self->metrics->{"disk-usage-".$mount_points{$d[5]}."-available.gauge"} = $d[3];
        $self->meta->{"disk-usage-".$mount_points{$d[5]}."-mount"} = $d[5];
        push @devices, $mount_points{$d[5]};
    }
    $self->meta->{"disk-usage-devices"} = join ",", @devices if @devices;
}

sub translate_device_mapper {
    my $device = shift;;
    for my $d ( glob(q!/dev/mapper/*!) ) {
        my $s = readlink($d);
        next unless $s;
        ($s) = ( $s =~ m!(dm-.+)$! );
        if ( $s eq $device ) {
            $d =~ s!^/dev/!!;
            return $d;
        }        
    }
    die "cannot resolv $device\n";
}

sub disk_io {
    my $self = shift;
    my @stats = glob '/sys/block/*/stat';
    my @devices;
    for my $stat ( @stats ) {
        my ($device) = ( $stat =~ m!^/sys/block/(.+)/stat$! );
        next if $device =~ m!^(loop|ram)\d+$!;
        open my $fh, '<', $stat or die "$!\n";
        my $dstat = <$fh>;
        close $fh;
        $dstat =~ s!^\s+!!g;
        my @dstats = split /\s+/, $dstat;
        if ( $device =~ m!^dm-! ) {
            $device = translate_device_mapper($device);
        }
        # readd-ios read-merges read-sectors readd-ticks 0..3
        # write-ios write-merges write-sectors write-ticks 4..7
        # ios-in-prog tot-ticks rq-ticks 8..9
        next if $dstats[0] == 0 && $dstats[4] == 0;
        $device =~ s![^A-Za-z0-9_-]!_!g;
        push @devices, $device;
        $self->metrics->{"disk-io-".$device."-read-ios.derive"} = $dstats[0];
        $self->metrics->{"disk-io-".$device."-read-sectors.derive"} = $dstats[2];
        $self->metrics->{"disk-io-".$device."-write-ios.derive"} = $dstats[4];
        $self->metrics->{"disk-io-".$device."-write-sectors.derive"} = $dstats[6];
    }
    $self->meta->{"disk-io-devices"} = join ",", @devices if @devices;
}


sub swaps {
    my $self = shift;
    open my $fh, '<', '/proc/swaps' or die "$!\n";
#   [vagrant@localhost ~]$ cat /proc/swaps 
#   Filename                                Type            Size    Used    Priority
#   /dev/dm-1                               partition       950264  208     -1
    my @swaps;
    while (<$fh>) {
        if ( m!^/dev/(.+?)\s*partition! ) {
            my $device = $1;
            if ( $device =~ m!^dm-! ) {
                $device = translate_device_mapper($device);
            }
            $device =~ s![^A-Za-z0-9_-]!_!g;
            push @swaps, $device;
        }
    }
    $self->meta->{"disk-swap-devices"} = join ",", @swaps if @swaps;
}

sub traffic {
    my $self = shift;

    my ($result, $exit_code) = cap_cmd(['ip','-s','-o','link']);
    die "failed to exec ip link\n" if $exit_code != 0;

#2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
#    link/ether 00:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
#    RX: bytes  packets  errors  dropped overrun mcast   
#    419890719  512995634 0       0       0       0      
#    TX: bytes  packets  errors  dropped carrier collsns 
#    2050758259 400885501 0       0       0       0 
#5: eth3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN qlen 1000
#    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
#    RX: bytes  packets  errors  dropped overrun mcast   
#    0          0        0       0       0       0      
#    TX: bytes  packets  errors  dropped carrier collsns 
#    0          0        0       0       0       0      
#6: eth1.66@eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP 
#    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
#    RX: bytes  packets  errors  dropped overrun mcast   
#    4092101350 335780455 0       0       0       3122   
#    TX: bytes  packets  errors  dropped carrier collsns 
#    2759531860 774335892 0       0       0       0      

    my @interfaces;
    for ( split /\n/, $result ) {
        chomp;chomp;
        if ( m!^\d+:\s*([a-z0-9]+):\s<([^>]+)>\s(.*)$! ) {
            my $interface = $1;
            my $state = $2;
            my $stats = $3;
            next if $interface eq 'lo'; #skip loopback
            next unless grep { $_ eq "UP" } split /,/, $state; #not up

            $interface =~ s![^A-Za-z0-9_-]!_!g;
            push @interfaces, $interface;

            my (undef,undef,undef,$rx_stat,undef,$tx_stat) = split /\\\s*/, $stats;
            my @rx_stats = split /\s+/, $rx_stat;
            $self->metrics->{"traffic-${interface}-rxbytes.derive"} = $rx_stats[0];
            my @tx_stats = split /\s+/, $tx_stat;
            $self->metrics->{"traffic-${interface}-txbytes.derive"} = $tx_stats[0];
        }
    }
    $self->meta->{"traffic-interfaces"} = join ",", @interfaces if @interfaces;
}

1;
