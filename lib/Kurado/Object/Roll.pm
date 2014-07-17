package Kurado::Object::Roll;

use strict;
use warnings;
use 5.10.0;
use Mouse;
use JSON::XS;

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

__PACKAGE__->meta->make_immutable();

sub TO_JSON {
    my $self = shift;
    +{map { ($_ => $self->$_) } qw/metrics_config plugins/};
}


1;

