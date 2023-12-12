package BBS::Universal;

# Pragmas
use strict;
no strict 'subs';
use utf8;
use constant {
    TRUE  => 1,
    FALSE => 0,
	YES   => 1,
	NO    => 0,

    ASCII   => 0,
    ATASCII => 1,
    PETSCII => 2,
    ANSI    => 3,
};
use English qw( -no_match_vars );
use Config;
use open qw(:std :utf8);

# Modules
use Debug::Easy;
use DateTime;
use DBI;
use DBD::mysql;
use File::Basename;
use Time::HiRes qw(time sleep);
use Term::ReadKey;
use Term::ANSIScreen qw( :color :cursor :screen );
use Text::Format;
use Text::SimpleTable;
use IO::Socket::INET;
use List::Util qw(min max);

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      TRUE
      FALSE
	  YES
	  NO
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
    our $DB_VERSION = '0.001';
    our $FILETRANSFER_VERSION = '0.001';
    our $MESSAGES_VERSION = '0.001';
    our $PETSCII_VERSION = '0.001';
    our $SYSOP_VERSION = '0.001';
    our $USERS_VERSION = '0.001';
} ## end BEGIN
our $ONLINE  = 0;
our $THREADS_RUNNING = 0;

sub DESTROY {
    my $self = shift;
    $self->{'dbh'}->disconnect();
}

sub small_new {
    my $class = shift;
    my $self  = shift;

    bless($self, $class);
    $self->{'CPU'}  = $self->cpu_info();
    $self->{'CONF'} = $self->configuration();
	$self->{'VERSIONS'} = $self->parse_versions();
	$self->db_initialize();
	$self->ascii_initialize();
	$self->atascii_initialize();
	$self->petscii_initialize();
	$self->ansi_initialize();
	$self->filetransfer_initialize();
	$self->messages_initialize();
	$self->users_initialize();
    $self->sysop_initialize();
    $self->{'debug'}->DEBUGMAX([$self]);

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
        'suffixes'        => qw( ASC ATA PET ANS ),
        'speeds'          => {                       # This depends on the granularity of Time::HiRes
            'FULL'  => 0,
            '300'   => 0.02,
            '1200'  => 0.005,
            '2400'  => 0.0025,
			'4800'  => 0.00125,
            '9600'  => 0.000625,
            '19200' => 0.0003125,
        },
        'mode'      => ASCII,                        # Default mode
        'bbs_name'  => undef,                        # These are pulled in from the configuration or connection
        'baud_rate' => undef,
        'user'      => undef,
        'host'      => undef,
        'port'      => undef,
    };

    bless($self, $class);
    $self->{'baud_rate'} = $self->configuration('BAUD RATE');
    $self->{'CPU'}       = $self->cpu_info();
    $self->{'CONF'}      = $self->configuration();
	$self->db_initialize();
	$self->ascii_initialize();
	$self->atascii_initialize();
	$self->petscii_initialize();
	$self->ansi_initialize();
	$self->filetransfer_initialize();
	$self->messages_initialize();
	$self->users_initialize();
    $self->sysop_initialize();
    $self->{'debug'}->DEBUGMAX([$self]);

    return ($self);
} ## end sub new

sub run {
    my $self = shift;

    $self->{'ERROR'} = undef;

    if ($self->greeting()) {    # Greeting also logs in
        $self->main_menu();
    }
    $self->disconnect();
    return (defined($self->{'ERROR'}));
} ## end sub run

sub greeting {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Sending greeting']);

    # Load and print greetings message here
    my $text = $self->load_file('greetings');
    $self->output($text);
    $self->{'debug'}->DEBUG(['Greeting sent']);
    return ($self->login());    # Login will also create new users
} ## end sub greeting

sub login {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Attempting login']);
    my $valid = FALSE;

    # Login stuff here

    #
    return ($valid);
} ## end sub login

sub main_menu {
    my $self = shift;

    my $disconnect = FALSE;
    $self->{'debug'}->DEBUG(['Main Menu loop start']);
    do {
        my $text = $self->load_file('main_menu');
        $self->output($text);
        my $cmd = $self->get_key(TRUE);              # Wait for character
        if (defined($cmd) && length($cmd) == 1) {    # Sanity
        }
    } until ($disconnect);
    $self->{'debug'}->DEBUG(['Main Menu loop end']);
} ## end sub main_menu

sub disconnect {
    my $self = shift;

    # Load and print disconnect message here
    $self->{'debug'}->DEBUG(['Send Disconnect message']);
    my $text = $self->load_file('disconnect');
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
    my $echo     = shift || FALSE;
    my $blocking = shift || FALSE;

    my $key = undef;
    if ($self->{'local_mode'}) {
        $key = ($blocking) ? ReadKey(0) : ReadKey(-1);
    } else {
        if ($blocking) {
            $self->{'debug'}->DEBUG(['Get key - blocking']);
            $self->{'cl_socket'}->recv($key, 1, MSG_WAITALL);
        } else {
            $self->{'debug'}->DEBUGMAX(['Get key - non-blocking']);    # could swamp debug logging if DEBUG
            $self->{'cl_socket'}->recv($key, 1, MSG_DONTWAIT);
        }
    } ## end else [ if ($self->{'local_mode'...})]
    $self->{'debug'}->DEBUG(["Key pressed - $key"]);
    $self->output($key) if ($echo && defined($key));
    return ($key);
} ## end sub get_key

sub get_line {
    my $self = shift;
    my $line;

    return ($line);
} ## end sub get_line

sub detokenize_text {    # Detokenize text markup
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Detokenizing text']);
    my $tokens = {
        'AUTHOR'             => 'Richard Kelsch',
        'SYSOP'              => $self->{'sysop'},
        'CPU IDENTITY'       => $self->{'cpu_identity'},
        'CPU CORES'          => $self->{'cpu_count'},
        'CPU SPEED'          => $self->{'cpu_clock'},
        'CPU THREADS'        => $self->{'cpu_threads'},
        'OS'                 => $self->{'os'},
        'UPTIME'             => split(`/usr/bin/uptime`, ' ', 1),
        'VERSIONS'           => 'placeholder',
        'PERL VERSION'       => $self->{'versions'}->{'perl'},
        'BBS NAME'           => $self->{'bbs_name'},
        'BBS VERSION'        => $self->{'versions'}->{'bbs'},
        'USER ID'            => $self->{'user_id'},
        'USERNAME'           => $self->{'username'},
        'USER GIVEN'         => $self->{'user_given'},
        'USER FAMILY'        => $self->{'user_family'},
        'USER LOCATION'      => $self->{'user_location'},
        'USER BIRTHDAY'      => $self->{'user_birthday'},
        'USER RETRO SYSTEMS' => $self->{'user_retro_systems'},
        'USER LOGIN TIME'    => $self->{'user_login_time'},
        'USER TEXT MODE'     => $self->{'user_mode'},
        'USER PERMISSIONS'   => $self->{'user_permissions'},
        'BAUD RATE'          => $self->{'baud_rate'},
    };

    $self->{'debug'}->DEBUGMAX([$text]);    # Before
    foreach my $key (keys %$tokens) {
        if ($key eq 'VERSIONS' && $text =~ /$key/i) {
            my $versions = '';
            foreach my $names (@{$self->{'VERSIONS'}}) {
                $versions .= $names . "\n";
            }
            $text =~ s/\[\% $key \%\]/$versions/gi;
        } else {
            $text =~ s/\[\% $key \%\]/$tokens->{$key}/gi;
        }
    } ## end foreach my $key (keys %$tokens)
    $self->{'debug'}->DEBUGMAX([$text]);    # After
    return ($text);
} ## end sub detokenize_text

sub output {
    my $self = shift;
    my $text = $self->detokenize_text(shift);

    my $mode = $self->{'mode'};
    if ($mode == ATASCII) {
        $self->{'debug'}->DEBUG(['Send ATASCII']);
        $self->atascii_output($text);
    } elsif ($mode == PETSCII) {
        $self->{'debug'}->DEBUG(['Send PETSCII']);
        $self->petscii_output($text);
    } elsif ($mode == ANSI) {
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
    if ($self->{'local_mode'} || !defined($self->{'cl_socket'})) {
        print $char;
    } else {
        $self->{'cl_socket'}->send($char);
    }

    # Send at the chosen baud rate by delaying the output by a fraction of a second
    # Only delay if the baud_rate is not FULL
    sleep $self->{'speeds'}->{ $self->{'baud_rate'} } if ($self->{'baud_rate'} ne 'FULL');
    return (TRUE);
} ## end sub send_char

# Typical subroutines, not objects

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

        return($results);
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
		"IO::Socket::INET              $IO::Socket::INET::VERSION",
		"Sys::Info                     $Sys::Info::VERSION",
    ];
    return ($versions);
} ## end sub parse_versions

sub cpu_identify {
	my $self = shift;

	return($self->{'CPUINFO'}) if (exists($self->{'CPUINFO'}));
	open(my $CPU,'<','/proc/cpuinfo');
	chomp(my @cpuinfo = <$CPU>);
	close($CPU);
	$self->{'CPUINFO'} = \@cpuinfo;

	my $cpu_identity;
	my $index = 0;
	chomp(my $bits = `getconf LONG_BIT`);
	my $hardware = { 'Hardware' => 'Unknown', 'Bits' => $bits };
	foreach my $line (@cpuinfo) {
		if ($line ne '') {
			my ($name,$val) = split(/: /,$line);
			$name = $self->trim($name);
			if ($name =~ /^(Hardware|Revision|Serial)/i) {
				$hardware->{$name} = $val;
			} else {
				if ($name eq 'processor') {
					$index = $val;
				} else {
					$cpu_identity->[$index]->{$name} = $val;
				}
			}
		}
	}
	my $response = {
		'CPU'      => $cpu_identity,
		'HARDWARE' => $hardware,
	};
	if (-e '/usr/bin/lscpu' || -e 'usr/local/bin/lscpu') {
		my $lscpu_short = `lscpu --extended=cpu,core,online,minmhz,maxmhz,mhz`;
		chomp(my $lscpu_version = `lscpu -V`);
		$lscpu_version =~ s/^lscpu from util-linux (\d+)\.(\d+)\.(\d+)/$1.$2/;
		my $lscpu_long = ($lscpu_version >= 2.38) ? `lscpu --hierarchic` : `lscpu`;
		$response->{'lscpu'}->{'short'} = $lscpu_short;
		$response->{'lscpu'}->{'long'} = $lscpu_long;
	}
	$self->{'debug'}->DEBUGMAX($response);
	$self->{'CPUINFO'} = $response; # Cache this stuff
	return($response);
}

sub cpu_info {
    my $self = shift;

	my $cpu = $self->cpu_identify();
	my $cpu_cores = scalar(@{$cpu->{'CPU'}});
	my $cpu_threads = (exists($cpu->{'CPU'}->[0]->{'logical processors'})) ? $cpu->{'CPU'}->[0]->{'logical processors'} : 1;
	my $cpu_bits = $cpu->{'HARDWARE'}->{'Bits'} + 0;
	chomp(my $load_average = `cat /proc/loadavg`);
    my $identity = $cpu->{'CPU'}->[0]->{'model name'};

    my $speed = $cpu->{'CPU'}->[0]->{'cpu MHz'} if (exists($cpu->{'CPU'}->[0]->{'cpu MHz'}));

	unless(defined($speed)) {
		chomp($speed = `cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`);
		$speed /= 1000;
	}

    if ($speed > 999.999) {      # GHz
        $speed = sprintf('%.02f GHz', ($speed / 1000));
    } elsif ($speed > 0) {                     # MHz
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

    $self->{'ansi_prefix'}       = $esc;
    $self->{'ansi_sequences'} = {
        'CLEAR'      => cls,
		'CLS'        => cls,
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
        'GREEN'          => $esc . '32m',
        'YELLOW'         => $esc . '33m',
        'BLUE'           => $esc . '34m',
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
    };

    $self->{'debug'}->DEBUG(['Initialized VT102']);
    return ($self);
}

sub ansi_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Send ANSI text']);
    foreach my $string (keys %{ $self->{'ansi_sequences'} }) {
        $text =~ s/\[\% $string \%\]/$self->{'ansi_sequences'}->{$string}/gi;
    }
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
}

 

# package BBS::Universal::ASCII;

sub ascii_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['ASCII Initialized']);
    return ($self);
} ## end sub ascii_initialize

sub ascii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Send ASCII text']);
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub ascii_output

 

# package BBS::Universal::ATASCII;

sub atascii_initialize {
    my $self = shift;

    $self->{'atascii_sequences'} = {
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

    $self->{'debug'}->DEBUG(['Send ATASCII text']);
    foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
        $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
    }
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub atascii_output

 

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
	my @dbhosts = split(/\s*,\s*/,$self->{'CONF'}->{'STATIC'}->{'DATABASE HOSTNAME'});
	my $errors = '';
	foreach my $host (@dbhosts) {
		$errors = '';
		$self->{'dsn'} = sprintf('dbi:%s:database=%s;' . 
			'host=%s;' .
			'port=%s;',
			$self->{'CONF'}->{'STATIC'}->{'DATABASE TYPE'},
			$self->{'CONF'}->{'STATIC'}->{'DATABASE NAME'},
			$host,
			$self->{'CONF'}->{'STATIC'}->{'DATABASE PORT'},
		);
		$self->{'dbh'} = DBI->connect(
			$self->{'dsn'},
			$self->{'CONF'}->{'STATIC'}->{'DATABASE USERNAME'},
			$self->{'CONF'}->{'STATIC'}->{'DATABASE PASSWORD'},
			{
				'PrintError' => TRUE,
				'AutoCommit' => TRUE
			},
		) or $errors = $DBI::errstr;
		last if ($errors eq '');
	}
	if ($errors ne '') {
		$self->{'debug'}->ERROR(["Database Host not found!\n$errors"]);
		exit(1);
	}
	$self->{'debug'}->DEBUG(["Connected to DB $self->{dsn}"]);
    return (TRUE);
}

sub db_count_users {
	my $self = shift;

	unless (exists($self->{'dbh'})) {
		$self->db_connect();
	}
	my $response = $self->{'dbh'}->do('SELECT COUNT(id) FROM users');
	return($response);
}

sub db_disconnect {
    my $self = shift;

	$self->{'dbh'}->disconnect() if (defined($self->{'dbh'}));
    return (TRUE);
}

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
	return(TRUE);
}

 

# package BBS::Universal::FileTransfer;

sub filetransfer_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['FileTransfer initialized']);
    return ($self);
} ## end sub filetransfer_initialize

sub load_file {
    my $self = shift;
    my $file = shift;

    my $filename = sprintf('%s.%s', $file, $self->{'suffixes'}->[$self->{'mode'}]);
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    return (join("\n", @text));
} ## end sub load_file

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

 

# package BBS::Universal::PETSCII;

sub petscii_initialize {
    my $self = shift;

    $self->{'petscii_sequences'} = {
        'CLEAR'         => chr(hex('0x93')),
        'WHITE'         => chr(5),
        'BLACK'         => chr(hex('0x90')),
        'RED'           => chr(hex('0x1C')),
        'GREEN'         => chr(hex('0x1E')),
        'BLUE'          => chr(hex('0x1F')),
        'DARK PURPLE'   => chr(hex('0x81')),
        'UNDERLINE ON'  => chr(2),
        'UNDERLINE OFF' => chr(hex('0x82')),
        'BLINK ON'      => chr(hex('0x0F')),
        'BLINK OFF'     => chr(hex('0x8F')),
        'REVERSE ON'    => chr(hex('0x12')),
        'REVERSE OFF'   => chr(hex('0x92')),
        'BROWN'         => chr(hex('0x95')),
        'PINK'          => chr(hex('0x96')),
        'DARK CYAN'     => chr(hex('0x97')),
        'GRAY'          => chr(hex('0x98')),
        'LIGHT GREEN'   => chr(hex('0x99')),
        'LIGHT BLUE'    => chr(hex('0x9A')),
        'LIGHT GRAY'    => chr(hex('0x9B')),
        'PURPLE'        => chr(hex('0x9C')),
        'YELLOW'        => chr(hex('0x9E')),
        'CYAN'          => chr(hex('0x9F')),
        'UP'            => chr(hex('0x91')),
        'DOWN'          => chr(hex('0x11')),
        'LEFT'          => chr(hex('0x9D')),
        'RIGHT'         => chr(hex('0x1D')),
        'ESC'           => chr(hex('0x1B')),
        'LINE FEED'     => chr(hex('0x0A')),
        'TAB'           => chr(9),
        'BELL'          => chr(7),
    };
    $self->{'debug'}->DEBUG(['Initialized ASCII']);
    return ($self);
} ## end sub petscii_initialize

sub petscii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Send PETSCII text']);
    my $s_len = length($text);
    foreach my $string (keys %{ $self->{'petscii_sequences'} }) {    # Decode macros
        $text =~ s/\[\% $string \%\]/$self->{'petscii_sequences'}->{$string}/gi;
    }
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub petscii_output

 

# package BBS::Universal::SysOp;

sub sysop_initialize {
    my $self = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    #### Format Versions for display
    my $versions;
    if ($wsize > 120) {
        $versions = "\t" . colored(['bold yellow on_red'], clline . " NAME                          VERSION\t\t NAME                          VERSION") . colored(['on_red'], clline) . "\n";
        my $odd = FALSE;
        foreach my $v (@{ $self->{'VERSIONS'} }) {
            if ($odd) {
                $versions .= "\t\t $v\n";
            } else {
                $versions .= "\t\t\t $v";
            }
            $odd = !$odd;
        } ## end foreach my $v (@{ $self->{'VERSIONS'...}})
        $versions .= "\n" if ($odd);
    } else {
        $versions = "\t" . colored(['bold yellow on_red'], clline . " NAME                          VERSION") . colored(['on_red'], clline) . "\n";
        foreach my $v (@{ $self->{'VERSIONS'} }) {
            $versions .= "\t\t\t $v\n";
        }
    } ## end else [ if ($wsize > 120) ]

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
        'HOSTNAME'        => $self->sysop_hostname,
        'IP ADDRESS'      => $self->sysop_ip_address(),
        'CPU CORES'       => $self->{'CPU'}->{'CPU CORES'},
        'CPU SPEED'       => $self->{'CPU'}->{'CPU SPEED'},
        'CPU IDENTITY'    => $self->{'CPU'}->{'CPU IDENTITY'},
        'CPU THREADS'     => $self->{'CPU'}->{'CPU THREADS'},
        'HARDWARE'        => $self->{'CPU'}->{'HARDWARE'},
        'VERSIONS'        => $versions,
        'BBS NAME'        => colored(['green'], $self->{'CONF'}->{'BBS NAME'}),
		# Non-static
        'THREADS COUNT'   => sub {
			my $self = shift;
			return($THREADS_RUNNING);
		},
        'USERS COUNT'     => sub {
			my $self = shift;
			return($self->db_count_users());
		},
        'UPTIME'          => sub {
			my $self = shift;
			return($self->get_uptime());
		},
        'DISK FREE SPACE' => sub {
			my $self = shift;
			return($self->sysop_disk_free());
		},
        'MEMORY'          => sub {
			my $self = shift;
			return($self->sysop_memory());
		},
		'ONLINE'          => sub {
			my $self = shift;
			return($self->sysop_online_count());
		},
        'CPU LOAD'        => sub {
			my $self = shift;
			return($self->cpu_info->{'CPU LOAD'});
		},
    };
	$self->{'SYSOP ORDER DETAILED'} = [qw(
		    id
			username
			fullname
			given
			family
			nickname
			birthday
			location
			baud_rate
			text_mode
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
	)];
	$self->{'SYSOP ORDER ABBREVIATED'} = [qw(
			id
			username
			fullname
			given
			family
			nickname
			text_mode
	)];
	$self->{'SYSOP HEADING WIDTHS'} = {
			'id' => 2,
			'username' => 16,
			'fullname' => 20,
			'given' => 12,
			'family' => 12,
			'nickname' => 8,
			'birthday' => 10,
			'location' => 20,
			'baud_rate' => 4,
			'login_time' => 10,
			'logout_time' => 10,
			'text_mode' => 9,
			'suffix' => 3,
			'timeout' => 5,
			'retro_systems' => 20,
			'accomplishments' => 20,
			'prefer_nickname' => 2,
			'view_files' => 2,
			'upload_files' => 2,
			'download_files' => 2,
			'remove_files' => 2,
			'read_message' => 2,
			'post_message' => 2,
			'remove_message' => 2,
			'sysop' => 2,
			'page_sysop' => 2,
	};
    #$self->{'debug'}->ERROR($self);exit;
    $self->{'debug'}->DEBUG(['Initialized SysOp object']);
    return ($self);
} ## end sub sysop_initialize

sub sysop_online_count {
	my $self = shift;

	return($ONLINE);
}

sub sysop_disk_free {
    my $self = shift;

    my @free     = split(/\n/, `nice df -h`);
    my $diskfree = '';
    foreach my $line (@free) {
        next if ($line =~ /tmp|boot/);
        if ($line =~ /^Filesystem/) {
            $diskfree .= "\t" . colored(['bold yellow on_blue'], " $line") . colored(['on_blue'], clline) . "\n";
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
	my $found = FALSE;
	my @sql_files = ('./sql/database_setup.sql','~/.bbs_universal/database_setup.sql');
	foreach my $file (@sql_files) {
		if (-e $file) {
			$self->{'debug'}->DEBUG(["SQL file $file found"]);
			$found = TRUE;
			$self->db_sql_execute($file);
			last;
		}
		$self->{'debug'}->WARNING(["SQL file $file not found"]);
	}
	unless($found) {
		$self->{'debug'}->ERROR(['Database setup file not found',join("\n",@sql_files)]);
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

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUG(['Loaded SysOp Menu']);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $keys = '';
	print $self->sysop_menu_choice('TOP','','');
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        print $self->sysop_menu_choice($kmenu,$mapping->{$kmenu}->{'color'},$mapping->{$kmenu}->{'text'});
        $keys .= $kmenu;
    }
	print $self->sysop_menu_choice('BOTTOM','','');
    print "\n",$self->sysop_prompt('Choose');
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
    my $output = "\t" . colored(['bold black on_green'], '  ' . shift(@mem) . ' ' . clline) . "\n";
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
	my $self = shift;
	my $boolean = shift;
	my $mode = shift;
	$boolean = $boolean + 0;
	if ($mode eq 'TF') {
		return(($boolean) ? 'TRUE' : 'FALSE');
	} elsif($mode eq 'YN') {
		return(($boolean) ? 'Yes' : 'No');
	}
	return($boolean);
}

sub sysop_list_users {
	my $self = shift;
	my $list_mode = shift;;

	my $table;
	$self->{'debug'}->DEBUG($list_mode);
	my $date_format = $self->configuration('SHORT DATE FORMAT');
	my $name_width = 15;
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
		$sth = $self->{'dbh'}->prepare($sql);
		@order = @{$self->{'SYSOP ORDER DETAILED'}};
	} else {
		@order = @{$self->{'SYSOP ORDER ABBREVIATED'}};
		$sql = 'SELECT id,username,fullname,given,family,nickname,text_mode FROM users_view';
		$sth = $self->{'dbh'}->prepare($sql);
	}
	$sth->execute();
	if ($list_mode =~ /VERTICAL/) {
		while(my $row = $sth->fetchrow_hashref()) {
			foreach my $name (@order) {
				next if ($name =~ /retro_systems|accomplishments/);
				if ($name ne 'id' && $row->{$name} =~ /^(0|1)$/) {
					$row->{$name} = $self->sysop_true_false($row->{$name},'YN');
				}
				$value_width = max(length($row->{$name}),$value_width);
				$self->{'debug'}->DEBUGMAX([$row,$name_width,$value_width]);
			}
		}
		$sth->finish();
		$self->{'debug'}->DEBUG(['Populate the table']);
		$sth = $self->{'dbh'}->prepare($sql);
		$sth->execute();
		$table = Text::SimpleTable->new($name_width,$value_width);
		$table->row('NAME','VALUE');
		$table->hr();
		while(my $Row = $sth->fetchrow_hashref()) {
			foreach my $name (@order) {
				if ($name ne 'id' && $Row->{$name} =~ /^(0|1)$/) {
					$Row->{$name} = $self->sysop_true_false($Row->{$name},'YN');
				} elsif ($name eq 'timeout') {
					$Row->{$name} = $Row->{$name} . ' Minutes'
				}
				$self->{'debug'}->DEBUGMAX([$name,$Row->{$name}]);
				$table->row($name . '',$Row->{$name} . '');
			}
		}
		$sth->finish();
		$self->{'debug'}->DEBUG(['Show table']);
		my $string = $table->boxes->draw();
		$self->{'debug'}->DEBUGMAX(\$string);
		print "$string\n";
	} else { # Horizontal
		my @hw;
		foreach my $name (@order) {
			push(@hw,$self->{'SYSOP HEADING WIDTHS'}->{$name});
		}
		$self->{'debug'}->DEBUGMAX(\@hw);
		$table = Text::SimpleTable->new(@hw);
		if ($list_mode =~ /ABBREVIATED/) {
			$table->row(@order);
		} else {
			my @title = ();
			foreach my $heading (@order) {
				push(@title,$self->sysop_vertical_heading($heading));
			}
			$table->row(@title);
		}
		$table->hr();
		while(my $row = $sth->fetchrow_hashref()) {
			my @vals = ();
			foreach my $name (@order) {
				push(@vals,$row->{$name} . '');
				$self->{'debug'}->DEBUGMAX([$name,$row->{$name}]);
			}
			$table->row(@vals);
		}
		$sth->finish();
		$self->{'debug'}->DEBUG(['Show table']);
		my $string = $table->boxes->draw();
		$self->{'debug'}->DEBUGMAX(\$string);
		print "$string\n";
	}
	print 'Press a key to continue ... ';
	return ($self->sysop_keypress(TRUE));
	return(TRUE);
}

sub sysop_vertical_heading {
	my $self = shift;
	my $text = shift;

	my $heading = '';
	for (my $count = 0;$count < length($text);$count++) {
		$heading .= substr($text,$count,1) . "\n";
	}
	return($heading);
}

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
    } ## end foreach my $conf (keys %{ $self...})
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
    foreach my $change ('AUTHOR EMAIL','AUTHOR LOCATION','AUTHOR NAME','STATIC NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME') {
        if ($output =~ /($change)/) {
            my $ch = colored(['yellow'], $1);
            $output =~ s/$1/$ch/gs;
        }
    } ## end foreach my $change ('STATIC NAME'...)
    print $output;
    if ($view) {
        print 'Press a key to continue ... ';
        return ($self->sysop_keypress(TRUE));
    } else {
		print $self->sysop_menu_choice('TOP','','');
		print $self->sysop_menu_choice('S','RED','Return to Settings Menu');
		print $self->sysop_menu_choice('BOTTOM','','');
		print $self->sysop_prompt('Choose');
        return (TRUE);
    }
} ## end sub sysop_view_configuration

sub sysop_edit_configuration {
    my $self = shift;

	$self->sysop_view_configuration(FALSE);
	my $choice;
    do {
		$choice = $self->sysop_keypress(TRUE);
    } until ($choice =~ /\d|S/i);
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

    print savepos, '_' x $width, loadpos;

    # TEMP
    return (<STDIN>);
} ## end sub sysop_get_line

sub sysop_user_edit {
    my $self = shift;

	$self->{'debug'}->DEBUG(['Begin user Edit']);
	my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R T U V W X Y Z );
	my $key;
	do {
		print $self->sysop_prompt('Please enter the username or account number') .
		  $self->{'ansi_sequences'}->{'DOWN'},
		  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x 16,
		  $self->{'ansi_sequences'}->{'UP'},
		  $self->{'ansi_sequences'}->{'LEFT'} x 16;
		chomp(my $search = <STDIN>);
		return(FALSE) if ($search eq '');
		my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
		$sth->execute($search,$search);
		my $user_row = $sth->fetchrow_hashref();
		$sth->finish();
		if (defined($user_row)) {
			$self->{'debug'}->DEBUGMAX($user_row);
			my $table = Text::SimpleTable->new(6,16,60);
			$table->row('CHOICE','FIELD','VALUE');
			$table->hr();
			my $count = 0;
			$self->{'debug'}->DEBUGMAX(['HERE',$self->{'SYSOP ORDER DETAILED'}]);
			my %choice;
			foreach my $field (@{$self->{'SYSOP ORDER DETAILED'}}) {
				if ($field =~ /_time|fullname|id/) {
					$table->row(' ',$field,$user_row->{$field});
				} else {
					if ($field ne 'id' && $user_row->{$field} =~ /^(0|1)$/) {
						$user_row->{$field} = $self->sysop_true_false($user_row->{$field},'YN');
					} elsif ($name eq 'timeout') {
						$user_row->{$field} = $user_row->{$field} . ' Minutes'
					}
					$table->row($choices[$count],$field,$user_row->{$field} . '');
					$choice{$choices[$count]} = $field;
					$count++;
				}
			}
			print $table->boxes->draw(),"\n";
			print $self->sysop_menu_choice('TOP','','');
			print $self->sysop_menu_choice('S','CYAN','Return to Users Edit Menu');
			print $self->sysop_menu_choice('BOTTOM','','');
		    print "\n",$self->sysop_prompt('Choose');
			$key = uc($self->sysop_keypress());
		} else {
			print "User not found!\n\n";
		}
	} until($key eq 'S');
    return (TRUE);
}

sub sysop_prompt {
	my $self = shift;
	my $text = shift;
	my $response =
	  $text .
	  ' ' .
	  $self->{'sysop_tokens'}->{'BIG BULLET RIGHT'} .
	  ' ';
	return($response);
}

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
    }
    foreach my $name (keys %{ $self->{'ansi_sequences'} }) {
        my $ch = $self->{'ansi_sequences'}->{$name};
        $text =~ s/\[\%\s+$name\s+\%\]/$ch/gi;
    }
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
		$response =
		  $self->{'sysop_tokens'}->{'TOP LEFT ROUNDED'} .
		  $self->{'sysop_tokens'}->{'THIN HORIZONTAL BAR'} .
		  $self->{'sysop_tokens'}->{'TOP RIGHT ROUNDED'} .
		  "\n";
	} elsif ($choice eq 'BOTTOM') {
		$response =
		  $self->{'sysop_tokens'}->{'BOTTOM LEFT ROUNDED'} .
		  $self->{'sysop_tokens'}->{'THIN HORIZONTAL BAR'} .
		  $self->{'sysop_tokens'}->{'BOTTOM RIGHT ROUNDED'} .
		  "\n";
	} else {
		$response =
		  $self->{'sysop_tokens'}->{'THIN VERTICAL BAR'} .
		  colored(["BOLD $color"],$choice) .
		  $self->{'sysop_tokens'}->{'THIN VERTICAL BAR'} .
		  ' ' .
		  colored([$color],$self->{'sysop_tokens'}->{'BIG BULLET RIGHT'}) .
		  ' ' .
		  $desc .
		  "\n";
	}
	return($response);
}

 

# package BBS::Universal::Users;

sub users_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Users initialized']);
    return ($self);
} ## end sub users_initialize

sub users_list {
    my $self = shift;
}

sub users_add {
    my $self = shift;
}

sub users_edit {
    my $self = shift;
}

sub users_delete {
    my $self = shift;
}

sub users_find {
    my $self = shift;
}

sub users_count {
    my $self = shift;
    return (0);
}

 

1;
