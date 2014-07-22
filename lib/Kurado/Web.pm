package Kurado::Web;

use strict;
use warnings;
use utf8;
use 5.10.0;
use Kossy;
use Log::Minimal;
use Kurado::Host;
use Kurado::Object::Plugin;


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

filter 'get_plugin' => sub {
    my ($app) = @_;
    sub {
        my ($self, $c) = @_;
        my $plugin = $c->req->param('plugin_identifier');
        $c->halt('400') unless $plugin;
        $c->stash->{plugin} = Kurado::Object::Plugin->new_from_identifier($plugin);
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
    $c->render('server.tx', {});
};

sub timestr {
    my $time = shift;
    my @lt = localtime($time);
    sprintf('%04d/%02d/%02d %02d:%02d:%02d',$lt[5]+1900,$lt[4]+1,@lt[3,2,1,0]);
    
}

get '/graph' => [qw/fill_config get_server get_plugin/] => sub {
    my ($self, $c)  = @_;
    my $result = $c->req->validator([
        'term' => {
            default => 'day',
            rule => [
                [['CHOICE',qw/year month week day 3days 8hours 1hour custom/],'invalid drawing term'],
            ],
        },
        'from' => {
            default => timestr(time-3600*32),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid From datetime'],
            ],
        },
        'to' => {
            default => timestr(time),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid To datetime'],
            ],
        },
        'width' => {
            default => 480,
            rule => [
                ['NATURAL','invalid width'],
            ],
        },
        'graph' => {
            rule => [
                ['NOT_NULL', 'missing graph key'],
            ],
        }
    ]);
    if ( $result->has_error ) {
        $c->halt(400,join("\n",@{$result->messages}));
    }
    
    my ($img,$data) = $c->stash->{host}->metrics_graph(
        plugin => $c->stash->{plugin},
        graph => $result->valid('graph'),
        term => $result->valid('term'),
        from => $result->valid('from'),
        to => $result->valid('to'),
        width => $result->valid('width'),
    );
    $c->res->content_type('text/plain');
    $c->res->body($img);
    return $c->res;
};

1;


