#!perl -T

use strict;
use warnings;

use Test::More;

plan tests => 23 * ($^P ? 4 : 5) + ($^P ? 1 : 3) + 7 + 15 * 2;

use Scope::Upper qw<:words>;

# Tests with hardcoded values are for internal use only and doesn't imply any
# kind of future compatibility on what the words should actually return.

my $top = HERE;

is $top, 0,     'main : here' unless $^P;
is TOP,  $top,  'main : top';
is UP,   $top,  'main : up';
is SUB,  undef, 'main : sub';
is EVAL, undef, 'main : eval';

{
 my $desc = '{ 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

do {
 my $desc = 'do { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
};

eval {
 my $desc = 'eval { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, HERE,  "$desc : eval";
};
diag $@ if $@;

eval q[
 my $desc = 'eval "1"';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, HERE,  "$desc : eval";
];
diag $@ if $@;

sub {
 my $desc = 'sub { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  HERE,  "$desc : sub";
 is EVAL, undef, "$desc : eval";
}->();

my $true  = 1;
my $false = !$true;

if ($true) {
 my $desc = 'if () { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

unless ($false) {
 my $desc = 'unless () { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

if ($false) {
 fail "false was true : $_" for 1 .. 5;
} else {
 my $desc = 'if () { } else { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

for (1) {
 my $desc = 'for (list) { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

for (1 .. 1) {
 my $desc = 'for (num range) { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

for (1 .. 1) {
 my $desc = 'for (pv range) { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

for (my $i = 0; $i < 1; ++$i) {
 my $desc = 'for (;;) { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

my $flag = 1;
while ($flag) {
 $flag = 0;
 my $desc = 'while () { 1 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

my @list = (1);
while (my $thing = shift @list) {
 my $desc = 'while (my $thing = ...) { 2 }';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}

do {
 my $desc = 'do { 1 } while (0)';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
} while (0);

map {
 my $desc = 'map { 1 } 1';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
} 1;

grep {
 my $desc = 'grep { 1 } 1';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
} 1;

my $var = 'a';
$var =~ s{.}{
 my $desc = 'subst';
 is HERE, 1,     "$desc : here" unless $^P;
 is TOP,  $top,  "$desc : top";
 is UP,   $top,  "$desc : up";
 is SUB,  undef, "$desc : sub";
 is EVAL, undef, "$desc : eval";
}e;

$var = 'a';
$var =~ s{.}{UP}e;
is $var, $top, 'subst : fake block';

$var = 'a';
$var =~ s{.}{do { UP }}e;
is $var, 1, 'subst : do block optimized away' unless $^P;

$var = 'a';
$var =~ s{.}{do { my $x; UP }}e;
is $var, 1, 'subst : do block preserved' unless $^P;

SKIP: {
 skip 'Perl 5.10 required to test given/when' => 4 * ($^P ? 4 : 5)
                                                                if "$]" < 5.010;

 eval <<'TEST_GIVEN';
  BEGIN {
   if ("$]" >= 5.017_011) {
    require warnings;
    warnings->unimport('experimental::smartmatch');
   }
  }
  use feature 'switch';
  my $desc = 'given';
  my $base = HERE;
  given (1) {
   is HERE, $base + 1, "$desc : here" unless $^P;
   is TOP,  $top,      "$desc : top";
   is UP,   $base,     "$desc : up";
   is SUB,  undef,     "$desc : sub";
   is EVAL, $base,     "$desc : eval";
  }
TEST_GIVEN
 diag $@ if $@;

 eval <<'TEST_GIVEN_WHEN';
  BEGIN {
   if ("$]" >= 5.017_011) {
    require warnings;
    warnings->unimport('experimental::smartmatch');
   }
  }
  use feature 'switch';
  my $desc = 'when in given';
  my $base = HERE;
  given (1) {
   my $given = HERE;
   when (1) {
    is HERE, $base + 3, "$desc : here" unless $^P;
    is TOP,  $top,      "$desc : top";
    is UP,   $given,    "$desc : up";
    is SUB,  undef,     "$desc : sub";
    is EVAL, $base,     "$desc : eval";
   }
  }
TEST_GIVEN_WHEN
 diag $@ if $@;

 eval <<'TEST_GIVEN_DEFAULT';
  BEGIN {
   if ("$]" >= 5.017_011) {
    require warnings;
    warnings->unimport('experimental::smartmatch');
   }
  }
  use feature 'switch';
  my $desc = 'default in given';
  my $base = HERE;
  given (1) {
   my $given = HERE;
   default {
    is HERE, $base + 3, "$desc : here" unless $^P;
    is TOP,  $top,      "$desc : top";
    is UP,   $given,    "$desc : up";
    is SUB,  undef,     "$desc : sub";
    is EVAL, $base,     "$desc : eval";
   }
  }
TEST_GIVEN_DEFAULT
 diag $@ if $@;

 eval <<'TEST_FOR_WHEN';
  BEGIN {
   if ("$]" >= 5.017_011) {
    require warnings;
    warnings->unimport('experimental::smartmatch');
   }
  }
  use feature 'switch';
  my $desc = 'when in for';
  my $base = HERE;
  for (1) {
   my $loop = HERE;
   when (1) {
    is HERE, $base + 2, "$desc : here" unless $^P;
    is TOP,  $top,      "$desc : top";
    is UP,   $loop,     "$desc : up";
    is SUB,  undef,     "$desc : sub";
    is EVAL, $base,     "$desc : eval";
   }
  }
TEST_FOR_WHEN
 diag $@ if $@;
}

SKIP: {
 skip 'Hardcoded values are wrong under the debugger' => 7 if $^P;

 my $base = HERE;

 do {
  eval {
   do {
    sub {
     eval q[
      {
       is HERE,           $base + 6, 'mixed : here';
       is TOP,            $top,      'mixed : top';
       is SUB,            $base + 4, 'mixed : first sub';
       is SUB(SUB),       $base + 4, 'mixed : still first sub';
       is EVAL,           $base + 5, 'mixed : first eval';
       is EVAL(EVAL),     $base + 5, 'mixed : still first eval';
       is EVAL(UP(EVAL)), $base + 2, 'mixed : second eval';
      }
     ];
    }->();
   }
  };
 } while (0);
}

{
 my $block = HERE;
 is SCOPE,     $block, 'block : scope';
 is SCOPE(0),  $block, 'block : scope 0';
 is SCOPE(1),  $top,   'block : scope 1';
 is CALLER,    $top,   'block : caller';
 is CALLER(0), $top,   'block : caller 0';
 is CALLER(1), $top,   'block : caller 1';
 sub {
  my $sub = HERE;
  is SCOPE,     $sub,   'block sub : scope';
  is SCOPE(0),  $sub,   'block sub : scope 0';
  is SCOPE(1),  $block, 'block sub : scope 1';
  is CALLER,    $sub,   'block sub : caller';
  is CALLER(0), $sub,   'block sub : caller 0';
  is CALLER(1), $top,   'block sub : caller 1';
  for (1) {
   my $loop = HERE;
   is SCOPE,     $loop,  'block sub for : scope';
   is SCOPE(0),  $loop,  'block sub for : scope 0';
   is SCOPE(1),  $sub,   'block sub for : scope 1';
   is SCOPE(2),  $block, 'block sub for : scope 2';
   is CALLER,    $sub,   'block sub for : caller';
   is CALLER(0), $sub,   'block sub for : caller 0';
   is CALLER(1), $top,   'block sub for : caller 1';
   is CALLER(2), $top,   'block sub for : caller 2';
   eval {
    my $eval = HERE;
    is SCOPE,     $eval,  'block sub for eval : scope';
    is SCOPE(0),  $eval,  'block sub for eval : scope 0';
    is SCOPE(1),  $loop,  'block sub for eval : scope 1';
    is SCOPE(2),  $sub,   'block sub for eval : scope 2';
    is SCOPE(3),  $block, 'block sub for eval : scope 3';
    is CALLER,    $eval,  'block sub for eval : caller';
    is CALLER(0), $eval,  'block sub for eval : caller 0';
    is CALLER(1), $sub,   'block sub for eval : caller 1';
    is CALLER(2), $top,   'block sub for eval : caller 2';
    is CALLER(3), $top,   'block sub for eval : caller 3';
   }
  }
 }->();
}
