package Scope::Upper::TestThreads;

use strict;
use warnings;

use Config qw<%Config>;

use Scope::Upper qw<SU_THREADSAFE>;

use VPIT::TestHelpers;

sub diag {
 require Test::Leaner;
 Test::Leaner::diag(@_);
}

sub import {
 shift;

 skip_all 'This Scope::Upper isn\'t thread safe' unless SU_THREADSAFE;

 my $force = $ENV{PERL_SCOPE_UPPER_TEST_THREADS} ? 1 : !1;
 skip_all 'This perl wasn\'t built to support threads'
                                                    unless $Config{useithreads};
 skip_all 'perl 5.13.4 required to test thread safety'
                                             unless $force or "$]" >= 5.013_004;

 load_or_skip_all('threads', $force ? '0' : '1.67', [ ]);

 my %exports = (
  spawn => \&spawn,
 );

 my $usleep;
 if (do { local $@; eval { require Time::HiRes; 1 } }) {
  defined and diag "Using Time::HiRes $_" for $Time::HiRes::VERSION;
  $exports{usleep} = \&Time::HiRes::usleep;
 } else {
  diag 'Using fallback usleep';
  $exports{usleep} = sub {
   my $s = int($_[0] / 2.5e5);
   sleep $s if $s;
  };
 }

 my $pkg = caller;
 while (my ($name, $code) = each %exports) {
  no strict 'refs';
  *{$pkg.'::'.$name} = $code;
 }
}

sub spawn {
 local $@;
 my @diag;
 my $thread = eval {
  local $SIG{__WARN__} = sub { push @diag, "Thread creation warning: @_" };
  threads->create(@_);
 };
 push @diag, "Thread creation error: $@" if $@;
 if (@diag) {
  require Test::Leaner;
  Test::Leaner::diag($_) for @diag;
 }
 return $thread ? $thread : ();
}

1;
