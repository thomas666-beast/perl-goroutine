use strict;
use warnings;
use Test::More tests => 3;

use Goroutine;

my $ch = chan();

my $hash = { name => 'gopher', langs => [ 'go', 'perl' ] };
$ch->send($hash);
is_deeply(scalar $ch->recv, $hash, 'a hash with a nested array round-trips');

my $array = [ 1, 2, 3 ];
$ch->send($array);
is_deeply(scalar $ch->recv, $array, 'an array round-trips');

$ch->send(undef);
is(scalar $ch->recv, undef, 'undef round-trips');
