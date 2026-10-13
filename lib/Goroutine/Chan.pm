package Goroutine::Chan;
use strict;
use warnings;

our $VERSION = '0.01';

sub new {
    my ($class) = @_;
    pipe(my $r, my $w) or die "pipe: $!";
    return bless { r => $r, w => $w }, $class;
}

sub send {
    my ($self, $value) = @_;
    my $frame = pack('N', length $value) . $value;
    syswrite($self->{w}, $frame) // die "send: $!";
    return 1;
}

sub recv {
    my ($self) = @_;
    sysread($self->{r}, my $header, 4) // die "recv: $!";
    my $len = unpack('N', $header);
    sysread($self->{r}, my $value, $len) // die "recv: $!";
    return $value;
}

1;
