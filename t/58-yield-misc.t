#!perl -T

use strict;
use warnings;

use Test::More tests => 4 * 3;

use lib 't/lib';
use VPIT::TestHelpers;

use Scope::Upper qw<yield HERE>;

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
