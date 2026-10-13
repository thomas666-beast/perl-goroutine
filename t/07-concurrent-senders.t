use strict;
use warnings;
use Test::More tests => 2;

use Goroutine;

my $SENDERS = 3;
my $PER     = 4;
my $SIZE    = 200_000;
my $TOTAL   = $SENDERS * $PER;

my $ch = chan();

my @pids = map {
    my $id = $_;
    go {
        for my $i (1 .. $PER) {
            $ch->send({ id => $id, i => $i, data => 'x' x $SIZE });
        }
    };
} 1 .. $SENDERS;

my @got;
my $finished = eval {
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm 10;
    push @got, scalar $ch->recv for 1 .. $TOTAL;
    alarm 0;
    1;
};
my $err = $@;
alarm 0;
kill 'TERM', @pids unless $finished;
wait_all();

ok($finished, 'received every message without an error or a hang')
    or diag("error: $err");

my $intact = grep { ref $_ eq 'HASH' && length($_->{data} // '') == $SIZE } @got;
is($intact, $TOTAL, 'every message arrived intact');
