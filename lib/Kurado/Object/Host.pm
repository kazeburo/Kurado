package Kurado::Object::Host;

use strict;
use warnings;
use 5.10.0;
use Mouse;
use JSON::XS;

has 'address' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'hostname' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'comments' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'roll' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'metrics_config' => (
    is => 'ro',
    isa => 'HashRef[Any]',
    required => 1
);

has 'plugins' => (
    is => 'ro',
    isa => 'ArrayRef[Kurado::Object::Plugin]',
    required => 1
);

has 'service' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub has_plugin {
    my $self = shift;
    my $plugin = shift;
    grep { $_->plugin eq $plugin } @{$self->plugins}
}

sub TO_JSON {
    my $self = shift;
    +{map { ($_ => $self->$_) } qw/address hostname comments roll metrics_config plugins/};
}

1;

