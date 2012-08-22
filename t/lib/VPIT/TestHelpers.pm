package VPIT::TestHelpers;

use strict;
use warnings;

my %exports = (
 load_or_skip => \&load_or_skip,
 skip_all     => \&skip_all,
);

sub import {
 my $pkg = caller;
 while (my ($name, $code) = each %exports) {
  no strict 'refs';
  *{$pkg.'::'.$name} = $code;
 }
}

sub skip_all {
 my ($msg) = @_;
 require Test::More;
 Test::More::plan(skip_all => $msg);
}

sub diag {
 require Test::More;
 Test::More::diag($_) for @_;
}

our $TODO;
local $TODO;

sub load_or_skip {
 my ($pkg, $ver, $imports, $desc) = @_;
 my $spec = $ver && $ver !~ /^[0._]*$/ ? "$pkg $ver" : $pkg;
 local $@;
 if (eval "use $spec (); 1") {
  $ver = do { no strict 'refs'; ${"${pkg}::VERSION"} };
  $ver = 'undef' unless defined $ver;
  if ($imports) {
   my @imports = @$imports;
   my $caller  = (caller 0)[0];
   local $@;
   my $res = eval <<"IMPORTER";
package
        $caller;
BEGIN { \$pkg->import(\@imports) }
1;
IMPORTER
   skip_all "Could not import '@imports' from $pkg $ver: $@" unless $res;
  }
  diag "Using $pkg $ver";
 } else {
  skip_all "$spec $desc";
 }
}

package VPIT::TestHelpers::Guard;

sub new {
 my ($class, $code) = @_;

 bless { code => $code }, $class;
}

sub DESTROY { $_[0]->{code}->() }

1;
