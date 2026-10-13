use strict;
use warnings;
use Test::More;

use Parallel::Goroutine;

# gselect must not always pick the same channel when several are ready.
# Without a shuffle, IO::Select returns fds in the order they were added,
# so the first channel wins every time. With a shuffle, both get picked.

my $a = chan();
my $b = chan();

my $ITERATIONS = 200;
my %picked;

for (1 .. $ITERATIONS) {
    $a->send('a');
    $b->send('b');

    my ($ch, $value) = gselect(1, $a, $b);
    last unless defined $ch;

    $picked{$value}++;

    # drain the loser so the next round starts clean
    my $other = ($ch == $a) ? $b : $a;
    $other->recv;
}

ok($picked{a}, "channel a was selected at least once ($picked{a} times)");
ok($picked{b}, "channel b was selected at least once ($picked{b} times)");

cmp_ok($picked{a} // 0, '>', 0, 'a count is positive');
cmp_ok($picked{b} // 0, '>', 0, 'b count is positive');

# Both should be roughly half. Allow a wide margin so the test does not
# flake; the failure mode we care about is one side getting zero.
my $ratio = ($picked{a} // 0) / $ITERATIONS;
cmp_ok($ratio, '>', 0.2, "a was not starved (ratio $ratio)");
cmp_ok($ratio, '<', 0.8, "b was not starved (ratio $ratio)");

done_testing();
