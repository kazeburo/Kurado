#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;
use DBI;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);
my $host = $plugin->address;
my ($port) = @{$plugin->plugin_arguments};
$port ||= $plugin->metrics_config->{MySQL}->{port};
$port ||= 3306;
my $user = $plugin->metrics_config->{MySQL}->{user} || 'root';
my $password = $plugin->metrics_config->{MySQL}->{password} || '';
my $dsn = "DBI:mysql:;hostname=$host;port=$port";
my $dbh = eval {
    DBI->connect(
        $dsn,
        $user,
        $password,
        {
            RaiseError => 1,
        }
    );
};
die "connection failed to " . $host .": $@" if $@;

## warn
my %warn;

## status
my %status;
my $rows = $dbh->selectall_arrayref('show /*!50002 GLOBAL */ status', { Slice => {} });
foreach my $row ( @$rows ) {
    $status{lc($row->{Variable_name})} = $row->{Value};
}

## variables
my %variable;
my $varible_rows = $dbh->selectall_arrayref('show variables', { Slice => {} });
foreach my $variable_row ( @$varible_rows ) {
    $variable{lc($variable_row->{Variable_name})} = $variable_row->{Value};
}

## replication
my $sth = $dbh->prepare('show slave status');
$sth->execute();
$variable{replication} = 0;
my $rep_status = $sth->fetchrow_hashref('NAME');
if ( $rep_status ) {
    $variable{replication} = 1;
    for (qw/Slave_IO_Running Slave_SQL_Running Master_Host Master_Port/) {
        $variable{'replication_'.lc($_)} = $rep_status->{$_} if exists $rep_status->{$_};
    }
    if ( $rep_status->{Last_Error} ) {
        $warn{replication} = $rep_status->{Last_Error};
    }

    $status{replication_second_behind_master} = exists $rep_status->{Seconds_Behind_Master} 
        ? $rep_status->{Seconds_Behind_Master} : 'U';
    $status{replication_read_master_log_pos} = $rep_status->{Read_Master_Log_Pos};
    $status{replication_exec_master_log_pos} = exists $rep_status->{Exec_Master_Log_Pos} 
        ? $rep_status->{Exec_Master_Log_Pos} : $rep_status->{Exec_master_log_pos};

}


## innodb
$variable{innodb} = 0;
$variable{innodb_flush_method} ||= 'fdatasync';
if ( exists $status{innodb_page_size} ) {
    # MySQL 5 Innodb
    $variable{innodb} = 1;

    $status{innodb_buffer_pool_hit_rate} = sprintf "%.5f",
        (1.0 - $status{"innodb_buffer_pool_reads"} / $status{"innodb_buffer_pool_read_requests"}) * 100;
    $status{innodb_buffer_pool_dirty_pages_rate} = sprintf "%.5f",
        $status{"innodb_buffer_pool_pages_dirty"} / $status{"innodb_buffer_pool_pages_data"} * 100.0;

    $status{innodb_buffer_pool_pages_total} = $status{innodb_buffer_pool_pages_total} * $status{innodb_page_size};
    $status{innodb_buffer_pool_pages_free} = $status{innodb_buffer_pool_pages_free} * $status{innodb_page_size};
}
else {
    # MySQL 4 Innodb
    my $engine_row = $dbh->selectrow_hashref('show /*!50000 ENGINE*/ innodb status',undef);
    if ( my $innodb_status = $engine_row->{Status} ) {
        $variable{innodb} = 1;
        $status{innodb_page_size} = 16384;

        for my $line ( split /\n/, $innodb_status ) {
            if ( $line =~ /Number of rows inserted (\d+), updated (\d+), deleted (\d+), read (\d+)/ ){
                $status{innodb_rows_inserted} = $1;
                $status{innodb_rows_updated} = $2;
                $status{innodb_rows_deleted} = $3;
                $status{innodb_rows_read} = $4;
            }
            if ( $line =~ /Buffer pool hit rate (\d+) \/ (\d+)/ ){
                my $cache_hit = $1;
                my $cache_total = $2;
                if ( $cache_total && $cache_total > 0 ){
                    $status{innodb_buffer_pool_hit_rate} = sprintf("%.5f", $cache_hit / $cache_total * 100);
                }
            }
            if ( $line =~ /^Buffer pool size\s*(\d+)$/ ) {
                $status{innodb_buffer_pool_pages_total} = $1 * $status{innodb_page_size};
                # MySQL4 buffer_pool_size
                $variable{innodb_buffer_pool_size} = $status{innodb_buffer_pool_pages_total};
            }
            if ( $line =~ /^Free buffers\s*(\d+)$/ ) {
                $status{innodb_buffer_pool_pages_free} = $1 * $status{innodb_page_size};
            }
            if ( $line =~ /^Database pages\s*(\d+)$/ ) {
                $status{innodb_buffer_pool_pages_data} = $1;
            }
            if ( $line =~ /^Modified db pages\s*(\d+)$/ ) {
                $status{innodb_buffer_pool_pages_dirty} = $1;
            }
            if ( $line =~ /^Pages read\s+(\d+), created\s+(\d+), written\s+(\d+)$/ ) {
                $status{innodb_pages_read} = $1;
                $status{innodb_pages_created} = $2;
                $status{innodb_pages_written} = $3;
            }
        } # for
        if ( exists $status{"innodb_buffer_pool_pages_dirty"} && exists $status{"innodb_buffer_pool_pages_data"} ) {
            $status{innodb_buffer_pool_dirty_pages_rate} = sprintf "%.5f",
                $status{"innodb_buffer_pool_pages_dirty"} / $status{"innodb_buffer_pool_pages_data"} * 100.0;
        }
      
    } # status
}

if ( exists $variable{innodb_buffer_pool_size} ) {
    my $buffer_pool_size = int $variable{innodb_buffer_pool_size} / (1024*1024);
    while($buffer_pool_size =~ s/(.*\d)(\d\d\d)/$1,$2/){} ;
    $buffer_pool_size .= "MB";
    $variable{innodb_buffer_pool_size} = $buffer_pool_size;
}

my %meta;
$meta{uptime} = $status{uptime} || 0;
$meta{$_} = $variable{$_} for grep { exists $variable{$_} } 
    qw/version version_comment slow_query_log 
       log_slow_queries long_query_time 
       log_queries_not_using_indexes max_connections
       max_connect_errors thread_cache_size
       innodb innodb_version innodb_buffer_pool_size innodb_flush_method
       innodb_support_xa innodb_flush_log_at_trx_commit innodb_doublewrite
       innodb_file_per_table innodb_file_format innodb_io_capacity 
       innodb_page_size
       replication replication_slave_io_running replication_slave_sql_running 
       replication_master_host replication_master_port
      /;
delete $meta{log_slow_queries} if exists $meta{log_slow_queries} && exists $meta{slow_query_log};

my %metrics;
for (qw/created_tmp_tables created_tmp_disk_tables created_tmp_files com_delete 
        com_insert com_replace com_select com_update slow_queries connections threads_created
        select_full_join select_full_range_join select_range select_range_check select_scan
        sort_merge_passes sort_range sort_rows sort_scan
        innodb_rows_read innodb_rows_deleted innodb_rows_updated innodb_rows_inserted
        innodb_pages_read innodb_pages_created innodb_pages_written
       /) {
    next if $_ =~ m!^innodb_! && !$meta{innodb};
    next if $_ =~ m!^replication_! && !$meta{replication};
    $metrics{"$_.derive"} = exists $status{$_} ? $status{$_} : 'U';
}
for (qw/threads_cached threads_connected threads_running
        innodb_buffer_pool_hit_rate innodb_buffer_pool_dirty_pages_rate
        innodb_buffer_pool_pages_total innodb_buffer_pool_pages_free
        replication_second_behind_master replication_read_master_log_pos replication_exec_master_log_pos
       /) {
    next if $_ =~ m!^innodb_! && !$meta{innodb};
    next if $_ =~ m!^replication_! && !$meta{replication};
    $metrics{"$_.gauge"} = exists $status{$_} ? $status{$_} : 'U';
}

my $time = time;
for my $key (sort keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}
for my $key (sort keys %metrics) {
    print "metrics.$key\t$metrics{$key}\t$time\n";
}
for my $key (sort keys %warn) {
    $warn{$key} =~ s/\x0d/\\r/g;
    $warn{$key} =~ s/\x0a/\\n/g;
    $warn{$key} =~ s/\x09/\\t/g;
    print "warn.$key\t$warn{$key}\t$time\n";
}

=pod

=head1 NAME

fetch/mysql.pl - metrics fetcher

=head1 SYNOPSIS

  % fetch/mysql.pl --help

=head1 DESCRIPTION

metrics fetcher

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
