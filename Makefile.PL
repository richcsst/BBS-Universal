package BBS::Universal;

use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use Config;
use Term::ANSIColor;
use Time::HiRes qw(sleep);

$|=1;
system('clear');
sleep 1;
baud_print('> ');
sleep 1;
baud_print("ATDT BBS::Universal\n\n");
sleep 2;
baud_print('Connected ');
sleep 0.5;
baud_print("300 baud...\n\n");
sleep 1;

baud_print('==============================================================================' . "\n");
baud_print(color('red'));
baud_print('        ____  ____ ____    _   _       _                          _' . "\n");
baud_print(color('yellow'));
baud_print('       | __ )| __ ) ___|  | | | |_ __ (_)_   _____ _ __ ___  __ _| |' . "\n");
baud_print(color('green'));
baud_print(q{       |  _ \|  _ \___ \  | | | | '_ \| \ \ / / _ \ '__/ __|/ _` | |} . "\n");
baud_print(color('magenta'));
baud_print('       | |_) | |_) |__) | | |_| | | | | |\ V /  __/ |  \__ \ (_| | |' . "\n");
baud_print(color('bright_blue'));
baud_print('       |____/|____/____/   \___/|_| |_|_| \_/ \___|_|  |___/\__,_|_|' . "\n\n");
baud_print(color('reset'));
baud_print("==============================================================================\n\n");

baud_print('TCP/IP ' . colored(['red'],'R') . colored(['yellow'],'e') . colored(['green'],'t') . colored(['magenta'],'r') . colored(['bright_blue'],'o') . 
  " BBS software for your modern computer\n\n");

print color('cyan');
if (WriteMakefile(
    NAME               => 'BBS::Universal',
    AUTHOR             => q{Richard Kelsch <rich@rk-internet.com>},
    VERSION_FROM       => 'lib/BBS/Universal.pm',
    ABSTRACT           => 'Universal BBS Server',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006001,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'  => 0,
        'Time::HiRes'          => 0,
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
    print color('reset');
    sleep 1;
    baud_print("\nProcess complete\n\n");
    sleep 1;
    baud_print("Disconnecting...");
    sleep 1;
    print "\n\n";

    exit(0);
}

print color('reset');
exit(1);

sub baud_print {
    my $text = shift;
    my $l = length($text) - 1;
    foreach my $c (0 .. $l) {
        print substr($text,$c,1);
        sleep(0.02);
    }
}
