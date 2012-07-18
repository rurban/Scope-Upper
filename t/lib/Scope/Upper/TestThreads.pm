package Scope::Upper::TestThreads;

use strict;
use warnings;

use Config qw<%Config>;

use Scope::Upper qw<SU_THREADSAFE>;

sub skipall {
 my ($msg) = @_;
 require Test::Leaner;
 Test::Leaner::plan(skip_all => $msg);
}

sub diag {
 require Test::Leaner;
 Test::Leaner::diag(@_);
}

sub import {
 shift;

 skipall 'This Scope::Upper isn\'t thread safe' unless SU_THREADSAFE;

 my $force = $ENV{PERL_SCOPE_UPPER_TEST_THREADS} ? 1 : !1;
 skipall 'This perl wasn\'t built to support threads'
                                                    unless $Config{useithreads};
 skipall 'perl 5.13.4 required to test thread safety'
                                             unless $force or "$]" >= 5.013_004;

 my $t_v = $force ? '0' : '1.67';
 my $has_threads =  do {
  local $@;
  eval "use threads $t_v; 1";
 };
 skipall "threads $t_v required to test thread safety" unless $has_threads;

 defined and diag "Using threads $_" for $threads::VERSION;

 my $has_time_hires = do {
  local $@;
  eval { require Time::HiRes; 1 };
 };

 my %exports = (
  spawn => \&spawn,
 );

 my $usleep;
 if ($has_time_hires) {
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
