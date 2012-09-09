#!perl -T

use strict;
use warnings;

use lib 't/lib';
use Scope::Upper::TestThreads;

use Test::Leaner;

use Scope::Upper qw<unwind UP>;

our $z;

sub up1 {
 my $tid  = threads->tid();
 local $z = $tid;
 my $p    = "[$tid] up1";

 usleep rand(1e6);

 my @res = (
  -1,
  sub {
   my @dummy = (
    999,
    sub {
     my $foo = unwind $tid .. $tid + 2 => UP;
     fail "$p: not reached";
    }->()
   );
   fail "$p: not reached";
  }->(),
  -2
 );

 is_deeply \@res, [ -1, $tid .. $tid + 2, -2 ], "$p: unwinded correctly";
}

my @threads = map spawn(\&up1), 1 .. 30;

$_->join for @threads;

pass 'done';

done_testing(scalar(@threads) + 1);
