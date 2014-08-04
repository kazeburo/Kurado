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
        if ( $key eq 'uptime' ) {
            push @info, 'uptime', $plugin->uptime2str($meta->{uptime});
        }
        else {
            push @info, $key, $meta->{$key};
        }
    }
    my ($port) = @{$plugin->plugin_arguments};
    $port ||= 80;
    $list .= join("\t",'#Memcached ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/usage items evictions count rate conn/;
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

view/memcached.pl - display metrics of memcached

=head1 SYNOPSIS

  % view/memcached.pl --help

=head1 DESCRIPTION

display metrics of memcached

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__
@@ usage
Cache usage
DEF:my1=<%RRD bytes.gauge %>:used:AVERAGE
DEF:my2=<%RRD limit_maxbytes.gauge %>:max:AVERAGE
AREA:my1#eaaf00:Used
GPRINT:my1:LAST:Cur\:%5.2lf%sB
GPRINT:my1:AVERAGE:Ave\:%5.2lf%sB
GPRINT:my1:MAX:Max\:%5.2lf%sB\l
LINE:my2#333333:Max 
GPRINT:my2:LAST:Cur\:%5.2lf%sB
GPRINT:my2:AVERAGE:Ave\:%5.2lf%sB
GPRINT:my2:MAX:Max\:%5.2lf%sB\l

@@ count
Request count
DEF:my1a=<%RRD cmd_get.derive %>:cmdset:AVERAGE
DEF:my2a=<%RRD cmd_set.derive %>:cmdget:AVERAGE
CDEF:my1=my1a,0,100000,LIMIT
CDEF:my2=my2a,0,100000,LIMIT
AREA:my1#00C000:Set
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
STACK:my2#0000C0:Get
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l


@@ rate
Cache hit rate
DEF:hits=<%RRD get_hits.derive %>:gethits:AVERAGE
DEF:misses=<%RRD get_misses.derive %>:getmisses:AVERAGE
CDEF:total=hits,misses,+
CDEF:rate=hits,total,/,100,*,0,100,LIMIT
AREA:rate#990000:Rate
GPRINT:rate:LAST:Cur\:%5.1lf[%%]
GPRINT:rate:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:rate:MAX:Max\:%5.1lf[%%]\l
LINE:100

@@ conn
Connections
DEF:conn=<%RRD curr_connections.gauge %>:n:AVERAGE
DEF:my2=<%RRD maxconns.gauge %>:n:AVERAGE
AREA:conn#00C000:Connection    
GPRINT:conn:LAST:Cur\:%7.1lf
GPRINT:conn:AVERAGE:Ave\:%7.1lf
GPRINT:conn:MAX:Max\:%7.1lf\l
LINE1:my2#C00000:Max Connection
GPRINT:my2:LAST:Cur\:%7.1lf\l

@@ evictions
Evictions
DEF:my1=<%RRD evictions.derive %>:evt_total:AVERAGE
DEF:my2=<%RRD evicted_unfetched.derive %>:evt_unfetched:AVERAGE
AREA:my1#800040:Evictions Total    
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE2:my2#004080:Evictions Unfetched
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l

@@ items
Cache items
DEF:my1=<%RRD curr_items.gauge %>:items_cur:AVERAGE
AREA:my1#00A000:Current Items
GPRINT:my1:LAST:Cur\:%8.0lf
GPRINT:my1:AVERAGE:Ave\:%8.0lf
GPRINT:my1:MAX:Max\:%8.0lf\l

