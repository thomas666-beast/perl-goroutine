use strict;
use warnings;
use Test::More tests => 2;

use Parallel::Goroutine;

my $ch = chan();

$ch->send('hello');
is(scalar $ch->recv, 'hello', 'recv returns the value that was sent');

$ch->send('world');
is(scalar $ch->recv, 'world', 'a second value also round-trips');
