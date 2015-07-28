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
my ($port,$path) = @{$plugin->plugin_arguments};
$port ||= 82;
$path ||= '/opcache-status.php';

my $furl = Furl->new(
    agent   => 'kurado-plugin',
    timeout => 10,
);
my $time = time;


my $res = $furl->request(
    scheme => 'http',
    host   => $host,
    port   => $port,
    path_query => $path
);
die "request failed: " .$res->status_line."\n"
    unless $res->is_success;
my $data = JSON->new->utf8->decode($res->content);

my $config = $data->{config} || {};
for my $key (qw/max_accelerated_files max_file_size interned_strings_max memory_max/) {
    if ( exists $config->{$key} ) {
        print "meta.$key\t$config->{$key}\t$time\n";
    }
}

my $stats = $data->{statictics} || {};
for my $key (qw/opcache_hit_rate max_cached_keys num_cached_keys num_cached_scripts/) {
    my $metrics = exists $stats->{$key} ? $stats->{$key} : 'U';
    print "metrics.$key.gauge\t$stats->{$key}\t$time\n";
}

$stats = $data->{interned_strings_usage} || {};
for my $key (qw/used_memory free_memory/) {
    my $metrics = exists $stats->{$key} ? $stats->{$key} : 'U';
    print "metrics.strings_$key.gauge\t$stats->{$key}\t$time\n";
}

$stats = $data->{memory_usage} || {};
for my $key (qw/wasted_memory free_memory used_memory/) {
    my $metrics = exists $stats->{$key} ? $stats->{$key} : 'U';
    print "metrics.$key.gauge\t$stats->{$key}\t$time\n";
}

