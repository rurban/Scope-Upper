#!perl -T

use strict;
use warnings;

use lib 't/lib';
use Scope::Upper::TestThreads;

use Test::Leaner;

use Scope::Upper qw<uplevel UP>;

sub depth {
 my $depth = 0;
 while (1) {
  my @c = caller($depth);
  last unless @c;
  ++$depth;
 }
 return $depth - 1;
}

is depth(),                           0, 'check top depth';
is sub { depth() }->(),               1, 'check subroutine call depth';
is do { local $@; eval { depth() } }, 1, 'check eval block depth';

our $z;

sub cb {
 my $d   = splice @_, 1, 1;
 my $p   = shift;
 my $tid = pop;
 is depth(), $d - 1, "$p: correct depth inside";
 $tid, @_, $tid + 2
}

sub up1 {
 my $tid  = threads->tid();
 local $z = $tid;
 my $p    = "[$tid] up1";

 usleep rand(1e6);

 my @res = (
  -2,
  sub {
   my @dummy = (
    -1,
    sub {
     my $d = depth();
     my @ret = &uplevel(\&cb => ($p, $d, $tid + 1, $tid) => UP);
     is depth(), $d, "$p: correct depth after uplevel";
     @ret;
    }->(),
    1
   );
  }->(),
  2
 );

 is_deeply \@res, [ -2, -1, $tid .. $tid + 2, 1, 2 ], "$p: returns correctly";
}

my @threads = map spawn(\&up1), 1 .. 30;

$_->join for @threads;

done_testing(3 + scalar(@threads) * 3);
