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
$port ||= 3128;


my %stats;
my %meta;
{
    my $client = Kurado::TinyTCP->new(
        server => $host . ':' . $port,
        timeout => 3.5
    );
    $client->write("GET cache_object://localhost/counters HTTP/1.0$CRLF$CRLF",1);
    my $raw_stats = $client->read_until_close(1);
    die "could not retrieve couter status from $host:$port" unless $raw_stats;
    foreach my $line ( split /\r?\n/, $raw_stats ) {
        if ( $line =~ /^client_http\.(requests|hits|errors)\s*=\s*(\-?\d+)$/ ) {
            $stats{'client-http.'.$1} = $2;
        }
    }
}

{
    my $client = Kurado::TinyTCP->new(
        server => $host . ':' . $port,
        timeout => 3.5
    );
    $client->write("GET cache_object://localhost/5min HTTP/1.0$CRLF$CRLF",1);
    my $raw_stats = $client->read_until_close(1);
    die "could not retrieve couter status from $host:$port" unless $raw_stats;
    foreach my $line ( split /\r?\n/, $raw_stats ) {
        if ( $line =~ /^client_http\.(all|miss|nm|hit)_median_svc_time\s*=\s*([0-9\.]+) seconds$/ ) {
            $stats{'svc-time.'.$1} = $2 * 1000; #msec
        }
    }
}

{
    my $client = Kurado::TinyTCP->new(
        server => $host . ':' . $port,
        timeout => 3.5
    );
    $client->write("GET cache_object://localhost/info HTTP/1.0$CRLF$CRLF",1);
    my $raw_stats = $client->read_until_close(1);
    die "could not retrieve couter status from $host:$port" unless $raw_stats;
    foreach my $line ( split /\r?\n/, $raw_stats ) {
        if ( $line =~ m!^Squid Object Cache: Version (.+)$! ) {
            $meta{version} = $1;
        }
        if ( $line =~ m!^\s*UP Time:\s*([0-9\.]+) seconds$! ) {
            $meta{uptime} = int($1);
        }
        if ( $line =~ m!^\s*Maximum number of file descriptors:\s*(\d+)$! ) {
            $stats{'file-descriptors.max'} = $1;
        }
        if ( $line =~ m!^\s*Number of file desc currently in use:\s*(\d+)$! ) {
            $stats{'file-descriptors.used'} = $1;
        }
        if ( $line =~ m!\s*(\d+) StoreEntries$! ) {
            $stats{'store-entries.total'} = $1;
        }
        if ( $line =~ m!\s*(\d+) StoreEntries with MemObjects$! ) {
            $stats{'store-entries.with-memobject'} = $1;
        }
    }
}

my $time = time;
for my $key (keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}
for my $key (qw/client-http.requests client-http.hits client-http.errors/) {
    my $val = exists $stats{$key} ? $stats{$key} : 'U';
    print "metrics.$key.derive\t$val\t$time\n";
}
for my $key (qw/svc-time.all svc-time.miss svc-time.nm svc-time.hit
                file-descriptors.max file-descriptors.used store-entries.total store-entries.with-memobject/) {
    my $val = exists $stats{$key} ? $stats{$key} : 'U';
    print "metrics.$key.gauge\t$val\t$time\n";
}


