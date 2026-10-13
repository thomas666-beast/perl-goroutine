use strict;
use warnings;
use Test::More tests => 4;

use Goroutine;

my $ch = chan();

# arguments are passed to the block
go { my ($name, $n) = @_; $ch->send("$name-$n") } 'foo', 42;
is(scalar $ch->recv, 'foo-42', 'go passes its arguments to the block');
is(wait_all(), 0, 'wait_all returns 0 when every goroutine succeeded');

# a goroutine that dies ("panics")
go { die "boom\n" };
is(wait_all(), 1, 'wait_all returns 1 when one goroutine died');

$ch->send('still alive');
is(scalar $ch->recv, 'still alive', 'the parent keeps working after a panic');
