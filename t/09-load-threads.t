#!perl

use strict;
use warnings;

use lib 't/lib';
use VPIT::TestHelpers;

my ($module, $thread_safe_var);
BEGIN {
 $module          = 'Scope::Upper';
 $thread_safe_var = 'Scope::Upper::SU_THREADSAFE()';
}

sub load_test {
 my $res;
 {
  my $var = 0;
  if (defined &Scope::Upper::reap) {
   &Scope::Upper::reap(sub { $var *= 2 });
   $var = 1;
  }
  $res = $var;
 }
 if ($res == 2) {
  return 1;
 } elsif ($res == 1) {
  return 2;
 } else {
  return $res;
 }
}

# Keep the rest of the file untouched

BEGIN {
 my $is_threadsafe;

 if (defined $thread_safe_var) {
  my $stat = run_perl "require POSIX; require $module; exit($thread_safe_var ? POSIX::EXIT_SUCCESS() : POSIX::EXIT_FAILURE())";
  require POSIX;
  my $res  = $stat >> 8;
  if ($res == POSIX::EXIT_SUCCESS()) {
   $is_threadsafe = 1;
  } elsif ($res == POSIX::EXIT_FAILURE()) {
   $is_threadsafe = !1;
  }
  if (not defined $is_threadsafe) {
   skip_all "Could not detect if $module is thread safe or not";
  }
 }

 VPIT::TestHelpers->import(
  threads => [ $module => $is_threadsafe ],
 )
}

my $could_not_create_thread = 'Could not create thread';

use Test::Leaner tests => 1 + (2 + 2 * 2) + 6 + (2 * 4) + 2;

sub is_loaded {
 my ($affirmative, $desc) = @_;

 my $res = load_test();

 if ($affirmative) {
  is $res, 1, "$desc: module loaded";
 } else {
  is $res, 0, "$desc: module not loaded";
 }
}

BEGIN {
 local $@;
 my $code = eval "sub { require $module }";
 die $@ if $@;
 *do_load = $code;
}

is_loaded 0, 'main body, beginning';

# Test serial loadings

SKIP: {
 my $thr = spawn(sub {
  my $here = "first serial thread";
  is_loaded 0, "$here, beginning";

  do_load;
  is_loaded 1, "$here, after loading";

  return;
 });

 skip "$could_not_create_thread (serial 1)" => 2 unless defined $thr;

 $thr->join;
 if (my $err = $thr->error) {
  die $err;
 }
}

is_loaded 0, 'main body, in between serial loadings';

SKIP: {
 my $thr = spawn(sub {
  my $here = "second serial thread";
  is_loaded 0, "$here, beginning";

  do_load;
  is_loaded 1, "$here, after loading";

  return;
 });

 skip "$could_not_create_thread (serial 2)" => 2 unless defined $thr;

 $thr->join;
 if (my $err = $thr->error) {
  die $err;
 }
}

is_loaded 0, 'main body, after serial loadings';

# Test nested loadings

SKIP: {
 my $thr = spawn(sub {
  my $here = 'parent thread';
  is_loaded 0, "$here, beginning";

  SKIP: {
   my $kid = spawn(sub {
    my $here = 'child thread';
    is_loaded 0, "$here, beginning";

    do_load;
    is_loaded 1, "$here, after loading";

    return;
   });

   skip "$could_not_create_thread (nested child)" => 2 unless defined $kid;

   $kid->join;
   if (my $err = $kid->error) {
    die "in child thread: $err\n";
   }
  }

  is_loaded 0, "$here, after child terminated";

  do_load;
  is_loaded 1, "$here, after loading";

  return;
 });

 skip "$could_not_create_thread (nested parent)" => (3 + 2) unless defined $thr;

 $thr->join;
 if (my $err = $thr->error) {
  die $err;
 }
}

is_loaded 0, 'main body, after nested loadings';

# Test parallel loadings

use threads;
use threads::shared;

my @locks = (1) x 5;
share($_) for @locks;

sub sync_master {
 my ($id) = @_;

 {
  lock $locks[$id];
  $locks[$id] = 0;
  cond_broadcast $locks[$id];
 }
}

sub sync_slave {
 my ($id) = @_;

 {
  lock $locks[$id];
  cond_wait $locks[$id] until $locks[$id] == 0;
 }
}

SKIP: {
 my $thr1 = spawn(sub {
  my $here = 'first simultaneous thread';
  is_loaded 0, "$here, beginning";
  sync_slave 0;

  do_load;
  is_loaded 1, "$here, after loading";
  sync_slave 1;
  sync_slave 2;

  sync_slave 3;
  is_loaded 1, "$here, still loaded while also loaded in the other thread";
  sync_slave 4;

  is_loaded 1, "$here, end";

  return;
 });

 skip "$could_not_create_thread (parallel 1)" => (4 * 2) unless defined $thr1;

 my $thr2 = spawn(sub {
  my $here = 'second simultaneous thread';
  is_loaded 0, "$here, beginning";
  sync_slave 0;

  sync_slave 1;
  is_loaded 0, "$here, loaded in other thread but not here";
  sync_slave 2;

  do_load;
  is_loaded 1, "$here, after loading";
  sync_slave 3;
  sync_slave 4;

  is_loaded 1, "$here, end";

  return;
 });

 sync_master($_) for 0 .. $#locks;

 $thr1->join;
 if (my $err = $thr1->error) {
  die $err;
 }

 skip "$could_not_create_thread (parallel 2)" => (4 * 1) unless defined $thr2;

 $thr2->join;
 if (my $err = $thr2->error) {
  die $err;
 }
}

is_loaded 0, 'main body, after simultaneous threads';

do_load;
is_loaded 1, 'main body, loaded at end';
