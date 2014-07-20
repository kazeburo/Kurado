package Kurado::ConfigLoader;

use strict;
use warnings;
use utf8;
use YAML::XS qw//;
use JSON::XS;
use File::Spec;
use Mouse;
use Unicode::EastAsianWidth;

use Kurado::Config;
use Kurado::Object::Host;
use Kurado::Object::Roll;
use Kurado::Object::Plugin;
use Kurado::Plugin::Compile;

has 'path' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

__PACKAGE__->meta->make_immutable();


sub yaml_head {
    my $ref = shift;
    my $dump = YAML::XS::Dump($ref);
    chomp($dump);
    my @dump = split /\n/, $dump;
    join("\n", map { "> $_"} splice(@dump,0,8), (@dump > 8 ? "..." : ""))."\n";
}

sub BUILD {
    my ($self) = @_;
    $self->{_roll_cache} = {};
    $self->{load_plugins} = {};
    $self->{service_hosts} = {};
    $self->parse_file();
}

sub parse_file {
    my ($self) = @_;
    my $path = $self->{path};
    my @configs = eval {
        YAML::XS::LoadFile($path);
    };
    die "Failed to load $path: $@" if $@;
    
    for ( @configs ) {
        if ( ! ref $_ || ref $_ ne "HASH" ) {
            die "config shuold be HASH(or dictionary):\n" . yaml_head($_); 
        }
    }

    my $main_config = shift @configs;
    $self->parse_main_config($main_config);

    $self->{services} = {};
    for my $service_config ( @configs ) {
        $self->parse_service_config($service_config);
    }
}

sub parse_main_config {
    my ($self, $config) = @_;

    my $main_config = $config->{config};
    die "There is no 'config' in:\n".yaml_head($config) unless $main_config;
    eval {
        $self->{config} = Kurado::Config->load($main_config, $self->{path});
    };
    die "failed to config: $@\n===\n".yaml_head($config) if $@;

    $self->{metrics_config} = $config->{metrics_config};
    $self->{metrics_config} ||= {};
    die "metrics_config should be HASH(or dictionary)\n".yaml_head($self->{metrics_config})
        if ! ref $self->{metrics_config} || ! ref $self->{metrics_config} eq 'HASH';
}

sub parse_service_config {
    my ($self,$config) = @_;
    my $service = $config->{service};
    die "There is no 'service' in:\n".yaml_head($config) unless $service;
    die "found duplicated service '$service'".yaml_head($config) if exists $self->{services}->{$service};
    my $servers_config = $config->{servers};
    $servers_config ||= [];
    die "metrics_config should be Array\n".yaml_head($servers_config)
        if ! ref $servers_config || ! ref $servers_config eq 'ARRAY';
    my @sections;
    my %labels;
    for my $server_config ( @$servers_config ) {
        my $roll = $server_config->{roll}
            or die "cannot find roll in service:$service servers:".yaml_head($server_config);
        my $hosts = $server_config->{hosts} || [];
        my $label = $server_config->{label} // '';

        # lebel の2重チェック
        if ( $label ) {
            die "found duplicated label '$label'".yaml_head($config) if exists $labels{$label};
        }

        my @hosts;
        for my $host_line ( @$hosts ) {
            my $host = eval {
                $self->parse_host( $host_line, $roll, $service );
            };
            die "$@".yaml_head($config) if $@;
            $self->{service_hosts}{$service}++;
            push @hosts, $host;
        }
        
        if ( @sections && !$label ) {
            push @{$sections[-1]->{hosts}}, @hosts;
            next;
        }

        push @sections, {
            label => $label,
            hosts => \@hosts,
        };
        $labels{$label} = 1;
    }

    $self->{services}->{$service} = \@sections;
}

sub parse_host {
    my ($self, $line, $roll_name, $service) = @_;

    my ( $address, $hostname, $comments )  = split /\s+/, $line, 3;
    die "cannot find address in '$line'\n" unless $address;
    $hostname //= $address;
    $comments //= "";
    die "duplicated host entry address $address in '$line'\n" if exists $self->{hosts}{$address};

    my $roll = $self->load_roll( $roll_name );
    $self->{hosts}{$address} =  Kurado::Object::Host->new(
        address => $address,
        hostname => $hostname,
        comments => $comments,
        roll => $roll_name,
        metrics_config => $roll->metrics_config,
        plugins => $roll->plugins,
        service => $service
    );
    $self->{hosts}{$address};
}

sub load_roll {
    my ($self, $roll_name) = @_;
    # cache
    return $self->{_roll_cache}{$roll_name} if $self->{_roll_cache}{$roll_name};
    my $path = File::Spec->catfile($self->config->rolls_dir, $roll_name);
    my ($roll_config) = eval {
        YAML::XS::LoadFile($path);
    };
    die "Failed to load roll $path: $@" if $@;
    if ( ! ref $roll_config || ref $roll_config ne "HASH" ) {
        die "roll config shuold be HASH(or dictionary):\n" . yaml_head($roll_config); 
    }
    my $metrics_config = $self->merge_metrics_config($roll_config->{metrics_config} || {});
    my @plugins;
    for ( @{$roll_config->{metrics} || []} ) {
        push @plugins, $self->parse_plugin($_);
    }    
    
    $self->{_roll_cache}{$roll_name} = Kurado::Object::Roll->new(
        metrics_config => $metrics_config,
        plugins => \@plugins
    );    
    $self->{_roll_cache}{$roll_name};
}

sub parse_plugin {
    my ($self, $line) = @_;
    my ( $plugin, @arguments )  = split /:/, $line;
    die "cannot find plugin name: in '$line'\n" unless $plugin;

    # compile plugin
    my $pc = Kurado::Plugin::Compile->new(config=>$self->config);
    my @loaded_plugins;
    for my $type (qw/view fetch/) {
        my $compiled = eval {
            $pc->compile(
                plugin => $plugin,
                type => $type,
            );
        };
        die "failed load plugin plugin:$plugin,type:$type $@\n" if $@;
        push @loaded_plugins, $type if $compiled;
    }
    die "Could not find plugin '$plugin'\n" if @loaded_plugins == 0;
    $self->{load_plugins}{$plugin} = \@loaded_plugins;
    return Kurado::Object::Plugin->new(
        plugin => $plugin,
        arguments => \@arguments,
    );
}

sub config {
    $_[0]->{config};
}

sub metrics_config {
    $_[0]->{metrics_config};
}

my $_JSON = JSON::XS->new->utf8;
sub merge_metrics_config {
    my ($self,$ref) = @_;
    $_JSON->decode($_JSON->encode({
        %{$self->{metrics_config}},
        %$ref
    }));
}

sub services {
    $_[0]->{services};
}

sub sorted_services {
    my $self = shift;
    [
        map {{
            service => $_,
            sections => $self->services->{$_},
            host_num => $self->{service_hosts}{$_},
        }} sort { lc($a) cmp lc($b) } keys %{$self->services}
    ];
}

sub host_by_address {
    my ($self,$address) = @_;
    return unless exists $self->{hosts}{$address};
    $self->{hosts}{$address};
}

sub plugins {
    my $self = shift;
    [ keys %{$self->{load_plugins}} ];
}

sub dump {
    my $self = shift;
    +{
        config => $self->config->dump,
        metrics_config => $self->metrics_config,
        services => $self->sorted_services,
    }
}

sub zlength {
    my $str = shift;
    my $width = 0;
    while ($str =~ m/(?:(\p{InFullwidth}+)|(\p{InHalfwidth}+))/go) {
        $width += ($1 ? length($1) * 2 : length($2));
    }
    $width;
}

sub statistics {
    my $self = shift;
    $self->sorted_services;
    my ($maxlen) = sort { $b <=> $a } map { zlength($_) } keys %{$self->services};

    $maxlen += 2;
    $maxlen = 50 if $maxlen < 50;
    my $body = "# REGISTERED HOSTS\n";
    $body .= "-". "-"x$maxlen . "+" ."-------\n";
    $body .= " SERVICE" . (" "x($maxlen-7)) . "| HOSTS \n";
    $body .= "-". "-"x$maxlen . "+" ."-------\n";
    for my $service (@{$self->sorted_services}) {
        $body .= " " . $service->{service} . (" "x($maxlen - zlength($service->{service}))) . '| ' . sprintf('% 5d',$service->{host_num}) . " \n"
    }
    $body .= "-"."-"x$maxlen . "+" ."-------\n";

    $body .= "\n# LOADED PLUGINS\n";

    $body .= " PLUGIN" . (" "x($maxlen-6)) . "|  TYPE \n";
    $body .= "-". "-"x$maxlen . "+" ."-------\n";
    for my $load_plugin (keys %{$self->{load_plugins}}) {
        for my $type ( @{$self->{load_plugins}{$load_plugin}} ) {
        $body .= " "
            . $load_plugin
            . (" "x($maxlen - zlength($load_plugin)))
            . '| '
            . sprintf('% 5s',$type) . " \n"
        }
    }
    $body .= "-"."-"x$maxlen . "+" ."-------\n";

    return "$body\n";
}

1;

