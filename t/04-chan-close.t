use strict;
use warnings;
use Test::More tests => 5;

use Goroutine;

my $ch = chan();
$ch->send('a');
$ch->send('b');

ok($ch->close, 'close returns true');

eval { $ch->send('late') };
like($@, qr/send on closed channel/, 'send after close dies');

is(scalar $ch->recv, 'a', 'item sent before close is still delivered (1)');
is(scalar $ch->recv, 'b', 'item sent before close is still delivered (2)');

my ($value, $ok) = $ch->recv;
ok(!$ok, 'recv on a drained, closed channel reports "not ok"');
