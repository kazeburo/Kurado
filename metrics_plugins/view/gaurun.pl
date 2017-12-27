#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);

sub metrics_list {
    my $plugin = shift;
    my $meta = $plugin->metrics_meta;
    my $list='';

    # info
    my @info;
    for my $key ( $plugin->sort_info(keys %$meta) ) {
        push @info, $key, $meta->{$key};
    }
    my ($port,$path) = @{$plugin->plugin_arguments};
    $port ||= 82;
    $list .= join("\t",'#Gaurun ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/queue ios ios_rate android android_rate/;
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

__DATA__
@@ queue
Queue
DEF:my1=<%RRD queue_usage.gauge %>:read:AVERAGE
DEF:my2=<%RRD queue_max.gauge %>:read:AVERAGE
AREA:my1#00C000:Queued
GPRINT:my1:LAST:Cur\:%8.0lf
GPRINT:my1:AVERAGE:Ave\:%8.0lf
GPRINT:my1:MAX:Max\:%8.0lf\l
LINE:my2#333333:Max   
GPRINT:my2:LAST:Cur\:%8.0lf
GPRINT:my2:AVERAGE:Ave\:%8.0lf
GPRINT:my2:MAX:Max\:%8.0lf\l


@@ ios
iOS
DEF:my1a=<%RRD ios_push_success.counter %>:read:AVERAGE
DEF:my2a=<%RRD ios_push_error.counter %>:read:AVERAGE
CDEF:my1=my1a,0,10000,LIMIT
CDEF:my2=my2a,0,10000,LIMIT
AREA:my2#990000:Error  
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l
STACK:my1#0000C0:Success
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l

@@ ios_rate
iOS success rate
DEF:my1=<%RRD ios_push_success.counter %>:read:AVERAGE
DEF:my2=<%RRD ios_push_error.counter %>:read:AVERAGE
CDEF:total=my1,my2,+
CDEF:my1r=my1,total,/,100,*
CDEF:my2r=my2,total,/,100,*
AREA:my2r#990000:Error  
GPRINT:my2r:LAST:Cur\:%5.1lf[%%]
GPRINT:my2r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my2r:MAX:Max\:%5.1lf[%%]\l
AREA:my1r#00cc00:Success
GPRINT:my1r:LAST:Cur\:%5.1lf[%%]
GPRINT:my1r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1r:MAX:Max\:%5.1lf[%%]\l


@@ android
Android
DEF:my1a=<%RRD android_push_success.counter %>:read:AVERAGE
DEF:my2a=<%RRD android_push_error.counter %>:read:AVERAGE
CDEF:my1=my1a,0,10000,LIMIT
CDEF:my2=my2a,0,10000,LIMIT
AREA:my2#990000:Error  
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l
STACK:my1#0000C0:Success
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l


@@ android_rate
Android success rate
DEF:my1=<%RRD android_push_success.counter %>:read:AVERAGE
DEF:my2=<%RRD android_push_error.counter %>:read:AVERAGE
CDEF:total=my1,my2,+
CDEF:my1r=my1,total,/,100,*
CDEF:my2r=my2,total,/,100,*
AREA:my2r#990000:Error  
GPRINT:my2r:LAST:Cur\:%5.1lf[%%]
GPRINT:my2r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my2r:MAX:Max\:%5.1lf[%%]\l
STACK:my1r#00cc00:Success
GPRINT:my1r:LAST:Cur\:%5.1lf[%%]
GPRINT:my1r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1r:MAX:Max\:%5.1lf[%%]\l


