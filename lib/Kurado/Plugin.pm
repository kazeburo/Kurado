package Kurado::Plugin;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Getopt::Long;
use Pod::Usage;
use JSON::XS;
use Text::MicroTemplate::DataSectionEx;

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
        pod2usage({
            -verbose => 99,
            -exitval => 'noexit',
            -output => *STDOUT,
        });
        exit(0);
    }
    if ( !$self->{address} || !$self->{hostname} ) {
        pod2usage({
            -msg => 'ERR: address and hostname are required',
            -verbose => 1,
            -exitval => 'noexit',
            -output => *STDERR,
        });
        exit(2);
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
        $self->{$key} = $BRIDGE{"kurado.${key}"};
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

sub unit {
    my $self = shift;
    my $n = shift;
    my($base, $unit);

    return $n unless $n =~ /^\d+$/;
    if ($n >= 1073741824) {
        $base = 1073741824;
        $unit = 'GB';
    } elsif ($n >= 1048576) {
        $base = 1048576;
        $unit = 'MB';
    } elsif ($n >= 1024) {
        $base = 1024;
        $unit = 'KB';
    } else {
        $base = 1;
        $unit = 'B';
    }

    $n = sprintf '%.2f', $n/$base;
    while($n =~ s/(.*\d)(\d\d\d)/$1,$2/){};
    return $n.$unit;
}

my @info_order = (
    [qr/^version$/i => 1],
    [qr/^uptime$/i => 2],
    [qr/^version/i => 3],
    [qr/^uptime/i => 4],
    [qr/version$/i => 5],
    [qr/uptime$/i => 6],
);
sub match_order {
    my $key = shift;
    my ($hit) = grep { $key =~ m!$_->[0]! } @info_order;
    return 999 unless $hit;
    $hit->[1];
}
sub sort_info {
    my $self = shift;
    sort {
        match_order($a) <=> match_order($b) || $a cmp $b
    } @_;
}

sub render {
    my $self = shift;
    my $template = shift;
    my $args = defined $_[0] && ref $_[0] ? $_[0] : { @_ };
    my $mt = Text::MicroTemplate::DataSectionEx->new(
        extension => "",
        package => $self->{caller}->[0],
        template_args => $args,
    );
    $mt->render($template);
}

1;



