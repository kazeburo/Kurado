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

my %meta;
$meta{uptime} = $status{uptime} || 0;
$meta{$_} = $variable{$_} for grep { exists $variable{$_} } 
    qw/version version_comment slow_query_log 
       log_slow_queries long_query_time 
       log_queries_not_using_indexes max_connections
       max_connect_errors thread_cache_size/;
delete $meta{log_slow_queries} if exists $meta{log_slow_queries} && exists $meta{slow_query_log};

my %metrics;
for (qw/created_tmp_tables created_tmp_disk_tables created_tmp_files com_delete 
        com_insert com_replace com_select com_update slow_queries connections threads_created
        select_full_join select_full_range_join select_range select_range_check select_scan
        sort_merge_passes sort_range sort_rows sort_scan
       /) {
    $metrics{"$_.derive"} = $status{$_} || 0;
}
for (qw/threads_cached threads_connected Threads_running/) {
    $metrics{"$_.gauge"} = $status{$_} || 0;
}

my $time = time;
for my $key (sort keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}
for my $key (sort keys %metrics) {
    print "metrics.$key\t$metrics{$key}\t$time\n";
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
