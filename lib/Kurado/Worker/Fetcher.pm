package Kurado::Worker::Fetcher;

use strict;
use warnings;
use Mouse;
use Parallel::Prefork;
use Log::Minimal;

use Kurado::MQ;
use Kurado::Host;

has 'config_loader' => (
    is => 'ro',
    isa => 'Kurado::ConfigLoader',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub config {
    $_[0]->config_loader->config;
}

sub run {
    my $self = shift;
    my $pm = Parallel::Prefork->new({
        max_workers  => $self->config->fetch_worker,
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM',
        }
    });
    while ($pm->signal_received ne 'TERM') {
        $pm->start(sub{
            my $mq = Kurado::MQ->new(server => $self->config->redis);
            local $SIG{TERM} = sub {
                $mq->{stop_loop} = 1;
            };
            $mq->subscribe(
                "kurado-fetch" => sub {
                    my ($topic, $message) = @_;
                    my ($address, $plugin_identifier) = split /\t/, $message, 2;
                    my $host = $self->config_loader->host_by_address($address);
                    if (!$host) {
                        warnf 'address"%s is not found. skip it', $address;
                        return;
                    }
                    my $plugin = Kurado::Object::Plugin->new_from_identifier($plugin_identifier);
                    my $host_obj = Kurado::Host->new(
                        config => $self->config,
                        host => $host,
                    );
                    my $message = $host_obj->fetch_metrics(plugin => $plugin);
                    $mq->enqueue('kurado-update',$message);
                },
            );
        });
    }
    $pm->wait_all_children();
}



1;


