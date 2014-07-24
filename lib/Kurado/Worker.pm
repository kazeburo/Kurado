package Kurado::Worker;

use strict;
use warnings;
use Mouse;
use Proclet;
use Plack::Loader;
use Plack::Builder;

use Kurado::ScoreBoard;
use Kurado::Worker::Updater;
use Kurado::Worker::TimeMage;
use Kurado::Worker::Fetcher;
use Kurado::Web;

has 'config_loader' => (
    is => 'ro',
    isa => 'Kurado::ConfigLoader',
    required => 1
);

has 'root_dir' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);


__PACKAGE__->meta->make_immutable();

sub run {
    my $self = shift;
    
    my $sb = Kurado::ScoreBoard->new(
        config => $self->config_loader->config,
    );
    my $proclet = Proclet->new(
        err_respawn_interval => 3,
        exec_notice => 0,
    );
    my $updater = Kurado::Worker::Updater->new(
        scoreboard => $sb,
        config_loader => $self->config_loader
    );
    my $fetcher = Kurado::Worker::Fetcher->new(
        scoreboard => $sb,
        config_loader => $self->config_loader
    );

    my $timemage = Kurado::Worker::TimeMage->new(
        config_loader => $self->config_loader
    );

    $proclet->service(
        code => sub {
            local $Log::Minimal::PRINT = sub {
                my ( $time, $type, $message, $trace,$raw_message) = @_;
                warn "[$type] $message at $trace\n";
            };
            local $0 = 'Kurado::Worker::Updater';
            $updater->run();
        },
        worker => 1,
        tag => 'updater'
    );

    $proclet->service(
        code => sub {
            local $Log::Minimal::PRINT = sub {
                my ( $time, $type, $message, $trace,$raw_message) = @_;
                warn "[$type] $message at $trace\n";
            };
            local $0 = 'Kurado::Worker::Fetcher';
            $fetcher->run();
        },
        worker => 1,
        tag => 'fetcher'
    );

    $proclet->service(
        code => sub {
            local $Log::Minimal::PRINT = sub {
                my ( $time, $type, $message, $trace,$raw_message) = @_;
                warn "[$type] $message at $trace\n";
            };
            local $0 = 'Kurado::Worker::TimeMage';
            $timemage->run();
        },
        worker => 1,
        tag => 'timemage',
        every => '* * * * *', # every minutes
    );

    $proclet->service(
        code => sub {
            local $Log::Minimal::PRINT = sub {
                my ( $time, $type, $message, $trace,$raw_message) = @_;
                warn "[$type] $message at $trace\n";
            };
            local $0 = 'Kurado::Worker::KillZombie';
            while(1) {
                $sb->kill_zombie(30);
                select undef, undef, undef, 3;
            }
        },
        worker => 1,
        tag => 'watcher'
    );


    my $app = Kurado::Web->new(
        config_loader => $self->config_loader,
        root_dir => $self->root_dir,
    );
    my $psgi_app = builder {
        enable 'ReverseProxy';
        enable 'Static',
            path => qr!^/(?:(?:css|fonts|js|img)/|favicon\.ico$)!,
                root => $self->root_dir . '/public';
        $app->psgi;
    };

    $proclet->service(
        code => sub {
            local $Log::Minimal::PRINT = sub {
                my ( $time, $type, $message, $trace,$raw_message) = @_;
                warn "[$type] $message at $trace\n";
            };
            local $0 = 'Kurado:Web';
            my $loader = Plack::Loader->load(
                'Starlet',
                port => 5434,
                host => 0,
                max_workers => $self->config_loader->config->web_worker,
            );
            $loader->run($psgi_app);
        },
        tag => 'web',
    );

    $proclet->run;
}

1;

