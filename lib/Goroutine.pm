package Goroutine;
use strict;
use warnings;
use Exporter 'import';
use Goroutine::Chan;

our $VERSION = '0.01';
our @EXPORT  = qw(chan);

sub chan {
    return Goroutine::Chan->new;
}

1;
