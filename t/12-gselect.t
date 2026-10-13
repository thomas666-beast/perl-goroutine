use strict;
use warnings;
use Test::More tests => 5;

use Parallel::Goroutine;

my $one = chan();
my $two = chan();

# data is already waiting on the second channel
$two->send('from two');
my ($ch, $value, $ok) = gselect(1, $one, $two);
is($ch,    $two,       'gselect returns the channel that had data');
is($value, 'from two', '... together with the value');
ok($ok,                '... and a true ok flag');

# nothing arrives: gselect gives up after the timeout
my @result = gselect(0.2, $one, $two);
is(scalar @result, 0, 'gselect returns an empty list on timeout');

# two goroutines race; the faster one must win
go { select(undef, undef, undef, 0.4);  $one->send('slow') };
go { select(undef, undef, undef, 0.05); $two->send('fast') };
($ch, $value) = gselect(3, $one, $two);
is($value, 'fast', 'gselect returns whichever channel delivers first');
wait_all();
