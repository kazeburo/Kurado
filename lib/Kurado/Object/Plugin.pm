package Kurado::Object::Plugin;

use strict;
use warnings;
use 5.10.0;
use Mouse;
use JSON::XS;

has 'plugin' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'arguments' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub TO_JSON {
    my $self = shift;
    +{map { ($_ => $self->$_) } qw/plugin arguments/};
}

1;


