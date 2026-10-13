package Parallel::Goroutine::Chan;
use strict;
use warnings;
use Storable qw(nfreeze thaw);
use Fcntl qw(:flock);
use File::Temp qw(tempfile);
use Errno qw(EPIPE);

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    pipe(my $r, my $w) or die "pipe: $!";

    my ($rlock, $wlock);
    for my $slot (\$rlock, \$wlock) {
        my ($fh, $name) = tempfile('gochan_XXXXXXXX', TMPDIR => 1);
        close $fh;      # we only need the file to exist
        $$slot = $name;
    }

    my $self = bless {
        r      => $r,
        w      => $w,
        rlock  => $rlock,
        wlock  => $wlock,
        owner  => $$,
    }, $class;

    ${*$r}{go_chan} = $self;    # let gselect find us from the filehandle
    return $self;
}

# Open a lock file lazily and keep the handle for this process only.
# After fork, the child's copy of a pre-fork handle would share the
# same open file description as the parent's, and flock() between them
# would be a no-op. Opening on first use in each process avoids that.
sub _lock_fh {
    my ($self, $which) = @_;
    my $cache = $self->{lock_fh} ||= {};
    my $fh    = $cache->{$which};
    return $fh if $fh;

    my $path = $self->{$which} or die "no $which path";
    open my $new, '>>', $path or die "lock $path: $!";
    $cache->{$which} = $new;
    return $new;
}

sub _write_frame {
    my ($self, $frame) = @_;
    my $len = length $frame;

    # Small frames: a single write is atomic on a pipe, so no lock needed.
    if ($len <= 4096) {
        my $n = syswrite($self->{w}, $frame);
        if (!defined $n) {
            die "send on closed channel\n" if $! == EPIPE;
            die "send: $!";
        }
        die "send: short write ($n of $len)\n" if $n != $len;
        return 1;
    }

    # Large frames: lock, then loop because syswrite may short-write.
    my $lock = $self->_lock_fh('wlock');
    flock($lock, LOCK_EX) or die "flock: $!";
    while (length $frame) {
        my $n = syswrite($self->{w}, $frame);
        if (!defined $n) {
            die "send on closed channel\n" if $! == EPIPE;
            die "send: $!";
        }
        substr($frame, 0, $n, '');
    }
    flock($lock, LOCK_UN) or die "flock unlock: $!";
    return 1;
}

sub _read_exact {
    my ($fh, $len) = @_;
    my $data = '';

    while (length($data) < $len) {
        my $n = sysread($fh, my $chunk, $len - length $data);
        die "recv: $!" unless defined $n;
        die "recv: channel ended unexpectedly\n" if $n == 0;
        $data .= $chunk;
    }

    return $data;
}

sub DESTROY {
    my ($self) = @_;
    return unless $self->{owner} == $$;
    if (my $cache = $self->{lock_fh}) {
        close $_ for values %$cache;
    }
    unlink $self->{rlock}, $self->{wlock};
}

sub send {
    my ($self, $value) = @_;
    die "send on closed channel\n" if $self->{send_closed};
    my $payload = nfreeze([$value]);
    my $frame   = pack('N', length $payload) . $payload;
    $self->_write_frame($frame);
    return 1;
}

sub recv {
    my ($self) = @_;
    return wantarray ? (undef, 0) : undef if $self->{closed};

    my $payload;
    {
        my $lock = $self->_lock_fh('rlock');
        flock($lock, LOCK_EX) or die "flock: $!";
        my $header = _read_exact($self->{r}, 4);
        my $len    = unpack('N', $header);

        $payload = $len ? _read_exact($self->{r}, $len) : '';
        flock($lock, LOCK_UN) or die "flock unlock: $!";
    }

    if ($payload eq '') {                  # the close marker
        $self->{closed} = 1;
        $self->_write_frame(pack('N', 0)); # put it back for the next receiver
        return wantarray ? (undef, 0) : undef;
    }
    my $value = thaw($payload)->[0];
    return wantarray ? ($value, 1) : $value;
}

sub close {
    my ($self) = @_;
    return 1 if $self->{send_closed};      # closing twice is harmless
    $self->{send_closed} = 1;
    $self->_write_frame(pack('N', 0));
    return 1;
}

sub each {
    my ($self, $callback) = @_;
    while (1) {
        my ($value, $ok) = $self->recv;
        last unless $ok;
        $callback->($value);
    }
    return;
}

1;

__END__

=head1 NAME

Parallel::Goroutine::Chan - a channel for passing values between goroutines

=head1 SYNOPSIS

    use Parallel::Goroutine;

    my $ch = chan();

    go {
        $ch->send($_) for 1 .. 3;
        $ch->close;
    };

    $ch->each(sub { print "got $_[0]\n" });
    wait_all();

=head1 DESCRIPTION

A channel carries values from one goroutine to another, in the order in
which they were sent. Every message is delivered to exactly one receiver, so
several goroutines can take jobs from one channel.

Channels are created with C<chan> from L<Parallel::Goroutine>, not by calling
C<new> yourself. They work with any number of senders and receivers at the
same time.

Values are copied when they are sent, using L<Storable>. Scalars, C<undef>,
array references, hash references and nested data structures can be sent.
Code references and filehandles cannot; C<send> dies if you try.

A channel holds roughly 64KB of data. When it is full, C<send> waits until a
receiver has made room.

=head1 METHODS

=head2 send VALUE

    $ch->send('hello');
    $ch->send({ id => 1, tags => [ 'a', 'b' ] });

Puts VALUE into the channel and returns true. It waits if the channel is
full. It dies with C<send on closed channel> if this channel object has been
closed with L</close>.

=head2 recv

    my $value = $ch->recv;
    my ($value, $ok) = $ch->recv;

Takes the next message out of the channel, waiting until there is one. In
scalar context it returns the value. In list context it returns the value and
an C<ok> flag.

The flag is true for every real message, even when the value itself is false
or C<undef>. It is false only when the channel has been closed and all
messages have been received; the value is then C<undef>. Once that has
happened, C<recv> keeps returning at once.

Be careful with list context: in C<is($ch-E<gt>recv, 'x')> the call returns
two values, and the extra C<ok> shifts the other arguments. Write
C<scalar $ch-E<gt>recv> there.

=head2 close

    $ch->close;

Tells the receivers that no more messages will come. Messages that were sent
before the call are still delivered. Returns true, and closing a channel twice
is harmless.

After C<close>, calling L</send> on the same channel object dies. This only
protects the process that called C<close>: a goroutine that was started
earlier has its own copy of the channel and can still send. The usual rule is
that the goroutine which sends is also the one which closes.

Every receiver sees the close, not just one of them, so a pool of workers can
all stop when the job channel is closed.

=head2 each CALLBACK

    my $value = $ch->recv;
    my ($value, $ok) = $ch->recv;

=head2 each CALLBACK

    $ch->each(sub {
        my ($value) = @_;
        ...
    });

Calls CALLBACK with each message, in order, until the channel is closed and
empty, then returns. It is the equivalent of Go's C<for v := range ch>.

=head1 SEE ALSO

L<Parallel::Goroutine>

=cut
