use strict;
use warnings;
use ExtUtils::MakeMaker;

# This module needs fork, pipes and flock: a Unix-like system.
# Exiting without writing a Makefile makes CPAN report "N/A" instead of "FAIL".
if ($^O eq 'MSWin32') {
    print "OS unsupported: Parallel::Goroutine needs a Unix-like system\n";
    exit 0;
}

WriteMakefile(
    NAME               => 'Parallel::Goroutine',
    VERSION_FROM       => 'lib/Parallel/Goroutine.pm',
    ABSTRACT           => 'Go-style goroutines and channels for Perl',
    AUTHOR             => 'Your Name <you@example.com>',
    LICENSE            => 'perl',
    MIN_PERL_VERSION   => '5.010',
    CONFIGURE_REQUIRES => { 'ExtUtils::MakeMaker' => '6.64' },
    PREREQ_PM          => {
        'Exporter'   => 0,
        'Fcntl'      => 0,
        'File::Temp' => 0,
        'IO::Handle' => 0,
        'IO::Select' => 0,
        'POSIX'      => 0,
        'Storable'   => 0,
    },
    TEST_REQUIRES      => { 'Test::More' => '0.88' },
    META_MERGE         => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/thomas666-beast/perl-goroutine.git',
                web  => 'https://github.com/thomas666-beast/perl-goroutine',
            },
            bugtracker => {
                web => 'https://github.com/thomas666-beast/perl-goroutine/issues',
            },
        },
    },
    test  => { TESTS => 't/*.t' },
    clean => { FILES => 'Parallel-Goroutine-*' },
);
