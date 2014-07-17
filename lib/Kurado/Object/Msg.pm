package Kurado::Object::Msg;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Mouse;

has 'plugin' => (
    is => 'ro',
    isa => 'Kurado::Object::Plugin',
    required => 1
);

has 'address' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'metrics_type' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'key' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'value' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'timestamp' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);


__PACKAGE__->meta->make_immutable();


1;


