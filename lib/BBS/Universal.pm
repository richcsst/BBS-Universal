package BBS::Universal;

# Pragmas
use 5.010;
use strict;
no strict 'subs';
no warnings;
use utf8;
use constant {
    TRUE        => 1,
    FALSE       => 0,
	YES         => 1,
	NO          => 0,
    BLOCKING    => 1,
    NONBLOCKING => 0,
	PASSWORD    => -1,
	ECHO        => 1,
	SILENT      => 0,

    ASCII   => 0,
    ATASCII => 1,
    PETSCII => 2,
    ANSI    => 3,
};
use open qw(:std :utf8);

# Modules
use threads (
	'yield',
	'exit' => 'threads_only',
	'stringify',
);
use English qw( -no_match_vars );
use Config;
use Debug::Easy;
use DateTime;
use DBI;
use DBD::mysql;
use File::Basename;
use Time::HiRes qw(time sleep);
use Term::ReadKey;
use Term::ANSIScreen qw( :cursor :screen );
use Term::ANSIColor;
use Text::Format;
use Text::SimpleTable;
use List::Util qw(min max);
use IO::Socket qw(AF_INET SOCK_STREAM SHUT_WR SHUT_RDWR SHUT_RD);
use Cache::Memcached::Fast::Safe;

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      TRUE
      FALSE
	  YES
	  NO
	  BLOCKING
	  NONBLOCKING
	  PASSWORD
	  ECHO
	  SILENT
      ASCII
      ATASCII
      PETSCII
      ANSI
    );
    our @EXPORT_OK = qw();
    binmode(STDOUT, ":encoding(UTF-8)");
    our $ANSI_VERSION = '0.001';
    our $ASCII_VERSION = '0.001';
    our $ATASCII_VERSION = '0.001';
    our $CPU_VERSION = '0.001';
    our $DB_VERSION = '0.001';
    our $FILETRANSFER_VERSION = '0.001';
    our $MESSAGES_VERSION = '0.001';
    our $NEWS_VERSION = '0.001';
    our $PETSCII_VERSION = '0.001';
    our $SYSOP_VERSION = '0.001';
    our $USERS_VERSION = '0.001';
} ## end BEGIN

sub DESTROY {
    my $self = shift;
    $self->{'dbh'}->disconnect();
}

sub small_new {
    my $class = shift;
    my $self  = shift;

    bless($self, $class);
	$self->populate_common();
    $self->{'debug'}->DEBUGMAX([$self]);

	$self->{'CACHE'} = Cache::Memcached::Fast::Safe->new(
		{
			'servers' => [
				{
					'address' => $self->{'CONF'}->{'MEMCACHED HOST'} . ':' . $self->{'CONF'}->{'MEMCACHED PORT'},
				},
			],
			'namespace' => $self->{'CONF'}->{'MEMCACHED NAMESPACE'},
			'utf8'      => TRUE,
		}
	);
	return ($self);
} ## end sub small_new

sub new {    # Always call with the socket as a parameter
    my $class = shift;

    my $params    = shift;
    my $socket    = (exists($params->{'socket'}))        ? $params->{'socket'}        : undef;
    my $cl_socket = (exists($params->{'client_socket'})) ? $params->{'client_socket'} : undef;
    my $lmode     = (exists($params->{'local_mode'}))    ? $params->{'local_mode'}    : FALSE;

    my $os   = `/usr/bin/uname -a`;
    my $self = {
		'thread_name'     => $params->{'thread_name'},
		'thread_number'   => $params->{'thread_number'},
        'local_mode'      => $lmode,
        'debuglevel'      => $params->{'debuglevel'},
        'debug'           => $params->{'debug'},
        'socket'          => $socket,
        'cl_socket'       => $cl_socket,
        'peerhost'        => (defined($cl_socket)) ? $cl_socket->peerhost() : undef,
        'peerport'        => (defined($cl_socket)) ? $cl_socket->peerport() : undef,
        'os'              => $os,
        'width'           => 40,
        'height'          => 24,
        'tab_stop'        => 4,
        'backspace'       => chr(8),
        'carriage_return' => chr(13),
        'line_feed'       => chr(10),
        'tab_stop'        => chr(9),
        'bell'            => chr(7),
        'ack'             => chr(6),
        'nak'             => chr(15),
        'vertical_tab'    => chr(11),
        'form_feed'       => chr(12),
        'xoff'            => chr(19),
        'xon'             => chr(17),
        'esc'             => chr(27),
        'can'             => chr(24),
        'null'            => chr(0),
        'delete'          => chr(127),
        'suffixes'        => [ qw( ASC ATA PET ANS ) ],
        'host'      => undef,
        'port'      => undef,
    };

    bless($self, $class);
	$self->populate_common();
	$self->{'CACHE'} = Cache::Memcached::Fast::Safe->new(
		{
			'servers' => [
				{
					'address' => $self->{'CONF'}->{'MEMCACHED HOST'} . ':' . $self->{'CONF'}->{'MEMCACHED PORT'},
				},
			],
			'namespace' => $self->{'CONF'}->{'MEMCACHED NAMESPACE'},
			'utf8'      => TRUE,
		}
	);
    $self->{'debug'}->DEBUGMAX([$self]);

    return ($self);
} ## end sub new

sub dump_permissions {
	my $self = shift;
	return('');
}

sub populate_common {
	my $self = shift;
    $self->{'CPU'}  = $self->cpu_info();
    $self->{'CONF'} = $self->configuration();
	$self->{'VERSIONS'} = $self->parse_versions();
    $self->{'USER'} = {
        'text_mode' => $self->{'CONF'}->{'DEFAULT TEXT MODE'},
        'suffix'    => $self->{'CONF'}->{'DEFAULT SUFFIX'},
    };
	$self->db_initialize();
	$self->ascii_initialize();
	$self->atascii_initialize();
	$self->petscii_initialize();
	$self->ansi_initialize();
	$self->filetransfer_initialize();
	$self->messages_initialize();
	$self->users_initialize();
    $self->sysop_initialize();
	$self->cpu_initialize();
	$self->news_initialize();
    chomp(my $os = `uname -a`);
	$self->{'SPEEDS'} = {                       # This depends on the granularity of Time::HiRes
		'FULL'  => 0,
		'300'   => 0.02,
		'1200'  => 0.005,
		'2400'  => 0.0025,
		'4800'  => 0.00125,
		'9600'  => 0.000625,
		'19200' => 0.0003125,
	};
	$self->{'TOKENS'} = {
		'SYSOP'              => ($self->{'sysop'}) ? 'SYSOP CREDENTIALS' : 'USER CREDENTIALS',
		'CPU IDENTITY'       => $self->{'CPU'}->{'CPU IDENTITY'},
		'CPU CORES'          => $self->{'CPU'}->{'CPU CORES'},
		'CPU SPEED'          => $self->{'CPU'}->{'CPU SPEED'},
		'CPU THREADS'        => $self->{'CPU'}->{'CPU THREADS'},
		'OS'                 => $os,
		'PERL VERSION'       => $self->{'VERSIONS'}->[0],
		'BBS VERSION'        => $self->{'VERSIONS'}->[1],
		'BANNER'             => sub {
			my $self = shift;
			my $banner = $self->load_file('files/main/banner');
			return($banner);
		},
		'FILE CATEGORY' => sub {
			my $self = shift;
			return($self->users_file_category());
		},
		'FORUM CATEGORY' => sub {
			my $self = shift;
			return($self->users_forum_category());
		},
		'USER INFO'          => sub {
			my $self = shift;
			return($self->user_info());
		},
		'BBS NAME'        => sub {
			my $self = shift;
			return($self->{'CONF'}->{'BBS NAME'});
		},
		'AUTHOR NAME'        => sub {
			my $self = shift;
			return($self->{'CONF'}->{'STATIC'}->{'AUTHOR NAME'});
		},
		'USER PERMISSIONS'   => sub {
			my $self = shift;
			return($self->dump_permissions);
		},
		'USER ID'            => sub {
			my $self = shift;
			return($self->{'USER'}->{'id'});
		},
		'USERNAME'           => sub {
			my $self = shift;
			return($self->{'USER'}->{'username'});
		},
		'USER GIVEN'         => sub {
			my $self = shift;
			return($self->{'USER'}->{'given'});
		},
		'USER FAMILY'        => sub {
			my $self = shift;
			return($self->{'USER'}->{'family'});
		},
		'USER LOCATION'      => sub {
			my $self = shift;
			return($self->{'USER'}->{'location'});
		},
		'USER BIRTHDAY'      => sub {
			my $self = shift;
			return($self->{'USER'}->{'birthday'});
		},
		'USER RETRO SYSTEMS' => sub {
			my $self = shift;
			return($self->{'USER'}->{'retro_systems'});
		},
		'USER LOGIN TIME'    => sub {
			my $self = shift;
			return($self->{'USER'}->{'login_time'});
		},
		'USER TEXT MODE'     => sub {
			my $self = shift;
			return($self->{'USER'}->{'text_mode'});
		},
		'BAUD RATE'          => sub {
			my $self = shift;
			return($self->{'baud_rate'});
		},
		'TIME'               => sub {
			my $self = shift;
			return(DateTime->now);
		},
		'UPTIME'             => sub {
			my $self = shift;
			chomp(my $uptime = `uptime -p`);
			return($uptime);
		},
		'VERSIONS'           => 'placeholder',
		'UPTIME'             => 'placeholder',
	};
	$self->{'COMMANDS'} = {
		'ACCOUNT MANAGER' => sub {
			my $self = shift;
			return($self->load_menu('files/main/menu'));
		},
		'BACK' => sub {
			my $self = shift;
			return($self->load_menu('files/main/menu'));
		},
		'DISCONNECT' => sub {
			my $self = shift;

			$self->output("\nDisconnect, are you sure (Y|N)?  ");
			unless($self->decision()) {
				return($self->load_menu('files/main/menu'));
			}
			$self->output("\n");
		},
		'FILE CATEGORY' => sub {
			my $self = shift;
			$self->choose_file_category();
			return($self->load_menu('files/main/files_menu'));
		},
		'FILES' => sub {
			my $self = shift;
			return($self->load_menu('files/main/files_menu'));
		},
		'LIST FILES' => sub {
			my $self = shift;
			$self->files_list_summary(FALSE);
			return($self->load_menu('files/main/files_menu'));
		},
		'LIST FILES DETAILED' => sub {
			my $self = shift;
			$self->files_list_detailed(FALSE);
			return($self->load_menu('files/main/files_menu'));
		},
		'SEARCH FILES SUMMARY' => sub {
			my $self = shift;
			$self->files_list_summary(TRUE);
			return($self->load_menu('files/main/files_menu'));
		},
		'SEARCH FILES DETAILED' => sub {
			my $self = shift;
			$self->files_list_detailed(TRUE);
			return($self->load_menu('files/main/files_menu'));
		},
		'NEWS' => sub {
			my $self = shift;
			return($self->load_menu('files/main/news'));
		},
		'NEWS SUMMARY' => sub {
			my $self = shift;
			$self->news_summary();
			return($self->load_menu('files/main/news'));
		},
		'NEWS DISPLAY' => sub {
			my $self = shift;
			$self->news_display();
			return($self->load_menu('files/main/news'));
		},
		'FORUMS' => sub {
			my $self = shift;
			return($self->load_menu('files/main/menu'));
		},
		'ABOUT' => sub {
			my $self = shift;
			return($self->load_menu('files/main/about'));
		},
	};
}

sub run {
    my $self = shift;
	my $sysop = shift;

	$self->{'sysop'} = $sysop;
    $self->{'ERROR'} = undef;

    if ($self->greeting()) {    # Greeting also logs in
        $self->main_menu('files/main/menu');
    }
    $self->disconnect();
    return (defined($self->{'ERROR'}));
} ## end sub run

sub greeting {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Sending greeting']);

    # Load and print greetings message here
    my $text = $self->load_file('files/main/greeting');
    $self->{'debug'}->DEBUGMAX([$text]);
    $self->output($text);
    $self->{'debug'}->DEBUG(['Greeting sent']);
    return ($self->login());    # Login will also create new users
} ## end sub greeting

sub login {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Attempting login']);
    my $valid = FALSE;

    my $username;
	if ($self->{'sysop'}) {
		$username = 'sysop';
		$self->output("\n\nAuto-login of $username successful\n\n");
		$valid = $self->users_load($username,'');
	} else {
        my $tries = $self->{'CONF'}->{'LOGIN TRIES'} + 0;
        do {
            do {
                $self->output("\n" . 'Please enter your username ("NEW" if you are a new user) > ');
                $username = $self->get_line(ECHO,32);
				$tries-- if ($username eq '');
				last if ($tries <= 0 || ! $self->is_connected());
            } until($username ne '');
			if ($self->is_connected()) {
				if (uc($username) eq 'NEW') {
					$valid = $self->create_account();
				} elsif ($username eq 'sysop' && ! $self->{'local_mode'}) {
					$self->output("\n\nSysOp cannot connect remotely\n\n");
				} else {
					$self->output("\n\nPlease enter your password > ");
					my $password = $self->get_line(PASSWORD,64);
					$self->{'debug'}->DEBUG(["Attempting to load $username"]);
					$valid = $self->users_load($username,$password);
				}
				if ($valid) {
					$self->{'debug'}->DEBUG(['Login successful']);
					$self->output("\n\nWelcome " . $self->{'fullname'} . ' (' . $self->{'username'} . ")\n\n");
				} else {
					$self->{'debug'}->WARNING(["Login for $username unsuccessful"]);
					$self->output("\n\nLogin incorrect\n\n");
					$tries--;
				}
			}
        } until($valid || $tries <= 0 || ! ($self->{'CACHE'}->get('RUNNING') && $self->is_connected()));
	}
	$self->{'debug'}->DEBUGMAX([$self->{'USER'}]);
    return ($valid);
} ## end sub login

sub create_account {
    my $self = shift;

    return(FALSE);
}

sub is_connected {
    my $self = shift;
	if ($self->{'CACHE'}->get('RUNNING') && ($self->{'sysop'} || defined($self->{'cl_socket'}))) {
		$self->{'CACHE'}->set(sprintf('SERVER_%02d', $self->{'thread_number'}), 'CONNECTED');
		$self->{'CACHE'}->set('UPDATE', TRUE);
		return(TRUE);
	} else {
		$self->{'CACHE'}->set(sprintf('SERVER_%02d', $self->{'thread_number'}), 'IDLE');
		$self->{'CACHE'}->set('UPDATE', TRUE);
		return(FALSE);
	}
}

sub decision {
    my $self = shift;

	my $response = uc($self->get_key(SILENT,BLOCKING));
    if ($response eq 'Y') {
		$self->output("YES\n");
		return (TRUE);
	}
    $self->output("NO\n");
    return (FALSE);
}

sub prompt {
    my $self = shift;
    my $text = shift;

    my $response;
    if ($self->{'USER'}->{'text_mode'} eq 'ATASCII') {
        $response = $text . chr(31) . ' ';
    } elsif ($self->{'USER'}->{'text_mode'} eq 'PETSCII') {
        $response = "$text > ";
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $response = $text . ' ' . $self->{'ansi_sequences'}->{'BIG BULLET RIGHT'} . ' ';
    } else {
        $response = "$text > ";
    }
    return($response);
}

sub menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

#	print "$choice - $color - $desc\n";
    if ($self->{'USER'}->{'text_mode'} eq 'ATASCII') {
        $self->output(" $choice " . chr(31) . " $desc");
    } elsif ($self->{'USER'}->{'text_mode'} eq 'PETSCII') {
        $self->output(" $choice > $desc");
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
		$self->output(
			$self->{'ansi_sequences'}->{'THIN VERTICAL BAR'} .
			colored([$color],$choice) .
			$self->{'ansi_sequences'}->{'THIN VERTICAL BAR'} .
			colored([$color],$self->{'ansi_sequences'}->{'BIG BULLET RIGHT'}) .
			" $desc"
		);
    } else {
        $self->output(" $choice > $desc");
    }
}

sub show_choices {
    my $self = shift;
    my $mapping = shift;

    my $keys = '';
	if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
		$self->output(
			$self->{'ansi_sequences'}->{'TOP LEFT ROUNDED'} .
			$self->{'ansi_sequences'}->{'THIN HORIZONTAL BAR'} .
			$self->{'ansi_sequences'}->{'TOP RIGHT ROUNDED'} .
			"\n"
		);
	}
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
		$self->menu_choice($kmenu,$mapping->{$kmenu}->{'color'},$mapping->{$kmenu}->{'text'});
		$self->output("\n");
    }
	if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
		$self->output(
			$self->{'ansi_sequences'}->{'BOTTOM LEFT ROUNDED'} .
			$self->{'ansi_sequences'}->{'THIN HORIZONTAL BAR'} .
			$self->{'ansi_sequences'}->{'BOTTOM RIGHT ROUNDED'}
		);
	}
}

sub load_menu {
	my $self = shift;
	my $file = shift;

	my $orig = $self->load_file($file);
	my @Text = split(/\n/,$orig);
	my $mapping = { 'TEXT' => '' };
	my $mode = TRUE;
	my $text = '';
	foreach my $line (@Text) {
		next if ($line =~ /^\#/);
		$self->{'debug'}->DEBUGMAX([$line]);
		if ($mode) {
			if ($line !~ /^---/) {
				my ($k, $cmd, $color, $t) = split(/\|/,$line);
				$k = uc($k);
				$cmd = uc($cmd);
				$self->{'debug'}->DEBUGMAX([$k, $cmd, $color, $t]);
				$mapping->{$k} = {
					'command' => $cmd,
					'color'   => $color,
					'text'    => $t,
				};
			} else {
				$mode = FALSE;
			}
		} else {
			$mapping->{'TEXT'} .= $self->detokenize_text($line) . "\n";
		}
	}
	return($mapping);
}

sub main_menu {
    my $self  = shift;
	my $file  = shift;

	my $connected = TRUE;
	my $command = '';
    $self->{'debug'}->DEBUG(['Main Menu loop start']);
	my $mapping = $self->load_menu($file);
    while($connected && $self->is_connected()) {
        $self->output($mapping->{'TEXT'} . "\n");
		$self->show_choices($mapping);
		$self->output("\n" . $self->prompt('Choose'));
		my $key;
		do {
			$key = uc($self->get_key(SILENT,BLOCKING));
		} until (exists($mapping->{$key}) || ! $self->is_connected());
		$self->output($mapping->{$key}->{'command'} . "\n");
		$command = $mapping->{$key}->{'command'};
		$self->{'debug'}->DEBUGMAX([$key,$mapping->{$key}]);
		$mapping = $self->{'COMMANDS'}->{$command}->($self);
		if (ref($mapping) ne 'HASH' || ! $self->is_connected()) {
			$connected = FALSE;
		}
    }
    $self->{'debug'}->DEBUG(['Main Menu end']);
} ## end sub main_menu

sub disconnect {
    my $self = shift;

    # Load and print disconnect message here
    $self->{'debug'}->DEBUG(['Send Disconnect message']);
    my $text = $self->load_file('files/main/disconnect');
    $self->output($text);
    $self->{'debug'}->DEBUG(['Disconnect message sent']);
    return (TRUE);
} ## end sub disconnect

sub categories_menu {    # Handle categories menu
    my $self = shift;

    $self->{'debug'}->DEBUG(['List Categories']);
    return (TRUE);
} ## end sub categories_menu

sub get_key {
    my $self     = shift;
    my $echo     = shift;
    my $blocking = shift;

    my $key = undef;
	local $/ = "\x{00}";
    if ($self->{'local_mode'}) {
        ReadMode 'ultra-raw';
        $key = ($blocking) ? ReadKey(0) : ReadKey(-1);
        ReadMode 'restore';
    } elsif ($self->is_connected()) {
		my $handle = $self->{'cl_socket'};
        ReadMode 'ultra-raw',$handle;
        $key = ($blocking) ? ReadKey($self->{'USER'}->{'timeout'} * 60,$handle) : ReadKey(-1,$handle);
        ReadMode 'restore',$handle;
    } ## end else [ if ($self->{'local_mode'...})]
    $self->{'debug'}->DEBUGMAX(["Key pressed - $key - " . ord($key)]);
    if ($echo == ECHO && defined($key)) {
        $key = $self->{'backspace'} if ($key eq chr(127));
        $self->output($key);
    } elsif ($echo == PASSWORD && defined($key)) {
        $self->output('*');
    }
    return ($key);
} ## end sub get_key

sub get_line {
    my $self  = shift;
    my $echo  = shift;
    my $limit = shift;

    $limit = min($limit,65535);

    my $line = '';
    my $key;

    while($self->is_connected() && $key ne chr(13) && length($line) < $limit) {
        $key = $self->get_key($echo,BLOCKING);
        if (defined($key) && $key ne '' && $self->is_connected()) {
            if ($key eq $self->{'backspace'} || $key eq chr(127)) {
                my $len = length($line);
                if ($len > 0) {
                    $line = substr($line,$len - 1);
                }
            } elsif ($key ne chr(13) && $key ne chr(10)) {
                $line .= $key;
            }
        }
    }

    if ($echo) {
        $self->{'debug'}->DEBUG(['User entered a line of text']);
        $self->{'debug'}->DEBUGMAX([$line]);
    } else {
        $self->{'debug'}->DEBUG(['User entered a password']);
    }
    return ($line);
} ## end sub get_line

sub detokenize_text {    # Detokenize text markup
    my $self = shift;
    my $text = shift;

    if (length($text) > 1) {
        $self->{'debug'}->DEBUG(['Detokenizing text']);
        $self->{'TOKENS'}->{'ONLINE'} = $self->{'CACHE'}->get('ONLINE');

        $self->{'debug'}->DEBUGMAX([$text]);    # Before
        foreach my $key (keys %{$self->{'TOKENS'}}) {
            if ($key eq 'VERSIONS' && $text =~ /$key/i) {
                my $versions = '';
                foreach my $names (@{$self->{'VERSIONS'}}) {
                    $versions .= $names . "\n";
                }
                $text =~ s/\[\%\s+$key\s+\%\]/$versions/gi;
            } elsif (ref($self->{'TOKENS'}->{$key}) eq 'CODE') {
                my $ch = $self->{'TOKENS'}->{$key}->($self); # Code call
                $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$key\s+\%\]/$self->{'tokens'}->{$key}/gi;
            }
        } ## end foreach my $key (keys %$tokens)
        $self->{'debug'}->DEBUGMAX([$text]);    # After
    }
    return ($text);
} ## end sub detokenize_text

sub output {
    my $self = shift;
    my $text = $self->detokenize_text(shift);

	if ($text =~ /\[\%\s+WRAP\s+\%\]/) {
		my $format = Text::Format->new(
			'columns' => $self->{'USER'}->{'max_columns'} - 1,
			'tabstop' => 4,
			'extraSpace' => TRUE,
			'firstIndent' => 0,
		);
 		my $header;
		($header,$text) = split(/\[\%\s+WRAP\s+\%\]/,$text);
		if ($text =~ /\[\%\s+JUSTIFY\s+\%\]/) {
			$text =~ s/\[\%\s+JUSTIFY\s+\%\]//g;
			$format->justify(TRUE);
		}
		$text = $format->format($text);
		$text = $header . $text;
	}
    my $mode = $self->{'USER'}->{'text_mode'};
    if ($mode eq 'ATASCII') {
        $self->{'debug'}->DEBUG(['Send ATASCII']);
        $self->atascii_output($text);
    } elsif ($mode eq 'PETSCII') {
        $self->{'debug'}->DEBUG(['Send PETSCII']);
        $self->petscii_output($text);
    } elsif ($mode eq 'ANSI') {
        $self->{'debug'}->DEBUG(['Send ANSI']);
        $self->ansi_output($text);
    } else {    # ASCII (always the default)
        $self->{'debug'}->DEBUG(['Send ASCII']);
        $self->ascii_output($text);
    }
    return (TRUE);
} ## end sub output

sub send_char {
    my $self = shift;
    my $char = shift;

    # This sends one character at a time to the socket to simulate a retro BBS
    if ($self->{'sysop'} || $self->{'local_mode'} || ! defined($self->{'cl_socket'})) {
        print $char;
    } else {
		my $handle = $self->{'cl_socket'};
		print $handle $char;
    }

    # Send at the chosen baud rate by delaying the output by a fraction of a second
    # Only delay if the baud_rate is not FULL
    sleep $self->{'SPEEDS'}->{ $self->{'baud_rate'} } if ($self->{'USER'}->{'baud_rate'} ne 'FULL');
    return (TRUE);
} ## end sub send_char

sub scroll {
	my $self = shift;
	my $nl   = shift;

	my $string;
	if ($self->{'local_mode'}) {
		$string = "\n\nScroll?  ";
	} else {
		$string = "$nl$nl" . 'Scroll?  ';
	}
	$self->send_char($string);
	if ($self->get_key(ECHO,BLOCKIMG) =~ /N/i) {
		return(FALSE);
	}
	return(TRUE);
}

sub static_configuration {
	my $self = shift;
	my $file = shift;

	$self->{'debug'}->DEBUG(['Getting static configuration']);
	$self->{'CONF'}->{'STATIC'}->{'AUTHOR NAME'} = 'Richard Kelsch';
	$self->{'CONF'}->{'STATIC'}->{'AUTHOR EMAIL'} = 'Richard Kelsch <rich@rk-internet.com>';
	$self->{'CONF'}->{'STATIC'}->{'AUTHOR LOCATION'} = 'Southern Utah - USA';
	if (-e $file) {
		open(my $CFG,'<',$file) or die "$file missing!";
		chomp(my @lines=<$CFG>);
		close($CFG);
		foreach my $line (@lines) {
			next if ($line eq '' || $line =~ /^\#/);
			my ($name,$val) = split(/\s+=\s+/,$line);
			$self->{'CONF'}->{'STATIC'}->{$name} = $val;
			$self->{'debug'}->DEBUGMAX([$name,$val]);
		}
	}
}

sub choose_file_category {
	my $self = shift;

	$self->{'debug'}->DEBUG(['Choose File Category']);
	my $table;
	my $choices = [qw(0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)];
	my $hchoice = {};
	my @categories;
	if ($self->{'USER'}->{'max_columns'} <= 40) {
		$table = Text::SimpleTable->new(6,20,15);
	} else {
		$table = Text::SimpleTable->new(6,30,43);
	}
	$table->row('CHOICE','TITLE','DESCRIPTION');
	$table->hr();
	my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
	$sth->execute();
	if ($sth->rows > 0 && $sth->rows <= 35) {
		while(my $row = $sth->fetchrow_hashref()) {
			$table->row($choices->[$row->{'id'} - 1],$row->{'title'},$row->{'description'});
			$hchoice->{$choices->[$row->{'id'} - 1]} = $row->{'id'};
			push(@categories,$row->{'title'});
		}
		$sth->finish();
		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output($table->boxes->draw());
		} else {
			$self->output($table->draw());
		}
		$self->output("\n" . $self->prompt('Choose Category (< = Nevermind)'));
		my $response;
		do {
			$response = uc($self->get_key(SILENT,BLOCKING));
		} until (exists($hchoice->{$response}) || $response eq '<' || ! $self->is_connected());
		if ($response ne '<') {
			$self->{'USER'}->{'file_category'} = $hchoice->{$response};
			$self->output($categories[$hchoice->{$response} - 1] . "\n");
			$sth = $self->{'dbh'}->prepare('UPDATE users SET file_category=? WHERE id=?');
			$sth->execute($hchoice->{$response},$self->{'USER'}->{'id'});
			$sth->finish();
		} else {
			$self->output("Nevermind\n");
		}
	}
}

# Typical subroutines, not objects

sub configuration {
    my $self = shift;

	unless(exists($self->{'CONF'}->{'STATIC'})) {
		my @static_file = ('./conf/bbs.rc','~/.bbs_universal/bbs.rc','/etc/bbs.rc');
		my $found = FALSE;
		foreach my $file (@static_file) {
			if (-e $file) {
				$self->{'debug'}->DEBUG(["$file found"]);
				$found = TRUE;
				$self->static_configuration($file);
				last;
			} else {
				$self->{'debug'}->WARNING(["$file not found, trying the next file in the list"]);
			}
		}
		unless($found) {
			$self->{'debug'}->ERROR(['BBS Static Configuration file not found',join("\n",@static_file)]);
			exit(1);
		}
		$self->db_connect();
	}
    #######################################################
    my $count = scalar(@_);
    if ($count == 1) {    # Get single value
        my $name = shift;
		$self->{'debug'}->DEBUG(["Get configuration value for $name"]);

        my $sth = $self->{'dbh'}->prepare('SELECT config_value FROM config WHERE config_name=?');
		my $result = $sth->execute($name);
		$sth->finish();
        return ($result);
    } elsif ($count == 2) {    # Set a single value
        my $name  = shift;
        my $fval  = shift;
		$self->{'debug'}->DEBUG(["Set configuration value for $name = $fval",'Preparing']);
		my $sth = $self->{'dbh'}->prepare('UPDATE config SET config_value=? WHERE config_name=?');
		$self->{'debug'}->DEBUG(['Executing']);
		my $result = $sth->execute($fval,$name);
		$sth->finish();
		$self->{'debug'}->DEBUG(['Updated in DB']);
		$self->{'CONF'}->{$name} = $fval;
        return(TRUE);
    } elsif ($count == 0) { # Get entire configuration forces a reload into CONF
		$self->{'debug'}->DEBUG(['Query entire configurion']);
		$self->db_connect() unless(exists($self->{'dbh'}));
        my $sth = $self->{'dbh'}->prepare('SELECT config_name,config_value FROM config');
		my $results = {};
		$sth->execute();
		while(my @row = $sth->fetchrow_array()) {
			$results->{$row[0]} = $row[1];
			$self->{'CONF'}->{$row[0]} = $row[1];
		}
		$sth->finish();

        return($self->{'CONF'});
    } ## end else [ if ($count == 1) ]
} ## end sub configuration

sub parse_versions {
    my $self = shift;

    my $versions = [
		"Perl                          $OLD_PERL_VERSION",
		"BBS::Universal                $BBS::Universal::VERSION",
		"BBS::Universal::ASCII         $BBS::Universal::ASCII_VERSION",
		"BBS::Universal::ATASCII       $BBS::Universal::ATASCII_VERSION",
		"BBS::Universal::PETSCII       $BBS::Universal::PETSCII_VERSION",
		"BBS::Universal::ANSI          $BBS::Universal::ANSI_VERSION",
		"BBS::Universal::CPU           $BBS::Universal::CPU_VERSION",
		"BBS::Universal::Messages      $BBS::Universal::MESSAGES_VERSION",
		"BBS::Universal::SysOp         $BBS::Universal::SYSOP_VERSION",
		"BBS::Universal::FileTransfer  $BBS::Universal::FILETRANSFER_VERSION",
		"BBS::Universal::Users         $BBS::Universal::USERS_VERSION",
		"BBS::Universal::DB            $BBS::Universal::DB_VERSION",
		"DBI                           $DBI::VERSION",
		"DBD::mysql                    $DBD::mysql::VERSION",
		"DateTime                      $DateTime::VERSION",
		"Debug::Easy                   $Debug::Easy::VERSION",
		"File::Basename                $File::Basename::VERSION",
		"Time::HiRes                   $Time::HiRes::VERSION",
		"Term::ReadKey                 $Term::ReadKey::VERSION",
		"Term::ANSIScreen              $Term::ANSIScreen::VERSION",
		"Text::Format                  $Text::Format::VERSION",
		"Text::SimpleTable             $Text::SimpleTable::VERSION",
		"IO::Socket                    $IO::Socket::VERSION",
    ];
    return ($versions);
} ## end sub parse_versions

sub get_uptime {
    my $self = shift;
    chomp(my $uptime = `uptime -p`);
    return (ucfirst($uptime));
}

sub pad_center {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

    if (defined($text) && $text ne '') {
        my $size    = length($text);
        my $padding = int(($width - $size) / 2);
        if ($padding > 0) {
            $text = ' ' x $padding . $text;
        }
    } ## end if (defined($text) && ...)
    return ($text);
} ## end sub pad_center

sub center {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

    return ($text) unless (defined($text) && $text ne '');
    if ($text =~ /\n/s) {
        chomp(my @lines = split(/\n/, $text));
        $text = '';
        foreach my $line (@lines) {
            $text .= $self->pad_center($line, $width) . "\n";
        }
        return ($text);
    } else {
        return ($self->pad_center($text, $width));
    }
} ## end sub center

sub trim {
	my $self = shift;
	my $text = shift;

	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return($text);
}

# package BBS::Universal::ANSI;

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27) . '[';

    $self->{'ansi_prefix'}    = $esc;
    $self->{'ansi_sequences'} = {
        'RETURN'   => chr(13),
        'LINEFEED' => chr(10),
        'NEWLINE'  => chr(13) . chr(10),

        'CLEAR'      => locate(1,1) . cls,
        'CLS'        => locate(1,1) . cls,
        'CLEAR LINE' => clline,
        'CLEAR DOWN' => cldown,
        'CLEAR UP'   => clup,

        # Cursor
        'UP'          => $esc . 'A',
        'DOWN'        => $esc . 'B',
        'RIGHT'       => $esc . 'C',
        'LEFT'        => $esc . 'D',
        'SAVE'        => $esc . 's',
        'RESTORE'     => $esc . 'u',
        'RESET'       => $esc . '0m',
        'BOLD'        => $esc . '1m',
        'FAINT'       => $esc . '2m',
        'ITALIC'      => $esc . '3m',
        'UNDERLINE'   => $esc . '4m',
        'SLOW BLINK'  => $esc . '5m',
        'RAPID BLINK' => $esc . '6m',

        # Attributes
        'INVERT'       => $esc . '7m',
        'REVERSE'      => $esc . '7m',
        'CROSSED OUT'  => $esc . '9m',
        'DEFAULT FONT' => $esc . '10m',
        'FONT1'        => $esc . '11m',
        'FONT2'        => $esc . '12m',
        'FONT3'        => $esc . '13m',
        'FONT4'        => $esc . '14m',
        'FONT5'        => $esc . '15m',
        'FONT6'        => $esc . '16m',
        'FONT7'        => $esc . '17m',
        'FONT8'        => $esc . '18m',
        'FONT9'        => $esc . '19m',

        # Color
        'NORMAL' => $esc . '21m',

        # Foreground color
        'BLACK'          => $esc . '30m',
        'RED'            => $esc . '31m',
        'PINK'           => color('ANSI198'),
        'ORANGE'         => color('ANSI202'),
        'GREEN'          => $esc . '32m',
        'YELLOW'         => $esc . '33m',
        'BLUE'           => $esc . '34m',
        'NAVY'           => color('ANSI17'),
        'MAGENTA'        => $esc . '35m',
        'CYAN'           => $esc . '36m',
        'WHITE'          => $esc . '37m',
        'DEFAULT'        => $esc . '39m',
        'BRIGHT BLACK'   => $esc . '90m',
        'BRIGHT RED'     => $esc . '91m',
        'BRIGHT GREEN'   => $esc . '92m',
        'BRIGHT YELLOW'  => $esc . '93m',
        'BRIGHT BLUE'    => $esc . '94m',
        'BRIGHT MAGENTA' => $esc . '95m',
        'BRIGHT CYAN'    => $esc . '96m',
        'BRIGHT WHITE'   => $esc . '97m',

        # Background color
        'B_BLACK'          => $esc . '40m',
        'B_RED'            => $esc . '41m',
        'B_GREEN'          => $esc . '42m',
        'B_YELLOW'         => $esc . '43m',
        'B_BLUE'           => $esc . '44m',
        'B_MAGENTA'        => $esc . '45m',
        'B_CYAN'           => $esc . '46m',
        'B_WHITE'          => $esc . '47m',
        'B_DEFAULT'        => $esc . '49m',
        'BRIGHT B_BLACK'   => $esc . '100m',
        'BRIGHT B_RED'     => $esc . '101m',
        'BRIGHT B_GREEN'   => $esc . '102m',
        'BRIGHT B_YELLOW'  => $esc . '103m',
        'BRIGHT B_BLUE'    => $esc . '104m',
        'BRIGHT B_MAGENTA' => $esc . '105m',
        'BRIGHT B_CYAN'    => $esc . '106m',
        'BRIGHT B_WHITE'   => $esc . '107m',

        # Special
        'HORIZONTAL RULE RED'     => "\r" . $esc . '41m' . clline . $esc . '0m',
        'HORIZONTAL RULE GREEN'   => "\r" . $esc . '42m' . clline . $esc . '0m',
        'HORIZONTAL RULE YELLOW'  => "\r" . $esc . '43m' . clline . $esc . '0m',
        'HORIZONTAL RULE BLUE'    => "\r" . $esc . '44m' . clline . $esc . '0m',
        'HORIZONTAL RULE MAGENTA' => "\r" . $esc . '45m' . clline . $esc . '0m',
        'HORIZONTAL RULE CYAN'    => "\r" . $esc . '46m' . clline . $esc . '0m',
        'HORIZONTAL RULE WHITE'   => "\r" . $esc . '47m' . clline . $esc . '0m',

        'EURO'                             => chr(128),
        'ELIPSIS'                          => chr(133),
        'BULLET DOT'                       => chr(149),
        'HOLLOW BULLET DOT'                => '○',
        'BIG HYPHEN'                       => chr(150),
        'BIGGEST HYPHEN'                   => chr(151),
        'TRADEMARK'                        => chr(153),
        'CENTS'                            => chr(162),
        'POUND'                            => chr(163),
        'YEN'                              => chr(165),
        'COPYRIGHT'                        => chr(169),
        'DOUBLE LT'                        => chr(171),
        'REGISTERED'                       => chr(174),
        'OVERLINE'                         => chr(175),
        'DEGREE'                           => chr(176),
        'SQUARED'                          => chr(178),
        'CUBED'                            => chr(179),
        'MICRO'                            => chr(181),
        'MIDDLE DOT'                       => chr(183),
        'DOUBLE GT'                        => chr(187),
        'QUARTER'                          => chr(188),
        'HALF'                             => chr(189),
        'THREE QUARTERS'                   => chr(190),
        'INVERTED QUESTION'                => chr(191),
        'DIVISION'                         => chr(247),
        'HEART'                            => '♥',
        'CLUB'                             => '♣',
        'DIAMOND'                          => '♦',
        'LARGE PLUS'                       => '┼',
        'LARGE VERTICAL BAR'               => '│',
        'LARGE OVERLINE'                   => '▔',
        'LARGE UNDERLINE'                  => '▁',
        'BULLET RIGHT'                     => '▶',
        'BULLET LEFT'                      => '◀',
        'SMALL BULLET RIGHT'               => '▸',
        'SMALL BULLET LEFT'                => '◂',
        'BIG BULLET RIGHT'                 => '►',
        'BIG BULLET LEFT'                  => '◄',
        'BULLET DOWN'                      => '▼',
        'BULLET UP'                        => '▲',
        'WEDGE TOP LEFT'                   => '◢',
        'WEDGE TOP RIGHT'                  => '◣',
        'WEDGE BOTTOM LEFT'                => '◥',
        'WEDGE BOTTOM RIGHT'               => '◤',
        'LOWER ONE EIGHT BLOCK'            => '▁',
        'LOWER ONE QUARTER BLOCK'          => '▂',
        'LOWER THREE EIGHTHS BLOCK'        => '▃',
        'LOWER FIVE EIGTHS BLOCK'          => '▅',
        'LOWER THREE QUARTERS BLOCK'       => '▆',
        'LOWER SEVEN EIGHTHS BLOCK'        => '▇',
        'LEFT SEVEN EIGHTHS BLOCK'         => '▉',
        'LEFT THREE QUARTERS BLOCK'        => '▊',
        'LEFT FIVE EIGHTHS BLOCK'          => '▋',
        'LEFT THREE EIGHTHS BLOCK'         => '▍',
        'LEFT ONE QUARTER BLOCK'           => '▎',
        'LEFT ONE EIGHTH BLOCK'            => '▏',
        'MEDIUM SHADE'                     => '▒',
        'DARK SHADE'                       => ' ',
        'UPPER ONE EIGHTH BLOCK'           => '▔',
        'RIGHT ONE EIGHTH BLOCK'           => '▕',
        'LOWER LEFT QUADRANT'              => '▖',
        'LOWER RIGHT QUADRANT'             => '▗',
        'UPPER LEFT QUADRANT'              => '▘',
        'LEFT LOWER RIGHT QUADRANTS'       => '▙',
        'UPPER LEFT LOWER RIGHT QUADRANTS' => '▚',
        'LEFT UPPER RIGHT QUADRANTS'       => '▛',
        'UPPER LEFT RIGHT QUADRANTS'       => '▜',
        'UPPER RIGHT QUADRANT'             => '▝',
        'UPPER RIGHT LOWER LEFT QUADRANTS' => '▞',
        'RIGHT LOWER LEFT QUADRANTS'       => '▟',
        'THICK VERTICAL BAR'               => chr(0xA6),
        'THIN HORIZONTAL BAR'              => '─',
        'THICK HORIZONTAL BAR'             => '━',
        'THIN VERTICAL BAR'                => '│',
        'MEDIUM VERTICAL BAR'              => '┃',
        'THIN DASHED HORIZONTAL BAR'       => '┄',
        'THICK DASHED HORIZONTAL BAR'      => '┅',
        'THIN DASHED VERTICAL BAR'         => '┆',
        'THICK DASHED VERTICAL BAR'        => '┇',
        'THIN DOTTED HORIZONTAL BAR'       => '┈',
        'THICK DOTTED HORIZONTAL BAR'      => '┉',
        'MEDIUM DASHED VERTICAL BAR'       => '┊',
        'THICK DASHED VERTICAL BAR'        => '┋',
        'U250C'                            => '┌',
        'U250D'                            => '┍',
        'U250E'                            => '┎',
        'U250F'                            => '┏',
        'U2510'                            => '┐',
        'U2511'                            => '┑',
        'U2512'                            => '┒',
        'U2513'                            => '┓',
        'U2514'                            => '└',
        'U2515'                            => '┕',
        'U2516'                            => '┖',
        'U2517'                            => '┗',
        'U2518'                            => '┘',
        'U2519'                            => '┙',
        'U251A'                            => '┚',
        'U251B'                            => '┛',
        'U251C'                            => '├',
        'U251D'                            => '┝',
        'U251E'                            => '┞',
        'U251F'                            => '┟',
        'U2520'                            => '┠',
        'U2521'                            => '┡',
        'U2522'                            => '┢',
        'U2523'                            => '┣',
        'U2524'                            => '┤',
        'U2525'                            => '┥',
        'U2526'                            => '┦',
        'U2527'                            => '┧',
        'U2528'                            => '┨',
        'U2529'                            => '┩',
        'U252A'                            => '┪',
        'U252B'                            => '┫',
        'U252C'                            => '┬',
        'U252D'                            => '┭',
        'U252E'                            => '┮',
        'U252F'                            => '┯',
        'U2530'                            => '┰',
        'U2531'                            => '┱',
        'U2532'                            => '┲',
        'U2533'                            => '┳',
        'U2534'                            => '┴',
        'U2535'                            => '┵',
        'U2536'                            => '┶',
        'U2537'                            => '┷',
        'U2538'                            => '┸',
        'U2539'                            => '┹',
        'U253A'                            => '┺',
        'U253B'                            => '┻',
        'U235C'                            => '┼',
        'U253D'                            => '┽',
        'U253E'                            => '┾',
        'U253F'                            => '┿',
        'U2540'                            => '╀',
        'U2541'                            => '╁',
        'U2542'                            => '╂',
        'U2543'                            => '╃',
        'U2544'                            => '╄',
        'U2545'                            => '╅',
        'U2546'                            => '╆',
        'U2547'                            => '╇',
        'U2548'                            => '╈',
        'U2549'                            => '╉',
        'U254A'                            => '╊',
        'U254B'                            => '╋',
        'U254C'                            => '╌',
        'U254D'                            => '╍',
        'U254E'                            => '╎',
        'U254F'                            => '╏',
        'CHECK'                            => '✓',
        'PIE'                              => 'π',
        'TOP LEFT ROUNDED'                 => '╭',
        'TOP RIGHT ROUNDED'                => '╮',
        'BOTTOM RIGHT ROUNDED'             => '╯',
        'BOTTOM LEFT ROUNDED'              => '╰',
        'FULL FORWARD SLASH'               => '╱',
        'FULL BACKWZARD SLASH'             => '╲',
        'FULL X'                           => '╳',
        'THIN LEFT HALF HYPHEN'            => '╴',
        'THIN TOP HALF BAR'                => '╵',
        'THIN RIGHT HALF HYPHEN'           => '╶',
        'THIN BOTTOM HALF BAR'             => '╷',
        'THICK LEFT HALF HYPHEN'           => '╸',
        'THICK TOP HALF BAR'               => '╹',
        'THICK RIGHT HALF HYPHEN'          => '╺',
        'THICK BOTTOM HALF BAR'            => '╻',
        'RIGHT TELESCOPE'                  => '╼',
        'DOWN TELESCOPE'                   => '╽',
        'LEFT TELESCOPE'                   => '╾',
        'UP TELESCOPE'                     => '╿',
        'MIDDLE VERTICAL RULE BLACK'       => $self->sysop_locate_middle('B_BLACK'),
        'MIDDLE VERTICAL RULE RED'         => $self->sysop_locate_middle('B_RED'),
        'MIDDLE VERTICAL RULE GREEN'       => $self->sysop_locate_middle('B_GREEN'),
        'MIDDLE VERTICAL RULE YELLOW'      => $self->sysop_locate_middle('B_YELLOW'),
        'MIDDLE VERTICAL RULE BLUE'        => $self->sysop_locate_middle('B_BLUE'),
        'MIDDLE VERTICAL RULE MAGENTA'     => $self->sysop_locate_middle('B_MAGENTA'),
        'MIDDLE VERTICAL RULE CYAN'        => $self->sysop_locate_middle('B_CYAN'),
        'MIDDLE VERTICAL RULE WHITE'       => $self->sysop_locate_middle('B_WHITE'),
        'HORIZONTAL RULE RED'              => "\r" . $self->{'ansi_sequences'}->{'B_RED'} . clline . $self->{'ansi_sequences'}->{'RESET'},        # Needs color defined before actual use
        'HORIZONTAL RULE GREEN'            => "\r" . $self->{'ansi_sequences'}->{'B_GREEN'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use
        'HORIZONTAL RULE YELLOW'           => "\r" . $self->{'ansi_sequences'}->{'B_YELLOW'} . clline . $self->{'ansi_sequences'}->{'RESET'},     # Needs color defined before actual use
        'HORIZONTAL RULE BLUE'             => "\r" . $self->{'ansi_sequences'}->{'B_BLUE'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE MAGENTA'          => "\r" . $self->{'ansi_sequences'}->{'B_MAGENTA'} . clline . $self->{'ansi_sequences'}->{'RESET'},    # Needs color defined before actual use
        'HORIZONTAL RULE CYAN'             => "\r" . $self->{'ansi_sequences'}->{'B_CYAN'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE WHITE'            => "\r" . $self->{'ansi_sequences'}->{'B_WHITE'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use
    };
    foreach my $count (0 .. 255) {
        $self->{'ansi_sequences'}->{"ANSI$count"} = color("ANSI$count");
    }
    $self->{'debug'}->DEBUG(['Initialized VT102']);
    return ($self);
} ## end sub ansi_initialize

sub ansi_output {
    my $self   = shift;
    my $text   = shift;
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $self->{'debug'}->DEBUG(['Send ANSI text']);
    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'ansi_sequences'} }) {
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_sequences'}->{$string}/gi;
            }
        } ## end foreach my $string (keys %{...})
    }
    my $s_len = length($text);
    my $nl    = $self->{'ansi_sequences'}->{'NEWLINE'};
    foreach my $count (0 .. $s_len) {
        my $char = substr($text, $count, 1);
        if ($char eq "\n") {
            if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
                $char = $nl;
            }
            $lines--;
            if ($lines <= 0) {
                $lines = $mlines;
                last unless ($self->scroll($nl));
            }
        } ## end if ($char eq "\n")
        $self->send_char($char);
    } ## end foreach my $count (0 .. $s_len)
    return (TRUE);
} ## end sub ansi_output

 

# package BBS::Universal::ASCII;

sub ascii_initialize {
    my $self = shift;

    $self->{'ascii_sequences'} = {
        'RETURN'   => chr(13),
        'LINEFEED' => chr(10),
        'NEWLINE'  => chr(13) . chr(10),
    };
    $self->{'debug'}->DEBUG(['ASCII Initialized']);
    return ($self);
} ## end sub ascii_initialize

sub ascii_output {
    my $self   = shift;
    my $text   = shift;
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    $self->{'debug'}->DEBUG(['Send ASCII text']);
    $self->{'debug'}->DEBUGMAX([$text]);
    my $s_len = length($text);
    my $nl    = $self->{'ascii_sequences'}->{'NEWLINE'};
    foreach my $count (0 .. $s_len) {
        my $char = substr($text, $count, 1);
        if ($char eq "\n") {
            if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
                $char = $nl;
            }
            $lines--;
            if ($lines <= 0) {
                $lines = $mlines;
                last unless ($self->scroll($nl));
            }
        } ## end if ($char eq "\n")
        $self->send_char($char);
    } ## end foreach my $count (0 .. $s_len)
    return (TRUE);
} ## end sub ascii_output

 

# package BBS::Universal::ATASCII;

sub atascii_initialize {
    my $self = shift;

    $self->{'atascii_sequences'} = {
        'HEART' => chr(0),
        '0x01'  => chr(1),

        'RETURN'      => chr(13),
        'LINEFEED'    => chr(10),
        'NEWLINE'     => chr(13) . chr(10),
        'ESC'         => chr(27),
        'UP'          => chr(28),
        'DOWN'        => chr(29),
        'LEFT'        => chr(30),
        'RIGHT'       => chr(31),
        'CLEAR'       => chr(125),
        'BACKSPACE'   => chr(126),
        'TAB'         => chr(127),
        'EOL'         => chr(155),
        'DELETE LINE' => chr(156),
        'INSERT LINE' => chr(157),
        'BELL'        => chr(253),
        'DELETE'      => chr(254),
        'INSERT'      => chr(255),
    };
    return ($self);
} ## end sub atascii_initialize

sub atascii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    $self->{'debug'}->DEBUG(['Send ATASCII text']);
    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
            if ($string eq $self->{'atascii_sequences'}->{'CLEAR'} && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
            }
        } ## end foreach my $string (keys %{...})
    }
    my $s_len = length($text);
    my $nl    = $self->{'atascii_sequences'}->{'NEWLINE'};
    foreach my $count (0 .. $s_len) {
        my $char = substr($text, $count, 1);
        if ($char eq "\n") {
            if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
                $char = $nl;
            }
            $lines--;
            if ($lines <= 0) {
                $lines = $mlines;
                last unless ($self->scroll($nl));
            }
        } ## end if ($char eq "\n")
        $self->send_char($char);
    } ## end foreach my $count (0 .. $s_len)
    return (TRUE);
} ## end sub atascii_output

 

# package BBS::Universal::CPU;

sub cpu_initialize {
    my $self = shift;
    return ($self);
}

sub cpu_info {
    my $self = shift;

    my $cpu         = $self->cpu_identify();
    my $cpu_cores   = scalar(@{ $cpu->{'CPU'} });
    my $cpu_threads = (exists($cpu->{'CPU'}->[0]->{'logical processors'})) ? $cpu->{'CPU'}->[0]->{'logical processors'} : 'No Hyperthreading';
    my $cpu_bits    = $cpu->{'HARDWARE'}->{'Bits'} + 0;
    chomp(my $load_average = `cat /proc/loadavg`);
    my $identity = $cpu->{'CPU'}->[0]->{'model name'};

    my $speed = $cpu->{'CPU'}->[0]->{'cpu MHz'} if (exists($cpu->{'CPU'}->[0]->{'cpu MHz'}));

    unless (defined($speed)) {
        chomp($speed = `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`);
        $speed /= 1000;
    }

    if ($speed > 999.999) {    # GHz
        $speed = sprintf('%.02f GHz', ($speed / 1000));
    } elsif ($speed > 0) {     # MHz
        $speed = sprintf('%.02f MHz', $speed);
    } else {
        $speed = 'Unknown';
    }
    my $response = {
        'CPU IDENTITY' => $identity,
        'CPU SPEED'    => $speed,
        'CPU CORES'    => $cpu_cores,
        'CPU THREADS'  => $cpu_threads,
        'CPU BITS'     => $cpu_bits,
        'CPU LOAD'     => $load_average,
        'HARDWARE'     => $cpu->{'HARDWARE'}->{'Hardware'},
    };
    $self->{'debug'}->DEBUGMAX([$response]);

    return ($response);
} ## end sub cpu_info

sub cpu_identify {
    my $self = shift;

    return ($self->{'CPUINFO'}) if (exists($self->{'CPUINFO'}));
    open(my $CPU, '<', '/proc/cpuinfo');
    chomp(my @cpuinfo = <$CPU>);
    close($CPU);
    $self->{'CPUINFO'} = \@cpuinfo;

    my $cpu_identity;
    my $index = 0;
    chomp(my $bits = `getconf LONG_BIT`);
    my $hardware = { 'Hardware' => 'Unknown', 'Bits' => $bits };
    foreach my $line (@cpuinfo) {
        if ($line ne '') {
            my ($name, $val) = split(/: /, $line);
            $name = $self->trim($name);
            if ($name =~ /^(Hardware|Revision|Serial)/i) {
                $hardware->{$name} = $val;
            } else {
                if ($name eq 'processor') {
                    $index = $val;
                } else {
                    $cpu_identity->[$index]->{$name} = $val;
                }
            } ## end else [ if ($name =~ /^(Hardware|Revision|Serial)/i)]
        } ## end if ($line ne '')
    } ## end foreach my $line (@cpuinfo)
    my $response = {
        'CPU'      => $cpu_identity,
        'HARDWARE' => $hardware,
    };
    if (-e '/usr/bin/lscpu' || -e 'usr/local/bin/lscpu') {
        my $lscpu_short = `lscpu --extended=cpu,core,online,minmhz,maxmhz`;
        chomp(my $lscpu_version = `lscpu -V`);
        $lscpu_version =~ s/^lscpu from util-linux (\d+)\.(\d+)\.(\d+)/$1.$2/;
        my $lscpu_long = ($lscpu_version >= 2.38) ? `lscpu --hierarchic` : `lscpu`;
        $response->{'lscpu'}->{'short'} = $lscpu_short;
        $response->{'lscpu'}->{'long'}  = $lscpu_long;
    } ## end if (-e '/usr/bin/lscpu'...)
    $self->{'debug'}->DEBUGMAX($response);
    $self->{'CPUINFO'} = $response;    # Cache this stuff
    return ($response);
} ## end sub cpu_identify

 

# package BBS::Universal::DB;

sub db_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized DB']);

    return ($self);
} ## end sub db_initialize

sub db_connect {
    my $self = shift;

    #	$self->{'dsn'} = sprintf('dbi:%s:database=%s;' .
    #		'host=%s;' .
    #		'port=%s;' .
    #		'mysql_ssl=%d;' .
    #		'mysql_ssl_client_key=%s;' .
    #		'mysql_ssl_client_cert=%s;' .
    #		'mysql_ssl_ca_file=%s',
    #		$self->{'CONF'}->{'DATABASE TYPE'},
    #		$self->{'CONF'}->{'DATABASE NAME'},
    #		$self->{'CONF'}->{'DATABASE HOSTNAME'},
    #		$self->{'CONF'}->{'DATABASE PORT'},
    #		TRUE,
    #		'/etc/mysql/certs/client-key.pem',
    #		'/etc/mysql/certs/client-cert.pem',
    #		'/etc/mysql/certs/ca-cert.pem'
    #	);
    my @dbhosts = split(/\s*,\s*/, $self->{'CONF'}->{'STATIC'}->{'DATABASE HOSTNAME'});
    my $errors  = '';
    foreach my $host (@dbhosts) {
        $errors        = '';
        $self->{'dsn'} = sprintf('dbi:%s:database=%s;' . 'host=%s;' . 'port=%s;', $self->{'CONF'}->{'STATIC'}->{'DATABASE TYPE'}, $self->{'CONF'}->{'STATIC'}->{'DATABASE NAME'}, $host, $self->{'CONF'}->{'STATIC'}->{'DATABASE PORT'},);
        $self->{'dbh'} = DBI->connect(
            $self->{'dsn'},
            $self->{'CONF'}->{'STATIC'}->{'DATABASE USERNAME'},
            $self->{'CONF'}->{'STATIC'}->{'DATABASE PASSWORD'},
            {
                'PrintError' => FALSE,
                'AutoCommit' => TRUE
            },
        ) or $errors = $DBI::errstr;
        last if ($errors eq '');
    } ## end foreach my $host (@dbhosts)
    if ($errors ne '') {
        $self->{'debug'}->ERROR(["Database Host not found!\n$errors"]);
        exit(1);
    }
    $self->{'debug'}->DEBUG(["Connected to DB $self->{dsn}"]);
    return (TRUE);
} ## end sub db_connect

sub db_count_users {
    my $self = shift;

    unless (exists($self->{'dbh'})) {
        $self->db_connect();
    }
    my $response = $self->{'dbh'}->do('SELECT COUNT(id) FROM users');
    return ($response);
} ## end sub db_count_users

sub db_disconnect {
    my $self = shift;

    $self->{'dbh'}->disconnect() if (defined($self->{'dbh'}));
    return (TRUE);
} ## end sub db_disconnect

sub db_insert {
    my $self  = shift;
    my $table = shift;
    my $hash  = shift;

    return (TRUE);
} ## end sub db_insert

sub db_sql_execute {
    my $self = shift;
    my $file = shift;

    print "Executing $file\n";
    system('mysql --user=' . $self->{'CONF'}->{'DATABASE USERNAME'} . ' --password=' . $self->{'CONF'}->{'DATABASE PASSWORD'} . " < $file");
    print "Done!\n";
    return (TRUE);
} ## end sub db_sql_execute

 

# package BBS::Universal::FileTransfer;

sub filetransfer_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['FileTransfer initialized']);
    return ($self);
} ## end sub filetransfer_initialize

sub load_file {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(["Load $file"]);
    my $filename = sprintf('%s.%s', $file, $self->{'USER'}->{'suffix'});
    $self->{'debug'}->DEBUG(["Load actual $filename"]);
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    return (join("\n", @text));
} ## end sub load_file

sub files_list_summary {
    my $self = shift;
	my $search = shift;

	my $sth;
	my $filter;
	if ($search) {
		$self->output("\n" . $self->prompt('Search for'));
		$filter = $self->get_line(ECHO,20);
		$sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE filename LIKE ? AND category=? ORDER BY uploaded DESC');
		$sth->execute($filter,$self->{'USER'}->{'file_category'});
	} else {
		$sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
		$sth->execute($self->{'USER'}->{'file_category'});
	}
	my @files;
	my $max_filename = 10;
	my $max_title = 20;
	if ($sth->rows > 0) {
		while(my $row = $sth->fetchrow_hashref()) {
			push(@files,$row);
			$max_filename = max(length($row->{'filename'}),$max_filename);
			$max_title = max(length($row->{'title'}),$max_title);
		}
		my $table = Text::SimpleTable->new($max_filename,$max_title);
		$table->row('FILENAME','TITLE');
		$table->hr();
		foreach my $record (@files) {
			$table->row($record->{'filename'},$record->{'title'});
		}
		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output($table->boxes->draw());
		} else {
			$self->output($table->draw());
		}
	} elsif ($search) {
		$self->output("\nSorry '$filter' not found");
	} else {
		$self->output("\nSorry, this file category is empty\n");
	}
	$self->output("\nPress a key to continue ...");
	$self->get_key(ECHO,BLOCKING);
    return (TRUE);
}

sub files_list_detailed {
    my $self = shift;
	my $search = shift;

	my $sth;
	my $filter;
	if ($search) {
		$self->output("\n" . $self->prompt('Search for'));
		$filter = $self->get_line(ECHO,20);
		$sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE filename LIKE ? AND category=? ORDER BY uploaded DESC');
		$sth->execute($filter,$self->{'USER'}->{'file_category'});
	} else {
		$sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
		$sth->execute($self->{'USER'}->{'file_category'});
	}
	my @files;
	my $max_filename = 10;
	my $max_title = 20;
	if ($sth->rows > 0) {
		while(my $row = $sth->fetchrow_hashref()) {
			push(@files,$row);
			$max_filename = max(length($row->{'filename'}),$max_filename);
			$max_title = max(length($row->{'title'}),$max_title);
		}
		my $table = Text::SimpleTable->new($max_filename,$max_title);
		$table->row('FILENAME','TITLE');
		$table->hr();
		foreach my $record (@files) {
			$table->row($record->{'filename'},$record->{'title'});
		}
		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output($table->boxes->draw());
		} else {
			$self->output($table->draw());
		}
	} elsif ($search) {
		$self->output("\nSorry '$filter' not found");
	} else {
		$self->output("\nSorry, this file category is empty\n");
	}
	$self->output("\nPress a key to continue ...");
	$self->get_key(ECHO,BLOCKING);
    return (TRUE);
}

sub save_file {
    my $self = shift;
    return (TRUE);
}

sub receive_file {
    my $self = shift;
}

sub send_file {
    my $self = shift;
    return (TRUE);
}

 

# package BBS::Universal::Messages;

sub messages_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized Messages']);
    return ($self);
} ## end sub messages_initialize

sub list_sections {
    my $self = shift;
}

sub list_messages {
    my $self = shift;
}

sub read_message {
    my $self = shift;
}

sub edit_message {
    my $self = shift;
}

sub delete_message {
    my $self = shift;
}

 

# package BBS::Universal::News;

sub news_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['News Initialized']);
    return ($self);
}

sub news_display {
	my $self = shift;

	my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,'} . $self->{'CONF'}->{'SHORT DATE FORMAT'} . q{') AS newsdate
		FROM news
		ORDER BY news_date DESC};
	my $sth = $self->{'dbh'}->prepare($sql);
	$sth->execute();
	if ($sth->rows > 0) {
		$self->output("\n");
		while(my $row = $sth->fetchrow_hashref()) {
			if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
				$self->output(
					'[% B_GREEN %] ' .
					$row->{'news_title'} .
					' [% RESET %] - ' .
					$row->{'newsdate'} . 
					"\n\n" .
					'[% WRAP %]' .
					$row->{'news_content'} .
					"\n\n"
				);
			} else {
				$self->output(
					'* ' .
					$row->{'news_title'} .
					' - ' .
					$row->{'newsdate'} .
					"\n\n" .
					'[% WRAP %]' .
					$row->{'news_content'} .
					"\n\n"
				);
			}
		}
	} else {
		$self->output('No News');
	}
	$sth->finish();
	$self->output("\nPress a key to continue ... ");
	$self->get_key(SILENT,BLOCKING);
	return(TRUE);
}

sub news_summary {
	my $self = shift;

	my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,'} . $self->{'CONF'}->{'SHORT DATE FORMAT'} . q{') AS newsdate
		FROM news
		ORDER BY news_date DESC};
	my $sth = $self->{'dbh'}->prepare($sql);
	$sth->execute();
	if ($sth->rows > 0) {
		my $table = Text::SimpleTable->new(10,$self->{'USER'}->{'max_columns'} - 13);
		$table->row('DATE','TITLE');
		$table->hr();
		while(my $row = $sth->fetchrow_hashref()) {
			$table->row($row->{'newsdate'},$row->{'news_title'});
		}
		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output($table->boxes->draw());
		} else {
			$self->output($table->draw());
		}
	} else {
		$self->output('No News');
	}
	$sth->finish();
	$self->output("\nPress a key to continue ... ");
	$self->get_key(SILENT,BLOCKING);
	return(TRUE);
}

 

# package BBS::Universal::PETSCII;

sub petscii_initialize {
    my $self = shift;

    $self->{'petscii_sequences'} = {
        'RETURN'            => chr(13),
        'LINEFEED'          => chr(10),
        'NEWLINE'           => chr(13) . chr(10),
        'CLEAR'             => chr(hex('0x93')),
        'CLS'               => chr(hex('0x93')),
        'WHITE'             => chr(5),
        'BLACK'             => chr(hex('0x90')),
        'RED'               => chr(hex('0x1C')),
        'GREEN'             => chr(hex('0x1E')),
        'BLUE'              => chr(hex('0x1F')),
        'DARK PURPLE'       => chr(hex('0x81')),
        'UNDERLINE ON'      => chr(2),
        'UNDERLINE OFF'     => chr(hex('0x82')),
        'BLINK ON'          => chr(hex('0x0F')),
        'BLINK OFF'         => chr(hex('0x8F')),
        'REVERSE ON'        => chr(hex('0x12')),
        'REVERSE OFF'       => chr(hex('0x92')),
        'BROWN'             => chr(hex('0x95')),
        'PINK'              => chr(hex('0x96')),
        'DARK CYAN'         => chr(hex('0x97')),
        'GRAY'              => chr(hex('0x98')),
        'LIGHT GREEN'       => chr(hex('0x99')),
        'LIGHT BLUE'        => chr(hex('0x9A')),
        'LIGHT GRAY'        => chr(hex('0x9B')),
        'PURPLE'            => chr(hex('0x9C')),
        'YELLOW'            => chr(hex('0x9E')),
        'CYAN'              => chr(hex('0x9F')),
        'UP'                => chr(hex('0x91')),
        'DOWN'              => chr(hex('0x11')),
        'LEFT'              => chr(hex('0x9D')),
        'RIGHT'             => chr(hex('0x1D')),
        'ESC'               => chr(hex('0x1B')),
        'LINE FEED'         => chr(hex('0x0A')),
        'TAB'               => chr(9),
        'BELL'              => chr(7),
        'DOTTED CENTER'     => chr(hex('0x7C')),
        'PIPE'              => chr(hex('0x7D')),
        'DOTTED RIGHT'      => chr(hex('0x7E')),
        'LEFT ANGLED BARS'  => chr(hex('0x7F')),
        'LEFT HALF'         => chr(hex('0xA1')),
        'BOTTOM HALF'       => chr(hex('0xA2')),
        'OVERLINE'          => chr(hex('0xA3')),
        'UNDERLINE'         => chr(hex('0xA4')),
        'VERTICAL LEFT'     => chr(hex('0x45')),
        'VERTICAL RIGHT'    => chr(hex('0xA6')),
        'DOTTED LEFT'       => chr(hex('0xA7')),
        'DOTED BOTTOM'      => chr(hex('0xA8')),
        'RIGHT ANGLED BARS' => chr(hex('0xA9')),

    };
    $self->{'debug'}->DEBUG(['Initialized ASCII']);
    return ($self);
} ## end sub petscii_initialize

sub petscii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    $self->{'debug'}->DEBUG(['Send PETSCII text']);
    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'petscii_sequences'} }) {    # Decode macros
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'petscii_sequences'}->{$string}/gi;
            }
        } ## end foreach my $string (keys %{...})
    }
    my $s_len = length($text);
    my $nl = $self->{'petscii_sequences'}->{'NEWLINE'};
    foreach my $count (0 .. $s_len) {
        my $char = substr($text, $count, 1);
        if ($char eq "\n") {
            if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
                $char = $nl;
            }
            $lines--;
            if ($lines <= 0) {
                $lines = $mlines;
                last unless ($self->scroll($nl));
            }
        } ## end if ($char eq "\n")
        $self->send_char($char);
    } ## end foreach my $count (0 .. $s_len)
    return (TRUE);
} ## end sub petscii_output

 

# package BBS::Universal::SysOp;

sub sysop_initialize {
    my $self = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    #### Format Versions for display
    my $sections;
    if ($wsize <= 80) {
        $sections = 1;
    } elsif ($wsize <= 120) {
        $sections = 2;
    } elsif ($wsize <= 160) {
        $sections = 3;
    } elsif ($wsize <= 200) {
        $sections = 4;
    } elsif ($wsize <= 240) {
        $sections = 5;
    } elsif ($wsize >= 280) {
        $sections = 6;
    }
    my $versions     = $self->sysop_versions_format($sections, FALSE);
    my $bbs_versions = $self->sysop_versions_format($sections, TRUE);

    $self->{'sysop_tokens'} = {
        'EURO'                             => chr(128),
        'ELIPSIS'                          => chr(133),
        'BULLET DOT'                       => chr(149),
        'HOLLOW BULLET DOT'                => '○',
        'BIG HYPHEN'                       => chr(150),
        'BIGGEST HYPHEN'                   => chr(151),
        'TRADEMARK'                        => chr(153),
        'CENTS'                            => chr(162),
        'POUND'                            => chr(163),
        'YEN'                              => chr(165),
        'COPYRIGHT'                        => chr(169),
        'DOUBLE LT'                        => chr(171),
        'REGISTERED'                       => chr(174),
        'OVERLINE'                         => chr(175),
        'DEGREE'                           => chr(176),
        'SQUARED'                          => chr(178),
        'CUBED'                            => chr(179),
        'MICRO'                            => chr(181),
        'MIDDLE DOT'                       => chr(183),
        'DOUBLE GT'                        => chr(187),
        'QUARTER'                          => chr(188),
        'HALF'                             => chr(189),
        'THREE QUARTERS'                   => chr(190),
        'INVERTED QUESTION'                => chr(191),
        'DIVISION'                         => chr(247),
        'HEART'                            => '♥',
        'CLUB'                             => '♣',
        'DIAMOND'                          => '♦',
        'LARGE PLUS'                       => '┼',
        'LARGE VERTICAL BAR'               => '│',
        'LARGE OVERLINE'                   => '▔',
        'LARGE UNDERLINE'                  => '▁',
        'BULLET RIGHT'                     => '▶',
        'BULLET LEFT'                      => '◀',
        'SMALL BULLET RIGHT'               => '▸',
        'SMALL BULLET LEFT'                => '◂',
        'BIG BULLET RIGHT'                 => '►',
        'BIG BULLET LEFT'                  => '◄',
        'BULLET DOWN'                      => '▼',
        'BULLET UP'                        => '▲',
        'WEDGE TOP LEFT'                   => '◢',
        'WEDGE TOP RIGHT'                  => '◣',
        'WEDGE BOTTOM LEFT'                => '◥',
        'WEDGE BOTTOM RIGHT'               => '◤',
        'LOWER ONE EIGHT BLOCK'            => '▁',
        'LOWER ONE QUARTER BLOCK'          => '▂',
        'LOWER THREE EIGHTHS BLOCK'        => '▃',
        'LOWER FIVE EIGTHS BLOCK'          => '▅',
        'LOWER THREE QUARTERS BLOCK'       => '▆',
        'LOWER SEVEN EIGHTHS BLOCK'        => '▇',
        'LEFT SEVEN EIGHTHS BLOCK'         => '▉',
        'LEFT THREE QUARTERS BLOCK'        => '▊',
        'LEFT FIVE EIGHTHS BLOCK'          => '▋',
        'LEFT THREE EIGHTHS BLOCK'         => '▍',
        'LEFT ONE QUARTER BLOCK'           => '▎',
        'LEFT ONE EIGHTH BLOCK'            => '▏',
        'MEDIUM SHADE'                     => '▒',
        'DARK SHADE'                       => ' ',
        'UPPER ONE EIGHTH BLOCK'           => '▔',
        'RIGHT ONE EIGHTH BLOCK'           => '▕',
        'LOWER LEFT QUADRANT'              => '▖',
        'LOWER RIGHT QUADRANT'             => '▗',
        'UPPER LEFT QUADRANT'              => '▘',
        'LEFT LOWER RIGHT QUADRANTS'       => '▙',
        'UPPER LEFT LOWER RIGHT QUADRANTS' => '▚',
        'LEFT UPPER RIGHT QUADRANTS'       => '▛',
        'UPPER LEFT RIGHT QUADRANTS'       => '▜',
        'UPPER RIGHT QUADRANT'             => '▝',
        'UPPER RIGHT LOWER LEFT QUADRANTS' => '▞',
        'RIGHT LOWER LEFT QUADRANTS'       => '▟',
        'THICK VERTICAL BAR'               => chr(0xA6),
        'THIN HORIZONTAL BAR'              => '─',
        'THICK HORIZONTAL BAR'             => '━',
        'THIN VERTICAL BAR'                => '│',
        'MEDIUM VERTICAL BAR'              => '┃',
        'THIN DASHED HORIZONTAL BAR'       => '┄',
        'THICK DASHED HORIZONTAL BAR'      => '┅',
        'THIN DASHED VERTICAL BAR'         => '┆',
        'THICK DASHED VERTICAL BAR'        => '┇',
        'THIN DOTTED HORIZONTAL BAR'       => '┈',
        'THICK DOTTED HORIZONTAL BAR'      => '┉',
        'MEDIUM DASHED VERTICAL BAR'       => '┊',
        'THICK DASHED VERTICAL BAR'        => '┋',
        'U250C'                            => '┌',
        'U250D'                            => '┍',
        'U250E'                            => '┎',
        'U250F'                            => '┏',
        'U2510'                            => '┐',
        'U2511'                            => '┑',
        'U2512'                            => '┒',
        'U2513'                            => '┓',
        'U2514'                            => '└',
        'U2515'                            => '┕',
        'U2516'                            => '┖',
        'U2517'                            => '┗',
        'U2518'                            => '┘',
        'U2519'                            => '┙',
        'U251A'                            => '┚',
        'U251B'                            => '┛',
        'U251C'                            => '├',
        'U251D'                            => '┝',
        'U251E'                            => '┞',
        'U251F'                            => '┟',
        'U2520'                            => '┠',
        'U2521'                            => '┡',
        'U2522'                            => '┢',
        'U2523'                            => '┣',
        'U2524'                            => '┤',
        'U2525'                            => '┥',
        'U2526'                            => '┦',
        'U2527'                            => '┧',
        'U2528'                            => '┨',
        'U2529'                            => '┩',
        'U252A'                            => '┪',
        'U252B'                            => '┫',
        'U252C'                            => '┬',
        'U252D'                            => '┭',
        'U252E'                            => '┮',
        'U252F'                            => '┯',
        'U2530'                            => '┰',
        'U2531'                            => '┱',
        'U2532'                            => '┲',
        'U2533'                            => '┳',
        'U2534'                            => '┴',
        'U2535'                            => '┵',
        'U2536'                            => '┶',
        'U2537'                            => '┷',
        'U2538'                            => '┸',
        'U2539'                            => '┹',
        'U253A'                            => '┺',
        'U253B'                            => '┻',
        'U235C'                            => '┼',
        'U253D'                            => '┽',
        'U253E'                            => '┾',
        'U253F'                            => '┿',
        'U2540'                            => '╀',
        'U2541'                            => '╁',
        'U2542'                            => '╂',
        'U2543'                            => '╃',
        'U2544'                            => '╄',
        'U2545'                            => '╅',
        'U2546'                            => '╆',
        'U2547'                            => '╇',
        'U2548'                            => '╈',
        'U2549'                            => '╉',
        'U254A'                            => '╊',
        'U254B'                            => '╋',
        'U254C'                            => '╌',
        'U254D'                            => '╍',
        'U254E'                            => '╎',
        'U254F'                            => '╏',
        'CHECK'                            => '✓',
        'PIE'                              => 'π',
        'TOP LEFT ROUNDED'                 => '╭',
        'TOP RIGHT ROUNDED'                => '╮',
        'BOTTOM RIGHT ROUNDED'             => '╯',
        'BOTTOM LEFT ROUNDED'              => '╰',
        'FULL FORWARD SLASH'               => '╱',
        'FULL BACKWZARD SLASH'             => '╲',
        'FULL X'                           => '╳',
        'THIN LEFT HALF HYPHEN'            => '╴',
        'THIN TOP HALF BAR'                => '╵',
        'THIN RIGHT HALF HYPHEN'           => '╶',
        'THIN BOTTOM HALF BAR'             => '╷',
        'THICK LEFT HALF HYPHEN'           => '╸',
        'THICK TOP HALF BAR'               => '╹',
        'THICK RIGHT HALF HYPHEN'          => '╺',
        'THICK BOTTOM HALF BAR'            => '╻',
        'RIGHT TELESCOPE'                  => '╼',
        'DOWN TELESCOPE'                   => '╽',
        'LEFT TELESCOPE'                   => '╾',
        'UP TELESCOPE'                     => '╿',
        'MIDDLE VERTICAL RULE BLACK'       => $self->sysop_locate_middle('B_BLACK'),
        'MIDDLE VERTICAL RULE RED'         => $self->sysop_locate_middle('B_RED'),
        'MIDDLE VERTICAL RULE GREEN'       => $self->sysop_locate_middle('B_GREEN'),
        'MIDDLE VERTICAL RULE YELLOW'      => $self->sysop_locate_middle('B_YELLOW'),
        'MIDDLE VERTICAL RULE BLUE'        => $self->sysop_locate_middle('B_BLUE'),
        'MIDDLE VERTICAL RULE MAGENTA'     => $self->sysop_locate_middle('B_MAGENTA'),
        'MIDDLE VERTICAL RULE CYAN'        => $self->sysop_locate_middle('B_CYAN'),
        'MIDDLE VERTICAL RULE WHITE'       => $self->sysop_locate_middle('B_WHITE'),
        'HORIZONTAL RULE RED'              => "\r" . $self->{'ansi_sequences'}->{'B_RED'} . clline . $self->{'ansi_sequences'}->{'RESET'},        # Needs color defined before actual use
        'HORIZONTAL RULE GREEN'            => "\r" . $self->{'ansi_sequences'}->{'B_GREEN'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use
        'HORIZONTAL RULE YELLOW'           => "\r" . $self->{'ansi_sequences'}->{'B_YELLOW'} . clline . $self->{'ansi_sequences'}->{'RESET'},     # Needs color defined before actual use
        'HORIZONTAL RULE BLUE'             => "\r" . $self->{'ansi_sequences'}->{'B_BLUE'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE MAGENTA'          => "\r" . $self->{'ansi_sequences'}->{'B_MAGENTA'} . clline . $self->{'ansi_sequences'}->{'RESET'},    # Needs color defined before actual use
        'HORIZONTAL RULE CYAN'             => "\r" . $self->{'ansi_sequences'}->{'B_CYAN'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE WHITE'            => "\r" . $self->{'ansi_sequences'}->{'B_WHITE'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use

        # Tokens
        'HOSTNAME'     => $self->sysop_hostname,
        'IP ADDRESS'   => $self->sysop_ip_address(),
        'CPU BITS'     => $self->{'CPU'}->{'CPU BITS'},
        'CPU CORES'    => $self->{'CPU'}->{'CPU CORES'},
        'CPU SPEED'    => $self->{'CPU'}->{'CPU SPEED'},
        'CPU IDENTITY' => $self->{'CPU'}->{'CPU IDENTITY'},
        'CPU THREADS'  => $self->{'CPU'}->{'CPU THREADS'},
        'HARDWARE'     => $self->{'CPU'}->{'HARDWARE'},
        'VERSIONS'     => $versions,
        'BBS VERSIONS' => $bbs_versions,
        'BBS NAME'     => colored(['green'], $self->{'CONF'}->{'BBS NAME'}),

        # Non-static
        'THREADS COUNT' => sub {
            my $self = shift;
            return ($self->{'CACHE'}->get('THREADS_RUNNING'));
        },
        'USERS COUNT' => sub {
            my $self = shift;
            return ($self->db_count_users());
        },
        'UPTIME' => sub {
            my $self = shift;
            return ($self->get_uptime());
        },
        'DISK FREE SPACE' => sub {
            my $self = shift;
            return ($self->sysop_disk_free());
        },
        'MEMORY' => sub {
            my $self = shift;
            return ($self->sysop_memory());
        },
        'ONLINE' => sub {
            my $self = shift;
            return ($self->sysop_online_count());
        },
        'CPU LOAD' => sub {
            my $self = shift;
            return ($self->cpu_info->{'CPU LOAD'});
        },
        'ENVIRONMENT' => sub {
            my $self = shift;
            return ($self->sysop_showenv());
        },
        'FILE CATEGORY' => sub {
            my $self = shift;

            my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
            $sth->execute($self->{'USER'}->{'file_category'});
            my ($result) = $sth->fetchrow_array();
            return ($result);
        },
        'COMMANDS REFERENCE' => sub {
            my $self = shift;
            my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
            my $table = Text::SimpleTable->new(40);
            $table->row('SYSOP MENU COMMANDS');
            $table->hr();
            foreach my $sysop_names (sort(keys %{$main::SYSOP_COMMANDS})) {
                $table->row($sysop_names);
            }
            $table->hr();
            $table->row('USER MENU COMMANDS');
            $table->hr();
            foreach my $names (sort(keys %{ $self->{'COMMANDS'} })) {
                $table->row($names);
            }
            return ($self->center($table->boxes->draw(), $wsize));
        },
    };
    $self->{'SYSOP ORDER DETAILED'} = [
        qw(
          id
          fullname
          username
          given
          family
          nickname
          birthday
          location
          baud_rate
          text_mode
          max_columns
          max_rows
          suffix
          timeout
          retro_systems
          accomplishments
          prefer_nickname
          view_files
          upload_files
          download_files
          remove_files
          read_message
          post_message
          remove_message
          sysop
          page_sysop
          login_time
          logout_time
        )
    ];
    $self->{'SYSOP ORDER ABBREVIATED'} = [
        qw(
          id
          fullname
          username
          given
          family
          nickname
          text_mode
        )
    ];
    $self->{'SYSOP HEADING WIDTHS'} = {
        'id'              => 2,
        'username'        => 16,
        'fullname'        => 20,
        'given'           => 12,
        'family'          => 12,
        'nickname'        => 12,
        'birthday'        => 10,
        'location'        => 20,
        'baud_rate'       => 4,
        'login_time'      => 10,
        'logout_time'     => 10,
        'text_mode'       => 9,
        'max_rows'        => 5,
        'max_columns'     => 5,
        'suffix'          => 3,
        'timeout'         => 5,
        'retro_systems'   => 20,
        'accomplishments' => 20,
        'prefer_nickname' => 2,
        'view_files'      => 2,
        'upload_files'    => 2,
        'download_files'  => 2,
        'remove_files'    => 2,
        'read_message'    => 2,
        'post_message'    => 2,
        'remove_message'  => 2,
        'sysop'           => 2,
        'page_sysop'      => 2,
        'password'        => 64,
    };

    # $self->{'debug'}->ERROR($self);exit;
    $self->{'debug'}->DEBUG(['Initialized SysOp object']);
    return ($self);
} ## end sub sysop_initialize

sub sysop_online_count {
    my $self = shift;

    return ($self->{'CACHE'}->get('ONLINE'));
}

sub sysop_versions_format {
    my $self     = shift;
    my $sections = shift;
    my $bbs_only = shift;

    my $versions = "\n\t";
    my $heading  = "\t";
    my $counter  = $sections;

    for (my $count = $sections - 1; $count > 0; $count--) {
        $heading .= ' NAME                          VERSION ';
        if ($count) {
            $heading .= "\t\t";
        } else {
            $heading .= "\n";
        }
    } ## end for (my $count = $sections...)
    $heading = colored(['bold yellow on_red'], $heading);
    foreach my $v (@{ $self->{'VERSIONS'} }) {
        next if ($bbs_only && $v !~ /^BBS/);
        $versions .= "\t\t $v";
        $counter--;
        if ($counter <= 1) {
            $counter = $sections;
            $versions .= "\n\t";
        }
    } ## end foreach my $v (@{ $self->{'VERSIONS'...}})
    chop($versions) if (substr($versions, -1, 1) eq "\t");
    return ($heading . $versions . "\n");
} ## end sub sysop_versions_format

sub sysop_disk_free {    # Show the Disk Free portion of Statistics
    my $self = shift;

    my @free     = split(/\n/, `nice df -h -T`);    # Get human readable disk free showing type
    my $diskfree = '';
    my $width    = 1;
    foreach my $l (@free) {
        $width = max(length($l), $width);           # find the width of the widest line
    }
    foreach my $line (@free) {
        next if ($line =~ /tmp|boot/);
        if ($line =~ /^Filesystem/) {
            $diskfree .= "\t" . colored(['bold yellow on_blue'], " $line " . ' ' x ($width - length($line))) . "\n";    # Make the heading the right width
        } else {
            $diskfree .= "\t\t\t $line\n";
        }
    } ## end foreach my $line (@free)
    return ($diskfree);
} ## end sub sysop_disk_free

sub sysop_first_time_setup {
    my $self = shift;
    my $row  = shift;

    print locate($row, 1), cldown;
    my $found     = FALSE;
    my @sql_files = ('./sql/database_setup.sql', '~/.bbs_universal/database_setup.sql');
    foreach my $file (@sql_files) {
        if (-e $file) {
            $self->{'debug'}->DEBUG(["SQL file $file found"]);
            $found = TRUE;
            $self->db_sql_execute($file);
            last;
        } ## end if (-e $file)
        $self->{'debug'}->WARNING(["SQL file $file not found"]);
    } ## end foreach my $file (@sql_files)
    unless ($found) {
        $self->{'debug'}->ERROR(['Database setup file not found', join("\n", @sql_files)]);
        exit(1);
    }
} ## end sub sysop_first_time_setup

sub sysop_load_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = { 'TEXT' => '' };
    my $mode    = 1;
    my $text    = locate($row, 1) . cldown;
    open(my $FILE, '<', $file);

    while (chomp(my $line = <$FILE>)) {
        next if ($line =~ /^\#/);
        $self->{'debug'}->DEBUGMAX([$line]);
        if ($mode) {
            if ($line !~ /^---/) {
                my ($k, $cmd, $color, $t) = split(/\|/, $line);
                $k   = uc($k);
                $cmd = uc($cmd);
                $self->{'debug'}->DEBUGMAX([$k, $cmd, $color, $t]);
                $mapping->{$k} = {
                    'command' => $cmd,
                    'color'   => $color,
                    'text'    => $t,
                };
                $mapping->{$k}->{'color'} =~ s/(BRIGHT) /${1}_/;    # Make it Term::ANSIColor friendly
            } else {
                $mode = 0;
            }
        } else {
            $mapping->{'TEXT'} .= $self->sysop_detokenize($line) . "\n";
        }
    } ## end while (chomp(my $line = <$FILE>...))
    close($FILE);
    return ($mapping);
} ## end sub sysop_load_menu

sub sysop_pager {
    my $self   = shift;
    my $text   = shift;
    my $offset = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my @lines  = split(/\n/, $text);
    my $size   = ($hsize - ($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')));
    my $scroll = TRUE;
    my $row    = $size - $offset;
    foreach my $line (@lines) {
        if (length($line) > $wsize) {
            my $count = int(length($line) / $wsize) + 1;
            $row -= $count;
            if ($row < 0) {
                $scroll = $self->sysop_scroll();
                last unless ($scroll);
                $row = $size - $count;
            }
            print "$line\n";
        } else {
            print "$line\n";
            $row--;
        }
        if ($row <= 0) {
            $row    = $size;
            $scroll = $self->sysop_scroll();
            last unless ($scroll);
        }
    } ## end foreach my $line (@lines)
    return ($scroll);
} ## end sub sysop_pager

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUG(['Loaded SysOp Menu']);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown;
    my $scroll = $self->sysop_pager($mapping->{'TEXT'}, 3);
    my $keys   = '';
    print "\r", cldown unless ($scroll);
    $self->sysop_show_choices($mapping);
    print "\n", $self->sysop_prompt('Choose');
    my $key;
    do {
        $key = uc($self->sysop_keypress());
    } until (exists($mapping->{$key}));
    print $mapping->{$key}->{'command'}, "\n";
    return ($mapping->{$key}->{'command'});
} ## end sub sysop_parse_menu

sub sysop_decision {
    my $self = shift;

    my $response;
    do {
        $response = uc($self->sysop_keypress());
    } until ($response =~ /Y|N/i);
    if ($response eq 'Y') {
        print "YES\n";
        return (TRUE);
    }
    print "NO\n";
    return (FALSE);
} ## end sub sysop_decision

sub sysop_keypress {
    my $self = shift;
    my $key;
    ReadMode 4;
    do {
        $key = ReadKey(0);
        threads->yield();
    } until (defined($key));
    ReadMode 0;
    return ($key);
} ## end sub sysop_keypress

sub sysop_ip_address {
    my $self = shift;

    chomp(my $ip = `nice hostname -I`);
    return ($ip);
} ## end sub sysop_ip_address

sub sysop_hostname {
    my $self = shift;

    chomp(my $hostname = `nice hostname`);
    return ($hostname);
} ## end sub sysop_hostname

sub sysop_locate_middle {
    my $self  = shift;
    my $color = shift || 'B_WHITE';

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $middle = int($wsize / 2);
    my $string = "\r" . $self->{'ansi_sequences'}->{'RIGHT'} x $middle . $self->{'ansi_sequences'}->{$color} . ' ' . $self->{'ansi_sequences'}->{'RESET'};
    return ($string);
} ## end sub sysop_locate_middle

sub sysop_memory {
    my $self = shift;

    my $memory = `nice free`;
    my @mem    = split(/\n/, $memory);
    my $output = "\t" . colored(['bold black on_green'], '  ' . shift(@mem) . ' ') . "\n";
    while (scalar(@mem)) {
        $output .= "\t\t\t" . shift(@mem) . "\n";
    }
    if ($output =~ /(Mem\:       )/) {
        my $ch = colored(['bold black on_green'], ' ' . $1 . ' ');
        $output =~ s/Mem\:       /$ch/;
    }
    if ($output =~ /(Swap\:      )/) {
        my $ch = colored(['bold black on_green'], ' ' . $1 . ' ');
        $output =~ s/Swap\:      /$ch/;
    }
    return ($output);
} ## end sub sysop_memory

sub sysop_true_false {
    my $self    = shift;
    my $boolean = shift;
    my $mode    = shift;
    $boolean = $boolean + 0;
    if ($mode eq 'TF') {
        return (($boolean) ? 'TRUE' : 'FALSE');
    } elsif ($mode eq 'YN') {
        return (($boolean) ? 'Yes' : 'No');
    }
    return ($boolean);
} ## end sub sysop_true_false

sub sysop_list_users {
    my $self      = shift;
    my $list_mode = shift;

    my $table;
    $self->{'debug'}->DEBUG($list_mode);
    my $date_format = $self->configuration('SHORT DATE FORMAT');
    my $name_width  = 15;
    my $value_width = 60;
    my $sth;
    my @order;
    my $sql;

    if ($list_mode =~ /DETAILED/) {
        $sql = q{
            SELECT
			  id,
			  username,
			  fullname,
			  given,
			  family,
			  nickname,
			  DATE_FORMAT(birthday,'} . $date_format . q{') AS birthday,
			  location,
			  baud_rate,
			  DATE_FORMAT(login_time,'} . $date_format . q{') AS login_time,
			  DATE_FORMAT(logout_time,'} . $date_format . q{') AS logout_time,
			  text_mode,
			  forum_category,
			  file_category,
			  max_columns,
			  max_rows,
			  suffix,
			  timeout,
			  retro_systems,
			  accomplishments,
			  prefer_nickname,
			  view_files,
			  upload_files,
			  download_files,
			  remove_files,
			  read_message,
			  post_message,
			  remove_message,
			  sysop,
			  page_sysop
			  FROM
			  users_view };
        $sth   = $self->{'dbh'}->prepare($sql);
        @order = @{ $self->{'SYSOP ORDER DETAILED'} };
    } else {
        @order = @{ $self->{'SYSOP ORDER ABBREVIATED'} };
        $sql   = 'SELECT id,username,fullname,given,family,nickname,text_mode FROM users_view';
        $sth   = $self->{'dbh'}->prepare($sql);
    }
    $sth->execute();
    if ($list_mode =~ /VERTICAL/) {
        while (my $row = $sth->fetchrow_hashref()) {
            foreach my $name (@order) {
                next if ($name =~ /retro_systems|accomplishments/);
                if ($name ne 'id' && $row->{$name} =~ /^(0|1)$/) {
                    $row->{$name} = $self->sysop_true_false($row->{$name}, 'YN');
                }
                $value_width = max(length($row->{$name}), $value_width);
                $self->{'debug'}->DEBUGMAX([$row, $name_width, $value_width]);
            } ## end foreach my $name (@order)
        } ## end while (my $row = $sth->fetchrow_hashref...)
        $sth->finish();
        $self->{'debug'}->DEBUG(['Populate the table']);
        $sth = $self->{'dbh'}->prepare($sql);
        $sth->execute();
        $table = Text::SimpleTable->new($name_width, $value_width);
        $table->row('NAME', 'VALUE');

        while (my $Row = $sth->fetchrow_hashref()) {
			$table->hr();
            foreach my $name (@order) {
                if ($name ne 'id' && $Row->{$name} =~ /^(0|1)$/) {
                    $Row->{$name} = $self->sysop_true_false($Row->{$name}, 'YN');
                } elsif ($name eq 'timeout') {
                    $Row->{$name} = $Row->{$name} . ' Minutes';
                }
                $self->{'debug'}->DEBUGMAX([$name, $Row->{$name}]);
                $table->row($name . '', $Row->{$name} . '');
            } ## end foreach my $name (@order)
        } ## end while (my $Row = $sth->fetchrow_hashref...)
        $sth->finish();
        $self->{'debug'}->DEBUG(['Show table']);
        my $string = $table->boxes->draw();
        $self->{'debug'}->DEBUGMAX(\$string);
        $self->sysop_pager("$string\n");
    } else {    # Horizontal
        my @hw;
        foreach my $name (@order) {
            push(@hw, $self->{'SYSOP HEADING WIDTHS'}->{$name});
        }
        $self->{'debug'}->DEBUGMAX(\@hw);
        $table = Text::SimpleTable->new(@hw);
        if ($list_mode =~ /ABBREVIATED/) {
            $table->row(@order);
        } else {
            my @title = ();
            foreach my $heading (@order) {
                push(@title, $self->sysop_vertical_heading($heading));
            }
            $table->row(@title);
        } ## end else [ if ($list_mode =~ /ABBREVIATED/)]
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            my @vals = ();
            foreach my $name (@order) {
                push(@vals, $row->{$name} . '');
                $self->{'debug'}->DEBUGMAX([$name, $row->{$name}]);
            }
            $table->row(@vals);
        } ## end while (my $row = $sth->fetchrow_hashref...)
        $sth->finish();
        $self->{'debug'}->DEBUG(['Show table']);
        my $string = $table->boxes->draw();
        $self->{'debug'}->DEBUGMAX(\$string);
        $self->sysop_pager("$string\n");
    } ## end else [ if ($list_mode =~ /VERTICAL/)]
    print 'Press a key to continue ... ';
    return ($self->sysop_keypress(TRUE));
    return (TRUE);
} ## end sub sysop_list_users

sub sysop_list_files {
    my $self = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $sizes = {};
    while (my $row = $sth->fetchrow_hashref()) {
        foreach my $name (keys %{$row}) {
            if ($name eq 'file_size') {
                my $size = int($row->{$name}) . 'k';
                $sizes->{$name} = max(length($size), $sizes->{$name});
            } else {
                $sizes->{$name} = max(length("$row->{$name}"), $sizes->{$name});
            }
        } ## end foreach my $name (keys %{$row...})
    } ## end while (my $row = $sth->fetchrow_hashref...)
    $sth->finish();
    my $table = ($wsize > 150) ? Text::SimpleTable->new($sizes->{'filename'}, $sizes->{'title'}, $sizes->{'type'}, $sizes->{'description'}, $sizes->{'username'}, $sizes->{'file_size'}->{'uploaded'}) : Text::SimpleTable->new($sizes->{'filename'}, $sizes->{'title'}, max($sizes->{'extension'},4), $sizes->{'description'}, $sizes->{'username'}, $sizes->{'file_size'});;
    if ($wsize > 150) {
		$table->row('FILENAME', 'TITLE', 'TYPE', 'DESCRIPTION', 'USER', 'SIZE', 'UPLOADED');
	} else {
		$table->row('FILENAME', 'TITLE', 'TYPE', 'DESCRIPTION', 'USER', 'SIZE');
	}
    $table->hr();
    $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $category;

    while (my $row = $sth->fetchrow_hashref()) {
		if ($wsize > 150) {
			$table->row($row->{'filename'}, $row->{'title'}, $row->{'type'}, $row->{'description'}, $row->{'username'}, int($row->{'file_size'} / 1024) . 'k', $row->{'uploaded'},);
		} else {
			$table->row($row->{'filename'}, $row->{'title'}, $row->{'extension'}, $row->{'description'}, $row->{'username'}, int($row->{'file_size'} / 1024) . 'k');
		}
        $category = $row->{'category'};
    }
    $sth->finish();
    print "\nCATEGORY:  ", $category, "\n", $table->boxes->draw(), "\n", 'Press a Key To Continue ...';
    $self->sysop_keypress();
    print " BACK\n";
    return (TRUE);
} ## end sub sysop_list_files

sub sysop_select_file_category {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
    $sth->execute();
    my $table = Text::SimpleTable->new(3, 30, 50);
    $table->row('ID', 'TITLE', 'DESCRIPTION');
    $table->hr();
    my $max_id = 1;
    while (my $row = $sth->fetchrow_hashref()) {
        $table->row($row->{'id'}, $row->{'title'}, $row->{'description'});
        $max_id = $row->{'id'};
    }
    $sth->finish();
    print $table->boxes->draw(), "\n", $self->sysop_prompt('Choose ID (< = Nevermind)');
    my $line;
    do {
        $line = uc($self->sysop_get_line(3));
    } until ($line =~ /^(\d+|\<)/i);
    if ($line eq '<') {
        return (FALSE);
    } elsif ($line >= 1 && $line <= $max_id) {
        $sth = $self->{'dbh'}->prepare('UPDATE users SET file_category=? WHERE id=1');
        $sth->execute($line);
        $sth->finish();
        $self->{'USER'}->{'file_category'} = $line + 0;
        return (TRUE);
    } else {
        return (FALSE);
    }
} ## end sub sysop_select_file_category

sub sysop_edit_file_categories {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
    $sth->execute();
    my $table = Text::SimpleTable->new(3, 30, 50);
    $table->row('ID', 'TITLE', 'DESCRIPTION');
    $table->hr();
    while (my $row = $sth->fetchrow_hashref()) {
        $table->row($row->{'id'}, $row->{'title'}, $row->{'description'});
    }
    $sth->finish();
    print $table->boxes->draw(), "\n", $self->sysop_prompt('Choose ID (A = Add, < = Nevermind)');
    my $line;
    do {
        $line = uc($self->sysop_get_line(3));
    } until ($line =~ /^(\d+|A|\<)/i);
    if ($line eq 'A') {    # Add
        print "\nADD NEW FILE CATEGORY\n";
        $table = Text::SimpleTable->new(11, 80);
        $table->row('TITLE',       "\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x 80);
        $table->row('DESCRIPTION', "\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x 80);
        print "\n", $table->boxes->draw();
        print $self->{'ansi_sequences'}->{'UP'} x 5, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
        my $title = $self->sysop_get_line(80);
        if ($title ne '') {
            print "\r", $self->{'ansi_sequences'}->{'DOWN'}, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
            my $description = $self->sysop_get_line(80);
            if ($description ne '') {
                $sth = $self->{'dbh'}->prepare('INSERT INTO file_categories (title,description) VALUES (?,?)');
                $sth->execute($title, $description);
                $sth->finish();
                print "\n\nNew Entry Added\n";
            } else {
                print "\n\nNevermind\n";
            }
        } else {
            print "\n\n\nNevermind\n";
        }
    } elsif ($line =~ /\d+/) {    # Edit
    }
    return (TRUE);
} ## end sub sysop_edit_file_categories

sub sysop_vertical_heading {
    my $self = shift;
    my $text = shift;

    my $heading = '';
    for (my $count = 0; $count < length($text); $count++) {
        $heading .= substr($text, $count, 1) . "\n";
    }
    return ($heading);
} ## end sub sysop_vertical_heading

sub sysop_view_configuration {
    my $self = shift;
    my $view = shift;

    # Get maximum widths
    my $name_width  = 6;
    my $value_width = 50;
    foreach my $cnf (keys %{ $self->configuration() }) {
        if ($cnf eq 'STATIC') {
            foreach my $static (keys %{ $self->{'CONF'}->{$cnf} }) {
                $name_width  = max(length($static),                            $name_width);
                $value_width = max(length($self->{'CONF'}->{$cnf}->{$static}), $value_width);
            }
        } else {
            $name_width  = max(length($cnf),                    $name_width);
            $value_width = max(length($self->{'CONF'}->{$cnf}), $value_width);
        }
    } ## end foreach my $cnf (keys %{ $self...})
    $self->{'debug'}->DEBUGMAX([$name_width, $value_width]);

    # Assemble table
    my $table = ($view) ? Text::SimpleTable->new($name_width, $value_width) : Text::SimpleTable->new(6, $name_width, $value_width);
    if ($view) {
        $table->row('STATIC NAME', 'STATIC VALUE');
    } else {
        $table->row(' ', 'STATIC NAME', 'STATIC VALUE');
    }
    $table->hr();
    foreach my $conf (sort(keys %{ $self->{'CONF'}->{'STATIC'} })) {
        next if ($conf eq 'DATABASE PASSWORD');
        if ($view) {
            $table->row($conf, $self->{'CONF'}->{'STATIC'}->{$conf});
        } else {
            $table->row(' ', $conf, $self->{'CONF'}->{'STATIC'}->{$conf});
        }
    } ## end foreach my $conf (sort(keys...))
    $table->hr();
    if ($view) {
        $table->row('NAME IN DB', 'VALUE IN DB');
    } else {
        $table->row('CHOICE', 'NAME IN DB', 'VALUE IN DB');
    }
    $table->hr();
    my $count = 0;
    foreach my $conf (sort(keys %{ $self->{'CONF'} })) {
        next if ($conf eq 'STATIC');
        if ($view) {
            $table->row($conf, $self->{'CONF'}->{$conf});
        } else {
            if ($conf =~ /AUTHOR/) {
                $table->row(' ', $conf, $self->{'CONF'}->{$conf});
            } else {
                $table->row($count, $conf, $self->{'CONF'}->{$conf});
                $count++;
            }
        } ## end else [ if ($view) ]
    } ## end foreach my $conf (sort(keys...))
    my $output = $table->boxes->draw();
    foreach my $change ('AUTHOR EMAIL', 'AUTHOR LOCATION', 'AUTHOR NAME', 'STATIC NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME') {
        if ($output =~ /($change)/) {
            my $ch = colored(['yellow'], $1);
            $output =~ s/$1/$ch/gs;
        }
    } ## end foreach my $change ('AUTHOR EMAIL'...)
    print $output;
    if ($view) {
        print 'Press a key to continue ... ';
        return ($self->sysop_keypress(TRUE));
    } else {
        print $self->sysop_menu_choice('TOP',    '',    '');
        print $self->sysop_menu_choice('Z',      'RED', 'Return to Settings Menu');
        print $self->sysop_menu_choice('BOTTOM', '',    '');
        print $self->sysop_prompt('Choose');
        return (TRUE);
    } ## end else [ if ($view) ]
} ## end sub sysop_view_configuration

sub sysop_edit_configuration {
    my $self = shift;

    $self->sysop_view_configuration(FALSE);
    my $choice;
    do {
        $choice = $self->sysop_keypress(TRUE);
    } until ($choice =~ /\d|Z/i);
    if ($choice !~ /\d/i) {
        print "BACK\n";
        return (FALSE);
    }
    my @conf = grep(!/STATIC|AUTHOR/, sort(keys %{ $self->{'CONF'} }));
    $self->{'debug'}->DEBUGMAX(["Choice $choice $conf[$choice]"]);
    print '(Edit) ', $conf[$choice], ' ', $self->{'sysop_tokens'}->{'BIG BULLET RIGHT'}, '  ';
    my $sizes = {
        'BAUD RATE'         => 4,
        'BBS NAME'          => 50,
        'BBS ROOT'          => 60,
        'HOST'              => 20,
        'THREAD MULTIPLIER' => 2,
        'PORT'              => 5,
    };
    my $string = $self->sysop_get_line($sizes->{ $conf[$choice] });
    return (FALSE) if ($string eq '');
    $self->{'debug'}->DEBUGMAX(["New value $conf[$choice] = $string"]);
    $self->configuration($conf[$choice], $string);
    return (TRUE);
} ## end sub sysop_edit_configuration

sub sysop_get_line {
    my $self  = shift;
    my $width = shift || 50;

    print savepos, "\n", loadpos, $self->{'ansi_sequences'}->{'DOWN'}, $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x $width, loadpos;
    chomp(my $response = <STDIN>);

    # TEMP
    return ($response);
} ## end sub sysop_get_line

sub sysop_user_delete {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Begin user Delete']);
    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my $key;
    print $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(20);
    return (FALSE) if ($search eq '' || $search eq 'sysop' || $search eq '1');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();
    if (defined($user_row)) {
        my $table = Text::SimpleTable->new(16, 60);
        $table->row('FIELD', 'VALUE');
        $table->hr();
        foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
			if ($field ne 'id' && $user_row->{$field} =~ /^(0|1)$/) {
				$user_row->{$field} = $self->sysop_true_false($user_row->{$field}, 'YN');
			} elsif ($field eq 'timeout') {
				$user_row->{$field} = $user_row->{$field} . ' Minutes';
			}
			$table->row($field, $user_row->{$field} . '');
        } ## end foreach my $field (@{ $self...})
		if ($self->sysop_pager($table->boxes->draw())) {
			print "Are you sure that you want to delete this user (Y|N)?  ";
			my $answer = $self->sysop_decision();
			if ($answer) {
				print "\n\nDeleting ",$user_row->{'username'}," ... ";
				$sth = $self->users_delete($user_row->{'id'});
			}
		}
	}
}

sub sysop_user_edit {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Begin user Edit']);
    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
    my $key;
    print $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(20);
    return (FALSE) if ($search eq '');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($user_row)) {
        $self->{'debug'}->DEBUGMAX($user_row);
        my $table = Text::SimpleTable->new(6, 16, 60);
        $table->row('CHOICE', 'FIELD', 'VALUE');
        $table->hr();
        my $count = 0;
        $self->{'debug'}->DEBUGMAX(['HERE', $self->{'SYSOP ORDER DETAILED'}]);
        my %choice;
        foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
            if ($field =~ /_time|fullname|_category|id/) {
                $table->row(' ', $field, $user_row->{$field} . '');
            } else {
                if ($field ne 'id' && $user_row->{$field} =~ /^(0|1)$/) {
                    $user_row->{$field} = $self->sysop_true_false($user_row->{$field}, 'YN');
                } elsif ($field eq 'timeout') {
                    $user_row->{$field} = $user_row->{$field} . ' Minutes';
                }
                $count++ if ($key_exit eq $choices[$count]);
                $table->row($choices[$count], $field, $user_row->{$field} . '');
                $choice{ $choices[$count] } = $field;
                $count++;
            } ## end else [ if ($field =~ /_time|fullname|_category|id/)]
        } ## end foreach my $field (@{ $self...})
        print $table->boxes->draw(), "\n";
        $self->{'debug'}->DEBUGMAX([$mapping]);
        $self->sysop_show_choices($mapping);
        print "\n", $self->sysop_prompt('Choose');
        do {
            $key = uc($self->sysop_keypress());
        } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
        if ($key !~ /$key_exit/i) {
            print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
            my $new = $self->sysop_get_line(1 + $self->{'SYSOP HEADING WIDTHS'}->{ $choice{$key} });
            unless ($new eq '') {
                $new =~ s/^(Yes|On)$/1/i;
                $new =~ s/^(No|Off)$/0/i;
            }
            if ($key =~ /prefer_nickname|view_files|upload_files|download_files|remove_files|read_message|post_message|remove_message|sysop|page_sysop/) {
                my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . choice { $key } . '=? WHERE id=?');
                $sth->execute($new, $user_row->{'id'});
                $sth->finish();
            } else {
                my $sth = $self->{'dbh'}->prepare('UPDATE users SET ' . $choice{$key} . '=? WHERE id=?');
                $sth->execute($new, $user_row->{'id'});
                $sth->finish();
            }
		} else {
			print "BACK\n";
        } ## end if ($key !~ /$key_exit/i)
    } elsif ($search ne '') {
        print "User not found!\n\n";
    }
    return (TRUE);
} ## end sub sysop_user_edit

sub sysop_user_add {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $flags_default = {
        'prefer_nickname' => 'Yes',
        'view_files'      => 'Yes',
        'upload_files'    => 'No',
        'download_files'  => 'Yes',
        'remove_files'    => 'No',
        'read_message'    => 'Yes',
        'post_message'    => 'Yes',
        'remove_message'  => 'No',
        'sysop'           => 'No',
        'page_sysop'      => 'Yes',
    };
    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $table = Text::SimpleTable->new(15, 80);
    my $user_template;
    push(@{ $self->{'SYSOP ORDER DETAILED'} }, 'password');

    foreach my $name (@{ $self->{'SYSOP ORDER DETAILED'} }) {
        next if ($name =~ /id|fullname|_time|suffix|max_|_category/);
        if ($name eq 'timeout') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Minutes\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name eq 'baud_rate') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (300,1200,2400,4800,9600,FULL)\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /username|given|family|password/) {
            if ($name eq 'given') {
                $table->row("$name (first)", ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            } elsif ($name eq 'family') {
                $table->row("$name (last)", ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            } else {
                $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            }
        } elsif ($name eq 'text_mode') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (ASCII,ATASCII,PETSCII,ANSI)\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name eq 'birthday') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " YEAR-MM-DD\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/) {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (Yes/No or On/Off or 1/0)\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /location|retro_systems|accomplishments/) {
            $table->row($name, "\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x ($self->{'SYSOP HEADING WIDTHS'}->{$name} * 4));
        } else {
            $table->row($name, "\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        }
        $user_template->{$name} = undef;
    } ## end foreach my $name (@{ $self->...})
    print $table->boxes->draw();
    $self->sysop_show_choices($mapping);
    my $column     = 21;
    my $adjustment = 7;
    foreach my $entry (@{ $self->{'SYSOP ORDER DETAILED'} }) {
        next if ($entry =~ /id|fullname|_time|suffix/);
        do {
            print locate($row + $adjustment, $column), ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$entry}), locate($row + $adjustment, $column);
            chomp($user_template->{$entry} = <STDIN>);
            return ('BACK') if ($user_template->{$entry} eq '<');
            if ($entry =~ /text_mode|baud_rate|timeout|prefer|_files|_message|sysop|given|family/) {
                if ($user_template->{$entry} eq '') {
                    if ($entry eq 'text_mode') {
                        $user_template->{$entry} = 'ASCII';
                    } elsif ($entry eq 'baud_rate') {
                        $user_template->{$entry} = 'FULL';
                    } elsif ($entry eq 'timeout') {
                        $user_template->{$entry} = $self->{'CONF'}->{'DEFAULT TIMEOUT'};
                    } elsif ($entry =~ /prefer|_files|_message|sysop/) {
                        $user_template->{$entry} = $flags_default->{$entry};
                    } else {
                        $user_template->{$entry} = uc($user_template->{$entry});
                    }
                } elsif ($entry =~ /given|family/) {
                    my $ucuser = uc($user_template->{$entry});
                    if ($ucuser eq $user_template->{$entry}) {
                        $user_template->{$entry} = ucfirst(lc($user_template->{$entry}));
                    } else {
                        substr($user_template->{$entry}, 0, 1) = uc(substr($user_template->{$entry}, 0, 1));
                    }
                } ## end elsif ($entry =~ /given|family/)
                print locate($row + $adjustment, $column), $user_template->{$entry};
            } elsif ($entry =~ /prefer_|_files|_message|sysop/) {
                $user_template->{$entry} = ucfirst($user_template->{$entry});
                print locate($row + $adjustment, $column), $user_template->{$entry};
            }
        } until ($self->sysop_validate_fields($entry, $user_template->{$entry}, $row + $adjustment, $column));
        $self->{'debug'}->DEBUGMAX([$entry, $user_template]);
        if ($user_template->{$entry} =~ /^(yes|on|true)$/i) {
            $user_template->{$entry} = TRUE;
        } elsif ($user_template->{$entry} =~ /^(no|off|false)$/i) {
            $user_template->{$entry} = FALSE;
        }
        $adjustment += 2;
    } ## end foreach my $entry (@{ $self...})
    pop(@{ $self->{'SYSOP ORDER DETAILED'} });
	if ($self->users_add($user_template)) {
		print "\n\n",colored(['green'],'SUCCESS'),"\n";
		return(TRUE);
	}
    return (FALSE);
} ## end sub sysop_user_add

sub sysop_show_choices {
    my $self    = shift;
    my $mapping = shift;

    print $self->sysop_menu_choice('TOP', '', '');
    my $keys = '';
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        print $self->sysop_menu_choice($kmenu, $mapping->{$kmenu}->{'color'}, $mapping->{$kmenu}->{'text'});
        $keys .= $kmenu;
    }
    print $self->sysop_menu_choice('BOTTOM', '', '');
    return (TRUE);
} ## end sub sysop_show_choices

sub sysop_validate_fields {
    my $self   = shift;
    my $name   = shift;
    my $val    = shift;
    my $row    = shift;
    my $column = shift;

    $self->{'debug'}->DEBUGMAX([$name, $val, $row, $column]);
    if ($name =~ /(username|given|family|baud_rate|timeout|_files|_message|sysop|prefer|password)/ && $val eq '') {    # cannot be empty
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Cannot Be Empty'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'baud_rate' && $val !~ /^(300|1200|2400|4800|9600|FULL)$/i) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only 300,1200,2400,4800,9600,FULL'), locate($row, $column);
        return (FALSE);
    } elsif ($name =~ /max_/ && $val =~ /\D/i) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only Numeric Values'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'timeout' && $val =~ /\D/) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Must be numeric'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'text_mode' && $val !~ /^(ASCII|ATASCII|PETSCII|ANSI)$/) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only ASCII,ATASCII,PETSCII,ANSI'), locate($row, $column);
        return (FALSE);
    } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/ && $val !~ /^(yes|no|true|false|on|off|0|1)$/i) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only Yes/No or On/Off or 1/0'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'birthday' && $val ne '' && $val !~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' YEAR-MM-DD'), locate($row, $column);
        return (FALSE);
    }
    return (TRUE);
} ## end sub sysop_validate_fields

sub sysop_prompt {
    my $self     = shift;
    my $text     = shift;
    my $response = $text . ' ' . $self->{'sysop_tokens'}->{'BIG BULLET RIGHT'} . ' ';
    return ($response);
} ## end sub sysop_prompt

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUGMAX([$text]);    # Before
    foreach my $key (keys %{ $self->{'sysop_tokens'} }) {
        my $ch = '';
        if (ref($self->{'sysop_tokens'}->{$key}) eq 'CODE') {
            $ch = $self->{'sysop_tokens'}->{$key}->($self);
        } else {
            $ch = $self->{'sysop_tokens'}->{$key};
        }
        $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
    } ## end foreach my $key (keys %{ $self...})
    foreach my $name (keys %{ $self->{'ansi_sequences'} }) {
        my $ch = $self->{'ansi_sequences'}->{$name};
        if ($name eq 'CLEAR') {
            $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
        }
        $text =~ s/\[\%\s+$name\s+\%\]/$ch/sgi;
    } ## end foreach my $name (keys %{ $self...})
    $self->{'debug'}->DEBUGMAX([$text]);    # After

    return ($text);
} ## end sub sysop_detokenize

sub sysop_menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

    my $response;
    if ($choice eq 'TOP') {
        $response = $self->{'sysop_tokens'}->{'TOP LEFT ROUNDED'} . $self->{'sysop_tokens'}->{'THIN HORIZONTAL BAR'} . $self->{'sysop_tokens'}->{'TOP RIGHT ROUNDED'} . "\n";
    } elsif ($choice eq 'BOTTOM') {
        $response = $self->{'sysop_tokens'}->{'BOTTOM LEFT ROUNDED'} . $self->{'sysop_tokens'}->{'THIN HORIZONTAL BAR'} . $self->{'sysop_tokens'}->{'BOTTOM RIGHT ROUNDED'} . "\n";
    } else {
        $response = $self->{'sysop_tokens'}->{'THIN VERTICAL BAR'} . colored(["BOLD $color"], $choice) . $self->{'sysop_tokens'}->{'THIN VERTICAL BAR'} . ' ' . colored([$color], $self->{'sysop_tokens'}->{'BIG BULLET RIGHT'}) . ' ' . $desc . "\n";
    }
    return ($response);
} ## end sub sysop_menu_choice

sub sysop_showenv {
    my $self = shift;
    my $MAX  = 0;

    my $text = '';
    foreach my $e (keys %ENV) {
        $MAX = max(length($e), $MAX);
    }

    foreach my $env (sort(keys %ENV)) {
        if ($ENV{$env} =~ /\n/g) {
            my @in     = split(/\n/, $ENV{$env});
            my $indent = $MAX + 4;
            $text .= sprintf("%${MAX}s = ---" . $env) . "\n";
            foreach my $line (@in) {
                if ($line =~ /\:/) {
                    my ($f, $l) = $line =~ /^(.*?):(.*)/;
                    chomp($l);
                    chomp($f);
                    $f = uc($f);
                    if ($f eq 'IP') {
                        $l = colored(['bright_green'], $l);
                        $f = 'IP ADDRESS';
                    }
                    my $le = 11 - length($f);
                    $f .= ' ' x $le;
                    $l = colored(['green'],    uc($l))                                                           if ($l =~ /^ok/i);
                    $l = colored(['bold red'], 'U') . colored(['bold white'], 'S') . colored(['bold blue'], 'A') if ($l =~ /^us/i);
                    $text .= colored(['bold white'], sprintf("%${indent}s", $f)) . " = $l\n";
                } else {
                    $text .= "$line\n";
                }
            } ## end foreach my $line (@in)
        } elsif ($env eq 'SSH_CLIENT') {
            my ($ip, $p1, $p2) = split(/ /, $ENV{$env});
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ip) . ' ' . colored(['cyan'], $p1) . ' ' . colored(['yellow'], $p2) . "\n";
        } elsif ($env eq 'SSH_CONNECTION') {
            my ($ip1, $p1, $ip2, $p2) = split(/ /, $ENV{$env});
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ip1) . ' ' . colored(['cyan'], $p1) . ' ' . colored(['bright_green'], $ip2) . ' ' . colored(['yellow'], $p2) . "\n";
        } elsif ($env eq 'TERM') {
            my $colorized = colored(['red'], '2') . colored(['green'], '5') . colored(['yellow'], '6') . colored(['cyan'], 'c') . colored(['bright_blue'], 'o') . colored(['magenta'], 'l') . colored(['bright_green'], 'o') . colored(['bright_blue'], 'r');
            my $line      = $ENV{$env};
            $line =~ s/256color/$colorized/;
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . $line . "\n";
        } elsif ($env eq 'WHATISMYIP') {
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ENV{$env}) . "\n";
        } else {
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . $ENV{$env} . "\n";
        }
    } ## end foreach my $env (sort(keys ...))
    return ($text);
} ## end sub sysop_showenv

sub sysop_scroll {
    my $self = shift;
    print "Scroll?  ";
    if ($self->sysop_keypress(ECHO, BLOCKING) =~ /N/i) {
        return (FALSE);
    }
    print "\r" . clline;
    return (TRUE);
} ## end sub sysop_scroll

sub sysop_list_bbs {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view');
    $sth->execute();
    my @listing;
    my ($id_size, $name_size, $hostname_size, $poster_size) = (1, 1, 1, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $id_size       = max(length('' . $row->{'bbs_id'}),  $id_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    } ## end while (my $row = $sth->fetchrow_hashref...)
    my $table = Text::SimpleTable->new($id_size, $name_size, $hostname_size, 5, $poster_size);
    $table->row('ID', 'NAME', 'HOSTNAME', 'PORT', 'POSTER');
    $table->hr();
    foreach my $line (@listing) {
        $table->row($line->{'bbs_id'}, $line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
    }
    print $table->boxes->draw();
    print 'Press a key to continue... ';
    $self->sysop_keypress();
} ## end sub sysop_list_bbs

sub sysop_edit_bbs {
    my $self = shift;

    my @choices = (qw( bbs_id bbs_name bbs_hostname bbs_port ));
    print $self->prompt('Please enter the ID, the hostname, or the BBS name to edit');
    my $search;
    $search = $self->sysop_get_line(50);
    return (FALSE) if ($search eq '');
    print "\r", cldown, "\n";
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
    $sth->execute($search, $search, $search);

    if ($sth->rows()) {
        my $bbs = $sth->fetchrow_hashref();
        $sth->finish();
        my $table = Text::SimpleTable->new(6, 12, 50);
        my $index = 1;
        $table->row('CHOICE', 'FIELD NAME', 'VALUE');
        $table->hr();
        foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port)) {
            if ($name =~ /bbs_id|bbs_poster/) {
                $table->row(' ', $name, $bbs->{$name});
            } else {
                $table->row($index, $name, $bbs->{$name});
                $index++;
            }
        } ## end foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port))
        print $table->boxes->draw();
        print $self->prompt('Edit which field (Z=Nevermind)');
        my $choice;
        do {
            $choice = $self->sysop_keypress();
        } until ($choice =~ /[1-3]|Z/i);
        if ($choice =~ /\D/) {
            print "BACK\n";
            return (FALSE);
        }
        print "\n", $self->sysop_prompt($choices[$choice] . ' (' . $bbs->{ $choices[$choice] } . ') ');
        my $width = ($choices[$choice] eq 'bbs_port') ? 5 : 50;
        my $new   = $self->sysop_get_line($width);
        return (FALSE) if ($new eq '');
        $sth = $self->{'dbh'}->prepare('UPDATE bbs_listing SET ' . $choices[$choice] . '=? WHERE bbs_id=?');
        $sth->execute($new, $bbs->{'bbs_id'});
        $sth->finish();
    } else {
        $sth->finish();
    }
} ## end sub sysop_edit_bbs

sub sysop_add_bbs {
    my $self = shift;

    my $table = Text::SimpleTable->new(12, 50);
    foreach my $name (qw(bbs_name bbs_hostname bbs_port)) {
        my $count = ($name eq 'bbs_port') ? 5 : 50;
        $table->row($name, "\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x $count);
        $table->hr() unless ($name eq 'bbs_port');
    }
    my @order = (qw(bbs_name bbs_hostname bbs_port));
    my $bbs   = {
		'bbs_name' => '',
		'bbs_hostname' => '',
		'bbs_port' => '',
	};
    my $index = 0;
    print $table->boxes->draw();
    print $self->{'ansi_sequences'}->{'UP'} x 9, $self->{'ansi_sequences'}->{'RIGHT'} x 17;
    $bbs->{'bbs_name'} = $self->sysop_get_line(50);
    if ($bbs->{'bbs_name'} ne '' && length($bbs->{'bbs_name'}) > 3) {
        print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 17;
        $bbs->{'bbs_hostname'} = $self->sysop_get_line(50);
        if ($bbs->{'bbs_hostname'} ne '' && length($bbs->{'bbs_hostname'}) > 5) {
            print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 17;
            $bbs->{'bbs_port'} = $self->sysop_get_line(5);
            if ($bbs->{'bbs_port'} ne '' && $bbs->{'bbs_port'} =~ /^\d+$/) {
                my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
                $sth->execute($bbs->{'bbs_name'}, $bbs->{'bbs_hostname'}, $bbs->{'bbs_port'});
                $sth->finish();
            } else {
                return (FALSE);
            }
        } else {
            return (FALSE);
        }
    } else {
        return (FALSE);
    }
    return (TRUE);
} ## end sub sysop_add_bbs

sub sysop_delete_bbs {
	my $self = shift;
    print $self->prompt('Please enter the ID, the hostname, or the BBS name to delete');
    my $search;
    $search = $self->sysop_get_line(50);
    return (FALSE) if ($search eq '');
    print "\r", cldown, "\n";
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
    $sth->execute($search, $search, $search);

    if ($sth->rows()) {
        my $bbs = $sth->fetchrow_hashref();
        $sth->finish();
        my $table = Text::SimpleTable->new(12, 50);
        $table->row('FIELD NAME', 'VALUE');
        $table->hr();
        foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port)) {
			$table->row($name, $bbs->{$name});
        } ## end foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port))
        print $table->boxes->draw();
        print 'Are you sure that you want to delete this BBS from the list (Y|N)?  ';
        my $choice = $self->sysop_decision();
        unless($choice) {
            return (FALSE);
        }
        $sth = $self->{'dbh'}->prepare('DELETE FROM bbs_listing WHERE bbs_id=?');
        $sth->execute($bbs->{'bbs_id'});
    }
	$sth->finish();
	return(TRUE);
}

 

# package BBS::Universal::Users;

sub users_initialize {
    my $self = shift;

    $self->{'USER'}->{'mode'} = ASCII;
    $self->{'debug'}->DEBUG(['Users initialized']);
    return ($self);
} ## end sub users_initialize

sub users_load {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    my $sth;
    if ($self->{'sysop'}) {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE username=?');
        $sth->execute($username);
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE username=? AND password=SHA2(?,512)');
        $sth->execute($username, $password);
    }
    my $results = $sth->fetchrow_hashref();
    if (defined($results)) {
        $self->{'debug'}->DEBUG(["$username found"]);
        $self->{'USER'} = $results;
        delete($self->{'USER'}->{'password'});
        return (TRUE);
    } ## end if (defined($results))
    return (FALSE);
} ## end sub users_load

sub users_list {
    my $self = shift;
}

sub users_add {
    my $self = shift;
	my $user_template = shift;

    $self->{'dbh'}->begin_work;
	my $sth = $self->{'dbh'}->prepare(
		q{
			INSERT INTO users (
				username,
				given,
				family,
				nickname,
				accomplishments,
				retro_systems,
				birthday,
				location,
				baud_rate,
				text_mode,
				password)
			  VALUES (?,?,?,?,?,?,DATE(?),?,?,(SELECT text_modes.id FROM text_modes WHERE text_modes.text_mode=?),SHA2(?,512))
		}
	);
	$self->{'debug'}->DEBUGMAX($user_template);
	$sth->execute($user_template->{'username'}, $user_template->{'given'}, $user_template->{'family'}, $user_template->{'nickname'}, $user_template->{'accomplishments'}, $user_template->{'retro_systems'}, $user_template->{'birthday'}, $user_template->{'location'}, $user_template->{'baud_rate'}, $user_template->{'text_mode'}, $user_template->{'password'},) or $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
	$sth = $self->{'dbh'}->prepare(
		q{
			INSERT INTO permissions (
				id,
				prefer_nickname,
				view_files,
				upload_files,
				download_files,
				remove_files,
				read_message,
				post_message,
				remove_message,
				sysop,
				page_sysop,
				timeout)
			  VALUES (LAST_INSERT_ID(),?,?,?,?,?,?,?,?,?,?,?);
		}
	);
	$sth->execute($user_template->{'prefer_nickname'}, $user_template->{'view_files'}, $user_template->{'upload_files'}, $user_template->{'download_files'}, $user_template->{'remove_files'}, $user_template->{'read_message'}, $user_template->{'post_message'}, $user_template->{'remove_message'}, $user_template->{'sysop'}, $user_template->{'page_sysop'}, $user_template->{'timeout'});

	if ($self->{'dbh'}->errstr) {
		$self->{'dbh'}->rollback;
		$self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
		$sth->finish();
		return(FALSE);
	} else {
		$self->{'dbh'}->commit;
		$self->{'debug'}->DEBUG(['Success']);
		$sth->finish();
		return(TRUE);
	}
}

sub users_edit {
    my $self = shift;
}

sub users_delete {
    my $self = shift;
	my $id   = shift;

	$self->{'debug'}->WARNING(["Delete user $id"]);
	$self->{'debug'}->DEBUG(['Delete Permissions first']);
	$self->{'dbh'}->begin_work();
	my $sth = $self->{'dbh'}->prepare('DELETE FROM permissions WHERE id=?');
	$sth->execute($id);
	if ($self->{'dbh'}->errstr) {
		$self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
		$self->{'dbh'}->rollback();
		$sth->finish();
		return(FALSE);
	} else {
		$sth->finish();
		$self->{'debug'}->DEBUG(['Permissions deleted, now the user']);
		$sth = $self->{'dbh'}->prepare('DELETE FROM users WHERE id=?');
		$sth->execute($id);
		if ($self->{'dbh'}->errstr) {
			$self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
			$self->{'dbh'}->rollback();
			$sth->finish();
			return(FALSE);
		} else {
			$self->{'dbh'}->commit();
			$self->{'debug'}->DEBUG(['Success']);
			$sth->finish();
			return(TRUE);
		}
	}
}

sub users_file_category {
	my $self = shift;

	my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
	$sth->execute($self->{'USER'}->{'file_category'});
	my ($category) = ($sth->fetchrow_array());
	$sth->finish();
	return($category);
}

sub users_forum_category {
	my $self = shift;

	my $sth = $self->{'dbh'}->prepare('SELECT name FROM message_categories WHERE id=?');
	$sth->execute($self->{'USER'}->{'forum_category'});
	my ($category) = ($sth->fetchrow_array());
	$sth->finish();
	return($category);
}

sub users_find {
    my $self = shift;
}

sub users_count {
    my $self = shift;
    return (0);
}

sub user_info {
    my $self = shift;
    return ('');
}

 

1;
