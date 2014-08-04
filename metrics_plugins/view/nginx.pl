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
        push @info, $key, $meta->{$key};
    }
    my ($port,$path,$http_host) = @{$plugin->plugin_arguments};
    $port ||= 80;
    $list .= join("\t",'#Nginx ('.$port.')',@info)."\n";
    $list .= "$_\n" for qw/processes reqs/;
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

view/nginx.pl - display metrics of nginx

=head1 SYNOPSIS

  % view/nginx.pl --help

=head1 DESCRIPTION

display metrics of nginx

=head1 AUTHOR

Masahiro Nagano <kazeburo {at} gmail.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

__DATA__
@@ processes
Connections
DEF:my1=<%RRD read.gauge %>:read:AVERAGE
DEF:my2=<%RRD write.gauge %>:write:AVERAGE
DEF:my3=<%RRD wait.gauge %>:wait:AVERAGE
AREA:my1#c0c0c0:Reading
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
STACK:my2#000080:Writing
GPRINT:my2:LAST:Cur\:%7.1lf
GPRINT:my2:AVERAGE:Ave\:%7.1lf
GPRINT:my2:MAX:Max\:%7.1lf\l
STACK:my3#008080:Waiting
GPRINT:my3:LAST:Cur\:%7.1lf
GPRINT:my3:AVERAGE:Ave\:%7.1lf
GPRINT:my3:MAX:Max\:%7.1lf\l

@@ reqs
Request per sec
DEF:my1a=<%RRD reqs.derive %>:request:AVERAGE
CDEF:my1=my1a,0,250000,LIMIT
LINE1:my1#00C000:Request
GPRINT:my1:LAST:Cur\:%7.1lf
GPRINT:my1:AVERAGE:Ave\:%7.1lf
GPRINT:my1:MAX:Max\:%7.1lf\l
