# t/15-gselect-fairness.t

use strict;
use warnings;
use Test::More;

use Parallel::Goroutine;
use Parallel::Goroutine::Chan;

# _pick_ready must be able to return each of its arguments.
# We call it many times with a known set and assert every element is
# seen at least once. Deterministic in practice: 200 draws from a
# 2-element set, both must appear.

my $ITER = 200;
my %seen;

for (1 .. $ITER) {
    my @picked = Parallel::Goroutine::_pick_ready('x', 'y');
    $seen{$picked[0]}++;
}

ok($seen{x}, '_pick_ready can return the first element');
ok($seen{y}, '_pick_ready can return the second element');

# And gselect must use it: two ready channels, both eventually picked.
my $a = chan();
my $b = chan();

my %gselect_picked;
for (1 .. $ITER) {
    $a->send('a');
    $b->send('b');
    my ($ch, $value) = gselect(1, $a, $b);
    $gselect_picked{$value}++;
    my $other = ($ch == $a) ? $b : $a;
    $other->recv;
}

ok($gselect_picked{a}, 'gselect selected a at least once');
ok($gselect_picked{b}, 'gselect selected b at least once');

done_testing();
