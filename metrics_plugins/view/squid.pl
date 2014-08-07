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
    $port ||= 3128;
    $list .= join("\t",'#Squid ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/reqs ratio svc items filedescriptor/;
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

view/squid.pl - display metrics of squid

=head1 SYNOPSIS

  % view/squid.pl --help

=head1 DESCRIPTION

display metrics of squid

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__
@@ reqs
Number of request
DEF:my1a=<%RRD client-http.requests.derive %>:request:AVERAGE
DEF:my2a=<%RRD client-http.hits.derive %>:httphit:AVERAGE
DEF:my3a=<%RRD client-http.errors.derive %>:httperror:AVERAGE
CDEF:my1=my1a,0,100000,LIMIT
CDEF:my2=my2a,0,100000,LIMIT
CDEF:my3=my3a,0,100000,LIMIT
LINE1:my1#000080:Request    
GPRINT:my1:LAST:Cur\:%6.1lf
GPRINT:my1:AVERAGE:Ave\:%6.1lf
GPRINT:my1:MAX:Max\:%6.1lf\l
LINE1:my2#008080:Hit Request
GPRINT:my2:LAST:Cur\:%6.1lf
GPRINT:my2:AVERAGE:Ave\:%6.1lf
GPRINT:my2:MAX:Max\:%6.1lf\l
LINE1:my3#CC0000:Err Request
GPRINT:my3:LAST:Cur\:%6.1lf
GPRINT:my3:AVERAGE:Ave\:%6.1lf
GPRINT:my3:MAX:Max\:%6.1lf\l

@@ ratio
Cache hit ratio
DEF:my1=<%RRD client-http.requests.derive %>:request:AVERAGE
DEF:my2=<%RRD client-http.hits.derive %>:httphit:AVERAGE
CDEF:my3=my2,my1,/,100,*,0,100,LIMIT
AREA:my3#990000:Ratio
GPRINT:my3:LAST:Cur\:%5.1lf[%%]
GPRINT:my3:AVERAGE:Ave\:%5.1lf[%%]
GPRINT:my3:MAX:Max\:%5.1lf[%%]\l
LINE:100

@@ svc
Response time (msec)
DEF:my1=<%RRD svc-time.all.gauge %>:allsvc:AVERAGE
DEF:my2=<%RRD svc-time.miss.gauge %>:misssvc:AVERAGE
DEF:my3=<%RRD svc-time.nm.gauge %>:nmsvc:AVERAGE
DEF:my4=<%RRD svc-time.hit.gauge %>:hitsvc:AVERAGE
LINE1:my1#CC0000:All        
GPRINT:my1:LAST:Cur\:%6.2lf
GPRINT:my1:AVERAGE:Ave\:%6.2lf
GPRINT:my1:MAX:Max\:%6.2lf\l
LINE1:my2#000080:Miss       
GPRINT:my2:LAST:Cur\:%6.2lf
GPRINT:my2:AVERAGE:Ave\:%6.2lf
GPRINT:my2:MAX:Max\:%6.2lf\l
LINE1:my3#008080:NotModified
GPRINT:my3:LAST:Cur\:%6.2lf
GPRINT:my3:AVERAGE:Ave\:%6.2lf
GPRINT:my3:MAX:Max\:%6.2lf\l
LINE1:my4#800080:Hit        
GPRINT:my4:LAST:Cur\:%6.2lf
GPRINT:my4:AVERAGE:Ave\:%6.2lf
GPRINT:my4:MAX:Max\:%6.2lf\l

@@ items
Cache items
DEF:my1=<%RRD store-entries.total.gauge %>:items_cur:AVERAGE
DEF:my2=<%RRD store-entries.with-memobject.gauge %>:items_cur:AVERAGE
AREA:my1#00A000:Total Items     
GPRINT:my1:LAST:Cur\:%8.0lf
GPRINT:my1:AVERAGE:Ave\:%8.0lf
GPRINT:my1:MAX:Max\:%8.0lf\l
LINE1:my2#0000A0:WithMemoryObject
GPRINT:my2:LAST:Cur\:%8.0lf
GPRINT:my2:AVERAGE:Ave\:%8.0lf
GPRINT:my2:MAX:Max\:%8.0lf\l

@@ filedescriptor
Used File Descriptors
DEF:my1=<%RRD file-descriptors.used.gauge %>:n:AVERAGE
DEF:my2=<%RRD file-descriptors.max.gauge %>:n:AVERAGE
LINE1:my2#C00000:Max file descriptors 
GPRINT:my2:LAST:Cur\:%7.0lf\l
AREA:my1#00C000:Used file descriptors
GPRINT:my1:LAST:Cur\:%7.0lf
GPRINT:my1:AVERAGE:Ave\:%7.0lf
GPRINT:my1:MAX:Max\:%7.0lf\l
