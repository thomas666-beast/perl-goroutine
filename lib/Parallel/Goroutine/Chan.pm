package Parallel::Goroutine::Chan;
use strict;
use warnings;
use Storable qw(nfreeze thaw);
use Fcntl qw(:flock);
use File::Temp qw(tempfile);

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
    return bless { r => $r, w => $w, rlock => $rlock, wlock => $wlock,
                   owner => $$ }, $class;
}

sub _lock {
    my ($path) = @_;
    open my $fh, '>>', $path or die "lock $path: $!";
    flock($fh, LOCK_EX) or die "flock: $!";
    return $fh;     # the lock is released when $fh goes out of scope
}

sub _write_frame {
    my ($self, $frame) = @_;
    my $lock = _lock($self->{wlock});

    while (length $frame) {
        my $n = syswrite($self->{w}, $frame);
        die "send: $!" unless defined $n;
        substr($frame, 0, $n, '');
    }
    return 1;
}

sub DESTROY {
    my ($self) = @_;
    unlink $self->{rlock}, $self->{wlock} if $self->{owner} == $$;
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
        my $lock   = _lock($self->{rlock});
        my $header = _read_exact($self->{r}, 4);
        my $len    = unpack('N', $header);

        $payload = $len ? _read_exact($self->{r}, $len) : '';
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

1;
