package Kurado::Worker::Updater;

use strict;
use warnings;
use Mouse;
use Parallel::Prefork;
use Log::Minimal;

use Kurado::MQ;
use Kurado::Metrics;

has 'config' => (
    is => 'ro',
    isa => 'Kurado::Config',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub run {
    my $self = shift;
    my $pm = Parallel::Prefork->new({
        max_workers  => $self->config->update_worker,
        trap_signals => {
            TERM => 'TERM',
            HUP  => 'TERM',
        }
    });
    while ($pm->signal_received ne 'TERM') {
        $pm->start(sub{
            my $mq = Kurado::MQ->new(server => $self->config->redis);
            my $metrics = Kurado::Metrics->new(config => $self->config);
            local $SIG{TERM} = sub {
                $mq->{stop_loop} = 1;
            };
            $mq->subscribe(
                "kurado-update" => sub {
                    my ($topic, $message) = @_;
                    $metrics->process_message($message);
                },
            );
        });
    }
    $pm->wait_all_children();
}



1;


