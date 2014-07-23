#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;
use Kurado::TinyTCP;
use IO::Socket qw(:crlf);

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);
my $host = $plugin->address;
my ($port) = @{$plugin->plugin_arguments};
$port ||= 6379;

my $client = Kurado::TinyTCP->new(
    server => $host . ':' . $port,
    timeout => 3.5
);

$client->write("info\r\n",1);
my $raw_stats = $client->read(1);
die "could not retrieve status from $host:$port" unless $raw_stats;

my %stats;
my $keys;
foreach my $line ( split /\r?\n/, $raw_stats ) {
    chomp($line);chomp($line);
    if ( $line =~ /^([^:]+?):(.+)$/ ) {
        my($k,$v) = ($1,$2);
        $stats{$k} = $v;
        if ($k =~ /^db[0-9]+/) {
            $keys += $v =~ /keys=(\d+),/ ? $1 : 0;
        }
    }
}

my $raw_res;
### slowlog
$client->write("slowlog len\r\n",1);
$raw_res = $client->read(1);
my $slowlog = $raw_res =~ /:([0-9]+)/ ? $1 : 0;

### config get
my %config;
$client->write("config get *\r\n",1);
$raw_res = $client->read(1);
my $ck;
foreach my $line ( split /\r?\n/, $raw_res ) {
    chomp($line);chomp($line);
    next if $line =~ /^[\*\$]/;
    if (! $ck) {
        $ck = $line;
    } else {
        $config{$ck} = $line;
        $ck = "";
    }
}

my %meta;
if ( $stats{redis_version} ) {
    $meta{version} = $stats{redis_version};
}
if ( my $uptime = $stats{uptime_in_seconds} ) {
    $meta{uptime} = $uptime;
}
foreach my $stats_key (qw/vm_enabled role/) {
    $meta{$stats_key} = $stats{$stats_key}
        if exists $stats{$stats_key};
}
foreach my $config_key (qw/maxmemory maxclients rdbcompression appendonly maxmemory-policy appendfsync save slowlog-max-len/) {
    $meta{$config_key} = $config{$config_key}
        if exists $config{$config_key};
}

my %metrics;
my @stats = (
    [qw/total_commands_processed derive/],
    [qw/total_connections_received derive/],
    [qw/connected_clients gauge/],
    [qw/connected_slaves gauge/],
    [qw/used_memory gauge/],
    [qw/changes_since_last_save gauge/],
    [qw/mem_fragmentation_ratio gauge/],
    [qw/evicted_keys derive/],
    [qw/pubsub_channels gauge/]
);
for my $stats_key (@stats) {
    $metrics{$stats_key->[0].".".$stats_key->[1]} = $stats{$stats_key->[0]}
        if exists $stats{$stats_key->[0]};
}
if ( !exists $stats{'changes_since_last_save.gauge'} ) {
    $metrics{'changes_since_last_save.gauge'} = $stats{'rdb_changes_since_last_save'}
        if exists $stats{'rdb_changes_since_last_save'};
    
}

$metrics{'keys.gauge'} = $keys;
$metrics{'slowlog.gauge'} = $slowlog;
my $time = time;
for my $key (keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}
for my $key (keys %metrics) {
    print "metrics.$key\t$metrics{$key}\t$time\n";
}



=pod

=head1 NAME

fetch/redis.pl - metrics fetcher for redis

=head1 SYNOPSIS

  % fetch/redis.pl --help

=head1 DESCRIPTION

metrics fetcher for redis

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
