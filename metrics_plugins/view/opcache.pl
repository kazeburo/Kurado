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
    $list .= join("\t",'#Opcache ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/scripts hits strings memory/;
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
@@ scripts
cached scripts
DEF:my1=<%RRD num_cached_keys.gauge %>:read:AVERAGE
DEF:my2=<%RRD num_cached_scripts.gauge %>:write:AVERAGE
DEF:my3=<%RRD max_cached_keys.gauge %>:wait:AVERAGE
LINE2:my1#e55337:Cached keys
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
LINE2:my2#d2f35e:Cached scripts
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l
LINE1:my3#020203:Max cached keys
GPRINT:my3:LAST:Cur\:%7.1lf
GPRINT:my3:AVERAGE:Ave\:%7.1lf
GPRINT:my3:MAX:Max\:%7.1lf\l


@@ hits
hit rate
DEF:my1=<%RRD opcache_hit_rate.gauge %>:request:AVERAGE
CDEF:rate=my1,0,100,LIMIT
AREA:rate#fff956:Rate
GPRINT:rate:LAST:Cur\:%5.1lf[%%]
GPRINT:rate:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:rate:MAX:Max\:%5.1lf[%%]\l
LINE:100

@@ strings
strings usage
DEF:my1=<%RRD strings_used_memory.gauge %>:read:AVERAGE
DEF:my2=<%RRD strings_free_memory.gauge %>:write:AVERAGE
AREA:my1#e3aa59:Used
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
STACK:my2#381707:Free
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l

@@ memory
strings usage
DEF:my1=<%RRD used_memory.gauge %>:read:AVERAGE
DEF:my2=<%RRD free_memory.gauge %>:write:AVERAGE
DEF:my3=<%RRD wasted_memory.gauge %>:write:AVERAGE
AREA:my1#de4446:Used
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
STACK:my2#dfe968:Free
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l
STACK:my3#000d48:Wasted
GPRINT:my3:LAST:Cur\:%7.1lf
GPRINT:my3:AVERAGE:Ave\:%7.1lf
GPRINT:my3:MAX:Max\:%7.1lf\l
