use strict;
use warnings;
use Test::More tests => 2;

use Parallel::Goroutine;

my $WORKERS = 3;
my $JOBS    = 20;

my $jobs    = chan();
my $results = chan();

my @pids = map {
    go {
        while (1) {
            my ($job, $ok) = $jobs->recv;
            last unless $ok;
            $results->send({ id => $job });
        }
    };
} 1 .. $WORKERS;

$jobs->send($_) for 1 .. $JOBS;
$jobs->close;

my @ids;
my $finished = eval {
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm 10;
    push @ids, scalar($results->recv)->{id} for 1 .. $JOBS;
    waitpid($_, 0) for @pids;       # every worker must notice the close and exit
    alarm 0;
    1;
};
my $err = $@;
alarm 0;
kill 'TERM', @pids unless $finished;
wait_all();

ok($finished, 'every worker stopped after the channel was closed')
    or diag("error: $err");

is_deeply([ sort { $a <=> $b } @ids ], [ 1 .. $JOBS ],
    'every job was processed exactly once');
