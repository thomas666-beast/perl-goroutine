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
        $code->(@args);
        POSIX::_exit(0);
    }
    push @CHILDREN, $pid;           # we are the parent: remember the child
    return $pid;
}

sub wait_all {
    waitpid($_, 0) for splice @CHILDREN;
    return;
}

1;
