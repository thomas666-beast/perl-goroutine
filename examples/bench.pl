#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(time);
use FindBin;
use lib "$FindBin::Bin/../lib";

use Parallel::Goroutine;

# ---- configuration ----------------------------------------------------

my %RUNS = (
    'scalar, 1 sender -> 1 receiver' => {
        senders   => 1,
        receivers => 1,
        messages  => 20_000,
        payload   => sub { "x" },
    },
    'scalar, 1 sender -> 4 receivers' => {
        senders   => 1,
        receivers => 4,
        messages  => 20_000,
        payload   => sub { "x" },
    },
    'scalar, 4 senders -> 1 receiver' => {
        senders   => 4,
        receivers => 1,
        messages  => 20_000,
        payload   => sub { "x" },
    },
    'scalar, 4 senders -> 4 receivers' => {
        senders   => 4,
        receivers => 4,
        messages  => 20_000,
        payload   => sub { "x" },
    },
    'hashref, 4 senders -> 4 receivers' => {
        senders   => 4,
        receivers => 4,
        messages  => 5_000,
        payload   => sub { { id => $_, tags => [ 'a', 'b' ] } },
    },
    'large scalar (50KB), 4 -> 4' => {
        senders   => 4,
        receivers => 4,
        messages  => 2_000,
        payload   => sub { 'x' x 50_000 },
    },
);

# ---- runner -----------------------------------------------------------

sub run {
    my ($cfg) = @_;
    my $senders   = $cfg->{senders};
    my $receivers = $cfg->{receivers};
    my $total     = $cfg->{messages};
    my $mk        = $cfg->{payload};

    my $ch = chan();

    # Start receivers first so they are blocked on recv before senders run.
    my @rpids = map {
        go {
            my $n = 0;
            while (1) {
                my ($v, $ok) = $ch->recv;
                last unless $ok;
                $n++;
            }
            $n;
        }
    } 1 .. $receivers;

    my $per_sender = int($total / $senders);
    my @spids = map {
        go {
            $ch->send($mk->($_)) for 1 .. $per_sender;
        }
    } 1 .. $senders;

    my $t0 = time;

    waitpid($_, 0) for @spids;
    $ch->close;
    waitpid($_, 0) for @rpids;

    my $dt   = time - $t0;
    my $sent = $per_sender * $senders;
    my $rate = $sent / ($dt || 1e-9);

    return ($sent, $dt, $rate);
}

# ---- main -------------------------------------------------------------

my $label_width = 0;
for (keys %RUNS) {
    $label_width = length if length > $label_width;
}

printf "%-*s  %10s  %8s  %14s\n",
       $label_width, 'configuration', 'messages', 'seconds', 'msgs/sec';
printf "%s\n", '-' x ($label_width + 38);

for my $name (sort keys %RUNS) {
    my ($sent, $dt, $rate) = run($RUNS{$name});
    printf "%-*s  %10d  %8.3f  %14.0f\n",
           $label_width, $name, $sent, $dt, $rate;
}

wait_all();
