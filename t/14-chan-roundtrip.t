use strict;
use warnings;
use Test::More tests => 16;

use Parallel::Goroutine;

# Values go through a real fork boundary and must come back unchanged.
# This test is the reference for any change to the wire format in
# Parallel::Goroutine::Chan::_encode / _decode.

my $ch = chan();

my @cases = (
    [ 'empty string',   ''                     ],
    [ 'plain string',   'hello, world'         ],
    [ 'integer',        42                     ],
    [ 'negative float', -3.25                  ],
    [ 'undef',          undef                  ],
    [ 'false',          0                      ],
    [ 'nested refs',    { a => [1, 2], b => { c => 'd' } } ],
    [ 'string with NUL', "a\0b\0c"             ],
);

# Send them all from a child, receive in the parent.
go {
    $ch->send($_->[1]) for @cases;
    $ch->close;
};

for my $case (@cases) {
    my ($label, $expected) = @$case;
    my ($got, $ok) = $ch->recv;
    ok($ok, "$label: ok flag is true");
    is_deeply($got, $expected, "$label: value round-trips");
}

wait_all();
