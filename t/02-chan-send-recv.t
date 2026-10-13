use strict;
use warnings;
use Test::More tests => 2;

use Goroutine;

my $ch = chan();

$ch->send('hello');
is($ch->recv, 'hello', 'recv returns the value that was sent');

$ch->send('world');
is($ch->recv, 'world', 'a second value also round-trips');
