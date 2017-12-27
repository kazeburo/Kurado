#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;
use Furl;
use JSON;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);
my $host = $plugin->address;
my ($port,$path,$http_host) = @{$plugin->plugin_arguments};
$port ||= 8778;
$path ||= '/jolokia';

my $furl = Furl->new(
    agent   => 'kurado-plugin',
    timeout => 10,
);
my $time = time;

{
    my $res = $furl->request(
        scheme => 'http',
        host   => $host,
        port   => $port,
        path_query => $path . '/read/java.lang:type=ClassLoading/LoadedClassCount',
    );
    die "request failed: " .$res->status_line."\n"
        unless $res->is_success;
    my $data = JSON->new->utf8->decode($res->content);
    print "metrics.loaded_class.gauge\t$data->{value}\t$time\n";
}

{
    my $res = $furl->request(
        scheme => 'http',
        host   => $host,
        port   => $port,
        path_query => $path . '/read/java.lang:type=Threading/ThreadCount,DaemonThreadCount',
    );
    die "request failed: " .$res->status_line."\n"
        unless $res->is_success;
    my $data = JSON->new->utf8->decode($res->content);
    print "metrics.thread_count.gauge\t$data->{value}->{ThreadCount}\t$time\n";
    print "metrics.daemon_thread_count.gauge\t$data->{value}->{DaemonThreadCount}\t$time\n";
}

{
    my $res = $furl->request(
        scheme => 'http',
        host   => $host,
        port   => $port,
        path_query => $path . '/read/java.lang:type=GarbageCollector,name=*/CollectionCount,CollectionTime',
    );
    die "request failed: " .$res->status_line."\n"
        unless $res->is_success;
    my $data = JSON->new->utf8->decode($res->content);
    my $value = $data->{value};
    my($ygc_c, $ygc_t, $fgc_c, $fgc_t) = ('U', 'U', 'U', 'U');
    for my $collector (keys %$value) {
        if ($collector =~ /name=(?:PS Scavenge|ParNew|G1 Young Generation)/) {
            $ygc_c = $value->{$collector}{CollectionCount};
            $ygc_t = $value->{$collector}{CollectionTime};
        } elsif ($collector =~ /name=(?:PS MarkSweep|ConcurrentMarkSweep|G1 Old Generation)/) {
            $fgc_c = $value->{$collector}{CollectionCount};
            $fgc_t = $value->{$collector}{CollectionTime};
        }
    }
    print "metrics.young_gc_count.derive\t$ygc_c\t$time\n";
    print "metrics.young_gc_time.derive\t$ygc_t\t$time\n";
    print "metrics.full_gc_count.derive\t$fgc_c\t$time\n";
    print "metrics.full_gc_time.derive\t$fgc_t\t$time\n";

    my $gc = '-';
    # Detect name of garbage collector
    for my $collector (keys %$value) {
        if ($collector =~ /name=MarkSweep/) {
            $gc = "Serial";
            last;
        } elsif ($collector =~ /name=PS /) {
            $gc = "Parallel";
            last;
        } elsif ($collector =~ /name=ConcurrentMarkSweep/) {
            $gc = "Concurrent Mark & Sweep";
            last;
        } elsif ($collector =~ /name=G1 /) {
            $gc = "G1";
            last;
        }
    }
    print "meta.gc\t$gc\t$time\n";
}

{
    my $res = $furl->request(
        scheme => 'http',
        host   => $host,
        port   => $port,
        path_query => $path . '/read/java.lang:type=Memory/HeapMemoryUsage,NonHeapMemoryUsage',
    );
    die "request failed: " .$res->status_line."\n"
        unless $res->is_success;
    my $data = JSON->new->utf8->decode($res->content);
    my $value = $data->{value};
    for my $k ( qw/max committed used/ ) {
        print "metrics.heap_memory_usage.$k.gauge\t$value->{HeapMemoryUsage}->{$k}\t$time\n";
        print "metrics.non_heap_memory_usage.$k.gauge\t$value->{NonHeapMemoryUsage}->{$k}\t$time\n";
    }
}

{
    my $res = $furl->request(
        scheme => 'http',
        host   => $host,
        port   => $port,
        path_query => $path . '/read/java.lang:type=MemoryPool,name=*/Type,Usage,MemoryManagerNames',
    );
    die "request failed: " .$res->status_line."\n"
        unless $res->is_success;
    my $data = JSON->new->utf8->decode($res->content);
    my $value = $data->{value};
    my @mp_eden = ('U', 'U', 'U');
    my @mp_surv = ('U', 'U', 'U');
    my @mp_old  = ('U', 'U', 'U');
    my @mp_perm = ('U', 'U', 'U');
    for my $mp (keys %$value) {
        if ($mp =~ /name=.*Eden Space/) {
            @mp_eden = @{ $value->{$mp}{Usage} }{qw(max committed used)}
        } elsif ($mp =~ /name=.*Survivor Space/) {
            @mp_surv = @{ $value->{$mp}{Usage} }{qw(max committed used)}
        } elsif ($mp =~ /name=.*(?:Tenured|Old) Gen/) {
            @mp_old  = @{ $value->{$mp}{Usage} }{qw(max committed used)}
        } elsif ($mp =~ /name=.*Perm Gen/) {
            @mp_perm = @{ $value->{$mp}{Usage} }{qw(max committed used)}
        } elsif ($mp =~ /name=Code Cache/) {
            ;
        }
    }

    print "metrics.memory_pool.eden.max.gauge\t$mp_eden[0]\t$time\n";
    print "metrics.memory_pool.eden.committed.gauge\t$mp_eden[1]\t$time\n";
    print "metrics.memory_pool.eden.used.gauge\t$mp_eden[2]\t$time\n";

    print "metrics.memory_pool.surv.max.gauge\t$mp_surv[0]\t$time\n";
    print "metrics.memory_pool.surv.committed.gauge\t$mp_surv[1]\t$time\n";
    print "metrics.memory_pool.surv.used.gauge\t$mp_surv[2]\t$time\n";

    print "metrics.memory_pool.old.max.gauge\t$mp_old[0]\t$time\n";
    print "metrics.memory_pool.old.committed.gauge\t$mp_old[1]\t$time\n";
    print "metrics.memory_pool.old.used.gauge\t$mp_old[2]\t$time\n";

    print "metrics.memory_pool.perm.max.gauge\t$mp_perm[0]\t$time\n";
    print "metrics.memory_pool.perm.committed.gauge\t$mp_perm[1]\t$time\n";
    print "metrics.memory_pool.perm.used.gauge\t$mp_perm[2]\t$time\n";
}

{
    my $res = $furl->request(
        scheme => 'http',
        host   => $host,
        port   => $port,
        path_query => $path . '/read/java.lang:type=Runtime/StartTime,VmVendor,SystemProperties,InputArguments,VmName,VmVendor',
    );
    die "request failed: " .$res->status_line."\n"
        unless $res->is_success;
    my $data = JSON->new->utf8->decode($res->content);
    my $value = $data->{value};
    my %meta;
    $meta{uptime} = $time - int($value->{StartTime}/1000);
    $meta{vm} = join(", ",
                     $value->{VmName} || 'Unknown',
                     $value->{SystemProperties}{'java.runtime.version'} || 'Unknown',
                     $value->{VmVendor} || 'Unknown',
                 );
    $meta{args} = ref($value->{InputArguments}) eq 'ARRAY' ? join(" ", @{ $value->{InputArguments} }) : $value->{InputArguments};

    for my $key (keys %meta) {
        print "meta.$key\t$meta{$key}\t$time\n";
    }
}


