use strict;
use warnings;
use Test::More tests => 2;

use Parallel::Goroutine;

my $WORKERS    = 3;
my $PER_WORKER = 10;
my $TOTAL      = $WORKERS * $PER_WORKER;
my $SIZE       = 50_000;

my $jobs    = chan();
my $results = chan();

my @pids = map {
    go {
        for (1 .. $PER_WORKER) {
            my $job = $jobs->recv;
            $results->send({ id => $job->{id} });
        }
    };
} 1 .. $WORKERS;

$jobs->send({ id => $_, data => 'x' x $SIZE }) for 1 .. $TOTAL;

my @ids;
my $finished = eval {
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm 10;
    push @ids, scalar($results->recv)->{id} for 1 .. $TOTAL;
    alarm 0;
    1;
};
my $err = $@;
alarm 0;
kill 'TERM', @pids unless $finished;
wait_all();

ok($finished, 'collected every result without an error or a hang')
    or diag("error: $err");

is_deeply([ sort { $a <=> $b } @ids ], [ 1 .. $TOTAL ],
    'every job was processed exactly once');
