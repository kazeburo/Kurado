package Kurado::Metrics;

use strict;
use warnings;
use Mouse;
use Log::Minimal;
use URI::Escape;

use Kurado::RRD;
use Kurado::Storage;
use Kurado::Object::Msg;

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
        if ( $msg->metrics_type eq 'metrics' ) {
            # rrd update
            #debugf("rrd update %s",$msg);
            eval {
                $rrd->update(msg=>$msg);
            };
            critf('failed update rrd %s : %s', $msg, $@) if $@;
        }
        elsif ( $msg->metrics_type eq 'meta' ) {
            # update storage
            $storage->set(
                msg => $msg,
                expires => 60*60
            );
        }
        elsif ( $msg->metrics_type eq 'warn' ) {
            # update storage
            $storage->set_warn(msg => $msg);
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
    
    my $obj_plugin = Kurado::Object::Plugin->new_from_identifier(uri_unescape($plugin));
    return Kurado::Object::Msg->new(
        address => $address,
        plugin => $obj_plugin,
        metrics_type => $type,
        key => $metrics_key,
        value => $value,
        timestamp => $timestamp
    );
}

1;

