package Goroutine::Chan;
use strict;
use warnings;

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

1;
