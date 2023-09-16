
use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use Config;
use Term::ANSIColor;

print colored(['red'], '==============================================================================') . "\n" .
colored(['red'], '================') . ' A Universal ' . colored(['cyan'], 'BBS') . ' ' . colored(['green'], 'Server') . ' For ' . colored(['blue'], 'R') . colored(['yellow'],'e') . colored(['magenta'],'t') . colored(['bright_green'], 'r') . colored(['bright_red'], 'o') . ' Computers ' . colored(['red'], '==================') . "\n" .
colored(['red'], '==============================================================================') . "\n\n";

if (WriteMakefile(
    NAME               => 'BBS::Universal',
    AUTHOR             => q{Richard Kelsch <rich@rk-internet.com>},
    VERSION_FROM       => 'lib/BBS/Universal.pm',
    ABSTRACT           => 'Universal BBS Server',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006001,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'  => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => '0.44',
    },
    PREREQ_FATAL   => 1,
    PREREQ_PM      => {
        'Time::HiRes'                  => '1.9715',
		'Text::Format'                 => '0.62',
        'Term::ANSIColor'              => '4.00',
		'Term::ANSIScreen'             => '1.50',
        'DateTime'                     => '1.18',
        'File::Basename'               => 0,
		'Text::SimpleTable::AutoWidth' => '0.09',
    },
    dist  => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',},
    clean => {FILES    => 'BBS-Universal-* _build* *bak *old'},
)) {
    exit(0);
}

exit(1);

