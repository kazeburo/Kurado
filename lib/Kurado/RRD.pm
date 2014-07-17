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
        plugin => 'Kurado::Object::Plugin',
        address => 'Str',
        key => 'Str',
        timestamp => 'Str',
        value => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $path = File::Spec->catfile(
        $self->data_dir,
        $args->{address},
        $args->{plugin}->plugin_identifier_escaped,
        uri_escape($args->{key}) . '.rrd'
    );

    $self->_create($path);

    my @param = (
        '-t', 'n',
        '--', join(':', $args->{timestamp}, $args->{value})
    );
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
    die "rrd update failed: $@" if $@;
    return 1;
}

1;


