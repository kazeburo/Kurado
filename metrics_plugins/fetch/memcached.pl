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
$port ||= 11211;

my $client = Kurado::TinyTCP->new(
    server => $host . ':' . $port,
    timeout => 3.5
);

$client->write("stats$CRLF",1);
my $raw_stats = $client->read(1);
die "could not retrieve status from $host:$port" unless $raw_stats;
while ( $raw_stats !~ m!END! ) {
  my $raw_buf = $client->read(1);
  die "could not retrieve status from $host:$port" unless $raw_buf;
  $raw_stats .= $raw_buf;
}

my %stats;
foreach my $line ( split /\r?\n/, $raw_stats ) {
    if ( $line =~ /^STAT\s([^ ]+)\s(.+)$/ ) {
        $stats{$1} = $2;
    }
}

my %meta;
if ( exists $stats{version} ) {
    $meta{version} = $stats{version};
}
if ( exists $stats{uptime} ) {
    $meta{uptime} = $stats{uptime}
}

if ( $stats{version} && $stats{version} =~ m!^1\.(\d+)! && $1 >= 4 ) {
    $client->write("stats settings$CRLF");
    my $raw_setting_stats = $client->read(1);
    die "could not retrieve status from $host:$port" unless $raw_setting_stats;
    while ( $raw_setting_stats !~ m!END! ) {
      my $raw_buf = $client->read(1);
      die "could not retrieve status from $host:$port" unless $raw_buf;
      $raw_setting_stats .= $raw_buf;
    }
    my %setting_stats;
    foreach my $line ( split /\r?\n/, $raw_setting_stats ) {
        if ( $line =~ /^STAT\s([^ ]+)\s(.+)$/ ) {
            $setting_stats{$1} = $2;
        }
    }
    $meta{maxconns} = $setting_stats{maxconns};
    $stats{maxconns} = $setting_stats{maxconns};
}



my $time = time;
for my $key (keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}
for my $key (qw/cmd_get cmd_set get_hits get_misses evictions evicted_unfetched/) {
    my $val = exists $stats{$key} ? $stats{$key} : 'U';
    print "metrics.$key.derive\t$val\t$time\n";
}
for my $key (qw/curr_connections bytes limit_maxbytes curr_items maxconns/) {
    my $val = exists $stats{$key} ? $stats{$key} : 'U';
    print "metrics.$key.gauge\t$val\t$time\n";
}



=pod

=head1 NAME

fetch/memcached.pl - metrics fetcher for memcached

=head1 SYNOPSIS

  % fetch/memcached.pl --help

=head1 DESCRIPTION

metrics fetcher for memcached

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
