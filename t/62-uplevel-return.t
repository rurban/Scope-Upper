#!perl -T

use strict;
use warnings;

use Test::More tests => (10 + 5 + 4) * 2 + 11;

use Scope::Upper qw<uplevel HERE UP>;

# Basic

sub check (&$$) {
 my ($code, $exp_in, $desc) = @_;

 local $Test::Builder::Level = ($Test::Builder::Level || 0) + 1;

 my $exp_out = [ 'A', map("X$_", @$exp_in), 'Z' ];

 my @ret = sub {
  my @ret = &uplevel($code, HERE);
  is_deeply \@ret, $exp_in, "$desc: inside";
  @$exp_out;
 }->('dummy');

 is_deeply \@ret, $exp_out, "$desc: outside";
}

check { return } [ ], 'empty explicit return';

check { () }     [ ], 'empty implicit return';

check { return 1 } [ 1 ], 'one const scalar explicit return';

check { 2 }        [ 2 ], 'one const scalar implicit return';

{
 my $x = 3;
 check { return $x } [ 3 ], 'one lexical scalar explicit return';
}

{
 my $x = 4;
 check { $x }        [ 4 ], 'one lexical scalar implicit return';
}

{
 our $x = 3;
 check { return $x } [ 3 ], 'one global scalar explicit return';
}

{
 our $x = 4;
 check { $x }        [ 4 ], 'one global scalar implicit return';
}

check { return 1 .. 5 } [ 1 .. 5 ],  'five const scalar explicit return';

check { 6 .. 10 }       [ 6 .. 10 ], 'five const scalar implicit return';

# Mark

{
 my $desc = 'one scalar explict return between two others, without args';
 my @ret = sub {
  my @ret = (1, uplevel(sub { return 2 }), 3);
  is_deeply \@ret, [ 1 .. 3 ], "$desc: inside";
  qw<X Y>;
 }->('dummy');
 is_deeply \@ret, [ qw<X Y> ], "$desc: outside";
}

{
 my $desc = 'one scalar implict return between two others, without args';
 my @ret = sub {
  my @ret = (4, uplevel(sub { 5 }), 6);
  is_deeply \@ret, [ 4 .. 6 ], "$desc: inside";
  qw<X Y>;
 }->('dummy');
 is_deeply \@ret, [ qw<X Y> ], "$desc: outside";
}

{
 my $desc = 'one scalar explict return between two others, with args';
 my @ret = sub {
  my @ret = (1, uplevel(sub { return 2 }, 7 .. 9, HERE), 3);
  is_deeply \@ret, [ 1 .. 3 ], "$desc: inside";
  qw<X Y>;
 }->('dummy');
 is_deeply \@ret, [ qw<X Y> ], "$desc: outside";
}

{
 my $desc = 'one scalar implict return between two others, with args';
 my @ret = sub {
  my @ret = (4, uplevel(sub { 5 }, 7 .. 9, HERE), 6);
  is_deeply \@ret, [ 4 .. 6 ], "$desc: inside";
  qw<X Y>;
 }->('dummy');
 is_deeply \@ret, [ qw<X Y> ], "$desc: outside";
}

{
 my $desc = 'complex chain of calls';

 sub one   { "<",   two("{", @_, "}"), ">" }
 sub two   { "(", three("[", @_, "]"), ")" }
 sub three { (uplevel { "A", "B", four(@_) } @_, UP), "Z" }
 sub four  {
  is_deeply \@_, [ qw|[ { * } ]| ], "$desc: inside";
  @_
 }

 my @ret  = one('*');
 is_deeply \@ret, [ qw|< ( A B [ { * } ] Z ) >| ], "$desc: outside";
}

# Magic

{
 package Scope::Upper::TestMagic;

 sub TIESCALAR {
  my ($class, $cb) = @_;
  bless { cb => $cb }, $class;
 }

 sub FETCH { $_[0]->{cb}->(@_) }

 sub STORE { die "Read only magic scalar" }
}

{
 tie my $mg, 'Scope::Upper::TestMagic', sub { $$ };
 check { return $mg } [ $$ ], 'one magical scalar explicit return';
 check { $mg }        [ $$ ], 'one magical scalar implicit return';

 tie my $mg2, 'Scope::Upper::TestMagic', sub { $mg };
 check { return $mg2 } [ $$ ], 'one double magical scalar explicit return';
 check { $mg2 }        [ $$ ], 'one double magical scalar implicit return';
}

# Destruction

{
 package Scope::Upper::TestTimelyDestruction;

 sub new {
  my ($class, $flag) = @_;
  $$flag = 0;
  bless { flag => $flag }, $class;
 }

 sub DESTROY {
  ${$_[0]->{flag}}++;
 }
}

{
 my $destroyed;
 {
  sub {
   my $z = Scope::Upper::TestTimelyDestruction->new(\$destroyed);
   is $destroyed, 0, 'destruction 1: not yet 1';
   uplevel {
    is $destroyed, 0, 'destruction 1: not yet 2';
    $z;
   }, do { is $destroyed, 0, 'destruction 1: not yet 3'; () }
  }->('dummy');
  is $destroyed, 1, 'destruction 1: destroyed 1';
 }
 is $destroyed, 1, 'destruction 1: destroyed 2';
}

SKIP: {
 skip 'This fails even with a plain subroutine call on 5.8.x' => 6
                                                                if "$]" < 5.009;

 my $destroyed;
 {
  my $z = Scope::Upper::TestTimelyDestruction->new(\$destroyed);
  is $destroyed, 0, 'destruction 2: not yet 1';
  sub {
   is $destroyed, 0, 'destruction 2: not yet 2';
   (uplevel {
    is $destroyed, 0, 'destruction 2: not yet 3';
    return $z;
   }), do { is $destroyed, 0, 'destruction 2: not yet 4'; () }
  }->('dummy');
  is $destroyed, 0, 'destruction 2: not yet 5';
 }
 is $destroyed, 1, 'destruction 2: destroyed';
}
