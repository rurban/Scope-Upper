#!perl -T

use strict;
use warnings;

use Test::More tests => 4 * 3 + 3;

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
      qr/^leave\(\) cannot target a substitution context at \Q$0\E line $line/,
      'leave() cannot exit subst';
}
