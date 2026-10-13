package Parallel::Goroutine;
use strict;
use warnings;
use Exporter 'import';
use IO::Handle;
use IO::Select;
use POSIX ();
use Parallel::Goroutine::Chan;

our $VERSION = '0.01';
our @EXPORT  = qw(chan go wait_all gselect);
my @CHILDREN;

sub chan {
    return Parallel::Goroutine::Chan->new;
}

sub go(&;@) {
    my ($code, @args) = @_;
    STDOUT->flush;                  # don't let the child inherit unwritten output
    STDERR->flush;
    my $pid = fork() // die "fork failed: $!";

    if ($pid == 0) {                # we are the child
        @CHILDREN = ();             # the child must not wait for its siblings
        local $SIG{PIPE} = 'IGNORE';  # a dead reader must not kill us
        my $ok = eval { $code->(@args); 1 };
        warn "goroutine $$ panicked: $@" unless $ok;
        STDOUT->flush;              # _exit skips the normal flush
        STDERR->flush;
        POSIX::_exit($ok ? 0 : 1);
    }
    push @CHILDREN, $pid;           # we are the parent: remember the child

    return $pid;
}

sub wait_all {
    my $failed = 0;
    for my $pid (splice @CHILDREN) {
        waitpid($pid, 0);
        $failed++ if $? != 0;
    }
    return $failed;
}

sub gselect {
    my ($timeout, @chans) = @_;

    my $select = IO::Select->new;
    for my $chan (@chans) {
        $select->add($chan->{r});
    }

    my @ready = $select->can_read($timeout) or return;
    my $fh    = $ready[0];
    my $chan  = ${*$fh}{go_chan};
    my ($value, $ok) = $chan->recv;
    return ($chan, $value, $ok);
}

1;

__END__

=head1 NAME

Parallel::Goroutine - Go-style goroutines and channels for Perl

=head1 SYNOPSIS

    use Parallel::Goroutine;

    my $jobs    = chan();
    my $results = chan();

    # start three workers
    for (1 .. 3) {
        go {
            while (1) {
                my ($job, $ok) = $jobs->recv;
                last unless $ok;            # the channel was closed
                $results->send($job * 2);
            }
        };
    }

    $jobs->send($_) for 1 .. 10;
    $jobs->close;

    my @answers = map { scalar $results->recv } 1 .. 10;
    wait_all();

=head1 DESCRIPTION

This module brings the two core ideas of Go's concurrency model to Perl:
I<goroutines> that run independently, and I<channels> that carry values
between them.

A goroutine is started with C<go>. Each goroutine is a separate process
created with C<fork>, so goroutines run in parallel on all CPU cores.
Because they are processes, goroutines do B<not> share variables. They
communicate only by sending values through channels, and every value sent
through a channel is copied. Hashes, arrays and nested data structures can
be sent. Code references and filehandles cannot.

A channel is a pipe with a small protocol on top. It is safe to use with
several senders and several receivers at the same time. A channel holds
roughly 64KB of data; when it is full, C<send> waits until a receiver has
made room.

Because it relies on C<fork>, C<flock> and pipes, this module works on
Unix-like systems only. Each goroutine is a whole process, so use tens or
hundreds of goroutines, not thousands.

=head1 FUNCTIONS

All four functions are exported by default.

=head2 go BLOCK LIST

    my $pid = go { ... } @args;

Runs BLOCK in a new goroutine and returns the process ID of that goroutine
at once, without waiting for it. The elements of LIST are passed to BLOCK in
C<@_>.

If BLOCK dies, the goroutine prints C<goroutine PID panicked: MESSAGE> to
C<STDERR> and exits with status 1. The calling process is not affected;
L</wait_all> reports the failure.

Output buffers of C<STDOUT> and C<STDERR> are flushed before the goroutine
starts and again when it ends, so text printed by a goroutine is neither lost
nor printed twice.

A goroutine is a copy of the calling process. It can use channels that
existed when it was started, so create your channels before calling C<go>.

=head2 chan

    my $ch = chan();

Creates a new channel and returns a L<Parallel::Goroutine::Chan> object. See
that module for C<send>, C<recv>, C<close> and C<each>.

=head2 wait_all

    my $failed = wait_all();

Waits until every goroutine started by the calling process has finished.
Returns the number of goroutines that failed (died or exited with a non-zero
status), so a return value of 0 means that everything went well. It also
returns 0 when there was nothing to wait for.

Call it before your program ends, so that no finished goroutine is left behind
as a zombie process. A goroutine that starts goroutines of its own should
call C<wait_all> itself.

=head2 gselect TIMEOUT, CHANNELS

    if (my ($ch, $value, $ok) = gselect(2, $one, $two)) {
        print "got $value\n";
    }
    else {
        print "nothing arrived within 2 seconds\n";
    }

Waits until one of the given channels has a message, receives it, and returns
three values: the channel, the value, and the C<ok> flag. As with C<recv>, the
flag is false when the channel has been closed and has no more messages.

TIMEOUT is in seconds and may be fractional. If no message arrives in time,
C<gselect> returns an empty list. If TIMEOUT is C<undef>, it waits for as long
as it takes.

If several goroutines receive from the same channel, another one may take the
message first. C<gselect> then waits for the next message, even beyond
TIMEOUT.

=cut
