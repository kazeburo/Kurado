#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);

# base.meta.disk-io-devices   mapper_VolGroup-lv_root,mapper_VolGroup-lv_swap,sda 1404873350
# base.meta.disk-usage-devices    mapper_VolGroup-lv_root 1404873350
# base.meta.disk-usage-mapper_VolGroup-lv_root-mount  /   1404873350
# base.meta.traffic-interfaces    eth0    1404873350
# base.meta.uptime    57649   1404873350
# base.meta.version   Linux version 2.6.32-431.el6.x86_64 (mockbuild@c6b8.bsys.dev.centos.org) (gcc version 4.4.7 20120313 (Red Hat 4.4.7-4) (GCC) ) #1 SMP Fri Nov 22 03:15:09 UTC 2013  1404873350

# グラフの順は
#  traffic
#  cpu-usage
#  load-avg
#  memory-usage
#  tcp-established
#  disk-usage
#  disk-io

sub metrics_list {
    my $plugin = shift;
    my $meta = $plugin->metrics_meta;
    my $list='';;
    # info
    my @info;
    push @info, 'uptime', $plugin->uptime2str($meta->{uptime}) if exists $meta->{uptime};
    push @info, 'version', $meta->{version} if exists $meta->{version};
    $list .= join("\t",'# ',@info)."\n";
    # traffic
    my @traffic_interface = split /,/, $meta->{'traffic-interfaces'} || '';
    $list .= "# Traffic\twarn\tno interfaces\n" if ! @traffic_interface;
    foreach my $interface ( @traffic_interface ) {
        $list .= "# Traffic($interface)\n";
        $list .= "traffic-$interface\n";
    }
    # cpu, load-avg,  memory-usage, tcp-established
    $list .= "# CPU Memory\n";
    $list .= "$_\n"for qw/cpu loadavg-1 memory-usage tcp-established/;

    # disk usage
    my @usage_devices = split /,/, $meta->{'disk-usage-devices'} || '';
    $list .= "# Disk Usage\twarn\tno devices\n" if ! @usage_devices;
    foreach my $device ( @usage_devices ) {
        my $mount = exists $meta->{"disk-usage-".$device."-mount"} ? $meta->{"disk-usage-".$device."-mount"} : $device;
        $list .= "# Disk Usage($mount)\n";
        $list .= "disk-usage-$device\n";
    }

    # disk io
    my @io_devices = split /,/, $meta->{'disk-io-devices'} || '';
    my %swap_devices = map { ($_ => 1) } split /,/, $meta->{'disk-swap-devices'} || '';
    $list .= "# Disk IO\twarn\tno devices\n" if ! @io_devices;
    foreach my $device ( @io_devices ) {
        my $is_swap = exists $swap_devices{$device} ? "-swap" : "";
        $list .= "# Disk IO($device$is_swap)\n";
        $list .= "disk-io-byte-$device\n";
        $list .= "disk-io-count-$device\n";
    }

    print $list;
}

sub metrics_graph {
    my $plugin = shift;
    my $graph = $plugin->graph;
    my $def = '';
    if ( $graph =~ m!^(cpu|loadavg-1|memory-usage|tcp-established)$! ) {
        $def = $plugin->render($1);
    }
    elsif ( $graph =~ m!^(traffic|disk-io-byte|disk-io-count|disk-usage)-(.+)$! ) {
        $def = $plugin->render($1,{device=>$2});
    }
    else {
        die "this plugin does not support graph '$graph'";
    }
    print $def."\n";
}

if ($plugin->graph ) {
    metrics_graph($plugin);
}
else {
    metrics_list($plugin);
}

=pod

=head1 NAME

view/base.pl - display plugin for base metrics

=head1 SYNOPSIS

  % view/base.pl --help

=head1 DESCRIPTION

display plugin for base metrics. metrics is pushed from server with kurado_agent

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__
@@ traffic
Throughput
DEF:ind=<%RRD_FOR traffic-<?= $device ?>-rxbytes.derive %>:n:AVERAGE
DEF:outd=<%RRD_FOR traffic-<?= $device ?>-txbytes.derive %>:n:AVERAGE
CDEF:in=ind,0,5000000000,LIMIT,8,*
CDEF:out=outd,0,5000000000,LIMIT,8,*
AREA:in#00C000:Inbound  
GPRINT:in:LAST:Cur\:%6.2lf%sbps
GPRINT:in:AVERAGE:Ave\:%6.2lf%sbps
GPRINT:in:MAX:Max\:%6.2lf%sbps\l
LINE1:out#0000FF:Outbound 
GPRINT:out:LAST:Cur\:%6.2lf%sbps
GPRINT:out:AVERAGE:Ave\:%6.2lf%sbps
GPRINT:out:MAX:Max\:%6.2lf%sbps\l

@@ cpu
CPU Usage[%]
DEF:my1=<%RRD_FOR cpu-user.derive %>:n:AVERAGE
DEF:my2=<%RRD_FOR cpu-nice.derive %>:n:AVERAGE
DEF:my3=<%RRD_FOR cpu-system.derive %>:n:AVERAGE
DEF:my4=<%RRD_FOR cpu-idle.derive %>:n:AVERAGE
DEF:my5=<%RRD_FOR cpu-iowait.derive %>:n:AVERAGE
DEF:my7=<%RRD_FOR cpu-irq.derive %>:n:AVERAGE
DEF:my8=<%RRD_FOR cpu-softirq.derive %>:n:AVERAGE
DEF:my9=<%RRD_FOR cpu-steal.derive %>:n:AVERAGE
DEF:my10=<%RRD_FOR cpu-guest.derive %>:n:AVERAGE
DEF:my11=<%RRD_FOR cpu-guest-nice.derive %>:n:AVERAGE
CDEF:total=my1,my2,+,my3,+,my4,+,my5,+,my7,+,my8,+,my9,+,my10,+,my11,+
CDEF:my1r=my1,total,/,100,*,0,100,LIMIT
CDEF:my2r=my2,total,/,100,*,0,100,LIMIT
CDEF:my3r=my3,total,/,100,*,0,100,LIMIT
CDEF:my4r=my4,total,/,100,*,0,100,LIMIT
CDEF:my5r=my5,total,/,100,*,0,100,LIMIT
CDEF:my7r=my7,total,/,100,*,0,100,LIMIT
CDEF:my8r=my8,total,/,100,*,0,100,LIMIT
CDEF:my9r=my9,total,/,100,*,0,100,LIMIT
CDEF:my10r=my10,total,/,100,*,0,100,LIMIT
CDEF:my11r=my11,total,/,100,*,0,100,LIMIT
AREA:my1r#a9a9a9:User   
GPRINT:my1r:LAST:Cur\:%5.1lf[%%]
GPRINT:my1r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1r:MAX:Max\:%5.1lf[%%]\l
STACK:my2r#000080:Nice   
GPRINT:my2r:LAST:Cur\:%5.1lf[%%]
GPRINT:my2r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my2r:MAX:Max\:%5.1lf[%%]\l
STACK:my3r#008080:System 
GPRINT:my3r:LAST:Cur\:%5.1lf[%%]
GPRINT:my3r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my3r:MAX:Max\:%5.1lf[%%]\l
STACK:my4r#800080:Idle   
GPRINT:my4r:LAST:Cur\:%5.1lf[%%]
GPRINT:my4r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my4r:MAX:Max\:%5.1lf[%%]\l
STACK:my5r#f00000:Wait   
GPRINT:my5r:LAST:Cur\:%5.1lf[%%]
GPRINT:my5r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my5r:MAX:Max\:%5.1lf[%%]\l
STACK:my7r#F39034:Intr   
GPRINT:my7r:LAST:Cur\:%5.1lf[%%]
GPRINT:my7r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my7r:MAX:Max\:%5.1lf[%%]\l
STACK:my8r#3D282A:SoftIRQ
GPRINT:my8r:LAST:Cur\:%5.1lf[%%]
GPRINT:my8r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my8r:MAX:Max\:%5.1lf[%%]\l
STACK:my9r#EBF906:Steal  
GPRINT:my9r:LAST:Cur\:%5.1lf[%%]
GPRINT:my9r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my9r:MAX:Max\:%5.1lf[%%]\l
STACK:my10r#81F781:Guest  
GPRINT:my10r:LAST:Cur\:%5.1lf[%%]
GPRINT:my10r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my10r:MAX:Max\:%5.1lf[%%]\l
STACK:my11r#8181F7:GstNice
GPRINT:my11r:LAST:Cur\:%5.1lf[%%]
GPRINT:my11r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my11r:MAX:Max\:%5.1lf[%%]\l

@@ loadavg-1
Load Average
DEF:my1=<%RRD_FOR loadavg-1.gauge %>:n:AVERAGE
DEF:my2=<%RRD_FOR processors.gauge %>:n:AVERAGE
AREA:my1#00C000:Load Average
GPRINT:my1:LAST:Cur\:%6.2lf
GPRINT:my1:AVERAGE:Ave\:%6.2lf
GPRINT:my1:MAX:Max\:%6.2lf\l
LINE1:my2#ff3e00:CPU Core    :dashes=3,6
GPRINT:my2:LAST:Cur\:%6.0lf\l

@@ memory-usage
Memory Usage
#dump    base.metrics.memory-buffers.gauge        36732928       1406000670
#dump    base.metrics.memory-cached.gauge         75522048       1406000670
#dump    base.metrics.memory-free.gauge          178077696       1406000670
#dump    base.metrics.memory-swap-total.gauge    973070336       1406000670
#dump    base.metrics.memory-swap-used.gauge             0       1406000670
#dump    base.metrics.memory-total.gauge         480718848       1406000670
#dump    base.metrics.memory-used.gauge          220954624       1406000670
DEF:used=<%RRD_FOR memory-used.gauge %>:n:AVERAGE
DEF:buffers=<%RRD_FOR memory-buffers.gauge %>:n:AVERAGE
DEF:cached=<%RRD_FOR memory-cached.gauge %>:n:AVERAGE
DEF:free=<%RRD_FOR memory-free.gauge %>:n:AVERAGE
DEF:total=<%RRD_FOR memory-total.gauge %>:n:AVERAGE
DEF:swap-used=<%RRD_FOR memory-swap-used.gauge %>:n:AVERAGE
DEF:swap-total=<%RRD_FOR memory-swap-total.gauge %>:n:AVERAGE
# used
AREA:used#ffdd67:used      
GPRINT:used:LAST:Cur\:%6.1lf%sByte
GPRINT:used:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:used:MAX:Max\:%6.1lf%sByte\l
# buffer
STACK:buffers#8a8ae6:buffers   
GPRINT:buffers:LAST:Cur\:%6.1lf%sByte
GPRINT:buffers:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:buffers:MAX:Max\:%6.1lf%sByte\l
# cached
STACK:cached#6060e0:cached    
GPRINT:cached:LAST:Cur\:%6.1lf%sByte
GPRINT:cached:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:cached:MAX:Max\:%6.1lf%sByte\l
# avail real
STACK:free#80e080:avail real
GPRINT:free:LAST:Cur\:%6.1lf%sByte
GPRINT:free:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:free:MAX:Max\:%6.1lf%sByte\l
# used swap
LINE2:swap-used#ff5f60:used  swap
GPRINT:swap-used:LAST:Cur\:%6.1lf%sByte
GPRINT:swap-used:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:swap-used:MAX:Max\:%6.1lf%sByte\l
# total swap
LINE1:swap-total#800180:total swap:dashes=2,4
GPRINT:swap-total:LAST:Cur\:%6.1lf%sByte
GPRINT:swap-total:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:swap-total:MAX:Max\:%6.1lf%sByte\l
# total real
LINE2:total#08007f:total real
GPRINT:total:LAST:Cur\:%6.1lf%sByte
GPRINT:total:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:total:MAX:Max\:%6.1lf%sByte\l

@@ tcp-established
TCP Established
DEF:tcpestab=<%RRD_FOR tcp-established.gauge %>:n:AVERAGE
AREA:tcpestab#00C000:Established
GPRINT:tcpestab:LAST:Cur\:%6.1lf
GPRINT:tcpestab:AVERAGE:Ave\:%6.1lf
GPRINT:tcpestab:MAX:Max\:%6.1lf\l

@@ disk-io-byte
DiskIO
# base.metrics.disk-io-mapper_VolGroup-lv_swap-read-sectors.derive    3272    1404873350
# base.metrics.disk-io-mapper_VolGroup-lv_swap-write-sectors.device   5040    1404873350
DEF:my1a=<%RRD_FOR disk-io-<?= $device ?>-read-sectors.derive %>:n:AVERAGE
DEF:my2a=<%RRD_FOR disk-io-<?= $device ?>-write-sectors.derive %>:n:AVERAGE
CDEF:my1=my1a,0,2000000000,LIMIT
CDEF:my2=my2a,0,2000000000,LIMIT
AREA:my1#00C000:Read/s 
GPRINT:my1:LAST:Cur\:%6.1lf%sByte
GPRINT:my1:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:my1:MAX:Max\:%6.1lf%sByte\l
STACK:my2#0000C0:Write/s
GPRINT:my2:LAST:Cur\:%6.1lf%sByte
GPRINT:my2:AVERAGE:Ave\:%6.1lf%sByte
GPRINT:my2:MAX:Max\:%6.1lf%sByte\l

@@ disk-io-count
DiskIO Count
DEF:my1a=<%RRD_FOR disk-io-<?= $device ?>-read-ios.derive %>:n:AVERAGE
DEF:my2a=<%RRD_FOR disk-io-<?= $device ?>-write-ios.derive %>:n:AVERAGE
CDEF:my1=my1a,0,100000000,LIMIT
CDEF:my2=my2a,0,100000000,LIMIT
AREA:my1#c0c0c0:Read  
GPRINT:my1:LAST:Cur\:%6.1lf%s
GPRINT:my1:AVERAGE:Ave\:%6.1lf%s
GPRINT:my1:MAX:Max\:%6.1lf%s\l
STACK:my2#800080:Write 
GPRINT:my2:LAST:Cur\:%6.1lf%s
GPRINT:my2:AVERAGE:Ave\:%6.1lf%s
GPRINT:my2:MAX:Max\:%6.1lf%s\l

@@ disk-usage
Disk Usage
# base.metrics.disk-usage-mapper_VolGroup-lv_root-available.gauge 36329940    1404873350
# base.metrics.disk-usage-mapper_VolGroup-lv_root-used.gauge  1487404 1404873350
DEF:avail=<%RRD_FOR disk-usage-<?= $device ?>-available.gauge %>:n:AVERAGE
DEF:used=<%RRD_FOR disk-usage-<?= $device ?>-used.gauge %>:n:AVERAGE
CDEF:avail_b=avail,1000,*
CDEF:used_b=used,1000,*
CDEF:total=avail_b,used_b,+
CDEF:rate=used_b,total,/
VDEF:slope=used_b,LSLSLOPE
VDEF:cons=used_b,LSLINT
CDEF:lsl2=used_b,POP,slope,COUNT,*,cons,+
LINE0:rate#ffffff:Capacity
GPRINT:rate:LAST:Cur\:%5.2lf[%%]\l
AREA:total#ff99ff:Total   
GPRINT:total:LAST:Cur\:%5.2lf%sB
AREA:used_b#cc00ff:Used
GPRINT:used_b:LAST:Cur\:%5.2lf%sB\l
LINE1:lsl2#00A000:Prediction:dashes=3,6
