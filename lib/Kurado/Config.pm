package Kurado::Config;

use strict;
use warnings;
use Mouse;
use Mouse::Util::TypeConstraints;
use File::Basename;

subtype 'Natural'
    => as 'Int'
    => where { $_ > 0 };

subtype 'Uint'
    => as 'Int'
    => where { $_ >= 0 };

subtype 'Flag'
    => as 'Int'
    => where { $_ <= 1 };

no Mouse::Util::TypeConstraints;

sub load {
    my ($class,$ref,$path) = @_;
    $ref->{_path} = $path;
    __PACKAGE__->new($ref);
}

# path

has '_path' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

# config

has 'redis' => (
    is => 'ro',
    isa => 'Str',
    default => '127.0.0.1:6379',
);

has 'data_dir' => (
    is => 'ro',
    isa => 'Str',
    default => 'data',
);

has 'rolls_dir' => (
    is => 'ro',
    isa => 'Str',
    default => 'sample_rolls',
);

has 'metrics_plugin_dir' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => 'sub { [qw/metrics_plugins metrics_site_plugins/] }',
);

# worker process numbers

has 'web_worker' => (
    is => 'ro',
    isa => 'Natural',
    default => 5,
);

has 'update_worker' => (
    is => 'ro',
    isa => 'Natural',
    default => 2,
);

has 'fetch_worker' => (
    is => 'ro',
    isa => 'Natural',
    default => 2,
);


#rel2abs

around ['data_dir','rolls_dir'] => sub {
    my $orig = shift;
    my $self = shift;
    my $dir = @_ ? $self->$orig(@_) : $self->$orig();
    File::Spec->rel2abs($dir, File::Basename::dirname($self->_path) );
};

around 'metrics_plugin_dir' => sub {
    my $orig = shift;
    my $self = shift;
    my $dirs = @_ ? $self->$orig(@_) : $self->$orig();
    [ map { File::Spec->rel2abs($_, File::Basename::dirname($self->_path)) } @$dirs ];
};

__PACKAGE__->meta->make_immutable();

sub dump {
    my $self = shift;
    my %dump;
    $dump{$_} = $self->$_ for qw/_path redis data_dir rolls_dir metrics_plugin_dir web_worker update_worker fetch_worker/;
    return \%dump;
}

1;

