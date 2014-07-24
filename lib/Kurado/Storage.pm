package Kurado::Storage;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Mouse;
use Data::Validator;
use Redis::Fast;
use List::MoreUtils;
use Log::Minimal;

has 'redis' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

__PACKAGE__->meta->make_immutable();

my %REDIS_CONNECTION;
sub connect {
    my $self = shift;
    $REDIS_CONNECTION{"$$-".$self->redis} ||= Redis::Fast->new(
        server => $self->redis,
        reconnect => 10,
        every => 100
    );
    $REDIS_CONNECTION{"$$-".$self->redis};
}

sub set {
    state $rule = Data::Validator->new(
        msg => 'Kurado::Object::Msg',
        expires => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    $self->_set(
        (map { ( $_ => $args->{$_} ) } qw/msg expires/),
        type => 'storage',
    );
}


sub set_warn {
    state $rule = Data::Validator->new(
        msg => 'Kurado::Object::Msg'
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my @lt = localtime($args->{msg}->{timestamp});
    my $timestr = sprintf '%04d-%02d-%02dT%02d:%02d:%02d', $lt[5]+1900, $lt[4]+1, @lt[3,2,1,0];
    $self->_set(
        msg  => $args->{msg},
        type => '__warn__',
        expires => 5*60,
        value => "$timestr ".$args->{msg}->value
    );
}

sub _set {
    state $rule = Data::Validator->new(
        msg => 'Kurado::Object::Msg',         
        expires => 'Str',
        type => 'Str',
        value => { isa => 'Str', optional => 1},
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
 
    my $set_key  = join "/", $args->{type},
        $args->{msg}->address, $args->{msg}->plugin->plugin_identifier_escaped;
    my $key = join "/", $args->{type}, 
        $args->{msg}->address, $args->{msg}->plugin->plugin_identifier_escaped, $args->{msg}->key;
    my $connect = $self->connect;
    my $now = time;
    my $expire_at = $now + $args->{expires};
    my $value = (exists $args->{value}) ? $args->{value} : $args->{msg}->value;
    my @res;
    $connect->multi(sub {});
    $connect->zadd($set_key, $expire_at, $args->{msg}->key, sub {});
    $connect->set($key, $value, sub {});
    $connect->expireat($key, $expire_at, sub {});
    if ( $args->{type} eq '__warn__' ) { #XXX
        my $has_warn_key = join "/", '__warn__', $args->{msg}->address;
        $connect->set($has_warn_key, $now, 'EX', $args->{expires}, sub {});
    }
    $connect->exec(sub { @res = @_ });
    $connect->wait_all_responses;
    if ( my @err = grep { ! defined $_->[0] } @{$res[0]} ) {
        die "Storage->set error: $err[0][1]\n";
    }
    return 1;
}

sub delete {
    state $rule = Data::Validator->new(
        plugin => 'Kurado::Object::Plugin',
        address => 'Str',
        key => 'Str'
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $set_key  = join "/", 'storage',
        $args->{address}, $args->{plugin}->plugin_identifier_escaped;
    my $key = join "/", 'storage', 
        $args->{address}, $args->{plugin}->plugin_identifier_escaped, $args->{key};

    my $connect = $self->connect;

    my @res;
    $connect->multi(sub{});
    $connect->zrem($set_key, $args->{key}, sub{});
    $connect->del($key, sub{});
    $connect->exec(sub { @res = @_ });
    $connect->wait_all_responses;
    if ( my @err = grep { ! defined $_->[0] } @{$res[0]} ) {
        die "Storage->delete error: $err[0][1]\n";
    }
    return 1;
}

*remove = \&delete;

sub get_by_plugin {
    state $rule = Data::Validator->new(
        plugin => 'Kurado::Object::Plugin',
        address => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $set_key  = join "/", 'storage',
        $args->{address}, $args->{plugin}->plugin_identifier_escaped;

    my $connect = $self->connect;
    my $time = time;
    $connect->zremrangebyscore($set_key, '-inf', '('.$time);
    my @keys = $connect->zrangebyscore($set_key, $time, '+inf');
    return {} unless @keys;
    my @values = $connect->mget(map { $set_key.'/'.$_  } @keys);
    my %ret = List::MoreUtils::pairwise { ($a, $b) } @keys, @values;
    return \%ret;
}

sub get_warn_by_plugin {
    state $rule = Data::Validator->new(
        plugin => 'Kurado::Object::Plugin',
        address => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $set_key  = join "/", '__warn__',
        $args->{address}, $args->{plugin}->plugin_identifier_escaped;

    my $connect = $self->connect;
    my $time = time;
    $connect->zremrangebyscore($set_key, '-inf', '('.$time);
    my @keys = $connect->zrangebyscore($set_key, $time, '+inf');
    if ( !@keys ) {
        return {};
    }
    my @values = $connect->mget(map { $set_key.'/'.$_  } @keys);
    my %ret = List::MoreUtils::pairwise { ($a, $b) } @keys, @values;
    return \%ret;
}

sub set_last_recieved {
    state $rule = Data::Validator->new(
        msg => 'Kurado::Object::Msg',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $value = time;
    my $key = join "/", '__last_recieved__', $args->{msg}->address, $args->{msg}->plugin->plugin_identifier_escaped;
    $self->connect->set($key, $value, 'EX', 365*86400);
}


sub get_last_recieved {
    state $rule = Data::Validator->new(
        plugin => 'Kurado::Object::Plugin',
        address => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);

    my $value = time;
    my $key = join "/", '__last_recieved__', $args->{address}, $args->{plugin}->plugin_identifier_escaped;
    $self->connect->get($key);
}

sub has_warn {
    state $rule = Data::Validator->new(
        address => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    my $key = join "/", '__warn__', $args->{address};
    $self->connect->get($key);
    
}


1;


