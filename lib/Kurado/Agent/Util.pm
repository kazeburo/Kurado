package Kurado::Agent::Util;

use strict;
use warnings;
use utf8;
use base qw/Exporter/;
use POSIX ":sys_wait_h";

our @EXPORT = qw/cap_cmd to_byte supervisor/;

sub cap_cmd {
    my ($cmdref) = @_;
    pipe my $logrh, my $logwh
        or die "Died: failed to create pipe:$!\n";
    my $pid = fork;
    if ( ! defined $pid ) {
        die "Died: fork failed: $!\n";
    } 

    elsif ( $pid == 0 ) {
        #child
        close $logrh;
        open STDOUT, '>&', $logwh
            or die "Died: failed to redirect STDOUT\n";
        close $logwh;
        exec @$cmdref;
        die "Died: exec failed: $!\n";
    }
    close $logwh;
    my $result;
    while(<$logrh>){
        $result .= $_;
    }
    close $logrh;
    while (wait == -1) {}
    my $exit_code = $?;
    $exit_code = $exit_code >> 8;
    return ($result, $exit_code);
}

# Convert string like a "123 KB" into as byte
sub to_byte {
    my $s = shift;
    my $b = 0;

    ($s) = ($s =~ /^\s*(.+?)\s*$/); # trim

    if ($s =~ /^[0-9]+$/) {
        $b = $s;
    } elsif ($s =~ /^([0-9]+)\s*([a-zA-Z]+)$/) {
        $b = $1;
        my $u = lc $2;
        if ($u eq 'kb') {
            $b = $b * 1024;
        } elsif ($u eq 'mb') {
            $b = $b * 1024 * 1024;
        } elsif ($u eq 'gb') {
            $b = $b * 1024 * 1024 * 1024;
        } elsif ($u eq 'tb') {
            $b = $b * 1024 * 1024 * 1024 * 1024;
        } else {
            warnf("Unknown unit: %s", $u);
        }
    } else {
        warnf("Failed to convert into as byte: %s", $s);
    }

    return $b;
}

sub supervisor {
    my $cb = shift;
    my $opts = @_ == 1 ? shift : { @_ };
    $opts->{interval} ||= 3;

    my @signals_received;
    $SIG{$_} = sub {
        warn "sig:$_[0]";
        push @signals_received, $_[0];
    } for (qw/INT TERM HUP/);
    $SIG{PIPE} = 'IGNORE';
    $SIG{CHLD} = sub {};

    my $pid;
    my $initial=1;
    while (1) {
        if ( $pid ) {
            my $kid = waitpid($pid, WNOHANG);
            if ( $kid == -1 ) {
                $pid = undef;
            }
            elsif ( $kid ) {
                my $status = $? >> 8;
                warn "[supervisor] process $pid died with status:$status\n" unless @signals_received;
                $pid = undef;
            }
        }

        if ( grep { $_ ne 'HUP' } @signals_received ) {
            warn "[supervisor] signals_received: " . join(",",  @signals_received) . "\n";
            last;
        }

        while ( my $signals_received = shift @signals_received ) {
            if ( $pid && $signals_received eq 'HUP' ) {
                warn "[supervisor] HUP signal received, send TERM to $pid\n";
                kill 'TERM', $pid;
                waitpid( $pid, 0 );
                $pid = undef;
            }
        }

        select( undef, undef, undef, $pid ? 60 : $opts->{interval}) if ! $initial;
        $initial=0;

        if ( ! defined $pid ) {
            $pid = fork();
            die "failed fork: $!\n" unless defined $pid;
            next if $pid; #main process

            # child process
            $SIG{$_} = 'DEFAULT' for (qw/INT TERM HUP CHLD/);

            $cb->();
            POSIX::_exit(255);
        }
    }  

    if ( $pid ) {
        kill 'TERM', $pid;
        waitpid( $pid, 0 );
    }
}


1;

