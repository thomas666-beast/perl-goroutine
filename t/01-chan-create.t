use strict;
use warnings;
use Test::More tests => 1;

use Goroutine;

my $ch = chan();
isa_ok($ch, 'Goroutine::Chan', 'chan() returns a channel object');
