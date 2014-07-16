package Kurado::Metrics;

use strict;
use warnings;
use Mouse;
use Log::Minimal;

use Kurado::RRD;
use Kurado::Storage;

has 'config' => (
    is => 'ro',
    isa => 'Kurado::Config',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub process_message {
    my ($self,$message) = @_;
    my $rrd = Kurado::RRD->new(data_dir=>$self->config->data_dir);
    my $storage = Kurado::Storage->new(redis=>$self->config->redis);
    foreach my $line ( split /\n/, $message ) {
        chomp $line;
        my $msg = eval {
            $self->parse_metrics_line($line);
        };
        if ($@) {
            warnf("'$line' has error '$@'. ignore it");
            next;
        }
        if ( $msg->{type} eq 'metrics' ) {
            # rrd update
            #debugf("rrd update %s",$msg);
            eval {
                $rrd->update(
                    plugin => $msg->{plugin},
                    address => $msg->{address},
                    key => $msg->{key},
                    timestamp => $msg->{timestamp},
                    value => $msg->{value},
                );
            };
            critf('failed update rrd %s : %s', $msg, $@) if $@;
        }
        elsif ( $msg->{type} eq 'meta' ) {
            # update storage
            $storage->set(
                plugin => $msg->{plugin},
                address => $msg->{address},
                key => $msg->{key},
                value => $msg->{value},
                expires => 60*60
            );
        }
        elsif ( $msg->{type} eq 'warn' ) {
            # update storage
            my @lt = localtime($msg->{timestamp});
            my $timestr = sprintf '%04d-%02d-%02dT%02d:%02d:%02d', $lt[5]+1900, $lt[4]+1, @lt[3,2,1,0];
            $storage->set(
                plugin => "__warn__/".$msg->{plugin},
                address => $msg->{address},
                key => $msg->{key},
                value => "[$timestr] $msg->{value}",
                expires => 5*60
            );
        }
    }
    
}

sub parse_metrics_line {
    my ($self, $line) = @_;
    my @msg = split /\t/, $line;
    if ( @msg != 4 ) {
        die "msg does not have 4 column. ignore it\n";
    }
    my ($address, $key, $value, $timestamp) = @msg;

    # base.metrics.tcp-established.gauge
    # base.meta.traffic-interfaces
    # base.warn.traffic-interfaces

    my ($plugin, $type, $metrics_key) = split /\./, $key, 3;
    if ( !$type || !$metrics_key ) {
        die "key does not contains two dot\n";
    }

    if ( $type !~ m!^(?:metrics|meta|warn)$! ) {
        die "invalid metrics-type\n";
    }

    if ( $type eq 'metrics' && $metrics_key !~ m!\.(?:gauge|counter|derive|absolute)$! ) {
        die "invalid rrd data type\n";
    }
    
    return {
        address => $address,
        plugin => $plugin,
        type => $type,
        key => $metrics_key,
        joined_key => $key,
        value => $value,
        timestamp => $timestamp
    };
}

1;

