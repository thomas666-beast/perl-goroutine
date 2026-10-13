# Parallel::Goroutine

> Go-style goroutines and channels for Perl.

[![CPAN](https://img.shields.io/badge/CPAN-Parallel%3A%3AGoroutine-blue)](https://metacpan.org/pod/Parallel::Goroutine)
[![License](https://img.shields.io/badge/license-Perl%205-green)](#license)

Bring the two core ideas of Go's concurrency model to Perl: **goroutines**
that run independently, and **channels** that carry values between them.
Each goroutine is a forked process, so they run in parallel on all CPU cores.

```perl
use Parallel::Goroutine;

my $jobs    = chan();
my $results = chan();

# start three workers
for (1 .. 3) {
    go {
        while (1) {
            my ($job, $ok) = $jobs->recv;
            last unless $ok;            # the channel was closed
            $results->send($job * 2);
        }
    };
}

$jobs->send($_) for 1 .. 10;
$jobs->close;

my @answers = map { scalar $results->recv } 1 .. 10;
wait_all();

print "@answers\n";   # 2 4 6 8 10 12 14 16 18 20
```

## Why

Perl has threads, forks, and event loops, but no single primitive that reads
like Go's `go` and `chan`. This module is a small, dependency-light attempt at
that: `go { ... }` runs a block in a new process, `chan()` makes a channel,
and goroutines talk to each other by sending values through it. The API
deliberately mirrors Go, so the mental model transfers.

## Features

- `go BLOCK LIST` — start a goroutine, get its PID back immediately
- `chan()` — create a channel
- `$ch->send($v)` / `$ch->recv` — blocking send and receive, safe with many
  senders and receivers
- `$ch->close` — tell every receiver no more messages are coming
- `$ch->each(sub { ... })` — the equivalent of `for v := range ch`
- `gselect TIMEOUT, @channels` — Go's `select` with an optional timeout
- `wait_all()` — reap every goroutine, count failures

## Requirements

- A Unix-like system (Linux, macOS, BSD). **Windows is not supported** —
  the module relies on `fork`, `flock`, and pipes.
- Perl 5.10 or later.
- Core modules only: `Exporter`, `Fcntl`, `File::Temp`, `IO::Handle`,
  `IO::Select`, `POSIX`, `Storable`.

## Installation

From CPAN:

```sh
cpanm Parallel::Goroutine
```

From a checkout:

```sh
perl Makefile.PL
make
make test
make install
```

## Notes on the model

Because goroutines are processes, they **do not share variables**. Every
value sent through a channel is copied, using `Storable` for references and a
fast raw path for plain scalars. Hashes, arrays, and nested structures work.
Code references and filehandles do not.

Channels hold roughly 64 KB of buffered data. When a channel is full, `send`
blocks until a receiver drains it. When it's empty, `recv` blocks until a
sender fills it. `close` wakes every blocked receiver at once.

Each goroutine is a whole process. Use **tens or hundreds**, not thousands.

## Testing

```sh
prove -l t/
```

The suite covers basic send/recv, `undef` and nested data, `close` semantics,
multiple concurrent senders and receivers, `gselect` with timeouts, `each`,
and goroutine panic handling.

## Contributing

Issues and pull requests are welcome:
<https://github.com/thomas666-beast/perl-goroutine/issues>

Please run `prove -l t/` before sending a patch.

## License

Same terms as Perl 5 itself. See [LICENSE](LICENSE) for the full text of the
Artistic License 2.0.

## See also

- [`Parallel::Goroutine::Chan`](https://metacpan.org/pod/Parallel::Goroutine::Chan)
- Go's [concurrency chapter](https://go.dev/tour/concurrency/1) — the model
  this module is imitating
- [`Coro`](https://metacpan.org/pod/Coro), [`threads`](https://metacpan.org/pod/threads),
  [`AnyEvent`](https://metacpan.org/pod/AnyEvent) — other Perl concurrency
  approaches with different trade-offs
