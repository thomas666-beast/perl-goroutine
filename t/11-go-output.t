use strict;
use warnings;
use Test::More tests => 2;
use File::Temp qw(tempfile);

use Parallel::Goroutine;

my ($tmp, $file) = tempfile(UNLINK => 1);
close $tmp;

{
    open my $saved, '>&', \*STDOUT or die "dup: $!";
    open STDOUT, '>', $file        or die "redirect: $!";
    STDOUT->autoflush(0);   # Test::More turns autoflush on; a normal script has it off

    print "before fork\n";
    go { print "hello from goroutine\n" };
    wait_all();

    close STDOUT;
    open STDOUT, '>&', $saved      or die "restore: $!";
}

open my $in, '<', $file or die "read: $!";
my @lines = <$in>;
close $in;

is(scalar(grep { /hello from goroutine/ } @lines), 1,
   'output printed by a goroutine appears exactly once');
is(scalar(grep { /before fork/ } @lines), 1,
   "the parent's earlier output is not duplicated");
