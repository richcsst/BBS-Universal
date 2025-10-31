#!/usr/bin/env perl

use 5.020;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;
use Config;
use Term::ANSIColor;
use Time::HiRes qw(sleep);

# It's nolstalgia folks

my $fast  = (scalar(@ARGV)) ? 1 : 0;    # Pass anything and it means Fast
my $speed = 0.00125;                     # For sleep to simulate 2400 baud

$| = 1;                                 # Turn off buffering
print chr(27) . '[2J' . chr(27) . '[H' . chr(27) . '[0m';
if ($fast) {
	print "WOPR Retro-Terminal.  Hayes modem ready 8/N/1 57,600 bps\n";
} else {
	print "WOPR Retro-Terminal.  Hayes modem ready 8/N/1 4800 bps\n";
}
sleep 1 unless ($fast);
baud_print('> ');
sleep 1 unless ($fast);
baud_print("ATDT BBS::Universal\n\n");
sleep 2 unless ($fast);
baud_print('Connected ... ');
sleep 1 unless ($fast);
if ($fast) {
	print "57,600 baud...\n\n";
} else {
	baud_print("4800 baud...\n\n");
}
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
baud_print(colored(['green'], "Done\n\n"));

#

WriteMakefile(
	NAME               => 'BBS::Universal',
	AUTHOR             => q{Richard Kelsch <rkelsch@cpan.org>},
	VERSION_FROM       => 'lib/BBS/Universal.pm',
	ABSTRACT           => 'Universal BBS Server',
	PL_FILES           => {},
	MIN_PERL_VERSION   => 5.020000,
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => '7.20',
		'Time::HiRes'         => '1.9700',
		'Term::ANSIColor'     => '4.00',
		'Config'              => 0,
	},
	BUILD_REQUIRES => {
		'Test::More' => '0.44',
	},
	PREREQ_PRINT => 1,
	PREREQ_FATAL => 1,
	PREREQ_PM => {
		'Config'                 => 0,
		'English'                => 0,
		'Time::HiRes'            => 0,
		'Text::Format'           => '0.50',
		'Term::ANSIColor'        => '4.00',
		'Term::ANSIScreen'       => '1.50',
		'DateTime'               => '1.18',
		'File::Basename'         => '2.85',
		'Text::SimpleTable'      => '2.07',
		'DBI'                    => '1.50',
		'DBD::mysql'             => '4.00',
		'Term::ReadKey'          => '2.30',
		'IO::Socket'             => '1.20',
		'Debug::Easy'            => '2.11',
		'List::Util'             => '1.40',
		'Cache::Memcached::Fast' => '0.25',
		'XML::RSS::LibXML'       => '0.3105',
		'Number::Format'         => 0,
	},

	EXE_FILES => ['bin/bbs'],
	dist      => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean     => { FILES    => 'BBS-Universal-* _build* *bak *old' },
	LICENSE   => 'artistic',
);

print chr(27) . '[0m', color('reset');
sleep 1 unless ($fast);

baud_print("\nProcess complete\n\n");
sleep 1 unless ($fast);

baud_print("Disconnecting...");
sleep 1 unless ($fast);

print "\n\n";

exit(0);

sub baud_print {
    my $text = shift;
    if ($fast) {
        print $text;
    } else {
        my $l = length($text) - 1;
        foreach my $c (0 .. $l) {
            print substr($text, $c, 1);
            sleep($speed);
        }
    } ## end else [ if ($fast) ]
} ## end sub baud_print

sub merge {    # Perl sometimes is a pain in the ...
    my @dir;
    opendir(my $DIR, 'lib/BBS/Universal/');
    chomp(@dir = readdir($DIR));
    closedir($DIR);

    my $master = slurp_file('src/Universal.pm');
    foreach my $file (sort(@dir)) {
        next if ($file !~ /\.pm$/);
        my $shortfile = "$file";
        $shortfile =~ s/\.pm//;
        $shortfile = uc($shortfile) . '_VERSION';
        open(my $FILE, '<', "lib/BBS/Universal/$file");
        chomp(my @lines = <$FILE>);
        close($FILE);
        my $text = '';

        foreach my $line (@lines) {
            $line =~ s/^1\;//;
            $line =~ s/^package/\# package/;
            if ($line =~ /^BEGIN/) {
                $line   =~ s/BEGIN \{ //;
                $line   =~ s/ \}//;
                $line   =~ s/\$VERSION/\$$shortfile/;
                $master =~ s/(\# VERSIONS \#)/    $line\n$1/s;
            } else {
                $text .= "$line\n";
            }
        } ## end foreach my $line (@lines)
        $master =~ s/\# MANUAL IMPORT HERE #/$text \n\n\# MANUAL IMPORT HERE \#/;

    } ## end foreach my $file (sort(@dir...))
    $master =~ s/\# (VERSIONS|MANUAL IMPORT HERE) \#\n//s;
    while ($master =~ /\n\n\n+/s) {
        $master =~ s/\n\n\n+/\n\n/gs;
    }
    open(my $OUT, '>', 'lib/BBS/Universal.pm');
    print $OUT $master;
    close($OUT);
} ## end sub merge

sub slurp_file {
    my $file = shift;
    return (
        do { local (@ARGV, $/) = $file; <> }
    );
} ## end sub slurp_file

__END__

