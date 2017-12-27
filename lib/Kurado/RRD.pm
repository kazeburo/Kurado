package Kurado::RRD;

use strict;
use warnings;
use 5.10.0;
use Mouse;
use RRDs 1.4004;
use File::Spec;
use File::Basename;
use File::Path qw/make_path/;
use Data::Validator;
use URI::Escape;
use Log::Minimal;

has 'data_dir' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);
__PACKAGE__->meta->make_immutable();

sub _create {
    my ($self,$path) = @_;
    return $path if -f $path;

    if ( $path !~ m!\.(gauge|counter|derive|absolute)\.rrd$! ) {
        die "invalid path. not contains data type: $path\n";
    }
    my $dst = uc($1);

    my @param = (
        '--start', time - 10,
        '--step', '60',
        "DS:n:${dst}:120:U:U",
        'RRA:AVERAGE:0.5:1:2880',    #1分   1分    2日 2*24*60/(1*1) daily用
        'RRA:AVERAGE:0.5:5:2880',   #5分   5分    10日 10*24*60/(5*1) weekly用
        'RRA:AVERAGE:0.5:60:960',   #1時間  60分  40日 40*24*60/(60*1) monthly用
        'RRA:AVERAGE:0.5:1440:1100', #24時間 1440分 1100日
        'RRA:MIN:0.5:1:2880', 
        'RRA:MIN:0.5:5:2880',
        'RRA:MIN:0.5:60:960',
        'RRA:MIN:0.5:1440:1100',
        'RRA:MAX:0.5:1:2880', 
        'RRA:MAX:0.5:5:2880',
        'RRA:MAX:0.5:60:960',
        'RRA:MAX:0.5:1440:1100',
    );

    eval {
        if ( ! -d dirname($path) ) {
            make_path(dirname($path)) or die "make_path: $!\n";
        }
        RRDs::create($path, @param);
        my $ERR=RRDs::error;
        die "$ERR\n" if $ERR;
    };
    die "rrd create failed: $@\n" if $@;
    return $path;
}

sub update {
    state $rule = Data::Validator->new(
        msg => 'Kurado::Object::Msg'
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $path = File::Spec->catfile(
        $self->data_dir,
        $args->{msg}->address,
        $args->{msg}->plugin->plugin_identifier_escaped,
        uri_escape($args->{msg}->key) . '.rrd'
    );

    $self->_create($path);

    my @param = (
        '-t', 'n',
        '--', join(':', $args->{msg}->timestamp, $args->{msg}->value)
    );
    debugf('rrd update %s %s', join(" ", @param), $path);
    eval {
        RRDs::update($path, @param);
        my $ERR=RRDs::error;
        if ( $ERR && $ERR =~ /illegal attempt to update using time.*when last update time is.*minimum one second step/ ) {
            warnf('failed update rrd %s%s: %s',$path,\@param, $ERR);
        }
        else {
            die "$ERR\n" if $ERR;
        }
    };
    die "rrd update failed: $@\n" if $@;
    return 1;
}

sub graph {
    state $rule = Data::Validator->new(
        def => 'Str',
        host => 'Kurado::Object::Host',
        plugin => 'Kurado::Object::Plugin',
        term => 'Str',
        from => 'Str',
        to => 'Str',
        width => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my ($title,$def) = $self->parse_graph_def(
        plugin => $args->{plugin},
        host => $args->{host},
        def => $args->{def},
    );

    my $period_title;
    my $period;
    my $end = 'now';
    my $xgrid;

    if ( $args->{term} eq 'custom' ) {
        my $from_time = HTTP::Date::str2time($args->{from});  
        die "invalid from date: $args->{from}\n" unless $from_time;
        my $to_time = $args->{to} ? HTTP::Date::str2time($args->{to}) : time;
        die "invalid to date: $args->{to}\n" unless $to_time;
        die "from($args->{from}) is newer than to($args->{to})\n" if $from_time > $to_time;
        $period_title = "$args->{from} to $args->{to}";
        $period = $from_time;
        $end = $to_time;
        my $diff = $to_time - $from_time;
        if ( $diff < 3 * 60 * 60 ) {
            $xgrid = 'MINUTE:10:MINUTE:30:MINUTE:30:0:%H:%M';
        }
        elsif ( $diff < 4 * 24 * 60 * 60 ) {
            $xgrid = 'HOUR:1:DAY:1:HOUR:2:0:%H:%M';
        }
        elsif ( $diff < 14 * 24 * 60 * 60) {
            $xgrid = 'DAY:1:DAY:7:DAY:2:0:%m/%d';
        }
        elsif ( $diff < 45 * 24 * 60 * 60) {
            $xgrid = 'DAY:1:WEEK:1:WEEK:1:0:%m/%d';
        }
        else {
            $xgrid = 'WEEK:1:MONTH:1:MONTH:1:2592000:%b';
        }
    }
    elsif ( $args->{term} eq 'year' ) {
        $period_title = 'Year';
        $period = -1 * 60 * 60 * 24 * 400;
        $xgrid = 'MONTH:1:MONTH:1:MONTH:1:2592000:%b'
    }
    elsif ( $args->{term} eq 'month' ) {
        $period_title = 'Month';
        $period = -1 * 60 * 60 * 24 * 35;
        $xgrid = 'WEEK:1:WEEK:1:WEEK:1:604800:Week %W'
    }
    elsif ( $args->{term} eq 'week' ) {
        $period_title = 'Week';
        $period = -1 * 60 * 60 * 24 * 8;
        $xgrid = 'DAY:1:DAY:1:DAY:1:86400:%a'
    }
    elsif ( $args->{term} eq 'day' ) {
        $period_title = 'Day';
        $period = -1 * 60 * 60 * 33; # 33 hours
        $xgrid = 'HOUR:2:HOUR:4:HOUR:4:0:%H:%M';
    }
    elsif ( $args->{term} eq '3days' ) {
        $period_title = '3 Days';
        $period = -1 * 60 * 60 * 24 * 3;
        $xgrid = 'HOUR:6:DAY:1:HOUR:12:0:%H:%M';
    }
    elsif ( $args->{term} eq '8hours' ) {
        $period_title = '8 Hours';
        $period = -1 * 8 * 60 * 60;
        $xgrid = 'MINUTE:30:HOUR:1:HOUR:1:0:%H:%M';
    }
    elsif ( $args->{term} eq '4hours' ) {
        $period_title = '4 Hours';
        $period = -1 * 4 * 60 * 60;
        $xgrid = 'MINUTE:30:HOUR:1:HOUR:1:0:%H:%M';
    }
    else {
        $period_title = 'Hour';
        $period = -1 * 60 * 70;
        $xgrid = 'MINUTE:10:MINUTE:20:MINUTE:10:0:%H:%M';
    }

    $period_title = $period_title . ' ' . $args->{host}->hostname;
    my ($tmpfh, $tmpfile) = File::Temp::tempfile(UNLINK => 0, SUFFIX => ".png");
    my @opt = (
        $tmpfile,
        '-w', $args->{width},
        '-h', 100,
        '-l', 0, #minimum
        '-u', 2, #maximum
        '-x', $xgrid,
        '-s', $period,
        '-e', $end,
        '-v', $title,
        #'--slope-mode',
        '--disable-rrdtool-tag',
        '--color', 'BACK#'.uc('f3f3f3'),
        '--color', 'CANVAS#'.uc('ffffff'),
        '--color', 'GRID#'.uc('8f8f8f'),
        '--color', 'MGRID#'.uc('666666'),
        '--color', 'FONT#'.uc('222222'),
        '--color', 'FRAME#'.uc('222222'),
        '--color', 'AXIS#'.uc('111111'),
        '--color', 'SHADEA#'.uc('dddddd'), #none
        '--color', 'SHADEB#'.uc('dddddd'), #none
        '--color', 'ARROW#'.uc('f89407'), 
        '--border', 1,
        '-t', $period_title,
        '--font-render-mode', 'light',
        '--font', "TITLE:8:",
        '--font', "AXIS:8:",
        '--font', "LEGEND:8:",
        @$def,
    );
    my @graphv;
    eval {
        @graphv = RRDs::graph(map { Encode::encode_utf8($_) } @opt);
        my $ERR=RRDs::error;
        die "$ERR\n" if $ERR;
    };
    if ( $@ ) {
        unlink($tmpfile);
        die "draw graph failed: $@\n";
    }

    open( my $fh, '<:bytes', $tmpfile ) or die "cannot open graph tmpfile: $!\n";
    local $/;
    my $graph_img = <$fh>;
    unlink($tmpfile);

    die "something wrong with image\n" unless $graph_img;

    return ($graph_img,\@graphv);
}

sub parse_graph_def {
    state $rule = Data::Validator->new(
        def => 'Str',
        host => 'Kurado::Object::Host',
        plugin => 'Kurado::Object::Plugin',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

# Graph Vertical-title
# DEF:ind=<%RRD_FOR traffic-eth1-rxbytes.derive %>:n:AVERAGE
# DEF:outd=<%RRD_FOR traffic-eth1-txbytes.derive %>:n:AVERAGE
# CDEF:in=ind,0,1250000000,LIMIT,8,*
# CDEF:out=outd,0,1250000000,LIMIT,8,*
# AREA:in#00C000:Inbound  
# GPRINT:in:LAST:Cur\:%6.2lf%sbps
# GPRINT:in:AVERAGE:Ave\:%6.2lf%sbps
# GPRINT:in:MAX:Max\:%6.2lf%sbps\l
# LINE1:out#0000FF:Outbound 
# GPRINT:out:LAST:Cur\:%6.2lf%sbps
# GPRINT:out:AVERAGE:Ave\:%6.2lf%sbps
# GPRINT:out:MAX:Max\:%6.2lf%sbps\l
    my $def = $args->{def};
    $def =~ s!<%RRD(?:_FOR)?\s+(.+?\.(?:gauge|counter|derive|absolute))\s+%>!&rrd_path_for($self,$args->{plugin},$args->{host},$1)!ge;
    $def =~ s!<%RRD_EXTEND\s+(.+?) +(.+?) +(.+?\.(?:gauge|counter|derive|absolute))\s+%>!&rrd_path_extend($self,$1,$2,$3)!ge;
    $def =~ s!^DEF:([^:]+):[^:]+:(MAX|AVERAGE|MIN)!DEF:$1:n:$2!gms;
    my @def = grep {$_} grep { $_ !~ m!^\s*(?:#|//)! } split /\n/,$def; # comment
    my $title = $args->{plugin}->plugin;
    if ( $def[0] !~ m!^C?DEF:! ) {
        $title = shift @def;
    }
    $title,\@def;
}


sub rrd_path_for {
    my ($self, $plugin,$host,$key) = @_;
    File::Spec->catfile(
        $self->data_dir,
        $host->address,
        $plugin->plugin_identifier_escaped,
        uri_escape($key) . '.rrd'
    );
}

sub rrd_path_extend {
    my ($self, $plugin,$ip, $key) = @_;
    File::Spec->catfile(
        $self->data_dir,
        $ip,
        $plugin,
        uri_escape($key) . '.rrd'
    );
    
}


1;


