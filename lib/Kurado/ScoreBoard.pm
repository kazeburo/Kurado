package Kurado::ScoreBoard;

use strict;
use warnings;
use utf8;
use File::Temp qw/tempdir/;
use File::Path qw/remove_tree/;
use Parallel::Scoreboard;
use Mouse;
use Log::Minimal;

has 'config' => (
    is => 'ro',
    isa => 'Kurado::Config',
    required => 1
);

__PACKAGE__->meta->make_immutable();

sub BUILD {
    my $self = shift;
    $self->{scoreboard_dir} = tempdir( CLEANUP => 0, DIR => $self->config->data_dir );
    $self->{sb} = Parallel::Scoreboard->new(base_dir=>$self->{scoreboard_dir});
    $self->{pid} = $$;
}

sub DEMOLISH {
    my $self = shift;
    if ( $self->{pid} == $$ && $self->{scoreboard_dir}) {
        delete $self->{sb};
        remove_tree(delete $self->{scoreboard_dir});
    }
}

sub idle {
    my ($self,$caller) = @_;
    ($caller) = caller unless $caller;
    $self->{sb}->update(sprintf('%s %s %s',0,time,$caller));
}

sub busy {
    my $self = shift;
    my ($caller) = caller;
    $self->{sb}->update(sprintf('%s %s %s',1,time,$caller));
    return Kurado::ScoreBoard::Guard->new(sub { $self->idle($caller) }) if defined wantarray;
    1;
}

sub kill_zombie {
    my $self = shift;
    my $threshold = shift;
    $threshold ||= 30;
    my $stats = $self->{sb}->read_all();
    my $now = time ;
    for my $pid ( keys %$stats) {
        my($status,$time,$type) = split /\s+/, $stats->{$pid}, 3;
        if ( $status == 1 && $now - $time > $threshold ) {
            warnf 'kill zombie $type pid:%s', $type, $pid;
            kill 'TERM', $pid;
        }
    }
}

1;

package Kurado::ScoreBoard::Guard;

sub new {
    my $class = shift;
    my $cb = shift;
    bless { cb => $cb, pid => $$ }, $class;
}

sub DESTROY {
    my $self = shift;
    if ( defined $self->{pid} && $self->{pid} == $$ ) {
        $self->{cb}->();
    }
}

1;



