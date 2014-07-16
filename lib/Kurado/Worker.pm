package Kurado::Worker;

use strict;
use warnings;
use Mouse;
use Proclet;

use Kurado::Worker::Updater;

has 'config_loader' => (
    is => 'ro',
    isa => 'Kurado::ConfigLoader',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub run {
    my $self = shift;
    my $proclet = Proclet->new(
        err_respawn_interval => 3,
    );
    my $updater = Kurado::Worker::Updater->new(config=>$self->config_loader->config);
    $proclet->service(
        code => sub {
            local $Log::Minimal::PRINT = sub {
                my ( $time, $type, $message, $trace,$raw_message) = @_;
                warn "[$type] $message at $trace\n";
            };
            $updater->run();
        },
        worker => 1,
        tag => 'updater'
    );


    

    $proclet->run;
}

1;

