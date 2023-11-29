#!/usr/bin/env perl

# =============================================================
#  ____  ____ ____    _   _       _                          _
# | __ )| __ ) ___|  | | | |_ __ (_)_   _____ _ __ ___  __ _| |
# |  _ \|  _ \___ \  | | | | '_ \| \ \ / / _ \ '__/ __|/ _` | |
# | |_) | |_) |__) | | |_| | | | | |\ V /  __/ |  \__ \ (_| | |
# |____/|____/____/   \___/|_| |_|_| \_/ \___|_|  |___/\__,_|_|
#
# =============================================================

use strict;
use English qw( -no_match_vars );
use Config;
use constant {    # Others are imported
    MAX_THREADS => 30,
};

## Imported:
#
# TRUE, FALSE, ASCII, ATASCII, PETSCII, VT102, _configuration

use threads (
    'yield',
    'exit' => 'threads_only',
    'stringify',
);
use threads::shared;

use Cwd;
use DateTime;
use Time::HiRes qw(time sleep);
use IO::Socket::INET;
use Debug::Easy;
use Getopt::Long;
use Term::ReadKey;
use Term::ANSIColor;
use Term::ANSIScreen qw( :cursor :screen );
use Text::SimpleTable::AutoWidth;

use BBS::Universal;
use BBS::Universal::ASCII;
use BBS::Universal::ATASCII;
use BBS::Universal::PETSCII;
use BBS::Universal::VT102;
use BBS::Universal::Messages;
use BBS::Universal::SysOp;
use BBS::Universal::FileTransfer;
use BBS::Universal::Users;
use BBS::Universal::DB;

BEGIN {
    our $VERSION = '0.001';
}

# Shared with threads
our $RUNNING : shared = TRUE;
our $TEST : shared    = FALSE;
our @SERVER_STATUS : shared = ();
our $UPDATE : shared = TRUE;

my $OLDDIR         = getcwd;
my $LEVEL          = 'ERROR';
my $SERVER_THREADS = {};
my $START_ROW      = 14;
my $ROW_ADJUST     = 0;

GetOptions(
    'test'    => \$TEST,
    'debug=s' => \$LEVEL,
);

my $DEBUG = Debug::Easy->new(
    'LogLevel' => $LEVEL,
    'Color'    => TRUE,
);

$SIG{'QUIT'} = $SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'HUP'} = \&hard_finish;

############## BBS Core ###################

my $CONF = _configuration();
chdir($CONF->{'bbs_root'});

main();

###########################################

sub logo {
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();

	$ROW_ADJUST = 0;

    print setscroll(1,$hsize), cls, locate(1,1),colored(['on_white'], ' ' x $wsize), "\n";
    print color('red');
    print center(' ____  ____ ____    _   _       _                          _ ', $wsize) . "\n";
    print color('yellow');
    print center('| __ )| __ ) ___|  | | | |_ __ (_)_   _____ _ __ ___  __ _| |', $wsize) . "\n";
    print color('green');
    print center(q{|  _ \|  _ \___ \  | | | | '_ \| \ \ / / _ \ '__/ __|/ _` | |}, $wsize) . "\n";
    print color('magenta');
    print center('| |_) | |_) |__) | | |_| | | | | |\ V /  __/ |  \__ \ (_| | |', $wsize) . "\n";
    print color('bright_blue');
    print center('|____/|____/____/   \___/|_| |_|_| \_/ \___|_|  |___/\__,_|_|', $wsize) . "\n\n";
    print color('reset');
    print center(sprintf('Version %.03f', $BBS::Universal::VERSION), $wsize), "\n";
    print center('Written By Richard Kelsch',                        $wsize), "\n";
    print center('Copyright © 2023 Richard Kelsch',                  $wsize), "\n";
    print center('Licensed under the GNU Public License Version 3',  $wsize), "\n\n";
    print colored(['on_white'], ' ' x $wsize), "\n\n";
	return($wsize,$hsize,$wpixels,$hpixels);
}

sub main {
    $DEBUG->DEBUG(['Main beginning']);
    my $key = '';

    my ($wsize, $hsize, $wpixels, $hpixels) = logo();

	my ($width,$height) = ($wsize,$hsize);
    print locate(14, 1), cldown, 'Loading ' . MAX_THREADS . ' Threads ...';

    my $socket;
    unless ($TEST) {
        $socket = IO::Socket::INET->new(
            'LocalHost' => $CONF->{'HOST'},
            'LocalPort' => $CONF->{'PORT'},
            'Proto'     => 'tcp',
            'Listen'    => 5,
            'ReuseAddr' => FALSE,
            'Timeout'   => 5,
            'Blocking'  => TRUE,
        );
        my $error = undef;
        $error = "Cannot create socket for $!n" unless ($socket);
		if (defined($error)) {
			$DEBUG->ERROR([$error,'Local Mode Only']);
			sleep 5;
		} else {
			$DEBUG->DEBUG(["Waiting for a connection for $CONF->{host} : $CONF->{port}"]);
			foreach my $thread (1 .. MAX_THREADS) {
				{
					lock(@SERVER_STATUS);
					$SERVER_STATUS[$thread] = FALSE;
				}
				my $name = sprintf('SERVER %02d', $thread);
				$DEBUG->DEBUG(["$name Ready"]);
				$SERVER_THREADS->{$name} = threads->create(\&run_bbs,
					{
						'thread_number' => $thread,
					  'thread_name' => $name,
					  'socket' => $socket,
					  'debuglevel' => $LEVEL
					}
				);
				{
					lock($UPDATE);
					$UPDATE = TRUE;
				}
				servers_status(FALSE);
			}
			$DEBUG->DEBUGMAX([keys %{$SERVER_THREADS}]);
			$SIG{'ALRM'} = \&servers_status;
			{
				lock($UPDATE);
				$UPDATE = TRUE;
			}
			servers_status(TRUE);
		}
    } ## end unless ($TEST)
	print setscroll(($START_ROW + $ROW_ADJUST), $hsize);
	print locate(($START_ROW + $ROW_ADJUST), 1), cldown;
	print colored(['on_white'],' ' x $wsize), "\n\n";

	my $cmds = {
		'SHUTDOWN'   => sub {
			print "\n\nShutting down threads\n";
			{
				lock($RUNNING);
				$RUNNING = FALSE;
			}
		},
		'SYSOP'      => sub {
			run_bbs_sysop(TRUE);
		},
		'LOGIN'      => sub {
			run_bbs_sysop(FALSE);
		},
		'STATISTICS' => sub {
			statistics();
		},
		'USERS'      => sub {
			users_edit();
		},
	};
    while ($RUNNING) {
		($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
		if ($wsize != $width || $hsize != $height) {
			alarm(0);
			($wsize, $hsize, $wpixels, $hpixels) = logo();
			($width,$height) = ($wsize,$hsize);
			servers_status(TRUE);
		}
        my $command = _sysop_parse_menu($DEBUG,($START_ROW + $ROW_ADJUST + 2));
		print "$command\n";

		$cmds->{$command}->();
        threads->yield();
    } ## end while ($RUNNING)
    $socket->close() if (defined($socket));
    finish();
    $DEBUG->DEBUG(['Main End']);
	print "Thank you for using BBS Universal\n\n";
} ## end sub main

sub statistics {
	return(TRUE);
}


sub center {
    my $text  = shift;
    my $width = shift;

    my $size = length($text);
    return ($text) unless (defined($text) && $size > 0);
    my $padding = int(($width - $size) / 2);
    return (($padding > 0) ? ' ' x $padding . $text : $text);
} ## end sub center

sub servers_status {
	my $show_alarm = TRUE;
	if (scalar(@_)) {
		$show_alarm = shift;
	}
	if ($UPDATE) {
		alarm(0);
		my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
		my $stp = int($wsize / 24);
		my $steps = $stp;
		my @row = ();
		my $table = Text::SimpleTable::AutoWidth->new(
			max_width => $wsize,
		);
		my $count = 1;
		$ROW_ADJUST = 2;
		foreach my $name (sort(keys %{$SERVER_THREADS})) {
			my $status = '';
			if ($SERVER_STATUS[$count] == TRUE) {
				$status = 'CONNECTED';
			} elsif ($SERVER_STATUS[$count] == FALSE) {
				$status = 'IDLE';
			} else {
				$status = 'FINISHED';
			}
			push(@row,"$name -> $status");
			$steps--;
			if ($steps == 1) {
				$steps = $stp;
				$table->row(@row);
				@row = ();
				$ROW_ADJUST++;
			}
			$count++;
			threads->yield();
		}
		if (scalar(@row)) {
			while ($steps >= 1) {
				push(@row,' ');
				$steps--;
				threads->yield();
			}
			$ROW_ADJUST++;
			$table->row(@row);
			lock($UPDATE);
			$UPDATE = FALSE;
		}
		my $tbl = $table->draw();
		my $cn = colored(['green'],'CONNECTED');
		my $idl = colored(['magenta'],'IDLE');
		my $fn = colored(['red'],'FINISHED');
		$tbl =~ s/CONNECTED/$cn/g;
		$tbl =~ s/IDLE/$idl/g;
		$tbl =~ s/FINISHED/$fn/g;
		if ($show_alarm) {
			print savepos, chr(27),'[?25l',locate(14,1), $tbl, loadpos, chr(27), '[?25h';
			$SIG{ALRM} = \&servers_status;
			alarm(1);
		} else {
			print locate(14,1), $tbl;
		}
	}
	return(TRUE);
}

sub run_bbs {
    # Only allow the main program to respond to signals, not the threads
    local $SIG{'QUIT'} = $SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'HUP'} = $SIG{'ALRM'} = undef;
    my $params      = shift;
    my $thread_name = $params->{'thread_name'};
	my $thread_number = $params->{'thread_number'};
    my $socket      = $params->{'socket'};
    my $debug       = Debug::Easy->new(
        'LogLevel'        => $params->{'debuglevel'},
        'Color'           => TRUE,
        'Prefix'          => '%Date% %Time% %Benchmark% %Loglevel% ' . $thread_name . ' [%Subroutine%][%Lastline%] ',
        'DEBUGMAX-Prefix' => '%Date% %Time% %Benchmark% %Loglevel% ' . $thread_name . ' [%Module%][%Lines%] ',
    );
    $debug->DEBUG(["BBS Server Thread $thread_name Started"]);
    $debug->DEBUGMAX([$params]);

    while ($RUNNING) {
        {
            my $client_socket = $socket->accept();
            if (defined($client_socket)) {
				{
					lock(@SERVER_STATUS);
					$SERVER_STATUS[$thread_number] = TRUE;
					lock($UPDATE);
					$UPDATE = TRUE;
				}
				$debug->DEBUG(['Client connected from ' . $client_socket->peerhost() . ':' . $client_socket->peerport()]);
                my $bbs = BBS::Universal->new(
                    {
                        'thread_name'   => $thread_name . 'socket' => $socket,
                        'client_socket' => $client_socket,
                        'debug'         => $debug,
                        'debuglevel'    => $params->{'debuglevel'},
                    }
                );
                $bbs->run();
                shutdown($client_socket, 1);    # Hang up
				{
					lock(@SERVER_STATUS);
					$SERVER_STATUS[$thread_number] = FALSE;
					lock($UPDATE);
					$UPDATE = TRUE;
				}
            } ## end if (defined($client_socket...))
        }
		threads->yield();
    } ## end while ($RUNNING)
	{
		lock(@SERVER_STATUS);
		$SERVER_STATUS[$thread_number] = -1;
	}
    $debug->INFO(["Thread $thread_name shutting down"]);
} ## end sub run_bbs

sub run_bbs_sysop {
    # Only allow the main program to respond to signals, not the threads
    local $SIG{'QUIT'} = $SIG{'INT'} = $SIG{'KILL'} = $SIG{'TERM'} = $SIG{'HUP'} = undef;
    my $sysop = shift;
    while ($RUNNING) {
        if ($sysop) {
            my $bbs = BBS::Universal->new(
                {
                    'thread_name' => 'CONSOLE',
                    'debug'       => $DEBUG,
                }
            );
            $bbs->run($sysop);
        } ## end if ($sysop)
        threads->yield() if (!$TEST);    # Be friendly
    } ## end while ($RUNNING)
} ## end sub run_bbs_sysop

sub clean_joinable {
	alarm(0);
    foreach my $thread (sort(keys %{$SERVER_THREADS})) {
		{
			lock($UPDATE);
			$UPDATE = TRUE;
		}
        $DEBUG->INFO(["Shutting Down Thread $thread"]);
        $SERVER_THREADS->{$thread}->join();
		servers_status(FALSE);
		alarm(0);
    }
    foreach my $thrd (threads->list(threads::running)) {
        $thrd->join();
		{
			lock($UPDATE);
			$UPDATE = TRUE;
		}
		servers_status(FALSE);
		alarm(0);
    }
	sleep 0.5;
} ## end sub clean_joinable

sub finish {
    {
        lock($RUNNING);
        $RUNNING = FALSE;
    }
    $DEBUG->INFO(['Shutting Down, waiting for all sessions to end nicely...']);
    clean_joinable();
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    print setscroll(1, $hsize), color('reset'), cls;
    $DEBUG->INFO(['Shutdown Complete']);
    chdir($OLDDIR);
	alarm(0);
} ## end sub finish

sub hard_finish {

    # Force a hard finish.
    #
    # It unceremoniously kills all threads (and disconnects anyone connected to them)

    {    # Always use semaphores when writing to a shared variable
        lock($RUNNING);
        $RUNNING = FALSE;
    }
    $DEBUG->WARNING(['Forcing Shutdown...']);
    sleep 2;
    foreach my $thread (threads::running) {
        $thread->kill('KILL');
    }
    clean_joinable();
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    print setscroll(1, $hsize), color('reset'), cls;
    $DEBUG->INFO(['Hard Shutdown Complete']);
    chdir($OLDDIR);
	alarm(0);
} ## end sub hard_finish

__END__

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
