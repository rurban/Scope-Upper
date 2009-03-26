#!perl -T

use strict;
use warnings;

sub skipall {
 my ($msg) = @_;
 require Test::More;
 Test::More::plan(skip_all => $msg);
}

use Config qw/%Config/;

BEGIN {
 skipall 'This perl wasn\'t built to support threads'
                                                    unless $Config{useithreads};
 skipall 'threads required to test thread safety' unless eval "use threads; 1";
}

my $num;
BEGIN { $num = 20; }

use Test::More tests => $num;

BEGIN {
 defined and diag "Using threads $_" for $threads::VERSION;

 if (eval "use Time::HiRes; 1") {
  defined and diag "Using Time::HiRes $_" for $Time::HiRes::VERSION;
  *usleep = \&Time::HiRes::usleep;
 } else {
  diag 'Using fallback usleep';
  *usleep = sub {
   my $s = int($_[0] / 2.5e5);
   sleep $s if $s;
  };
 }
}

use Scope::Upper qw/unwind UP/;

our $z;

BEGIN {
}

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

$_->join for map threads->create(\&up1), 1 .. $num;
