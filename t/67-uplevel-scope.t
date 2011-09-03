#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

use Scope::Upper qw<uplevel HERE UP>;

{
 our $x = 1;
 sub {
  local $x = 2;
  sub {
   local $x = 3;
   uplevel { is $x, 3, 'global variables scoping 1' } HERE;
  }->();
 }->();
}

{
 our $x = 4;
 sub {
  local $x = 5;
  sub {
   local $x = 6;
   uplevel { is $x, 6, 'global variables scoping 2' } UP;
  }->();
 }->();
}

sub {
 "abc" =~ /(.)/;
 sub {
  "xyz" =~ /(.)/;
  uplevel { is $1, 'x', 'match variables scoping 1' } HERE;
 }->();
}->();

sub {
 "abc" =~ /(.)/;
 sub {
  "xyz" =~ /(.)/;
  uplevel { is $1, 'x', 'match variables scoping 2' } UP;
 }->();
}->();
