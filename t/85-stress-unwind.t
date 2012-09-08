#!perl -T

use strict;
use warnings;

use lib 't/lib';
use Test::Leaner 'no_plan';

use Scope::Upper qw<unwind UP HERE>;

our ($call, @args);

$call = sub {
 my ($height, $level, $i) = @_;
 $level = $level ? 'UP ' x $level : 'HERE';
 return [ [ "unwind(\@args => $level)\n", [ \@args ] ] ];
};

# @_[0 .. $#_] also ought to work, but it sometimes evaluates to nonsense in
# scalar context on perl 5.8.5 and below.

sub list { wantarray ? @_ : $_[$#_] }

my @blocks = (
 [ 'sub {',     '}->()' ],
 [ 'eval {',    '}' ],
);

my @contexts = (
 [ '',        '; ()', 'v' ],
 [ 'scalar(', ')',    's' ],
 [ 'list(',   ')',    'l' ],
);

for my $block (@blocks) {
 $_ .= "\n" for @$block[0, 1];
}
for my $cxt (@contexts) {
 $_ .= "\n" for @$cxt[0, 1];
}

sub contextify {
 my ($cxt, $active, $exp, @items) = @_;
 return $exp unless $active;
 if ($cxt eq 'v') {
  return [ ];
 } elsif ($cxt eq 's') {
  return [ $cxt, @$exp ];
 } else {
  return [ @items, @$exp ];
 }
}

my $integer = 0;
my $items   = 0;

sub gen {
 my ($height, $level, $i) = @_;
 push @_, $i = 0 if @_ == 2;
 my @res;
 my $up = $i == $height + 1 ? $call->(@_) : gen($height, $level, $i + 1);
 my $active = $i <= ($height - $level);
 for my $base (@$up) {
  my ($code, $exp) = @$base;
  for my $blk (@blocks) {
   for my $cx (@contexts) {
    push @res, [
     $blk->[0] . $cx->[0] . $code . $cx->[1] . $blk->[1],
     contextify($cx->[2], $active, $exp),
    ];
    my @items = map $integer++, 0 .. ($items++ % 3);
    my $list  = join ', ', @items;
    push @res, [
     $blk->[0] . $cx->[0] . "($list, $code)" . $cx->[1] . $blk->[1],
     contextify($cx->[2], $active, $exp, @items),
    ];
   }
  }
 }
 return \@res;
}

sub linearize { join ', ', map { defined($_) ? $_ : '(undef)' } @_ }

sub expect {
 my @spec = @{$_[0]};
 my @acc;
 for my $s (reverse @spec) {
  if (ref $s) {
   unshift @acc, @$s;
  } elsif ($s =~ /^[0-9]+$/) {
   unshift @acc, $s;
  } elsif ($s eq 's') {
   @acc = (@acc ? $acc[-1] : undef);
  } else {
   return 'XXX';
  }
 }
 return linearize @acc;
}

sub runtests {
 my ($height, $level) = @_;
 my $i;
 my $tests = gen @_;
 for (@$tests) {
  ++$i;
  no warnings 'void';
  my $res = linearize eval $_->[0];
  my $exp;
  if ($@) {
   $res = '*TEST DID NOT COMPILE*';
  } else {
   $exp = expect $_->[1];
  }
  if ($res ne $exp) {
   diag <<DIAG;
=== This testcase failed ===
$_->[0];
==== vvvvv Errors vvvvvv ===
DIAG
  }
  is $res, $exp, "stress unwind $height $level $i";
 }
}

for ([ ], [ 'A' ], [ qw<B C> ]) {
 @args = @$_;
 runtests 0, 0;
 runtests 0, 1;
 runtests 1, 0;
 runtests 1, 1;
}
