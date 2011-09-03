#!perl -T

use strict;
use warnings;

use Test::More tests => (1 * 3 + 2 * 4 + 3 * 5) * 2 + 7 + 5 + 6 + 5;

use Scope::Upper qw<uplevel HERE UP TOP>;

our ($desc, $target);

my @cxt;

sub three {
 my ($depth, $code) = @_;
 $cxt[0] = HERE;
 $target = $cxt[$depth];
 &uplevel($code => $target);
 pass("$desc: reached end of three()");
}

my $two = sub {
 $cxt[1] = HERE;
 three(@_);
 pass("$desc: reached end of \$two");
};

sub one {
 $cxt[2] = HERE;
 $two->(@_);
 pass("$desc: reached end of one()");
}

sub tester_sub {
 is(HERE, $target, "$desc: right context");
}

my $tester_anon = sub {
 is(HERE, $target, "$desc: right context");
};

my @subs = (\&three, $two, \&one);

for my $height (0 .. 2) {
 my $base = $subs[$height];

 for my $anon (0, 1) {
  my $code = $anon ? $tester_anon : \&tester_sub;

  for my $depth (0 .. $height) {
   local $target;
   local $desc = "uplevel at depth $depth/$height";
   $desc .= $anon ? ' (anonymous callback)' : ' (named callback)';

   local $@;
   eval { $base->($depth, $code) };
   is $@, '', "$desc: no error";
  }
 }
}

{
 my $desc = 'uplevel called without a code reference';
 local $@;
 eval {
  three(0, "wut");
  fail "$desc: uplevel should have croaked";
 };
 like $@, qr/^First argument to uplevel must be a code reference/,"$desc: dies";
}

sub four {
 my $desc = shift;
 my $cxt  = HERE;
 uplevel { is HERE, $cxt, "$desc: right context" };
 pass "$desc: reached end of four()";
}

{
 my $desc = 'uplevel called without a target';
 local $@;
 eval {
  four($desc);
 };
 is $@, '', "$desc: no error";
}

{
 my $desc = 'uplevel to top';
 local $@;
 eval {
  uplevel sub { fail "$desc: uplevel body should not be executed" }, TOP;
  fail "$desc: uplevel should have croaked";
 };
 like $@, qr/^Can't uplevel outside a subroutine/, "$desc: dies";
}

{
 my $desc = 'uplevel to eval 1';
 local $@;
 eval {
  uplevel sub { fail "$desc: uplevel body should not be executed" }, HERE;
  fail "$desc: uplevel should have croaked";
 };
 like $@, qr/^Can't uplevel to an eval frame/, "$desc: dies";
}

{
 my $desc = 'uplevel to eval 2';
 local $@;
 sub {
  eval {
   uplevel {
    fail "$desc: uplevel body should not be executed"
   };
   fail "$desc: uplevel should have croaked";
  };
  return;
 }->();
 like $@, qr/^Can't uplevel to an eval frame/, "$desc: dies";
}

# Target destruction

{
 our $destroyed;
 sub Scope::Upper::TestCodeDestruction::DESTROY { ++$destroyed }

 {
  local $@;
  local $destroyed = 0;
  my $desc = 'target destruction 1';

  {
   my $lexical;
   my $target = sub {
    my $code = shift;
    ++$lexical;
    $code->();
   };
   $target = bless $target, 'Scope::Upper::TestCodeDestruction';

   eval {
    $target->(
     sub {
      uplevel {
       is $destroyed, 0, "$desc: not yet 1";
      } UP;
      is $destroyed, 0, "$desc: not yet 2";
     },
    );
   };
   is $@,         '', "$desc: no error";
   is $destroyed, 0,  "$desc: not yet 3";
  }

  is $destroyed, 1, "$desc: target is detroyed";
 }

 SKIP: {
  skip 'This fails even with a plain subroutine call on 5.8.x' => 6
                                                                if "$]" < 5.009;
  local $@;
  local $destroyed = 0;
  my $desc = 'target destruction 2';

  {
   my $lexical;
   my $target = sub {
    my $code = shift;
    ++$lexical;
    $code->();
   };
   $target = bless $target, 'Scope::Upper::TestCodeDestruction';

   eval {
    $target->(
     sub {
      uplevel {
       $target->(sub {
        is $destroyed, 0, "$desc: not yet 1";
       });
       is $destroyed, 0, "$desc: not yet 2";
      } UP;
      is $destroyed, 0, "$desc: not yet 3";
     },
    );
   };
   is $@,         '', "$desc: no error";
   is $destroyed, 0,  "$desc: not yet 4";
  }

  is $destroyed, 1, "$desc: target is detroyed";
 }

 {
  local $@;
  local $destroyed = 0;
  my $desc = 'target destruction 3';

  {
   my $lexical;
   my $target = sub {
    ++$lexical;
    if (@_) {
     my $code = shift;
     $code->();
    } else {
     is $destroyed, 0, "$desc: not yet 1";
    }
   };
   $target = bless $target, 'Scope::Upper::TestCodeDestruction';

   eval {
    $target->(
     sub {
      &uplevel($target => UP);
      is $destroyed, 0, "$desc: not yet 2";
     },
    );
   };
   is $@,         '', "$desc: no error";
   is $destroyed, 0,  "$desc: not yet 3";
  }

  is $destroyed, 1, "$desc: target is detroyed";
 }
}
