#!/usr/bin/env perl

=pod
=encoding utf8

=head1 NAME

 BBS::Universal

 =============================================================
  ____  ____ ____    _   _       _                          _ 
 | __ )| __ ) ___|  | | | |_ __ (_)_   _____ _ __ ___  __ _| |
 |  _ \|  _ \___ \  | | | | '_ \| \ \ / / _ \ '__/ __|/ _` | |
 | |_) | |_) |__) | | |_| | | | | |\ V /  __/ |  \__ \ (_| | |
 |____/|____/____/   \___/|_| |_|_| \_/ \___|_|  |___/\__,_|_|

 =============================================================

=head1 DESCRIPTION

A Universal BBS that connects to TCP/IP instead of serial

It works with a variety of text encoding formats

=over 4

=item B<ASCII>

Simple plain ASCII text

=item B<ATASCII>

Atari 8 bit ATASCII

It has graphics characters and cursor movement

=item B<PETSCII>

Commodore 8 bit PETSCII

It has color, graphics characters and cursor movement

=item B<VT102>

DEC VT-102 encoded text

It has color, graphics characters and cursor movement.  Typically used on Terminals and Unix/Linux/Windows/Mac consoles and terminal clients.

=back

=cut

use strict;
use English qw( -no_match_vars );
use Config;
use constant {    # Others are imported
    MAX_THREADS => 16,
};

## Imported from above:
#
# TRUE, FALSE, ASCII, ATASCII, PETSCII, VT102, _configuration

use threads (
    'yield',
    'exit' => 'threads_only',
    'stringify',
);
use threads::shared;

use DateTime;
use Time::HiRes qw(time sleep);
use Term::ANSIScreen;
use Sys::CPU;
use IO::Socket::INET;
use Debug::Easy;
use Getopt::Long;

use BBS::Universal;

BEGIN {
    our $VERSION = '0.001';
} ## end BEGIN

my $RUNNING : shared = TRUE;
my $SYSOP : shared   = FALSE;
my $TEST : shared    = FALSE;
my $LEVEL = 'ERROR';
my $SERVER_THREADS = {};

GetOptions(
    'test'  => \$TEST,
    'sysop' => \$SYSOP,
	'debug=s' => \$LEVEL,
);

our $DEBUG = Debug::Easy->new(
	'LogLevel' => $LEVEL,
	'Color'    => TRUE,
);

$SIG{'QUIT'} = $SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'HUP'} = \&hard_finish;

############## BBS Core ###################

my $CONF = _configuration();
$DEBUG->DEBUG(['Loading configuration hash into memory']);

main();

###########################################

sub finish {
    $RUNNING = FALSE;
    $DEBUG->INFO(['Shutting Down, waiting for all sessions to end nicely...']);
    clean_joinable();
    $DEBUG->INFO(['Shutdown Complete']);
} ## end sub finish

sub hard_finish {
    # Force a hard finish.
    #
    # It unceremoniously kills all threads (and disconnects anyone connected to them)

    $RUNNING = FALSE;
    $DEBUG->WARNING(['Forcing Shutdown...']);
    sleep 2;
    foreach my $thread (threads::running) {
        $thread->kill('KILL');
    }
    clean_joinable();
    $DEBUG->INFO(['Shutdown Complete']);
} ## end sub hard_finish

sub main {
	$DEBUG->DEBUG(['Main beginning']);
    my $key = '';

	if ($TEST) {
		run_bbs_sysop();
	} else {
		$SERVER_THREADS->{'MASTER'} = threads->create(\&run_bbs_sysop);
		foreach my $thread (1 .. MAX_THREADS) {
			my $name = sprintf('SERVER %02d',$thread);
			$SERVER_THREADS->{$name} = threads->create(\&run_bbs, $name);
		}
		$DEBUG->DEBUGMAX([keys %{$SERVER_THREADS}]);
		while ($RUNNING) {
			# SysOp stuff here
			threads->yield();
		}
	}
    finish();
	$DEBUG->DEBUG(['Main End']);
} ## end sub main

sub run_bbs {
	local $SIG{'QUIT'} = $SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'HUP'} = undef;
	my $thread_name = shift;
    my $host = $CONF->{'HOST'};
    my $port = $CONF->{'PORT'};

    while ($RUNNING) {
        $DEBUG->DEBUG(["$thread_name - Waiting for a connection for $host : $port"]);
        {
            my $socket = IO::Socket::INET->new(
                'LocalHost' => $host,
                'LocalPort' => $port,
                'Proto'     => 'tcp',
                'Listen'    => 5,
                'ReuseAddr' => FALSE,
                'Timeout'   => 15,
                'Blocking'  => TRUE,
            );
            my $error = undef;
            $error = "Cannot create socket for $!n" unless ($socket);
            if (defined($error)) {
                $DEBUG->ERROR([$error]);
                sleep 15;
            } else {
                $socket->autoflush();
                $DEBUG->DEBUG(['BBS Server Started']);
                my $client_socket = $socket->accept();
                my $bbs           = BBS::Universal->new(
                    {
                        'socket'        => $socket,
                        'client_socket' => $client_socket,
                        'debug'         => $DEBUG,
                    }
                );
                $bbs->run();
                shutdown($client_socket, 1);    # Hang up
                $socket->close();
            } ## end else [ if (defined($error)) ]
        }
    } ## end while ($RUNNING)
} ## end sub run_bbs

sub run_bbs_sysop {
	local $SIG{'QUIT'} = $SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'HUP'} = undef;
    while ($RUNNING) {
        if ($SYSOP || $TEST) {
            $DEBUG->DEBUG(['BBS Server Started']);
            my $bbs = BBS::Universal->new(
                {
                    'socket'        => undef,
                    'client_socket' => undef,
                    'debug'         => $DEBUG,
                }
            );
            $bbs->run();
            $SYSOP = FALSE;
			$RUNNING = FALSE if ($TEST);
        } ## end if ($SYSOP)
        threads->yield() if (! $TEST);    # Be friendly
    } ## end while ($RUNNING)
} ## end sub run_bbs_sysop

sub clean_joinable {
    my @joinable = threads->list(threads::joinable);
    foreach my $thread (@joinable) {
        $thread->join() if ($thread->is_joinable);    # Sanity checks always
    }
} ## end sub clean_joinable

__END__
