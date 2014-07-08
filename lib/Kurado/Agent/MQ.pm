package Kurado::Agent::MQ;

use strict;
use warnings;
use utf8;
use Net::MQTT::Constants;
use Net::MQTT::Message;
use POSIX qw(EINTR EAGAIN EWOULDBLOCK :sys_wait_h);
use IO::Socket qw(:crlf IPPROTO_TCP TCP_NODELAY);
use IO::Socket::INET;
use IO::Select;

our $READ_BYTES = 16 * 1024;

sub new {
    my $class = shift;
    my %args = ref $_ ? %{$_[0]} : @_;
    %args = (
        server => '127.0.0.1:1883',
        keep_alive_timer => 180,
        timeout => 30,
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
    my $socket = IO::Socket::INET->new(
        PeerAddr => $self->{server},
        Timeout => $self->{timeout},
    ) or die "Socket connect failed: $!";
    $socket->blocking(0);
    $socket->setsockopt(IPPROTO_TCP, TCP_NODELAY, 1)
        or die "setsockopt(TCP_NODELAY) failed:$!";
    $self->{sock} = $socket;

    # on connect
    my $msg = Net::MQTT::Message->new(
        message_type => MQTT_CONNECT,
        keep_alive_timer => $self->{keep_alive_timer}
    );
    $msg = $msg->bytes;
    $self->write_all($msg) or die "Failed to send MQTT_CONNECT\n";

    # conn-ack
    my $buf = '';
    while (1) {
        my $mqtt = Net::MQTT::Message->new_from_bytes($buf, 1);
        last if defined $mqtt;
        $self->read_timeout(\$buf, $READ_BYTES, length $buf)
            or die "No ConnAck\n";
    }

    # ping 
    $self->{next_ping} = time + $self->{keep_alive_timer};
    $self->{got_ping_response} = 1;

    $socket;
}

sub send_message {
    my $self = shift;
    my $msg = Net::MQTT::Message->new(@_);
    $msg = $msg->bytes;
    $self->write_all($msg);
}

sub read_message {
    my $self = shift;
    $self->{sockbuf} = '';
    while (1) {
        my $mqtt = Net::MQTT::Message->new_from_bytes($self->{sockbuf}, 1);
        return $mqtt if (defined $mqtt);
        $self->read_timeout(\$self->{sockbuf}, $READ_BYTES, length $self->{sockbuf})
            or return;
    }
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
                # mqtt socker
                my $msg = $self->read_message();
                if ( ref $msg && $msg->message_type == MQTT_PINGRESP) {
                    $self->{got_ping_response} = 1;
                }
            }
            else {
                my $msg = $sub->($rs);
                $self->send_message(
                    message_type => MQTT_PUBLISH,
                    retain => 0,
                    topic => $msg->[0],
                    message => $msg->[1],
                ) if ref $msg;
            }
        }
        if ( time >= $self->{next_ping} ) {
            die "Ping response timeout. maybe disconnected\n" unless $self->{got_ping_response};
            $self->{got_ping_response} = 0;
            $self->send_message(
                message_type => MQTT_PINGREQ,
            );            
            $self->{next_ping} = time + $self->{keep_alive_timer};
        }
    }
}

sub timetick_publisher {
    my ($self, $interval, $sub ) = @_;
    my $socket = $self->connect;

    my $next_tick = $interval + time;
    $next_tick = $next_tick - ($next_tick % $interval);

    my $s = IO::Select->new($socket);
    $self->{stop_loop} = 0;
    while ( !$self->{stop_loop} ) {
        my $read_timeout = $next_tick > $self->{next_ping} ? $self->{next_ping} : $next_tick;
        $read_timeout = $read_timeout - time;
        my @can_read = $s->can_read($read_timeout);
        for my $rs (@can_read) {
            if ( fileno($rs) == fileno($socket) ) {
                # mqtt socker
                my $msg = $self->read_message();
                if ( ref $msg && $msg->message_type == MQTT_PINGRESP) {
                    $self->{got_ping_response} = 1;
                }
            }
        }
        # ping
        if ( time >= $self->{next_ping} ) {
            die "Ping response timeout. maybe disconnected\n" unless $self->{got_ping_response};
            $self->{got_ping_response} = 0;
            $self->send_message(
                message_type => MQTT_PINGREQ,
            );            
            $self->{next_ping} = time + $self->{keep_alive_timer};
        }
        # app
        if ( time >= $next_tick  ) {
            $next_tick = time + $interval;
            my $msg = $sub->();
            $self->send_message(
                message_type => MQTT_PUBLISH,
                retain => 0,
                topic => $msg->[0],
                message => $msg->[1],
            ) if ref $msg;
        }
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

