package Scope::Upper::TestGenerator;

use strict;
use warnings;

our ($call, $test, $allblocks);

our $local_var = '$x';

our $local_decl = sub {
 my $x = $_[3];
 return "local $local_var = $x;\n";
};

our $local_cond = sub {
 my $x = $_[3];
 return defined $x ? "($local_var eq $x)" : "(!defined($local_var))";
};

our $local_test = sub {
 my ($height, $level, $i, $x) = @_;
 my $cond = $local_cond->(@_);
 return "ok($cond, 'local h=$height, l=$level, i=$i');\n";
};

my @blocks = (
 [ '{',         '}' ],
 [ 'sub {',     '}->();' ],
 [ 'do {',      '};' ],
 [ 'eval {',    '};' ],
 [ 'for (1) {', '}' ],
 [ 'eval q[',   '];' ],
);

sub import {
 if ("$]" >= 5.010_001) {
  push @blocks, [ 'given (1) {', '}' ];
  require feature;
  feature->import('switch');
 }
}

@blocks = map [ map "$_\n", @$_ ], @blocks;

sub _block {
 my ($height, $level, $i) = @_;
 my $j = $height - $i;
 $j = 0 if $j > $#blocks or $j < 0;
 return [ map "$_\n", @{$blocks[$j]} ];
}

sub gen {
 my ($height, $level, $i, $x) = @_;

 if (@_ == 2) {
  $i = 0;
  push @_, $i;
 }

 return $call->(@_) if $height < $i;

 my @res;
 my @blks = $allblocks ? @blocks : _block(@_);

 my $up   = gen($height, $level, $i + 1, $x);
 my $t    = $test->(@_);
 my $loct = $local_test->(@_);
 for my $base (@$up) {
  for my $blk (@blks) {
   push @res, join '', $blk->[0], $base, $t, $loct, $blk->[1];
  }
 }

 $_[3]    = $x = $i + 1;
 $up      = gen($height, $level, $i + 1, $x);
 $t       = $test->(@_);
 my $locd = $local_decl->(@_);
 $loct    = $local_test->(@_);
 for my $base (@$up) {
  for my $blk (@blks) {
   push @res, join '', $blk->[0], $locd, $base, $t, $loct, $blk->[1];
  }
 }

 return \@res;
}

1;
