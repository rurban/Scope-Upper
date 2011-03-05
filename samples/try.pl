#!perl

use strict;
use warnings;

use blib;

use Scope::Upper qw<unwind want_at :words>;

sub try (&) {
 my @result = shift->();
 my $cx = SUB UP; # Point to the sub above this one
 unwind +(want_at($cx) ? @result : scalar @result) => $cx;
}

sub zap {
 try {
  my @things = qw<a b c>;
  return @things; # returns to try() and then outside zap()
 };
 print "NOT REACHED\n";
}

my @stuff = zap(); # @stuff contains qw<a b c>
my $stuff = zap(); # $stuff contains 3

print "zap() returns @stuff in list context and $stuff in scalar context\n";
