#!perl

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
use constant { # Others are imported
	MAX_THREADS => 16,
};

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

use BBS::Universal;

BEGIN {
	our $VERSION = '0.001';
	our $DEBUG   = Debug::Easy->new(
		'LogLevel' => 'ERROR',
		'Color' => 1,
	);
};

## Imported from above:
#
# TRUE, FALSE, ASCII, ATASCII, PETSCII, VT102, _configuration

############## BBS Core ###################

my $CONF = _configuration(); $DEBUG->DEBUG('Loading configuration hash into memory');

###########################################

sub run_bbs {
	my $host = shift;
	my $port = shift;

	while ($RUNNING) {
		$DEBUG->DEBUG('Waiting for a connection');
		{
			my $socket = IO::Socket::INET->new(
				'LocalHost' => $host,
				'LocalPort' => $port,
				'Proto' => 'tcp',
				'Listen' => 5,
				'ReuseAddr' => FALSE,
				'Timeout' => 15,
				'Blocking' => TRUE,
			);
			my $error = undef;
			$error = "Cannot create socket for $!n" unless($socket);
			if (defined($error)) {
				$DEBUG->ERROR($error);
				sleep 15;
			} else {
				$socket->autoflush();
				$DEBUG->DEBUG('BBS Server Started');
				my $client_socket = $socket->accept();
				my $bbs = BBS::Universal->new(
					{
                        'socket' => $socket,
						'client_socket' => $client_socket,
						'debug' => $DEBUG,
					}
				);
				$bbs->run();
				shutdown($client_socket,1); # Hang up
				$socket->close();
			}
		}
	}
}

sub clean_joinable {
	my @joinable = threads->list(threads::joinable);
	foreach my $thread (@joinable) {
		$thread->join() if ($thread->is_joinable); # Sanity checks always
	}
}

__END__

