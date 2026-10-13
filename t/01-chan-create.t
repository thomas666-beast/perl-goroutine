use strict;
use warnings;
use Test::More tests => 1;

use Parallel::Goroutine;

my $ch = chan();
isa_ok($ch, 'Parallel::Goroutine::Chan', 'chan() returns a channel object');
