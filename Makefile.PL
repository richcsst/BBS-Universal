#!/usr/bin/env perl

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
print "WOPR Retro-Terminal.  Hayes modem ready 8/N/1 2400 bps\n";
sleep 1 unless ($fast);
baud_print('> ');
sleep 1 unless ($fast);
baud_print("ATDT BBS::Universal\n\n");
sleep 2 unless ($fast);
baud_print('Connected ... ');
sleep 1 unless ($fast);
baud_print("2400 baud...\n\n");
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

# Merge files because you tick me off Perl

baud_print("Creating a proper Universal.pm ... ");
merge();
baud_print(colored(['green'],"Done\n\n"));

#

if (
    WriteMakefile(
        NAME               => 'BBS::Universal',
        AUTHOR             => q{Richard Kelsch <rich@rk-internet.com>},
        VERSION_FROM       => 'lib/BBS/Universal.pm',
        ABSTRACT           => 'Universal BBS Server',
        PL_FILES           => {},
        MIN_PERL_VERSION   => 5.006001,
        CONFIGURE_REQUIRES => {
            'ExtUtils::MakeMaker' => '7.62',
            'Time::HiRes'         => '1.9767',
            'Term::ANSIColor'     => '5.01',
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
            'File::Basename'               => '2.85',
            'Text::SimpleTable'            => '2.07',
            'DBI'                          => '1.643',
            'DBD::mysql'                   => '4.050',
            'Term::ReadKey'                => '2.38',
            'IO::Socket::INET'             => '1.46',
            'Debug::Easy'                  => '2.11',
			'List::Util'                   => '1.60',
			'utf8'                         => 0,
        },

		EXE_FILES => ['bin/bbs.pl'],
        dist    => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
        clean   => { FILES    => 'BBS-Universal-* _build* *bak *old' },
#        license => ['gpl_3'], # GNU Public License Version 3
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
            sleep(0.0025);    # 2400 baud
        }
    } ## end else [ if ($fast) ]
} ## end sub baud_print

sub merge {
	my @dir;
	opendir(my $DIR,'lib/BBS/Universal/');
	chomp(@dir = readdir($DIR));
	closedir($DIR);

	my $master = slurp_file('src/Universal.pm.template');
	foreach my $file (sort(@dir)) {
		next if ($file !~ /\.pm$/);
		my $shortfile = "$file";
		$shortfile =~ s/\.pm//;
		$shortfile = uc($shortfile) . '_VERSION';
		open(my $FILE,"lib/BBS/Universal/$file");
		chomp(my @lines = <$FILE>);
		close($FILE);
		my $text = '';
		foreach my $line (@lines) {
			$line =~ s/^1\;//;
			$line =~ s/^package/\# package/;
			if ($line =~ /^BEGIN/) {
				$line =~ s/BEGIN \{ //;
				$line =~ s/ \}//;
				$line =~ s/\$VERSION/\$$shortfile/;
				$master =~ s/BEGIN \{(.*?)\} \#/BEGIN \{$1    $line\n\} #/s;
			} else {
				$text .= "$line\n";
			}
		}
		$master =~ s/\# MANUAL IMPORT HERE #/$text \n\n\# MANUAL IMPORT HERE \#/;
	}
	$master =~ s/\# MANUAL IMPORT HERE \#//;
	while($master =~ /\n\n\n+/s) {
		$master =~ s/\n\n\n+/\n\n/gs;
	}
	open(my $OUT,'>','lib/BBS/Universal.pm');
	print $OUT $master;
	close($OUT);
}

sub slurp_file {
	my $file = shift;
	return( do { local (@ARGV, $/) = $file; <> } );
}

__END__

