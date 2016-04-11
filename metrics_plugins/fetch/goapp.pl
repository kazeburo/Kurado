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
$port ||= 1056;
$path ||= '/stat/go';

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


for my $key (qw/cgo_call_num gc_num memory_mallocs memory_frees/) {
    my $metrics = exists $data->{$key} ? $data->{$key} : 'U';
    print "metrics.$key.counter\t$data->{$key}\t$time\n";
}


for my $key (qw/goroutine_num memory_alloc/) {
    my $metrics = exists $data->{$key} ? $data->{$key} : 'U';
    print "metrics.$key.gauge\t$data->{$key}\t$time\n";
}


