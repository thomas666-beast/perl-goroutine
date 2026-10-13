package Goroutine;
use strict;
use warnings;
use Exporter 'import';
use POSIX ();
use Goroutine::Chan;

our $VERSION = '0.01';
our @EXPORT  = qw(chan go);

sub chan {
    return Goroutine::Chan->new;
}

sub go(&;@) {
    my ($code, @args) = @_;
    my $pid = fork() // die "fork failed: $!";
    if ($pid == 0) {                # we are the child
        $code->(@args);
        POSIX::_exit(0);
    }
    return $pid;                    # we are the parent
}

1;
