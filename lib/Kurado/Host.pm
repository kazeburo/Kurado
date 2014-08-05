package Kurado::Host;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Mouse;
use Log::Minimal;
use Data::Validator;

use Kurado::Plugin::Compile;
use Kurado::Storage;
use Kurado::RRD;

has 'config_loader' => (
    is => 'ro',
    isa => 'Kurado::ConfigLoader',
    required => 1
);

has 'host' => (
    is => 'ro',
    isa => 'Kurado::Object::Host',
    required => 1
);

__PACKAGE__->meta->make_immutable();

our $LAST_RECEIVED_EXPIRES = 300;

sub config {
    $_[0]->config_loader->config;
}

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
        
        my $last_received = $self->storage->get_last_recieved(
            plugin => $plugin,
            address => $self->address,            
        );
        if ( (!$last_received || $last_received < time - $LAST_RECEIVED_EXPIRES ) && !$self->config_loader->has_fetch_plugin($plugin->plugin) ) {
            $warn->{'__system__'} = 'Metrics are not updated in the last 5 minutes. This host or kurado_agent has been down';
            $warn->{'__system__'} .= '.last updated: ' . localtime($last_received) if $last_received;
        }

        #run list
        my $metrics = eval {
            my ($stdout, $stderr, $success) = $self->compile->run(
                host => $self->host,
                plugin => $plugin,
                type => 'view',
            );
            die "$stderr\n" unless $success;
            warnf $stderr if $stderr;
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
            my @meta;
            while ( @args ) {
                my $key = shift(@args);
                my $val = shift(@args);
                push @meta, {key=>$key,value=>$val};
            }
            my %meta = @args;
            # label
            push @metrics, {
                graphs => [],
                label => $label,
                meta => \@meta
            };
        }
        else {
            $line =~ s!^ *!!g;
            $line =~ s! *$!!g;
            if (!@metrics) {
                push @metrics, {
                    graphs => [$line],
                    label => "",
                    meta => [],
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
    state $rule = Data::Validator->new(
        graph => 'Str',
        plugin => 'Kurado::Object::Plugin',
        term => 'Str',
        from => 'Str',
        to => 'Str',
        width => 'Str'
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    my ($img,$data);
    eval {
        my ($stdout, $stderr, $success) = $self->compile->run(
            host => $self->host,
            plugin => $args->{plugin},
            type => 'view',
            graph => $args->{graph},
        );
        die "$stderr\n" unless $success;
        warnf $stderr if $stderr;
        my $rrd = Kurado::RRD->new(data_dir => $self->config->data_dir);        
        ($img,$data) = $rrd->graph(
            def => $stdout,
            host => $self->host,
            plugin => $args->{plugin},
            term => $args->{term},
            from => $args->{from},
            to => $args->{to},
            width => $args->{width},
        );
    };
    die sprintf('address:%s plugin:%s graph:%s: %s'."\n",$self->host->address, $args->{plugin}->plugin, $args->{graph}, $@) if $@;
    return ($img,$data);
}


sub fetch_metrics {
    state $rule = Data::Validator->new(
        plugin => 'Kurado::Object::Plugin',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    my $body = '';
    eval {
        my ($stdout, $stderr, $success) = $self->compile->run(
            host => $self->host,
            plugin => $args->{plugin},
            type => 'fetch',
        );
        die "$stderr\n" unless $success;
        warnf $stderr if $stderr;
        $body .= $self->parse_fetched_metrics(
            plugin => $args->{plugin},
            result => $stdout
        );
    };
    if ( $@ ) {
        my $warn = $@;
        $warn =~ s!(?:\n|\r)!!g;
        my $time = time;
        my $plugin_key = $args->{plugin}->plugin_identifier_escaped;
        my $self_ip = $self->host->address;
        $body .= "$self_ip\t$plugin_key.warn.command\t$warn\t$time\n";
    }
    $body;
}

sub parse_fetched_metrics {
    state $rule = Data::Validator->new(
        plugin => 'Kurado::Object::Plugin',
        result => 'Str',
    )->with('Method');
    my ($self, $args) = $rule->validate(@_);
    my $time = time;
    my $result = $args->{result};
    my $plugin_key = $args->{plugin}->plugin_identifier_escaped;
    my $self_ip = $self->host->address;
    my $body = '';
    for my $ret (split /\n/, $result) {
        chomp($ret);
        my @ret = split /\t/,$ret;
        if ( $ret[0] !~ m!^(?:metrics|meta)\.! ) {
            $ret[0] = "metrics.$ret[0]";
        }
        if ( $ret[0] =~ m!^metrics\.! && $ret[0] !~ m!\.(?:gauge|counter|derive|absolute)$! ) {
            $ret[0] = "$ret[0].gauge";
        }
        $ret[0] = "$plugin_key.$ret[0]";
        $ret[2] ||= $time;
        $body .= join("\t", $self_ip, @ret[0,1,2])."\n";
    }
    $body;
}

    # 2 = critical
    # 1 = warn
    # 0 = ok

sub status {
    my $self = shift;

    if ( my ($base_plugin) = $self->host->has_plugin('base') ) {
        my $last_received = $self->storage->get_last_recieved(
            plugin => $base_plugin,
            address => $self->address,            
        );
        if ( !$last_received || $last_received < time - $LAST_RECEIVED_EXPIRES ) {
            return 2;
        }
    }

    my $has_warn = $self->storage->has_warn(
        address => $self->address,
    );
    return 1 if $has_warn;

    for my $plugin ( @{$self->host->plugins} ) {
        next if $self->config_loader->has_fetch_plugin($plugin->plugin);
        my $last_received = $self->storage->get_last_recieved(
            plugin => $plugin,
            address => $self->address,            
        );
        if ( !$last_received || $last_received < time - $LAST_RECEIVED_EXPIRES ) {
            return 1;
        }        
    }

    return 0;
}

1;


