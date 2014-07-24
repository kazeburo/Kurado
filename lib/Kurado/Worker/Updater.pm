package Kurado::Worker::Updater;

use strict;
use warnings;
use Mouse;
use Parallel::Prefork;
use Log::Minimal;

use Kurado::MQ;
use Kurado::Metrics;

has 'config_loader' => (
    is => 'ro',
    isa => 'Kurado::ConfigLoader',
    required => 1
);

has 'scoreboard' => (
    is => 'ro',
    isa => 'Kurado::ScoreBoard',
    required => 1
);


__PACKAGE__->meta->make_immutable();

sub config {
    $_[0]->config_loader->config
}

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
            $self->scoreboard->idle;
            $mq->subscribe(
                "kurado-update" => sub {
                    my ($topic, $message) = @_;
                    my $gurad = $self->scoreboard->busy;
                    $metrics->process_message($message);
                },
            );
        });
    }
    $pm->wait_all_children();
}



1;


