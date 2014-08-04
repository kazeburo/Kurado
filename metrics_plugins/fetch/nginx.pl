#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;
use Furl;
use IO::Socket qw/inet_aton pack_sockaddr_in/;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);
my $host = $plugin->address;
my ($port,$path,$http_host) = @{$plugin->plugin_arguments};
$port ||= 80;
$path ||= '/nginx_status';
$http_host ||= $host;

my $furl = Furl->new(
    agent   => 'kurado-plugin',
    timeout => 10,
    get_address => sub {
        pack_sockaddr_in($port, inet_aton($host));
    }
);

my $res = $furl->request(
    scheme => 'http',
    host   => $http_host,
    port   => $port,
    path_query => $path,
);

die "server-status failed: " .$res->status_line."\n"
    unless $res->is_success;

my %meta;
if ( my $server_version = $res->header('Server') ) {
    $meta{server} = $server_version;
}

my $body = $res->body;
my %metrics;
if ( $body =~ /Reading: (\d+) Writing: (\d+) Waiting: (\d+)/ ) {
    $metrics{read} = $1;
    $metrics{write} = $2;
    $metrics{wait} = $3;
}
if ( $body =~ /(\d+) (\d+) (\d+)/ ) {
    $metrics{reqs} = $3;
}

my $time = time;
for my $key (keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}

for my $key (qw/read write wait/) {
    my $metrics = exists $metrics{$key} ? $metrics{$key} : 'U';
    print "metrics.$key.gauge\t$metrics{$key}\t$time\n";
}

for my $key (qw/reqs/) {
    my $metrics = exists $metrics{$key} ? $metrics{$key} : 'U';
    print "metrics.$key.derive\t$metrics{$key}\t$time\n";
}


