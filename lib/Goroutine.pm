package Goroutine;
use strict;
use warnings;
use Exporter 'import';
use IO::Handle;
use IO::Select;
use POSIX ();
use Goroutine::Chan;

our $VERSION = '0.01';
our @EXPORT  = qw(chan go wait_all gselect);
my @CHILDREN;

sub chan {
    return Goroutine::Chan->new;
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
