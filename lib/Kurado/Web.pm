package Kurado::Web;

use strict;
use warnings;
use utf8;
use 5.10.0;

use Kossy;
use Kurado::Host;

our $VERSION = '0.01';

sub config_loader {
    $_[0]->{config_loader}
}

filter 'fill_config' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        $c->stash->{config_loader} = $self->config_loader;
        $app->($self, $c);
    };
};

filter 'get_server' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        my $address = $c->req->param('address');
        $c->halt('400') unless $address;
        my $host = $self->config_loader->host_by_address($address);
        $c->halt('404') unless $host;        
        $c->stash->{host} = Kurado::Host->new(
            config => $self->config_loader->config,
            host => $host,
        );
        $app->($self, $c);
    };
};


get '/' => [qw/fill_config/] => sub {
    my ($self, $c)  = @_;

    my @services;
    if ( my $service = $c->req->param('service') ) {
        $c->halt(404) unless exists $self->config_loader->services->{$service};
        my $sections = $self->config_loader->services->{$service};
        push @services, {
            service => $service,
            sections => $sections
        };
    }

    $c->render('index.tx', {
        services => @services ? \@services : $self->config_loader->sorted_services,
    });
};

get '/server' => [qw/fill_config get_server/] => sub {
    my ($self, $c)  = @_;
    $c->render('server.tx', {
    });
};

1;


