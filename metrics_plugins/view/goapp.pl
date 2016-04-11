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
    $list .= join("\t",'#GoApp ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/goroutine cgo gc alloc malloc/;
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
@@ goroutine
number of goroutine
DEF:my1=<%RRD goroutine_num.gauge %>:read:AVERAGE
AREA:my1#00C000:Goroutine
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l

@@ cgo
cgo call per seconds
DEF:my1=<%RRD cgo_call_num.counter %>:read:AVERAGE
LINE2:my1#004080:cgo call/sec
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l

@@ gc
gc per seconds
DEF:my1=<%RRD gc_num.counter %>:read:AVERAGE
LINE2:my1#800040:gc/sec
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l

@@ alloc
memory alloc
DEF:my1=<%RRD memory_alloc.gauge %>:read:AVERAGE
AREA:my1#edaa40:memory alloc
GPRINT:my1:LAST:Cur\:%5.1lf%sB
GPRINT:my1:AVERAGE:Ave\:%5.1lf%sB
GPRINT:my1:MAX:Max\:%5.1lf%sB\l

@@ malloc
memory malloc / free
DEF:my1=<%RRD memory_mallocs.counter %>:read:AVERAGE
DEF:my2=<%RRD memory_frees.counter %>:read:AVERAGE
LINE2:my1#de4446:malloc
GPRINT:my1:LAST:Cur\:%5.1lf
GPRINT:my1:AVERAGE:Ave\:%5.1lf
GPRINT:my1:MAX:Max\:%5.1lf\l
LINE2:my2#000d48:free  
GPRINT:my2:LAST:Cur\:%5.1lf
GPRINT:my2:AVERAGE:Ave\:%5.1lf
GPRINT:my2:MAX:Max\:%5.1lf\l


