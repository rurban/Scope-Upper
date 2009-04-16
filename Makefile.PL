use strict;
use warnings;
use ExtUtils::MakeMaker;

my $dist = 'Scope-Upper';

my %META = (
 configure_requires => {
  'ExtUtils::MakeMaker' => 0,
 },
 build_requires => {
  'ExtUtils::MakeMaker' => 0,
  'Test::More'          => 0,
 },
 resources => {
  bugtracker => "http://rt.cpan.org/NoAuth/ReportBug.html?Queue=$dist",
  homepage   => "http://search.cpan.org/dist/$dist/",
  license    => 'http://dev.perl.org/licenses/',
  repository => "http://git.profvince.com/?p=perl/modules/$dist.git",
 },
);

WriteMakefile(
    NAME             => 'Scope::Upper',
    AUTHOR           => 'Vincent Pit <perl@profvince.com>',
    LICENSE          => 'perl',
    VERSION_FROM     => 'lib/Scope/Upper.pm',
    ABSTRACT_FROM    => 'lib/Scope/Upper.pm',
    PL_FILES         => {},
    PREREQ_PM        => {
        'Exporter' => 0,
        'XSLoader' => 0,
    },
    MIN_PERL_VERSION => 5.006,
    META_MERGE       => \%META,
    dist             => {
        PREOP    => 'pod2text lib/Scope/Upper.pm > $(DISTVNAME)/README',
        COMPRESS => 'gzip -9f', SUFFIX => 'gz'
    },
    clean            => {
        FILES => "$dist-* *.gcov *.gcda *.gcno cover_db Debian_CPANTS.txt"
    },
);

package MY;

sub postamble {
 return <<'POSTAMBLE';
testdeb: all
	PERL_DL_NONLAZY=1 PERLDB_OPTS="NonStop=1" prove --exec='$(PERL) -d -T -I$(INST_LIB) -I$(INST_ARCHLIB)' $(TEST_FILES)
POSTAMBLE
}
