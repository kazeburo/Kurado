package Kurado::Host;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Mouse;
use Log::Minimal;

use Kurado::Plugin::Compile;
use Kurado::Storage;

has 'config' => (
    is => 'ro',
    isa => 'Kurado::Config',
    required => 1
);

has 'host' => (
    is => 'ro',
    isa => 'Kurado::Object::Host',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub plugins {
    my $self = shift;
    $self->host->plugins;
}

sub address {
    my $self = shift;
    $self->host->address;
}

sub hostname {
    my $self = shift;
    $self->host->hostname;
}

sub service {
    my $self = shift;
    $self->host->service;
}

sub comments {
    my $self = shift;
    $self->host->comments;
}

sub compile {
    my $self = shift;
    $self->{compile} ||= Kurado::Plugin::Compile->new(config=>$self->config);
}

sub storage {
    my $self = shift;
    $self->{storage} ||= Kurado::Storage->new(redis=>$self->config->redis);
}

sub metrics_list {
    my $self = shift;

    my @list;
    for my $plugin (@{$self->plugins}) {
        my $warn = $self->storage->get_warn_by_plugin(
            plugin => $plugin,
            address => $self->address,
        );

        #run list
        my $metrics = eval {
            my ($stdout, $stderr, $success) = $self->compile->run(
                host => $self->host,
                plugin => $plugin,
                type => 'view',
            );
            die "$stderr\n" unless $success;
            $self->parse_metrics_list($stdout);
        };
        if ( $@ ) {
            $warn->{_exec_plugin_} = $@;
        }
        push @list, {
            plugin => $plugin,
            warn => $warn,
            metrics => $metrics
        };
    }
    \@list;
}

# #       uptime  up 0 days,  8:56
# # Traffic(eth0)
# traffic-eth0
# # CPU Memory
# cpu
# load-avg
# memory-usage
# tcp-established
# # Disk Usage(/)
# disk-usage-mapper_VolGroup-lv_root
# # Disk Usage(mapper_VolGroup-lv_root)
# disk-io-mapper_VolGroup-lv_root

sub parse_metrics_list {
    my $self = shift;
    my $list = shift;
    my @metrics;
    for my $line ( split /\n/, $list ) {
        next unless $line;
        if ( $line =~ m/^#/ ) {
            $line =~ s!^# *!!g;
            $line =~ s! *$!!g;
            my ($label, @args) = split /\t/,$line;
            die "odd number of metrics_list meta in '# $line'" if @args % 2;
            my %meta = @args;
            # label
            push @metrics, {
                graphs => [],
                label => $label,
                meta => \%meta
            };
        }
        else {
            $line =~ s!^ *!!g;
            $line =~ s! *$!!g;
            if (!@metrics) {
                push @metrics, {
                    graphs => [$line],
                    label => "",
                    meta => {},
                };
            }
            else {
                push @{$metrics[-1]{graphs}}, $line;
            }
        }
    }
    return \@metrics;
}

sub metrics_graph {

}



1;


