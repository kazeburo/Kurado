package Kurado::Plugin;

use strict;
use warnings;
use 5.10.0;
use Getopt::Long;
use Pod::Usage;
use JSON::XS;

my $_JSON = JSON::XS->new->utf8;
our %BRIDGE = ();

sub new {
    my $class = shift;
    my @args = @_;
    my @caller = caller;
    # ($package, $filename, $line) = caller;
    my $self = bless {
        caller => \@caller,
        args => \@args,
    }, $class;
    $self->parse_options();
    $self;
}

sub parse_options {
    my $self = shift;
    local @ARGV = @{$self->{args}};

    my $parser = Getopt::Long::Parser->new(
        config => [ "no_auto_abbrev", "no_ignore_case", "pass_through" ],
    );

    $parser->getoptions(
        "address=s"          => \$self->{address},
        "hostname=s"         => \$self->{hostname},
        "comments=s"         => \my @comments,
        "plugin-arguments=s" => \my @plugin_arguments,
        "graph=s"            => \$self->{graph},
        "h|help"             => \my $help,
        "v|version"          => \my $version,
        "metrics-config-json=s" => \$self->{metrics_config_json},
        "metrics-meta-json=s"   => \$self->{metrics_meta_json},
    );

    my $plugin_version = eval '$'.$self->{caller}->[0]."::VERSION";
    $plugin_version //= 'unknown';

    if ( $version ) {
        print "display/base.pl version $plugin_version\n";
        print "Try `$self->{caller}[1] --help` for more options.\n\n";
        exit 0;
    }

    if ( $help ) {
        pod2usage(
            -verbose => 2,
            -exitval => 0,
            -input => $self->{caller}->[1],
        );
    }

    if ( !$self->{address} || !$self->{hostname} ) {
        pod2usage(
            -verbose => 1,
            -exitval => 1,
            -input => $self->{caller}->[1],
        );        
    }

    $self->{comments} = \@comments;
    $self->{plugin_arguments} = \@plugin_arguments;
}

sub address {
    $_[0]->{address};
}

sub hostname {
    $_[0]->{hostname};
}

sub comments {
    $_[0]->{comments};
}

sub plugin_arguments {
    $_[0]->{plugin_arguments};
}

sub graph {
    $_[0]->{graph};
}

sub jdclone {
    my $ref = shift;
    $_JSON->decode($_JSON->encode($ref));
}

use Log::Minimal;

sub meta_config {
    my ($self,$key) = @_;

    return $self->{$key} if $self->{$key};
    if ( $self->{"${key}_json"} ) {
        if ( $self->{"${key}_json"} =~ m!^{! ) {
            $self->{$key} = eval { $_JSON->decode($self->{"${key}_json"}) };
            die $@ if $@;
        }
        else {
            $self->{$key} = eval {
                open(my $fh, '<', $self->{"${key}_json"}) or die $!;
                my $json_text = do { local $/; <$fh> };
                $_JSON->decode($json_text)
            };
            die $@ if $@;
        }
    }
    elsif ( $BRIDGE{"kurado.${key}"} && ref $BRIDGE{"kurado.${key}"}) {
        $self->{$key} = jdclone($BRIDGE{"kurado.${key}"});
    }
    elsif ( exists $ENV{"kurado.${key}_json"} ) {
        $self->{$key} = eval { $_JSON->decode($ENV{"kurado.${key}_json"}) };
        die $@ if $@;
    }
    else {
        $self->{$key} = {};
    }
    $self->{$key}
}

sub metrics_config {
    my $self = shift;
    $self->meta_config('metrics_config');
}

sub metrics_meta {
    my $self = shift;
    $self->meta_config('metrics_meta');
}

sub uptime2str {
    my $self = shift;
    my $uptime = shift;
    my $day = int( $uptime /86400 );
    my $hour = int( ( $uptime % 86400 ) / 3600 );
    my $min = int( ( ( $uptime % 86400 ) % 3600) / 60 );
    sprintf("up %d days, %2d:%02d", $day, $hour, $min);
}

1;


