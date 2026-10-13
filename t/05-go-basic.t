use strict;
use warnings;
use Test::More tests => 3;

use Goroutine;

my $ch = chan();

my $pid = go { $ch->send($$) };

ok($pid > 0, 'go returns a positive PID');

my $child_pid = $ch->recv;
is($child_pid, $pid, 'the goroutine reports the PID that go returned');
isnt($child_pid, $$, 'the goroutine runs in a different process than the caller');

waitpid($pid, 0);   # clean up the finished child
