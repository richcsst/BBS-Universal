package BBS::Universal;

use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use Config;
use Term::ANSIColor;
use Time::HiRes qw(sleep);

# It's nolstalgia folks

my $fast = (scalar(@ARGV)) ? 1 : 0;

$| = 1;    # Turn off buffering
print chr(27) . '[2J' . chr(27) . '[H' . chr(27) . '[0m';
print "WORP Retro-Terminal.  Hayes modem ready 8/N/1 1200 bps\n";
sleep 1 unless ($fast);
baud_print('> ');
sleep 1 unless ($fast);
baud_print("ATDT BBS::Universal\n\n");
sleep 2 unless ($fast);
baud_print('Connected ... ');
sleep 1 unless ($fast);
baud_print("1200 baud...\n\n");
sleep 1 unless ($fast);
baud_print("Welcome to...\n\n");
sleep 1 unless ($fast);
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

baud_print('TCP/IP ' . colored(['red'], 'R') . colored(['yellow'], 'e') . colored(['green'], 't') . colored(['magenta'], 'r') . colored(['bright_blue'], 'o') . " BBS software for your modern computer, written in Perl\n\n");

if (
    WriteMakefile(
        NAME               => 'BBS::Universal',
        AUTHOR             => q{Richard Kelsch <rich@rk-internet.com>},
        VERSION_FROM       => 'lib/BBS/Universal.pm',
        ABSTRACT           => 'Universal BBS Server',
        PL_FILES           => {},
        MIN_PERL_VERSION   => 5.006001,
        CONFIGURE_REQUIRES => {
            'ExtUtils::MakeMaker' => 0,
            'Time::HiRes'         => 0,
        },
        BUILD_REQUIRES => {
            'Test::More' => '0.44',
        },
        PREREQ_FATAL => 1,
        PREREQ_PM    => {
            'Time::HiRes'                  => '1.9715',
            'Text::Format'                 => '0.50',
            'Term::ANSIColor'              => '4.00',
            'Term::ANSIScreen'             => '1.50',
            'DateTime'                     => '1.18',
            'File::Basename'               => 0,
            'Text::SimpleTable::AutoWidth' => '0.09',
        },
        dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
        clean => { FILES    => 'BBS-Universal-* _build* *bak *old' },
    )
) {
    print chr(27) . '[0m', color('reset');
    sleep 1 unless ($fast);
    baud_print("\nProcess complete\n\n");
    sleep 1 unless ($fast);
    baud_print("Disconnecting...");
    sleep 1 unless ($fast);
    print "\n\n";

    exit(0);
} ## end if (WriteMakefile(NAME...))

print color('reset');
exit(0);

sub baud_print {
    my $text = shift;
    if ($fast) {
        print $text;
    } else {
        my $l = length($text) - 1;
        foreach my $c (0 .. $l) {
            print substr($text, $c, 1);
            sleep(0.005);    # 1200 baud
        }
    } ## end else [ if ($fast) ]
} ## end sub baud_print
