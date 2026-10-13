use strict;
use warnings;
use Test::More tests => 4;

use Parallel::Goroutine;

my $ch = chan();

my @pids = map {
    my $n = $_;
    go { select(undef, undef, undef, 0.3); $ch->send($n) };
} 1 .. 3;

is(scalar @pids, 3, 'started three goroutines');

wait_all();

is(scalar(grep { kill 0, $_ } @pids), 0,
   'no child processes remain after wait_all');

my @got = sort { $a <=> $b } map { scalar $ch->recv } 1 .. 3;
is_deeply(\@got, [1, 2, 3], 'all three goroutines delivered their value');

ok(eval { wait_all(); 1 }, 'wait_all with no children is harmless');
