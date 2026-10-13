use strict;
use warnings;
use Test::More tests => 3;

use Parallel::Goroutine;

alarm 10;   # safety net: if each() never stops, the test is killed instead of hanging

# each() calls the callback for every message until the channel is closed
my $ch = chan();
$ch->send($_) for 1 .. 5;
$ch->close;

my @seen;
$ch->each(sub { push @seen, $_[0] });
is_deeply(\@seen, [ 1 .. 5 ], 'each calls the callback for every message');

my ($value, $ok) = $ch->recv;
ok(!$ok, 'the channel is closed once each has finished');

# each() inside a goroutine
my $jobs = chan();
my $out  = chan();
go {
    $jobs->each(sub { $out->send($_[0] * 2) });
    $out->close;
};
$jobs->send($_) for 1 .. 3;
$jobs->close;

my @doubled;
$out->each(sub { push @doubled, $_[0] });
wait_all();
is_deeply(\@doubled, [ 2, 4, 6 ], 'each works between goroutines');
