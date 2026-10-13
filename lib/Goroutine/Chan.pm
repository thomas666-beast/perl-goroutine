package Goroutine::Chan;
use strict;
use warnings;
use Storable qw(nfreeze thaw);

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    pipe(my $r, my $w) or die "pipe: $!";
    return bless { r => $r, w => $w }, $class;
}

sub send {
    my ($self, $value) = @_;
    die "send on closed channel\n" if $self->{send_closed};
    my $payload = nfreeze([$value]);
    my $frame   = pack('N', length $payload) . $payload;
    syswrite($self->{w}, $frame) // die "send: $!";
    return 1;
}

sub recv {
    my ($self) = @_;
    return wantarray ? (undef, 0) : undef if $self->{closed};

    sysread($self->{r}, my $header, 4) // die "recv: $!";
    my $len = unpack('N', $header);

    if ($len == 0) {                       # the close marker
        $self->{closed} = 1;
        return wantarray ? (undef, 0) : undef;
    }

    sysread($self->{r}, my $payload, $len) // die "recv: $!";
    my $value = thaw($payload)->[0];
    return wantarray ? ($value, 1) : $value;
}

sub close {
    my ($self) = @_;
    return 1 if $self->{send_closed};      # closing twice is harmless
    $self->{send_closed} = 1;
    syswrite($self->{w}, pack('N', 0)) // die "close: $!";
    return 1;
}

1;
