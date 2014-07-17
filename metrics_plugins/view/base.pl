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
    foreach my $interface ( @traffic_interface ) {
        $list .= "# Traffic($interface)\n";
        $list .= "traffic-$interface\n";
    }
    # cpu, load-avg,  memory-usage, tcp-established
    $list .= "# CPU Memory\n";
    $list .= "$_\n"for qw/cpu load-avg memory-usage tcp-established/;

    # disk usage
    my @usage_devices = split /,/, $meta->{'disk-usage-devices'} || '';
    foreach my $device ( @usage_devices ) {
        my $mount = exists $meta->{"disk-usage-".$device."-mount"} ? $meta->{"disk-usage-".$device."-mount"} : $device;
        $list .= "# Disk Usage($mount)\n";
        $list .= "disk-usage-$device\n";
    }

    # disk io
    my @io_devices = split /,/, $meta->{'disk-io-devices'} || '';
    foreach my $device ( @usage_devices ) {
        $list .= "# Disk Usage($device)\n";
        $list .= "disk-io-$device\n";
    }

    print $list;
}

sub metrics_graph {
    my $plugin = shift;
}

if ($plugin->{graph} ) {
    metrics_graph($plugin);
}
metrics_list($plugin);

=pod

=head1 NAME

display/base.pl - display plugin for base metrics

=head1 SYNOPSIS

  % display/base.pl --help

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
DEF:ind=<%RRD%>:in:AVERAGE
DEF:outd=<%RRD%>:out:AVERAGE
CDEF:in=ind,0,1250000000,LIMIT,8,*
CDEF:out=outd,0,1250000000,LIMIT,8,*
AREA:in#00C000:Inbound  
GPRINT:in:LAST:Cur\:%6.2lf%sbps
GPRINT:in:AVERAGE:Ave\:%6.2lf%sbps
GPRINT:in:MAX:Max\:%6.2lf%sbps\l
LINE1:out#0000FF:Outbound 
GPRINT:out:LAST:Cur\:%6.2lf%sbps
GPRINT:out:AVERAGE:Ave\:%6.2lf%sbps
GPRINT:out:MAX:Max\:%6.2lf%sbps\l


