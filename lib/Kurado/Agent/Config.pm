package Kurado::Agent::Config;

use strict;
use warnings;
use utf8;
use Kurado::Agent::TOML;
use boolean qw//;
use Cwd::Guard qw/cwd_guard/;

my $PARSER = Kurado::Agent::TOML->new;

sub new {
    my $class = shift;
    my $path = shift;
    my $self = bless {
        plugins => {
        }
    }, $class;
    my $dir = cwd_guard($path);
    for my $inc_path ( glob '*.toml' ) {
        $self->parse_file($inc_path);
    }
    $self;
}

sub parse_file {
    my ($self, $path) = @_;
    my $ref = eval {
        $PARSER->parse_file($path);
    };
    die "can't load config $path: $@\n" if $@;

    my $plugins = delete $ref->{plugin};
    if ( $plugins && $plugins->{metrics} ) {
        for (keys %{$plugins->{metrics}}) {
            $self->{plugins}->{$_} = $plugins->{metrics}->{$_}->{command};
        }
    }
}

sub plugins { $_[0]->{plugins} || {} };



1;


