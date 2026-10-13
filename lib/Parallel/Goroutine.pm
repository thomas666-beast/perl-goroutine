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
    my %chan_for_fd;
    for my $chan (@chans) {
        $select->add($chan->{r});
        $chan_for_fd{ fileno $chan->{r} } = $chan;
    }

    my @ready = $select->can_read($timeout) or return;
    my $chan  = $chan_for_fd{ fileno $ready[0] };
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

=cut

