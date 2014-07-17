package Kurado::Storage;

use strict;
use warnings;
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
        plugin => 'Str',
        address => 'Str',
        key => 'Str',
        value => 'Str',
        expires => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
 
    my $set_key  = join "/", "storage", $args->{address}, $args->{plugin};
    my $key = join "/", "storage", $args->{address}, $args->{plugin}, $args->{key};
    my $connect = $self->connect;

    my $expire_at = time + $args->{expires};

    my @res;
    $connect->multi(sub {});
    $connect->zadd($set_key, $expire_at, $args->{key}, sub {});
    $connect->set($key, $args->{value}, sub {});
    $connect->expireat($key, $expire_at, sub {});
    $connect->exec(sub { @res = @_ });
    $connect->wait_all_responses;
    if ( my @err = grep { ! defined $_->[0] } @{$res[0]} ) {
        die "Storage->set error: $err[0][1]\n";
    }
    return 1;
}

sub delete {
    state $rule = Data::Validator->new(
        plugin => 'Str',
        address => 'Str',
        key => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    my $set_key  = join "/", "storage", $args->{address}, $args->{plugin};
    my $key = join "/", "storage", $args->{address}, $args->{plugin}, $args->{key};

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
        plugin => 'Str',
        address => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    my $set_key  = join "/", "storage", $args->{address}, $args->{plugin};

    my $connect = $self->connect;
    my $time = time;
    $connect->zremrangebyscore($set_key, '-inf', '('.$time);
    my @keys = $connect->zrangebyscore($set_key, $time, '+inf');
    return {} unless @keys;
    my @values = $connect->mget(map { $set_key.'/'.$_  } @keys);
    my %ret = List::MoreUtils::pairwise { ($a, $b) } @keys, @values;
    return \%ret;
}

1;


