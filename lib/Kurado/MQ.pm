package Kurado::MQ;

use strict;
use warnings;
use POSIX qw(EINTR EAGAIN EWOULDBLOCK :sys_wait_h);
use IO::Socket qw(:crlf IPPROTO_TCP TCP_NODELAY);
use IO::Socket::INET;
use IO::Select;
use Encode;

our $READ_BYTES = 16 * 1024;

sub new {
    my $class = shift;
    my %args = ref $_ ? %{$_[0]} : @_;
    %args = (
        server => '127.0.0.1:6379',
        keep_alive_timer => 30,
        timeout => 10,
        %args,
    );
    my $server = shift;
    my $self = bless \%args, $class;
    $self->connect;
    $self;
}

sub connect {
    my $self = shift;
    return $self->{sock} if $self->{sock};
    $self->{sockbuf} = '';
    $self->{message_id} = 1;
    my $socket = IO::Socket::INET->new(
        PeerAddr => $self->{server},
        Timeout => $self->{timeout},
    ) or die "Socket connect failed: $!";
    $socket->blocking(0);
    $socket->setsockopt(IPPROTO_TCP, TCP_NODELAY, 1)
        or die "setsockopt(TCP_NODELAY) failed:$!";
    $self->{sock} = $socket;

    # ping 
    $self->{next_ping} = time + $self->{keep_alive_timer};

    $socket;
}

sub send_message {
    my $self = shift;
    my @msg = @_;
    return unless @msg;
    my $msg = '*'.scalar(@msg).$CRLF;
    for my $m (@msg) {
        $m = Encode::encode_utf8($m);
        $msg .= '$'.length($m).$CRLF;
        $msg .= $m.$CRLF;
    }
    $self->write_all($msg);
}

sub read_message {
    my $self = shift;
    $self->{sockbuf} = '';
    while (1) {
        my $msg = $self->parse_reply($self->{sockbuf});
        return $msg if (defined $msg);
        $self->read_timeout(\$self->{sockbuf}, $READ_BYTES, length $self->{sockbuf})
            or return;
    }
}

sub parse_reply {
    my $self = shift;
    my $buf = shift;
    return unless $buf =~ m/$CRLF$/sm;
    $buf =~ s/$CRLF$//sm;

    my $s = substr($buf,0,1,"");
    if ( $s eq '+' ) {
        # 1 line reply
        return Kurado::Agent::MQ::Msg->new($s);
    }
    elsif ( $s eq '-' ) {
        # error
        # -ERR unknown command 'a'
        return Kurado::Agent::MQ::Msg->new(undef,$s);
    }
    elsif ( $s eq ':' ) {
        # numeric
        # :1404956783
        return Kurado::Agent::MQ::Msg->new($s);
    }
    elsif ( $s eq '$' ) {
        # bulk
        # C: get mykey
        # S: $3
        # S: foo
        my @msg = split /$CRLF/,$buf, 2;
        return unless @msg == 2;
        if ( $msg[0] eq '-1' ) {
            return Kurado::Agent::MQ::Msg->new(undef);
        }
        return unless $msg[0] == length($msg[1]);
        return Kurado::Agent::MQ::Msg->new($msg[1]);
    }
    elsif ( $s eq '*' ) {
        # multibulk
        # *3
        # $3
        # foo
        # $-1
        # $3
        # baa
        #
        ## null list/timeout
        # *-1
        #

        my @msg = split /$CRLF/,$buf;
        my $n = shift @msg;
        return Kurado::Agent::MQ::Msg->new(undef) if $n eq '-1';
        my @res;
        while (my $k = shift @msg) {
            return unless $k =~ m!^\$(-?\d+)$!;
            my $length = $1;
            if ( $length eq '-1' ) {
                push @res, undef;
                next;
            }
            my $v = shift @msg;
            return unless length($v) == $length;
            push @res, $v;
        }
        return if @res != $n;
        return Kurado::Agent::MQ::Msg->new(\@res);
    }
    die "failed parse_reply\n";
}

sub watchfh_publisher {
    my ($self, $fh, $sub ) = @_;
    my $socket = $self->connect;
    my @fh = ref $fh eq 'ARRAY' ? @$fh : ($fh);
    my $s = IO::Select->new($socket, @fh);
    $self->{stop_loop} = 0;
    while ( !$self->{stop_loop} ) {
        my $read_timeout = $self->{next_ping} - time;
        my @can_read = $s->can_read($read_timeout);
        for my $rs (@can_read) {
            if ( fileno($rs) == fileno($socket) ) {
                # redis socket
                die "may be disconnected from server\n";
            }
            else {
                my $msg = $sub->($rs);
                if ( ref $msg ) {
                    $self->send_message(
                        'RPUSH', $msg->[0], $msg->[1]
                    ) or die "failed to send_message 'RPUSH': $!\n";
                    my $res = $self->read_message();
                    if ( !ref $res || !$res->success ) {
                        die "failed to push msg: ".$res->error."\n";
                    }
                }
            }
        }
        if ( time >= $self->{next_ping} ) {
            $self->send_message('PING') 
                or die "failed to send_message 'PING': $!\n";
            $self->read_message()
                or die "failed to read Pong. maybe disconnected from server\n";
            $self->{next_ping} = time + $self->{keep_alive_timer};
        }
    }
}

sub timetick_publisher {
    my ($self, $interval, $max_delay, $sub ) = @_;
    my $socket = $self->connect;

    my $next_tick = $interval + time;
    $next_tick = $next_tick - ($next_tick % $interval) + int(rand($max_delay));

    my $s = IO::Select->new($socket);
    $self->{stop_loop} = 0;
    while ( !$self->{stop_loop} ) {
        my $read_timeout = $next_tick > $self->{next_ping} ? $self->{next_ping} : $next_tick;
        $read_timeout = $read_timeout - time;
        if ( $s->can_read($read_timeout) ) {
            # redis socket
            die "may be disconnected from server\n";
        }
        # ping
        if ( time >= $self->{next_ping} ) {
            $self->send_message('PING') 
                or die "failed to send_message 'PING': $!\n";
            $self->read_message()
                or die "failed to read Pong. maybe disconnected from server\n";
            $self->{next_ping} = time + $self->{keep_alive_timer};
        }
        # app
        if ( time >= $next_tick  ) {
            $next_tick = time + $interval;
            my $msg = $sub->();
            if ( ref $msg ) {
                $self->send_message(
                    'RPUSH', $msg->[0], $msg->[1]
                ) or die "failed to send_message 'RPUSH': $!\n";
                my $res = $self->read_message();
                if ( !ref $res || !$res->success ) {
                    die "failed to push msg: ".$res->error."\n";
                }
            }
        }
    }
}

sub subscribe {
    my $self = shift;
    my %callbacks = @_;
    my $socket = $self->connect;

    my $queue_wait = int($self->{timeout}/2); # brocking time. half of timeout
    $queue_wait ||= 1;
    my @req = ('BRPOP');
    push @req, $_ for keys %callbacks;
    push @req, $queue_wait;

    my $s = IO::Select->new($socket);
    $self->{stop_loop} = 0;
    while ( !$self->{stop_loop} ) {
        $self->send_message(@req) 
            or die "failed to send_message 'BRPOP': $!\n";
        my $res = $self->read_message();
        if ( !ref $res || !$res->success ) {
            die "failed to pop msg: ".$res->error."\n";
        }
        if ( ! defined $res->message || ! ref $res->message ) {
            # timeout
            next;
        }
        my ($received_topic,$message) = @{$res->message};
        next unless exists $callbacks{$received_topic}; #??
        eval {
            $callbacks{$received_topic}->($received_topic,$message);
        };
        warn "[ERROR] $received_topic: $@\n" if $@;
    }
}


# returns (positive) number of bytes read, or undef if the socket is to be closed
sub read_timeout {
    my ($self, $buf, $len, $off, $timeout) = @_;
    $timeout ||= $self->{timeout};
    $self->do_io(undef, $buf, $len, $off, $timeout);
}

# returns (positive) number of bytes written, or undef if the socket is to be closed
sub write_timeout {
    my ($self, $buf, $len, $off, $timeout) = @_;
    $timeout ||= $self->{timeout};
    $self->do_io(1, $buf, $len, $off, $timeout);
}

# writes all data in buf and returns number of bytes written or undef if failed
sub write_all {
    my ($self, $buf, $timeout) = @_;
    $timeout ||= $self->{timeout};
    my $off = 0;
    while (my $len = length($buf) - $off) {
        my $ret = $self->write_timeout($buf, $len, $off, $timeout)
            or return;
        $off += $ret;
    }
    return length $buf;
}

# returns value returned by $cb, or undef on timeout or network error
sub do_io {
    my ($self, $is_write, $buf, $len, $off, $timeout) = @_;
    my $sock = $self->{sock};
    my $ret;
 DO_READWRITE:
    # try to do the IO
    if ($is_write) {
        $ret = syswrite $sock, $buf, $len, $off
            and return $ret;
    } else {
        $ret = sysread $sock, $$buf, $len, $off
            and return $ret;
    }
    unless ((! defined($ret)
                 && ($! == EINTR || $! == EAGAIN || $! == EWOULDBLOCK))) {
        die "cannot write/read mqtt socket\n";
        return;
    }
    # wait for data
 DO_SELECT:
    while (1) {
        my ($rfd, $wfd);
        my $efd = '';
        vec($efd, fileno($sock), 1) = 1;
        if ($is_write) {
            ($rfd, $wfd) = ('', $efd);
        } else {
            ($rfd, $wfd) = ($efd, '');
        }
        my $start_at = time;
        my $nfound = select($rfd, $wfd, $efd, $timeout);
        $timeout -= (time - $start_at);
        last if $nfound;
        return if $timeout <= 0;
    }
    goto DO_READWRITE;
}

1;

package Kurado::Agent::MQ::Msg;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $msg = shift;
    bless {
        msg => $msg, 
        (@_) ? (err => $_[0]) : (),
    }, $class;
}

sub error {
    my $self = shift;
    return $self->{err} if exists $self->{err};
    return;
}

sub success {
    my $self = shift;
    exists $self->{err} ? 0 : 1;
}

sub message {
    my $self = shift;
    return $self->{msg};
}


1;


