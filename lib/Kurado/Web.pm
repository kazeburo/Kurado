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
            config_loader => $self->config_loader,
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
    my $time = time;
    $time = $time - ($time%(60*15));
    my $result = $c->req->validator([
        'term' => {
            default => 'day',
            rule => [
                [['CHOICE',qw/month day 3days 8hours 4hours 1hour custom/],'invalid drawing term'],
            ],
        },
        'from' => {
            default => timestr($time-3600*32),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid From datetime'],
            ],
        },
        'to' => {
            default => timestr($time),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid To datetime'],
            ],
        },
    ]);
    if ( $result->has_error ) {
        $c->halt(400,join("\n",@{$result->messages}));
    }

    my $s_width=400; 
    my $m_width=500; 
    my $l_width=1100;
    my %terms = (
        day => [{term=>"day",width=>$m_width},{term=>"week",width=>$m_width}],
        month => [{term=>"day",width=>400},{term=>"week",width=>$s_width},{term=>"month",width=>$s_width},{term=>"year",width=>$s_width}],
        "3days" => [{term=>"3days",width=>$l_width}],
        "8hours" => [{term=>"8hours",width=>$l_width}],
        "4hours" => [{term=>"4hours",width=>$l_width}],
        "1hour" => [{term=>"1hour",width=>$l_width}],
        custom => [{term=>"custom",width=>$l_width}],
    );
    my $term = $result->valid('term');
    my $terms = $terms{$term};
    my $plugin_identifier = $c->req->param('plugin_identifier');

    my $merge_nav = sub {
        my ($te, $pl) = @_;
        my @params = (address => $c->stash->{host}->address);
        if ( $te eq 'custom' ) {
            push @params, 'from', $result->valid('from');
            push @params, 'to', $result->valid('to');
        }
        push @params, 'term', $te if $te && $te ne 'day';
        push @params, 'plugin_identifier', $pl if $pl;
        return [@params];
    };

    $c->render('server.tx', { terms => $terms, term => $term, plugin_identifier => $plugin_identifier, result => $result, merge_nav => $merge_nav });
};


get '/servers' => [qw/fill_config/] => sub {
    my ($self, $c)  = @_;
    my $time = time;
    $time = $time - ($time%(60*15));
    my $result = $c->req->validator([
        'term' => {
            default => 'day',
            rule => [
                [['CHOICE',qw/day week month year 3days 8hours 4hours 1hour custom/],'invalid drawing term'],
            ],
        },
        'from' => {
            default => timestr($time-3600*32),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid From datetime'],
            ],
        },
        'to' => {
            default => timestr($time),
            rule => [
                [sub{ HTTP::Date::str2time($_[1]) }, 'invalid To datetime'],
            ],
        },
        '@address' => {
            rule => [
                [['@SELECTED_NUM',1,500],'# of address should be in 1 to 500'],
                ['@SELECTED_UNIQ','found duplicated address'],
            ],
        },
    ]);
    if ( $result->has_error ) {
        $c->halt(400,join("\n",@{$result->messages}));
    }

    my @address = $result->valid('address');

    # 2 = critical
    # 1 = warn
    # 0 = ok

    my @hosts;
    my %uniq_plugins;
    my @uniq_plugins;
    for my $address ( @address ) {
        my $host = $self->config_loader->host_by_address($address);
        if ( !$host ) {
            next;
        }
        for my $plugin (@{$host->plugins}) {
            next if $uniq_plugins{$plugin->plugin_identifier};
            push @uniq_plugins, $plugin->plugin_identifier;
            $uniq_plugins{$plugin->plugin_identifier} = 1;
        }
        push @hosts, Kurado::Host->new(
            config_loader => $self->config_loader,
            host => $host,
        );
    }

    my $s_width=420; 
    my %terms = (
        day => [{term=>"day",width=>$s_width}],
        week => [{term=>"week",width=>$s_width}],
        month => [{term=>"month",width=>$s_width}],
        year => [{term=>"year",width=>$s_width}],
        "3days" => [{term=>"3days",width=>$s_width}],
        "8hours" => [{term=>"8hours",width=>$s_width}],
        "4hours" => [{term=>"4hours",width=>$s_width}],
        "1hour" => [{term=>"1hour",width=>$s_width}],
        custom => [{term=>"custom",width=>$s_width}],
    );
    my $term = $result->valid('term');
    my $terms = $terms{$term};
    my $plugin_identifier = $c->req->param('plugin_identifier');
    my @host_query = map { ("address",$_->address) } @hosts;
    my $merge_nav = sub {
        my ($te, $pl, $adr) = @_;
        my @params;
        if ( $te eq 'custom' ) {
            push @params, 'from', $result->valid('from');
            push @params, 'to', $result->valid('to');
        }
        push @params, 'term', $te if $te && $te ne 'day';
        push @params, 'plugin_identifier', $pl if $pl;
        return [address => $adr, @params] if $adr;
        return [@host_query, @params];
    };

    $c->render('servers.tx', {
        terms => $terms,
        term => $term,
        plugin_identifier => $plugin_identifier,
        result => $result,
        hosts=>\@hosts,
        merge_nav => $merge_nav,
        uniq_plugins => \@uniq_plugins,
    });
};


sub timestr {
    my $time = shift;
    my @lt = localtime($time);
    sprintf('%04d-%02d-%02d %02d:%02d:%02d',$lt[5]+1900,$lt[4]+1,@lt[3,2,1,0]);
    
}

get '/graph' => [qw/fill_config get_server get_plugin/] => sub {
    my ($self, $c)  = @_;
    my $result = $c->req->validator([
        'term' => {
            default => 'day',
            rule => [
                [['CHOICE',qw/year month week day 3days 8hours 4hours 1hour custom/],'invalid drawing term'],
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
            default => 460,
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
    eval {
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
    };
    if ($@) {
        $c->halt(500,$@);
    }
    return $c->res;
};

router [qw/GET POST/] => '/api/host-status' => [qw/fill_config/] => sub {
    my ($self, $c)  = @_;
    my $result = $c->req->validator([
        '@address' => {
            rule => [
                [['@SELECTED_NUM',1,500],'# of address should be in 1 to 500'],
                ['@SELECTED_UNIQ','found duplicated address'],
            ],
        },
    ]);
    if ( $result->has_error ) {
        $c->halt(400,join("\n",@{$result->messages}));
    }
    my @address = $result->valid('address');

    # 2 = critical
    # 1 = warn
    # 0 = ok

    my %result;
    for my $address ( @address ) {
        my $host = $self->config_loader->host_by_address($address);
        if ( !$host ) {
            $result{$address} = 2;
            next;
        }
        my $host_obj = Kurado::Host->new(
            config_loader => $self->config_loader,
            host => $host,
        );
        $result{$address} = $host_obj->status;
    }
    $c->render_json(\%result);
};

get '/api/servers' => [qw/fill_config/] => sub {
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
    else {
        @services = @{$self->config_loader->sorted_services};
    }

    my $servers='';
    for my $service ( @services ) {
        for my $section ( @{$service->{sections}} ) {
            for my $host ( @{$section->{hosts}} ) {
                $servers .= sprintf("%s %s %s\n",$host->{address},$host->{hostname},$host->{comments});
            }
        }
    }
    $c->res->content_type('text/plain');
    $c->res->body($servers);
    $c->res;
};


1;


