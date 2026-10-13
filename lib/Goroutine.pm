package Goroutine;
use strict;
use warnings;
use Exporter 'import';
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
    my $pid = fork() // die "fork failed: $!";
    if ($pid == 0) {                # we are the child
        @CHILDREN = ();             # the child must not wait for its siblings
        my $ok = eval { $code->(@args); 1 };
        warn "goroutine $$ panicked: $@" unless $ok;
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
