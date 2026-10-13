package Goroutine::Chan;
use strict;
use warnings;
use Storable qw(nfreeze thaw);
use Fcntl qw(:flock);
use File::Temp qw(tempfile);

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    pipe(my $r, my $w) or die "pipe: $!";
    my ($fh, $wlock) = tempfile('gochan_XXXXXXXX', TMPDIR => 1);
    close $fh;      # we only need the file to exist

    return bless { r => $r, w => $w, wlock => $wlock, owner => $$ }, $class;
}

sub _write_frame {
    my ($self, $frame) = @_;
    open my $lock, '>>', $self->{wlock} or die "lock: $!";
    flock($lock, LOCK_EX) or die "flock: $!";
    while (length $frame) {
        my $n = syswrite($self->{w}, $frame);
        die "send: $!" unless defined $n;
        substr($frame, 0, $n, '');
    }
    return 1;
}

sub DESTROY {
    my ($self) = @_;
    unlink $self->{wlock} if $self->{owner} == $$;
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

    my $header = _read_exact($self->{r}, 4);
    my $len = unpack('N', $header);

    if ($len == 0) {                       # the close marker
        $self->{closed} = 1;
        return wantarray ? (undef, 0) : undef;
    }

    my $payload = _read_exact($self->{r}, $len);
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
