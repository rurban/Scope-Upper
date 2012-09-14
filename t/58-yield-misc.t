#!perl -T

use strict;
use warnings;

use Test::More tests => 4 * 3 + 1 + 3;

use lib 't/lib';
use VPIT::TestHelpers;

use Scope::Upper qw<yield leave HERE>;

# Test timely destruction of values returned from yield()

our $destroyed;
sub guard { VPIT::TestHelpers::Guard->new(sub { ++$destroyed }) }

{
 my $desc = 'scalar context, above';
 local $destroyed;
 {
  my $obj = guard();
  my $res = do {
   is $destroyed, undef, "$desc: not yet destroyed 1";
   yield $obj => HERE;
   fail 'not reached 1';
  };
  is $destroyed, undef, "$desc: not yet destroyed 2";
 }
 is $destroyed, 1, "$desc: destroyed 1";
}

{
 my $desc = 'scalar context, below';
 local $destroyed;
 {
  my $res = do {
   my $obj = guard();
   is $destroyed, undef, "$desc: not yet destroyed 1";
   yield $obj => HERE;
   fail 'not reached 1';
  };
  is $destroyed, undef, "$desc: not yet destroyed 2";
 }
 is $destroyed, 1, "$desc: destroyed 1";
}

{
 my $desc = 'void context, above';
 local $destroyed;
 {
  my $obj = guard();
  {
   is $destroyed, undef, "$desc: not yet destroyed 1";
   yield $obj => HERE;
   fail 'not reached 1';
  }
  is $destroyed, undef, "$desc: not yet destroyed 2";
 }
 is $destroyed, 1, "$desc: destroyed 1";
}

{
 my $desc = 'void context, below';
 local $destroyed;
 {
  {
   is $destroyed, undef, "$desc: not yet destroyed 1";
   my $obj = guard();
   yield $obj => HERE;
   fail 'not reached 2';
  }
  is $destroyed, 1, "$desc: destroyed 1";
 }
 is $destroyed, 1, "$desc: destroyed 2";
}

# Test 'return from do' in special cases

{
 no warnings 'void';
 my @res = (1, do {
  my $cxt = HERE;
  my $thing = (777, do {
   my @stuff = (888, do {
    yield 2, 3 => $cxt;
    map { my $x; $_ x 3 } qw<x y z>
   }, 999);
   if (@stuff) {
    my $y;
    ++$y;
    'YYY';
   } else {
    die 'not reached';
   }
  });
  if (1) {
   my $z;
   'ZZZ';
  }
  'VVV'
 }, 4);
 is "@res", '1 2 3 4', 'yield() found the op to return to';
}

# Test leave

{
 my @res = (1, do {
  leave;
  'XXX';
 }, 2);
 is "@res", '1 2', 'leave without arguments';
}

{
 my @res = (1, do {
  leave 2, 3;
  'XXX';
 }, 4);
 is "@res", '1 2 3 4', 'leave with arguments';
}

{
 my $s = 'a';
 local $@;
 eval {
  $s =~ s/./leave; die 'not reached'/e;
 };
 my $err  = $@;
 my $line = __LINE__-3;
 like $err,
      qr/^leave\(\) can't target a substitution context at \Q$0\E line $line/,
      'leave() cannot exit subst';
}
