#!perl -T

use strict;
use warnings;

use lib 't/lib';
use Scope::Upper::TestThreads;

use Test::Leaner;

use Scope::Upper qw<uid validate_uid UP HERE>;

my $top = uid;

sub cb {
 my $tid  = threads->tid();

 my $here = uid;
 my $up;
 {
  $up = uid HERE;
  is uid(UP), $here, "uid(UP) == \$here in block (in thread $tid)";
 }

 is uid(UP), $top, "uid(UP) == \$top (in thread $tid)";

 usleep rand(1e6);

 ok validate_uid($here), "\$here is valid (in thread $tid)";
 ok !validate_uid($up),  "\$up is no longer valid (in thread $tid)";

 return $here;
}

my %uids;
my $threads = 0;
for my $thread (map threads->create(\&cb), 1 .. 30) {
 ++$threads;
 my $tid = $thread->tid;
 my $uid = $thread->join;
 ++$uids{$uid};
 ok !validate_uid($uid), "\$here is no longer valid (out of thread $tid)";
}

is scalar(keys %uids), $threads, 'all the UIDs were different';

done_testing($threads * 5 + 1);
