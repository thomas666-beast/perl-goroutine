package Goroutine;
use strict;
use warnings;
use Exporter 'import';
use IO::Handle;
use POSIX ();
use Goroutine::Chan;

our $VERSION = '0.01';
our @EXPORT  = qw(chan go wait_all);
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

1;
