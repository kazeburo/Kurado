#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);

sub metrics_list {
    my $plugin = shift;
    my $meta = $plugin->metrics_meta;
    my $list='';

    # info
    my @info;
    for my $key ( $plugin->sort_info(keys %$meta) ) {
        next if $key eq 'has-reqs';
        if ( $key eq 'uptime' ) {
            push @info, 'uptime', $plugin->uptime2str($meta->{uptime});
        }
        else {
            push @info, $key, $meta->{$key};
        }
    }
    my ($port,$path,$http_host) = @{$plugin->plugin_arguments};
    $port ||= 80;
    $list .= join("\t",'#HTTP ('.$port.')',@info)."\n";
    $list .= "worker\n";
    $list .= "reqs\n" if $meta->{'has-reqs'};
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

=pod

=head1 NAME

view/http.pl - display metrics of http

=head1 SYNOPSIS

  % view/http.pl --help

=head1 DESCRIPTION

display metrics of http

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__
@@ worker
DEF:my1=<%RRD busy.gauge %>:busy:AVERAGE
DEF:my2=<%RRD idle.gauge %>:idle:AVERAGE
AREA:my1#00C000:Busy
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
STACK:my2#0000C0:Idle
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l

@@ reqs
DEF:my1a=<%RRD reqs.derive %>:rps:AVERAGE
CDEF:my1=my1a,0,10000000,LIMIT
LINE1:my1#aa0000:Request/sec
GPRINT:my1:LAST:Cur\:%6.2lf
GPRINT:my1:AVERAGE:Ave\:%6.2lf
GPRINT:my1:MAX:Max\:%6.2lf\l

