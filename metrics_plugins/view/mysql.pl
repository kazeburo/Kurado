#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);

my $sample = <<'EOF';
meta.log_queries_not_using_indexes      OFF     1406532863
meta.long_query_time    10.000000       1406532863
meta.max_connect_errors 10      1406532863
meta.max_connections    151     1406532863
meta.slow_query_log     OFF     1406532863
meta.thread_cache_size  0       1406532863
meta.uptime     460     1406532863
meta.version    5.1.73  1406532863
meta.version_comment    Source distribution     1406532863
metrics.Threads_running.gauge   0       1406532863
metrics.com_delete.derive       0       1406532863
metrics.com_insert.derive       0       1406532863
metrics.com_replace.derive      0       1406532863
metrics.com_select.derive       0       1406532863
metrics.com_update.derive       0       1406532863
metrics.connections.derive      22      1406532863
metrics.created_tmp_disk_tables.derive  0       1406532863
metrics.created_tmp_files.derive        5       1406532863
metrics.created_tmp_tables.derive       39      1406532863
metrics.select_full_join.derive 0       1406532863
metrics.select_full_range_join.derive   0       1406532863
metrics.select_range.derive     0       1406532863
metrics.select_range_check.derive       0       1406532863
metrics.select_scan.derive      39      1406532863
metrics.slow_queries.derive     0       1406532863
metrics.sort_merge_passes.derive        0       1406532863
metrics.sort_range.derive       0       1406532863
metrics.sort_rows.derive        0       1406532863
metrics.sort_scan.derive        0       1406532863
metrics.threads_cached.gauge    0       1406532863
metrics.threads_connected.gauge 1       1406532863
metrics.threads_created.derive  21      1406532863
EOF

sub metrics_list {
    my $plugin = shift;
    my $meta = $plugin->metrics_meta;
    my $list='';

    my $replication = delete $meta->{replication};
    my $innodb = delete $meta->{innodb};

    # info
    my @mysql;
    my @replication;
    my @innodb;
    for my $key ( $plugin->sort_info(keys %$meta) ) {
        if ( $key eq 'uptime' ) {
            push @mysql, 'uptime', $plugin->uptime2str($meta->{uptime});
        }
        elsif ( $key =~ m!^innodb_(.+)$! ) {
            push @innodb, $1, $meta->{$key};
        }
        elsif ( $key =~ m!^replication_(.+)$! ) {
            push @replication, $1, $meta->{$key};
        }
        else {
            push @mysql, $key, $meta->{$key};
        }
    }
    my ($port) = @{$plugin->plugin_arguments};
    $port = $port ? '('.$port.')' : "";
    $list .= join("\t",'#MySQL'.$port,@mysql)."\n";
    $list .= "$_\n" for qw/rate count slow select-type sort tmp-obj thread/;
    if ( $replication ) {
        $list .= join("\t",'#MySQL replication'.$port,@replication)."\n";
        $list .= "$_\n" for qw/replication-second replication-position/;
    }
    if ( $innodb ) {
        $list .= join("\t",'#MySQL InnoDB'.$port,@innodb)."\n";
        $list .= "$_\n" for qw/row-ops-rate row-pos-speed cache-rate bp-usage dirty-rate page-io innodb-io/;
    }
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
@@ rate
Queries Rate
DEF:my1=<%RRD_FOR com_select.derive %>:n:AVERAGE
DEF:my2=<%RRD_FOR com_insert.derive %>:n:AVERAGE
DEF:my3=<%RRD_FOR com_replace.derive %>:n:AVERAGE
DEF:my4=<%RRD_FOR com_update.derive %>:n:AVERAGE
DEF:my5=<%RRD_FOR com_delete.derive %>:n:AVERAGE
CDEF:total=my1,my2,+,my3,+,my4,+,my5,+
CDEF:my1r=my1,total,/,100,*
CDEF:my2r=my2,total,/,100,*
CDEF:my3r=my3,total,/,100,*
CDEF:my4r=my4,total,/,100,*
CDEF:my5r=my5,total,/,100,*
AREA:my1r#c0c0c0:Select 
GPRINT:my1r:LAST:Cur\:%5.1lf[%%]
GPRINT:my1r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1r:MAX:Max\:%5.1lf[%%]\l
STACK:my2r#000080:Insert 
GPRINT:my2r:LAST:Cur\:%5.1lf[%%]
GPRINT:my2r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my2r:MAX:Max\:%5.1lf[%%]\l
STACK:my3r#008080:Replace
GPRINT:my3r:LAST:Cur\:%5.1lf[%%]
GPRINT:my3r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my3r:MAX:Max\:%5.1lf[%%]\l
STACK:my4r#800080:Update 
GPRINT:my4r:LAST:Cur\:%5.1lf[%%]
GPRINT:my4r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my4r:MAX:Max\:%5.1lf[%%]\l
STACK:my5r#C0C000:Delete 
GPRINT:my5r:LAST:Cur\:%5.1lf[%%]
GPRINT:my5r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my5r:MAX:Max\:%5.1lf[%%]\l

@@ count
Queries Count
DEF:my1a=<%RRD_FOR com_select.derive %>:n:AVERAGE
DEF:my2a=<%RRD_FOR com_insert.derive %>:n:AVERAGE
DEF:my3a=<%RRD_FOR com_replace.derive %>:n:AVERAGE
DEF:my4a=<%RRD_FOR com_update.derive %>:n:AVERAGE
DEF:my5a=<%RRD_FOR com_delete.derive %>:n:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
CDEF:my2=my2a,0,1000000000,LIMIT
CDEF:my3=my3a,0,1000000000,LIMIT
CDEF:my4=my4a,0,1000000000,LIMIT
CDEF:my5=my5a,0,1000000000,LIMIT
AREA:my1#c0c0c0:Select 
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
STACK:my2#000080:Insert 
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l
STACK:my3#008080:Replace
GPRINT:my3:LAST:Cur\:%7.1lf
GPRINT:my3:AVERAGE:Ave\:%7.1lf
GPRINT:my3:MAX:Max\:%7.1lf\l
STACK:my4#800080:Update 
GPRINT:my4:LAST:Cur\:%7.1lf
GPRINT:my4:AVERAGE:Ave\:%7.1lf
GPRINT:my4:MAX:Max\:%7.1lf\l
STACK:my5#C0C000:Delete 
GPRINT:my5:LAST:Cur\:%7.1lf
GPRINT:my5:AVERAGE:Ave\:%7.1lf
GPRINT:my5:MAX:Max\:%7.1lf\l

@@ select-type
Select Types
DEF:my1a=<%RRD_FOR select_full_join.derive %>:n:AVERAGE
DEF:my2a=<%RRD_FOR select_full_range_join.derive %>:n:AVERAGE
DEF:my3a=<%RRD_FOR select_range.derive %>:n:AVERAGE
DEF:my4a=<%RRD_FOR select_range_check.derive %>:n:AVERAGE
DEF:my5a=<%RRD_FOR select_scan.derive %>:n:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
CDEF:my2=my2a,0,1000000000,LIMIT
CDEF:my3=my3a,0,1000000000,LIMIT
CDEF:my4=my4a,0,1000000000,LIMIT
CDEF:my5=my5a,0,1000000000,LIMIT
AREA:my1#3d1400:Full Join      
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
STACK:my2#aa3a26:Full Range Join
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l
STACK:my3#edaa40:Range          
GPRINT:my3:LAST:Cur\:%7.1lf
GPRINT:my3:AVERAGE:Ave\:%7.1lf
GPRINT:my3:MAX:Max\:%7.1lf\l
STACK:my4#13333b:Range Check    
GPRINT:my4:LAST:Cur\:%7.1lf
GPRINT:my4:AVERAGE:Ave\:%7.1lf
GPRINT:my4:MAX:Max\:%7.1lf\l
STACK:my5#686240:Scan           
GPRINT:my5:LAST:Cur\:%7.1lf
GPRINT:my5:AVERAGE:Ave\:%7.1lf
GPRINT:my5:MAX:Max\:%7.1lf\l

@@ sort
Sorts
DEF:my1a=<%RRD_FOR sort_rows.derive %>:n:AVERAGE
DEF:my2a=<%RRD_FOR sort_range.derive %>:n:AVERAGE
DEF:my3a=<%RRD_FOR sort_merge_passes.derive %>:n:AVERAGE
DEF:my4a=<%RRD_FOR sort_scan.derive %>:n:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
CDEF:my2=my2a,0,1000000000,LIMIT
CDEF:my3=my3a,0,1000000000,LIMIT
CDEF:my4=my4a,0,1000000000,LIMIT
AREA:my1#ffab02:Sort Rows        
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
LINE1:my2#157418:Sort Ranges      
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l
LINE1:my3#da4625:Sort Merge Pass  
GPRINT:my3:LAST:Cur\:%7.1lf
GPRINT:my3:AVERAGE:Ave\:%7.1lf
GPRINT:my3:MAX:Max\:%7.1lf\l
LINE1:my4#4345ff:Sort Scan        
GPRINT:my4:LAST:Cur\:%7.1lf
GPRINT:my4:AVERAGE:Ave\:%7.1lf
GPRINT:my4:MAX:Max\:%7.1lf\l

@@ tmp-obj
Temporary Objects
DEF:my1a=<%RRD_FOR created_tmp_tables.derive %>:n:AVERAGE
DEF:my2a=<%RRD_FOR created_tmp_disk_tables.derive %>:n:AVERAGE
DEF:my3a=<%RRD_FOR created_tmp_files.derive %>:n:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
CDEF:my2=my2a,0,1000000000,LIMIT
CDEF:my3=my3a,0,1000000000,LIMIT
AREA:my1#ffab02:Created Tmp Tables     
GPRINT:my1:LAST:Cur\:%6.2lf
GPRINT:my1:AVERAGE:Ave\:%6.2lf
GPRINT:my1:MAX:Max\:%6.2lf\l
LINE1:my2#f51e2f:Created Tmp Disk Tables
GPRINT:my2:LAST:Cur\:%6.2lf
GPRINT:my2:AVERAGE:Ave\:%6.2lf
GPRINT:my2:MAX:Max\:%6.2lf\l
LINE1:my3#157418:Created Tmp Files      
GPRINT:my3:LAST:Cur\:%6.2lf
GPRINT:my3:AVERAGE:Ave\:%6.2lf
GPRINT:my3:MAX:Max\:%6.2lf\l

@@ slow
Slow Queries
DEF:my1a=<%RRD_FOR slow_queries.derive %>:n:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
AREA:my1#00c000:Slow Queries
GPRINT:my1:LAST:Cur\:%7.3lf
GPRINT:my1:AVERAGE:Ave\:%7.3lf
GPRINT:my1:MAX:Max\:%7.3lf\l

@@ thread
Threads/connections
DEF:my1=<%RRD_FOR threads_cached.gauge %>:n:AVERAGE
DEF:my2=<%RRD_FOR threads_connected.gauge %>:n:AVERAGE
DEF:my3=<%RRD_FOR threads_running.gauge %>:n:AVERAGE
DEF:my4a=<%RRD_FOR threads_created.derive %>:n:AVERAGE
DEF:my5a=<%RRD_FOR connections.derive %>:n:AVERAGE
CDEF:my4=my4a,0,1000000000,LIMIT
CDEF:my5=my5a,0,1000000000,LIMIT
LINE1:my1#CC0000:Cached           
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#000080:Connected        
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l
LINE1:my3#008080:Running          
GPRINT:my3:LAST:Cur\:%6.1lf
GPRINT:my3:AVERAGE:Ave\:%6.1lf
GPRINT:my3:MAX:Max\:%6.1lf\l
LINE1:my4#00c000:Threads created/s
GPRINT:my4:LAST:Cur\:%6.2lf
GPRINT:my4:AVERAGE:Ave\:%6.2lf
GPRINT:my4:MAX:Max\:%6.2lf\l
LINE1:my5#ffab02:Connections/s    
GPRINT:my5:LAST:Cur\:%6.2lf
GPRINT:my5:AVERAGE:Ave\:%6.2lf
GPRINT:my5:MAX:Max\:%6.2lf\l

@@ replication-second
Seconds Behind Master
DEF:my1=<%RRD replication_second_behind_master.gauge %>:n:AVERAGE
LINE1:my1#c03300:Seconds
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l

@@ replication-position
Position Behind Master
DEF:read=<%RRD replication_read_master_log_pos.gauge %>:n:AVERAGE
DEF:exec=<%RRD replication_exec_master_log_pos.gauge %>:n:AVERAGE
CDEF:my1=read,exec,-,0,1000000000,LIMIT
AREA:my1#c00066:Position
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l

@@ row-ops-rate
ROW OPERATIONS Rate
DEF:my1=<%RRD innodb_rows_inserted.derive %>:ir:AVERAGE
DEF:my2=<%RRD innodb_rows_updated.derive %>:ur:AVERAGE
DEF:my3=<%RRD innodb_rows_deleted.derive %>:dr:AVERAGE
DEF:my4=<%RRD innodb_rows_read.derive %>:rr:AVERAGE
CDEF:total=my1,my2,+,my3,+,my4,+
CDEF:my1r=my1,total,/,100,*
CDEF:my2r=my2,total,/,100,*
CDEF:my3r=my3,total,/,100,*
CDEF:my4r=my4,total,/,100,*
AREA:my1r#c0c0c0:Insert
GPRINT:my1r:LAST:Cur\:%5.1lf[%%]
GPRINT:my1r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1r:MAX:Max\:%5.1lf[%%]\l
STACK:my2r#000080:Update
GPRINT:my2r:LAST:Cur\:%5.1lf[%%]
GPRINT:my2r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my2r:MAX:Max\:%5.1lf[%%]\l
STACK:my3r#008080:Delete
GPRINT:my3r:LAST:Cur\:%5.1lf[%%]
GPRINT:my3r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my3r:MAX:Max\:%5.1lf[%%]\l
STACK:my4r#800080:Read  
GPRINT:my4r:LAST:Cur\:%5.1lf[%%]
GPRINT:my4r:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my4r:MAX:Max\:%5.1lf[%%]\l

@@ row-pos-speed
ROW OPERATIONS Speed
DEF:my1a=<%RRD innodb_rows_inserted.derive %>:ir:AVERAGE
DEF:my2a=<%RRD innodb_rows_updated.derive %>:ur:AVERAGE
DEF:my3a=<%RRD innodb_rows_deleted.derive %>:dr:AVERAGE
DEF:my4a=<%RRD innodb_rows_read.derive %>:rr:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
CDEF:my2=my2a,0,1000000000,LIMIT
CDEF:my3=my3a,0,1000000000,LIMIT
CDEF:my4=my4a,0,1000000000,LIMIT
LINE1:my1#CC0000:Insert
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#000080:Update
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l
LINE1:my3#008080:Delete
GPRINT:my3:LAST:Cur\:%6.1lf
GPRINT:my3:AVERAGE:Ave\:%6.1lf
GPRINT:my3:MAX:Max\:%6.1lf\l
LINE1:my4#800080:Read  
GPRINT:my4:LAST:Cur\:%6.1lf
GPRINT:my4:AVERAGE:Ave\:%6.1lf
GPRINT:my4:MAX:Max\:%6.1lf\l

@@ cache-rate
Buffer pool hit rate
DEF:my1=<%RRD innodb_buffer_pool_hit_rate.gauge %>:cr:AVERAGE
AREA:my1#990000:Hit Rate
GPRINT:my1:LAST:Cur\:%5.1lf[%%]
GPRINT:my1:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1:MAX:Max\:%5.1lf[%%]\l
LINE:100

@@ bp-usage
Buffer pool usage
DEF:my1=<%RRD innodb_buffer_pool_pages_total.gauge %>:bp_total:AVERAGE
DEF:my3=<%RRD innodb_buffer_pool_pages_free.gauge %>:bp_free:AVERAGE
CDEF:my2=my1,my3,-
AREA:my1#3d1400:Pool Size 
GPRINT:my1:LAST:Cur\:%5.1lf%S\l
AREA:my2#edaa40:Used Pages
GPRINT:my2:LAST:Cur\:%5.1lf%S
GPRINT:my2:AVERAGE:Ave\:%5.1lf%S
GPRINT:my2:MAX:Max\:%5.1lf%S\l

@@ dirty-rate
Dirty pages rate
DEF:my2=<%RRD innodb_buffer_pool_pages_data.gauge %>:bp_total:AVERAGE
DEF:my4=<%RRD innodb_buffer_pool_pages_dirty.gauge %>:bp_free:AVERAGE
CDEF:my1=my4,my2,/,100,*
AREA:my1#13333b:Dirty page rate
GPRINT:my1:LAST:Cur\:%5.1lf[%%]
GPRINT:my1:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my1:MAX:Max\:%5.1lf[%%]\l
LINE:100

@@ page-io
Buffer Pool Activity
DEF:my1a=<%RRD innodb_pages_created.derive %>:pr:AVERAGE
DEF:my2a=<%RRD innodb_pages_read.derive %>:pw:AVERAGE
DEF:my3a=<%RRD innodb_pages_written.derive %>:pw:AVERAGE
CDEF:my1=my1a,0,1000000000,LIMIT
CDEF:my2=my2a,0,1000000000,LIMIT
CDEF:my3=my3a,0,1000000000,LIMIT
LINE1:my1#d6883a:Pages Create
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#e6d882:Pages Read  
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l
LINE1:my3#55ad84:Pages Write 
GPRINT:my3:LAST:Cur\:%6.1lf
GPRINT:my3:AVERAGE:Ave\:%6.1lf
GPRINT:my3:MAX:Max\:%6.1lf\l

@@ innodb-io
DEF:file_reads=<%RRD innodb_data_reads.derive %>:file_reads:AVERAGE
DEF:file_writes=<%RRD innodb_data_writes.derive %>:file_writes:AVERAGE
DEF:log_writes=<%RRD innodb_log_writes.derive %>:log_writes:AVERAGE
DEF:file_fsyncs=<%RRD innodb_data_fsyncs.derive %>:file_fsyncs:AVERAGE
LINE1:file_reads#402204:File Reads 
GPRINT:file_reads:LAST:Cur\: %5.1lf
GPRINT:file_reads:AVERAGE:Ave\: %5.1lf
GPRINT:file_reads:MAX:Max\: %5.1lf\l
LINE1:file_writes#B3092B:File Writes
GPRINT:file_writes:LAST:Cur\: %5.1lf
GPRINT:file_writes:AVERAGE:Ave\: %5.1lf
GPRINT:file_writes:MAX:Max\: %5.1lf\l
LINE1:log_writes#FFBF00:Log Writes 
GPRINT:log_writes:LAST:Cur\: %5.1lf
GPRINT:log_writes:AVERAGE:Ave\: %5.1lf
GPRINT:log_writes:MAX:Max\: %5.1lf\l
LINE1:file_fsyncs#0ABFCC:File Fsyncs
GPRINT:file_fsyncs:LAST:Cur\: %5.1lf
GPRINT:file_fsyncs:AVERAGE:Ave\: %5.1lf
GPRINT:file_fsyncs:MAX:Max\: %5.1lf\l
