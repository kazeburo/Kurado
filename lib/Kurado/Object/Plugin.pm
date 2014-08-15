package Kurado::Object::Plugin;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Mouse;
use JSON::XS;
use URI::Escape;

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

sub new_from_identifier {
    my $class = shift;
    my $identifier = shift;
    my ($plugin, @args) = split /:/, $identifier;
    $class->new(
        plugin => $plugin,
        arguments => \@args,
    );
}


sub plugin_identifier {
    my $self = shift;
    my $str = $self->plugin . ((@{$self->arguments}) ? ':'.join(":",@{$self->arguments}) : '');
    $str;
}

sub plugin_identifier_short {
    my $self = shift;    
    my $str = $self->plugin_identifier;
    if ( length $str <= 27 ) {
        return $str;
    }
    substr($str,0,25) . '..';
}


sub plugin_identifier_escaped {
    my $self = shift;
    uri_escape($self->plugin_identifier, "^A-Za-z0-9\-_"); #escape dot
}

sub TO_JSON {
    my $self = shift;
    +{map { ($_ => $self->$_) } qw/plugin arguments/};
}

1;


