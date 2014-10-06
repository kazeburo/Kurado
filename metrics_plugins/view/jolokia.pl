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
        if ( $key eq 'uptime' ) {
            push @info, 'uptime', $plugin->uptime2str($meta->{uptime});
        }
        else {
            push @info, $key, $meta->{$key};
        }
    }
    my ($port) = @{$plugin->plugin_arguments};
    $port ||= 8773;
    $list .= join("\t",'#Memcached ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/class_c thread_c gc_c gc_t m_heap_s m_nonheap_s 
                           mp_eden_s mp_surv_s mp_old_s mp_perm_s/;
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
@@ class_c
Loaded class
DEF:my1=<%RRD loaded_class.gauge %>:class_c:AVERAGE
AREA:my1#6060e0:Loaded class
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l

@@ thread_c
Threads
DEF:my1=<%RRD thread_count.gauge %>:thread_c:AVERAGE
DEF:my2=<%RRD daemon_thread_count.gauge %>:dthread_c:AVERAGE
LINE2:my1#008080:Total threads 
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#000080:Daemon threads
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l

@@ gc_c
GC count [GC/sec]
DEF:my1=<%RRD young_gc_count.derive %>:ygc_c:AVERAGE
DEF:my2=<%RRD full_gc_count.derive %>:fgc_c:AVERAGE
LINE2:my1#d1a2f6:Young Gen
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#7020AF:Full     
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l

@@ gc_t
GC time [Elapsed/sec]
DEF:my1=<%RRD young_gc_time.derive %>:ygc_t:AVERAGE
DEF:my2=<%RRD full_gc_time.derive %>:fgc_t:AVERAGE
LINE2:my1#F0B300:Young Gen
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#906D08:Full     
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l

@@ m_heap_s
Memory/Heap
DEF:my1=<%RRD heap_memory_usage.max.gauge %>:m_h_max_s:AVERAGE
DEF:my2=<%RRD heap_memory_usage.committed.gauge %>:m_h_comt_s:AVERAGE
DEF:my3=<%RRD heap_memory_usage.used.gauge %>:m_h_used_s:AVERAGE
GPRINT:my1:LAST:Max\: %6.1lf%S\l
AREA:my2#afffb2:Committed
GPRINT:my2:LAST:Cur\:%6.1lf%S
GPRINT:my2:AVERAGE:Ave\:%6.1lf%S
GPRINT:my2:MAX:Max\:%6.1lf%S\l
LINE1:my2#00A000
AREA:my3#FFC0C0:Used     
GPRINT:my3:LAST:Cur\:%6.1lf%S
GPRINT:my3:AVERAGE:Ave\:%6.1lf%S
GPRINT:my3:MAX:Max\:%6.1lf%S\l
LINE1:my3#aa0000

@@ m_nonheap_s
Memory/Non-Heap
DEF:my1=<%RRD non_heap_memory_usage.max.gauge %>:m_nh_max_s:AVERAGE
DEF:my2=<%RRD non_heap_memory_usage.committed.gauge %>:m_nh_comt_s:AVERAGE
DEF:my3=<%RRD non_heap_memory_usage.used.gauge %>:m_nh_used_s:AVERAGE
GPRINT:my1:LAST:Max\: %6.1lf%S\l
AREA:my2#73b675:Committed
GPRINT:my2:LAST:Cur\:%6.1lf%S
GPRINT:my2:AVERAGE:Ave\:%6.1lf%S
GPRINT:my2:MAX:Max\:%6.1lf%S\l
LINE1:my2#3d783f
AREA:my3#b67777:Used     
GPRINT:my3:LAST:Cur\:%6.1lf%S
GPRINT:my3:AVERAGE:Ave\:%6.1lf%S
GPRINT:my3:MAX:Max\:%6.1lf%S\l
LINE1:my3#8b4444

@@ mp_eden_s
MemoryPool/New:Eden
DEF:my1=<%RRD memory_pool.eden.max.gauge %>:mp_eden_max_s:AVERAGE
DEF:my2=<%RRD memory_pool.eden.committed.gauge %>:mp_eden_comt_s:AVERAGE
DEF:my3=<%RRD memory_pool.eden.used.gauge %>:mp_eden_used_s:AVERAGE
GPRINT:my1:LAST:Max\: %6.1lf%S\l
AREA:my2#afffb2:Committed
GPRINT:my2:LAST:Cur\:%6.1lf%S
GPRINT:my2:AVERAGE:Ave\:%6.1lf%S
GPRINT:my2:MAX:Max\:%6.1lf%S\l
LINE1:my2#00A000
AREA:my3#FFC0C0:Used     
GPRINT:my3:LAST:Cur\:%6.1lf%S
GPRINT:my3:AVERAGE:Ave\:%6.1lf%S
GPRINT:my3:MAX:Max\:%6.1lf%S\l
LINE1:my3#aa0000

@@ mp_surv_s
MemoryPool/New:Survivor
DEF:my1=<%RRD memory_pool.surv.max.gauge %>:mp_surv_max_s:AVERAGE
DEF:my2=<%RRD memory_pool.surv.committed.gauge %>:mp_surv_comt_s:AVERAGE
DEF:my3=<%RRD memory_pool.surv.used.gauge %>:mp_surv_used_s:AVERAGE
GPRINT:my1:LAST:Max\: %6.1lf%S\l
AREA:my2#afffb2:Committed
GPRINT:my2:LAST:Cur\:%6.1lf%S
GPRINT:my2:AVERAGE:Ave\:%6.1lf%S
GPRINT:my2:MAX:Max\:%6.1lf%S\l
LINE1:my2#00A000
AREA:my3#FFC0C0:Used     
GPRINT:my3:LAST:Cur\:%6.1lf%S
GPRINT:my3:AVERAGE:Ave\:%6.1lf%S
GPRINT:my3:MAX:Max\:%6.1lf%S\l
LINE1:my3#aa0000

@@ mp_old_s
MemoryPool/Old
DEF:my1=<%RRD memory_pool.old.max.gauge %>:mp_old_max_s:AVERAGE
DEF:my2=<%RRD memory_pool.old.committed.gauge %>:mp_old_comt_s:AVERAGE
DEF:my3=<%RRD memory_pool.old.used.gauge %>:mp_old_used_s:AVERAGE
GPRINT:my1:LAST:Max\: %6.1lf%S\l
AREA:my2#afffb2:Committed
GPRINT:my2:LAST:Cur\:%6.1lf%S
GPRINT:my2:AVERAGE:Ave\:%6.1lf%S
GPRINT:my2:MAX:Max\:%6.1lf%S\l
LINE1:my2#00A000
AREA:my3#FFC0C0:Used     
GPRINT:my3:LAST:Cur\:%6.1lf%S
GPRINT:my3:AVERAGE:Ave\:%6.1lf%S
GPRINT:my3:MAX:Max\:%6.1lf%S\l
LINE1:my3#aa0000

@@ mp_perm_s
MemoryPool/Permanent
DEF:my1=<%RRD memory_pool.perm.max.gauge %>:mp_perm_max_s:AVERAGE
DEF:my2=<%RRD memory_pool.perm.committed.gauge %>:mp_perm_comt_s:AVERAGE
DEF:my3=<%RRD memory_pool.perm.used.gauge %>:mp_perm_used_s:AVERAGE
GPRINT:my1:LAST:Max\: %6.1lf%S\l
AREA:my2#73b675:Committed
GPRINT:my2:LAST:Cur\:%6.1lf%S
GPRINT:my2:AVERAGE:Ave\:%6.1lf%S
GPRINT:my2:MAX:Max\:%6.1lf%S\l
LINE1:my2#3d783f
AREA:my3#b67777:Used     
GPRINT:my3:LAST:Cur\:%6.1lf%S
GPRINT:my3:AVERAGE:Ave\:%6.1lf%S
GPRINT:my3:MAX:Max\:%6.1lf%S\l
LINE1:my3#8b4444




