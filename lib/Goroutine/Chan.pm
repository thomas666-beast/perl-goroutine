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
    my $payload = nfreeze([$value]);
    my $frame   = pack('N', length $payload) . $payload;
    syswrite($self->{w}, $frame) // die "send: $!";
    return 1;
}

sub recv {
    my ($self) = @_;
    sysread($self->{r}, my $header, 4) // die "recv: $!";
    my $len = unpack('N', $header);
    sysread($self->{r}, my $payload, $len) // die "recv: $!";
    return thaw($payload)->[0];
}

1;
