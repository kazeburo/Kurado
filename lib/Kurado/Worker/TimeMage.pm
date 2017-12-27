package Kurado::Worker::TimeMage;

use strict;
use warnings;
use Mouse;
use Parallel::Prefork;
use Log::Minimal;

use Kurado::MQ;

has 'config_loader' => (
    is => 'ro',
    isa => 'Kurado::ConfigLoader',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub run {
    my $self = shift;
    sleep 3; # 0秒を避ける
    my $hosts = $self->config_loader->hosts;
    my $mq = Kurado::MQ->new( server => $self->config_loader->config->redis );
    for my $adrs ( keys %$hosts ) {
        my $host = $hosts->{$adrs};
        for my $plugin ( @{$host->plugins} ) {
            next unless $self->config_loader->has_fetch_plugin($plugin->plugin);
            my $msg = $host->address ."\t". $plugin->plugin_identifier;
            debugf("enqueue %s", $msg);
            $mq->enqueue('kurado-fetch',$msg);
        }
    }
}


1;





