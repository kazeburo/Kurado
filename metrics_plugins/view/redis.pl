#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);

# meta.maxmemory-policy   volatile-lru    1406098240
# meta.appendfsync        everysec        1406098240
# meta.uptime     519361  1406098240
# meta.role       master  1406098240
# meta.save       900 1 300 10 60 10000   1406098240
# meta.maxclients 4064    1406098240
# meta.slowlog-max-len    128     1406098240
# meta.maxmemory  0       1406098240
# meta.version    2.8.12  1406098240
# meta.appendonly no      1406098240
# meta.rdbcompression     yes     1406098240
# metrics.total_commands_processed.derive 115611  1406098240
# metrics.connected_slaves.gauge  0       1406098240
# metrics.evicted_keys.derive     0       1406098240
# metrics.keys.gauge      1219    1406098240
# metrics.mem_fragmentation_ratio.gauge   2.55    1406098240
# metrics.total_connections_received.derive       927     1406098240
# metrics.connected_clients.gauge 9       1406098240
# metrics.pubsub_channels.gauge   0       1406098240
# metrics.slowlog.gauge   0       1406098240
# metrics.used_memory.gauge       866184  1406098240

sub metrics_list {
    my $plugin = shift;
    my $meta = $plugin->metrics_meta;
    my $list='';

    # info
    my @info;
    for my $key ( $plugin->sort_info(keys %$meta) ) {
        if ( $key eq 'uptime' ) {
            push @info, 'uptime', $plugin->uptime2str($meta->{uptime});
        }
        elsif ( $key eq 'maxmemory' ) {
            push @info, 'maxmemory', $plugin->unit($meta->{maxmemory});
        }
        else {
            push @info, $key, $meta->{$key};
        }
    }
    my ($port) = @{$plugin->plugin_arguments};
    $port ||= 6379;
    $list .= join("\t",'#Redis('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/cmd conn mem keys evicted fragmentation pubsub_ch slowlog unsaved/;
    print $list;
}

sub metrics_graph {
    my $plugin = shift;
    my $graph = $plugin->graph;
    my $def = '';
    $def = $plugin->render($graph);
    print "$def\n";
}

if ($plugin->graph ) {
    metrics_graph($plugin);
}
else {
    metrics_list($plugin);
}

=pod

=head1 NAME

view/redis.pl - display metrics of redis

=head1 SYNOPSIS

  % view/redis.pl --help

=head1 DESCRIPTION

display metrics of redis

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__
@@ cmd
Command Processed
DEF:my1a=<%RRD_FOR total_commands_processed.derive %>:n:AVERAGE
CDEF:my1=my1a,0,10000000,LIMIT
AREA:my1#FF8C00:Total Command
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l

@@ conn
Connections
DEF:my1=<%RRD_FOR connected_clients.gauge %>:n:AVERAGE
DEF:my2=<%RRD_FOR connected_slaves.gauge %>:n:AVERAGE
DEF:my3a=<%RRD_FOR total_connections_received.derive %>:n:AVERAGE
CDEF:my3=my3a,0,10000000,LIMIT
AREA:my1#00c000:Clients 
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l
LINE2:my2#990033:Slaves  
GPRINT:my2:LAST:Cur\:%5.1lf
GPRINT:my2:AVERAGE:Ave\:%5.1lf
GPRINT:my2:MAX:Max\:%5.1lf\l
LINE2:my3#596acf:Received
GPRINT:my3:LAST:Cur\:%5.1lf
GPRINT:my3:AVERAGE:Ave\:%5.1lf
GPRINT:my3:MAX:Max\:%5.1lf\l

@@ mem
Memory Usage
DEF:my1=<%RRD_FOR used_memory.gauge %>:n:AVERAGE
CDEF:sm=my1,900,TREND
CDEF:cf=86400,-8,1800,sm,PREDICT
AREA:my1#4682B4:Used
GPRINT:my1:LAST:Cur\:%5.1lf%sB
GPRINT:my1:AVERAGE:Ave\:%5.1lf%sB
GPRINT:my1:MAX:Max\:%5.1lf%sB\l
LINE1:cf#b78795:Prediction:dashes=4,6

@@ keys
Keys
DEF:my1=<%RRD_FOR keys.gauge %>:n:AVERAGE
CDEF:sm=my1,900,TREND
CDEF:cf=86400,-8,1800,sm,PREDICT
AREA:my1#2a9b2a:Keys
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l
LINE1:cf#b78795:Prediction:dashes=4,6

@@ evicted
Evicted Keys/sec
DEF:my1=<%RRD_FOR evicted_keys.derive %>:n:AVERAGE
LINE2:my1#800040:Evicted Keys/sec
GPRINT:my1:LAST:Cur\:%5.1lf%s
GPRINT:my1:AVERAGE:Ave\:%5.1lf%s
GPRINT:my1:MAX:Max\:%5.1lf%s\l

@@ fragmentation
Fragmentation Ratio
DEF:my1=<%RRD_FOR mem_fragmentation_ratio.gauge %>:n:AVERAGE
LINE2:my1#d27b86:Fragmentation
GPRINT:my1:LAST:Cur\:%5.1lf[%%]
GPRINT:my1:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1:MAX:Max\:%5.1lf[%%]\l

@@ pubsub_ch
Pub/Sub Channels
DEF:my1=<%RRD_FOR pubsub_channels.gauge %>:n:AVERAGE
LINE2:my1#2E8B57:Pub/Sub Channels
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l

@@ slowlog
Slowlog(total)
DEF:my1=<%RRD_FOR slowlog.gauge %>:n:AVERAGE
AREA:my1#00c000:Slowlog
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l

@@ unsaved
Unsaved Changes
DEF:my1=<%RRD_FOR changes_since_last_save.gauge %>:n:AVERAGE
AREA:my1#BDB76B:Changes
GPRINT:my1:LAST:Cur\:%6.1lf%s
GPRINT:my1:AVERAGE:Ave\:%6.1lf%s
GPRINT:my1:MAX:Max\:%6.1lf%s\l



