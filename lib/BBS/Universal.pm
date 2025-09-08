package BBS::Universal;

# Pragmas
use 5.010;
use strict;
no strict 'subs';
no warnings;

# use Carp::Always;
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
	NUMERIC     => 2,

    ASCII   => 0,
    ATASCII => 1,
    PETSCII => 2,
    ANSI    => 3,

	LINEMODE          => 34,

    SE                => 240,
    NOP               => 214,
    DATA_MARK         => 242,
    BREAK             => 243,
    INTERRUPT_PROCESS => 244,
    ABORT_OUTPUT      => 245,
    ARE_YOU_THERE     => 246,
    ERASE_CHARACTER   => 247,
    ERASE_LINE        => 248,
    GO_AHEAD          => 249,
    SB                => 250,
    WILL              => 251,
    WONT              => 252,
    DO                => 253,
    DONT              => 254,
    IAC               => 255,
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
use Cache::Memcached::Fast;

BEGIN {
    require Exporter;

    our $VERSION = '0.005';
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
		NUMERIC

		ASCII
		ATASCII
		PETSCII
		ANSI

		LINEMODE

		SE
		NOP
		DATA_MARK
		BREAK
		INTERRUPT_PROCESS
		ABORT_OUTPUT
		ARE_YOU_THERE
		ERASE_CHARACTER
		ERASE_LINE
		GO_AHEAD
		SB
		WILL
		WONT
		DO
		DONT
		IAC
    );
    our @EXPORT_OK = qw();
    binmode(STDOUT, ":encoding(UTF-8)");
}

sub DESTROY {
    my $self = shift;

    $self->{'dbh'}->disconnect();
}

sub small_new {
    my $class = shift;
    my $self  = shift;

    bless($self, $class);
    $self->populate_common();

    $self->{'CACHE'} = Cache::Memcached::Fast->new(
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
}

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
        'suffixes'        => [qw( ASC ATA PET ANS )],
        'host'            => undef,
        'port'            => undef,
		'access_levels'   => {
			'USER'         => 0,
			'VETERAN'      => 1,
			'JUNIOR SYSOP' => 2,
			'SYSOP'        => 3,
		},
		'telnet_commands' => [
			'SE (Subnegotiation end)',
			'NOP (No operation)',
			'Data Mark',
			'Break',
			'Interrupt Process',
			'Abort output',
			'Are you there?',
			'Erase character',
			'Erase Line',
			'Go ahead',
			'SB (Subnegotiation begin)',
			'WILL',
			"WON'T",
			'DO',
			"DON'T",
			'IAC',
		],
		'telnet_options'  => [
			'Binary Transmission',
			'Echo',
			'Reconnection',
			'Suppress Go Ahead',
			'Approx Message Size Negotiation',
			'Status',
			'Timing Mark',
			'Remote Controlled Trans and Echo',
			'Output Line Width',
			'Output Page Size',
			'Output Carriage-Return Disposition',
			'Output Horizontal Tab Stops',
			'Output Horizontal Tab Disposition',
			'Output Formfeed Disposition',
			'Output Vertical Tabstops',
			'Output Vertical Tab Disposition',
			'Output Linefeed Disposition',
			'Extended ASCII',
			'Logout',
			'Byte Macro',
			'Data Entry Terminal',
			'RFC 1043',
			'RFC 732',
			'SUPDUP',
			'RFC 736',
			'RFC 734',
			'SUPDUP Output',
			'Send Location',
			'Terminal Type',
			'End of Record',
			'TACACS User Identification',
			'Output Marking',
			'Terminal Location Number',
			'Telnet 3270 Regime',
			'30X.3 PAD',
			'Negotiate About Window Size',
			'Terminal Speed',
			'Remote Flow Control',
			'Linemode',
			'X Display Location',
			'Environment Option',
			'Authentication Option',
			'Encryption Option',
			'New Environment Option',
			'TN3270E',
			'XAUTH',
			'CHARSET',
			'Telnet Remote Serial Port (RSP)',
			'Com Port Control Option',
			'Telnet Suppress Local Echo',
			'Telnet Start TLS',
			'KERMIT',
			'SEND-URL',
			'FORWARD_',
		],
    };

    bless($self, $class);
    $self->populate_common();
    $self->{'CACHE'} = Cache::Memcached::Fast->new(
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
    our $ANSI_VERSION = '0.002';
    our $ASCII_VERSION = '0.002';
    our $ATASCII_VERSION = '0.002';
    our $BBS_LIST_VERSION = '0.001';
    our $CPU_VERSION = '0.002';
    our $DB_VERSION = '0.002';
    our $FILETRANSFER_VERSION = '0.002';
    our $MESSAGES_VERSION = '0.001';
    our $NEWS_VERSION = '0.003';
    our $PETSCII_VERSION = '0.002';
    our $SYSOP_VERSION = '0.003';
    our $TEXT_EDITOR_VERSION = '0.001';
    our $USERS_VERSION = '0.003';
} ## end sub new

sub populate_common {
    my $self = shift;

    $self->{'CPU'}      = $self->cpu_info();
    $self->{'CONF'}     = $self->configuration();
    $self->{'VERSIONS'} = $self->parse_versions();
    $self->{'USER'}     = {
        'text_mode'   => $self->{'CONF'}->{'DEFAULT TEXT MODE'},
        'max_columns' => 80,
        'max_rows'    => 25,
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
    $self->bbs_list_initialize();
    chomp(my $os = `uname -a`);
    $self->{'SPEEDS'} = {    # This depends on the granularity of Time::HiRes
        'FULL'  => 0,
        '300'   => 0.02,
        '1200'  => 0.005,
        '2400'  => 0.0025,
        '4800'  => 0.00125,
        '9600'  => 0.000625,
        '19200' => 0.0003125,
    };

	$self->{'FORTUNE'} = (-e '/usr/bin/fortune' || -e '/usr/local/bin/fortune') ? TRUE : FALSE;
    $self->{'TOKENS'} = {
        'CPU IDENTITY' => $self->{'CPU'}->{'CPU IDENTITY'},
        'CPU CORES'    => $self->{'CPU'}->{'CPU CORES'},
        'CPU SPEED'    => $self->{'CPU'}->{'CPU SPEED'},
        'CPU THREADS'  => $self->{'CPU'}->{'CPU THREADS'},
        'OS'           => $os,
        'PERL VERSION' => $self->{'VERSIONS'}->[0],
        'BBS VERSION'  => $self->{'VERSIONS'}->[1],
        'SYSOP'        => sub {
            my $self = shift;
            if ($self->{'sysop'}) {
                return ('SYSOP CREDENTIALS');
            } else {
                return ('USER CREDENTIALS');
            }
        },
		'FORTUNE' => sub {
			my $self = shift;
			return($self->get_fortune);
		},
        'BANNER' => sub {
            my $self   = shift;
            my $banner = $self->files_load_file('files/main/banner');
            return ($banner);
        },
        'FILE CATEGORY' => sub {
            my $self = shift;
            return ($self->users_file_category());
        },
        'FORUM CATEGORY' => sub {
            my $self = shift;
            return ($self->users_forum_category());
        },
        'USER INFO' => sub {
            my $self = shift;
            return ($self->users_info());
        },
        'BBS NAME' => sub {
            my $self = shift;
            return ($self->{'CONF'}->{'BBS NAME'});
        },
        'AUTHOR NAME' => sub {
            my $self = shift;
            return ($self->{'CONF'}->{'STATIC'}->{'AUTHOR NAME'});
        },
        'USER PERMISSIONS' => sub {
            my $self = shift;
            return ($self->dump_permissions);
        },
        'USER ID' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'id'});
        },
        'USER FULLNAME' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'fullname'});
        },
        'USER USERNAME' => sub {
            my $self = shift;
            if ($self->{'USER'}->{'prefer_nickname'}) {
                return ($self->{'USER'}->{'nickname'});
            } else {
                return ($self->{'USER'}->{'username'});
            }
        },
        'USER NICKNAME' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'nickname'});
        },
        'USER EMAIL' => sub {
            my $self = shift;
            if ($self->{'USER'}->{'show_email'}) {
                return ($self->{'USER'}->{'email'});
            } else {
                return ('[HIDDEN]');
            }
        },
        'USER COLUMNS' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'max_columns'});
        },
        'USER ROWS' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'max_rows'});
        },
        'USER SCREEN SIZE' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'});
        },
        'USER GIVEN' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'given'});
        },
        'USER FAMILY' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'family'});
        },
        'USER LOCATION' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'location'});
        },
        'USER BIRTHDAY' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'birthday'});
        },
        'USER RETRO SYSTEMS' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'retro_systems'});
        },
        'USER LOGIN TIME' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'login_time'});
        },
        'USER TEXT MODE' => sub {
            my $self = shift;
            return ($self->{'USER'}->{'text_mode'});
        },
        'BAUD RATE' => sub {
            my $self = shift;
            return ($self->{'baud_rate'});
        },
        'TIME' => sub {
            my $self = shift;
            return (DateTime->now);
        },
        'UPTIME' => sub {
            my $self = shift;
            chomp(my $uptime = `uptime -p`);
            return ($uptime);
        },
        'SHOW BBS LIST' => sub {
            my $self = shift;
            return ($self->bbs_list_all());
        },
        'SHOW USERS LIST' => sub {
            my $self = shift;
            return ($self->users_list());
        },
        'ONLINE' => sub {
            my $self = shift;
            return ($self->{'CACHE'}->get('ONLINE'));
        },
        'VERSIONS' => 'placeholder',
        'UPTIME'   => 'placeholder',
    };

    $self->{'COMMANDS'} = {
        'UPDATE ACCOMPLISHMENTS' => sub {
            my $self = shift;
			$self->users_update_accomplishments();
            return ($self->load_menu('files/main/account'));
        },
		'FORUM CATEGORIES' => sub {
			my $self = shift;
			$self->messages_forum_categories();
            return ($self->load_menu('files/main/forums'));
		},
		'FORUM MESSAGES LIST' => sub {
			my $self = shift;
			$self->messages_list_messages();
            return ($self->load_menu('files/main/forums'));
		},
		'FORUM MESSAGES READ' => sub {
			my $self = shift;
			$self->messages_read_message();
            return ($self->load_menu('files/main/forums'));
		},
		'FORUM MESSAGES EDIT' => sub {
			my $self = shift;
			$self->messages_edit_message('EDIT');
            return ($self->load_menu('files/main/forums'));
		},
		'FORUM MESSAGES ADD' => sub {
			my $self = shift;
			$self->messages_edit_message('ADD');
            return ($self->load_menu('files/main/forums'));
		},
		'FORUM MESSAGES DELETE' => sub {
			my $self = shift;
			$self->messages_delete_message();
            return ($self->load_menu('files/main/forums'));
		},
        'UPDATE LOCATION' => sub {
            my $self = shift;
			$self->users_update_location();
            return ($self->load_menu('files/main/account'));
        },
        'UPDATE EMAIL' => sub {
            my $self = shift;
			$self->users_update_email();
            return ($self->load_menu('files/main/account'));
        },
        'UPDATE RETRO SYSTEMS' => sub {
            my $self = shift;
			$self->users_update_retro_systems();
            return ($self->load_menu('files/main/account'));
        },
		'CHANGE ACCESS LEVEL' => sub {
			my $self = shift;
			$self->users_change_access_level();
			return($self->load_menu('files/main/account'));
		},
		'CHANGE BAUD RATE' => sub {
			my $self = shift;
			$self->users_change_baud_rate();
			return($self->load_menu('files/main/account'));
		},
		'CHANGE DATE FORMAT' => sub {
			my $self = shift;
			$self->users_change_date_format();
			return($self->load_menu('files/main/account'));
		},
        'CHANGE SCREEN SIZE' => sub {
            my $self = shift;
            $self->users_change_screen_size();
            return ($self->load_menu('files/main/account'));
        },
        'CHOOSE TEXT MODE' => sub {
            my $self = shift;
			$self->users_update_text_mode();
            return ($self->load_menu('files/main/account'));
        },
        'TOGGLE SHOW EMAIL' => sub {
            my $self = shift;
            $self->users_toggle_permission('show_email');
            return ($self->load_menu('files/main/account'));
        },
        'TOGGLE PREFER NICKNAME' => sub {
            my $self = shift;
            $self->users_toggle_permission('prefer_nickname');
            return ($self->load_menu('files/main/account'));
        },
        'TOGGLE PLAY FORTUNES' => sub {
            my $self = shift;
            $self->users_toggle_permission('play_fortunes');
            return ($self->load_menu('files/main/account'));
        },
        'BBS LIST ADD' => sub {
            my $self = shift;
            $self->bbs_list_add();
            return ($self->load_menu('files/main/bbs_listing'));
        },
        'BBS LISTING' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/bbs_listing'));
        },
		'LIST USERS' => sub {
			my $self = shift;
			return($self->load_menu('files/main/list_users'));
		},
        'ACCOUNT MANAGER' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/account'));
        },
        'BACK' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/menu'));
        },
        'DISCONNECT' => sub {
            my $self = shift;
            $self->output("\nDisconnect, are you sure (y|N)?  ");
            unless ($self->decision()) {
                return ($self->load_menu('files/main/menu'));
            }
            $self->output("\n");
        },
        'FILE CATEGORY' => sub {
            my $self = shift;
            $self->choose_file_category();
            return ($self->load_menu('files/main/files_menu'));
        },
        'FILES' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/files_menu'));
        },
        'LIST FILES SUMMARY' => sub {
            my $self = shift;
            $self->files_list_summary(FALSE);
            return ($self->load_menu('files/main/files_menu'));
        },
        'LIST FILES DETAILED' => sub {
            my $self = shift;
            $self->files_list_detailed(FALSE);
            return ($self->load_menu('files/main/files_menu'));
        },
        'SEARCH FILES SUMMARY' => sub {
            my $self = shift;
            $self->files_list_summary(TRUE);
            return ($self->load_menu('files/main/files_menu'));
        },
        'SEARCH FILES DETAILED' => sub {
            my $self = shift;
            $self->files_list_detailed(TRUE);
            return ($self->load_menu('files/main/files_menu'));
        },
        'NEWS' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/news'));
        },
        'NEWS SUMMARY' => sub {
            my $self = shift;
            $self->news_summary();
            return ($self->load_menu('files/main/news'));
        },
        'NEWS DISPLAY' => sub {
            my $self = shift;
            $self->news_display();
            return ($self->load_menu('files/main/news'));
        },
        'FORUMS' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/forums'));
        },
        'ABOUT' => sub {
            my $self = shift;
            return ($self->load_menu('files/main/about'));
        },
    };
}

sub run {
    my $self  = shift;
    my $sysop = shift;

    $self->{'sysop'} = $sysop;
    $self->{'ERROR'} = undef;

	my $handle = $self->{'cl_socket'};
	print $handle chr(IAC) . chr(WONT) . chr(LINEMODE) unless($self->{'localmode'} || $self->{'sysop'});$|=1;
    if ($self->greeting()) {    # Greeting also logs in
        $self->main_menu('files/main/menu');
    }
    $self->disconnect();
    return (defined($self->{'ERROR'}));
} ## end sub run

sub greeting {
    my $self = shift;

    # Load and print greetings message here
	$self->output("\n\n");
    my $text = $self->files_load_file('files/main/greeting');
    $self->output($text);
    return ($self->login());    # Login will also create new users
}

sub login {
    my $self = shift;

    my $valid = FALSE;

    my $username;
    if ($self->{'sysop'}) {
        $username = 'sysop';
        $self->output("\n\nAuto-login of $username successful\n\n");
        $valid = $self->users_load($username, '');
		if ($self->{'local_mode'}) { # override DB values
			my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
			$self->{'USER'}->{'columns'} = $wsize;
		}
    } else {
        my $tries = $self->{'CONF'}->{'LOGIN TRIES'} + 0;
        do {
            do {
                $self->output("\n" . 'Please enter your username ("NEW" if you are a new user) > ');
                $username = $self->get_line(ECHO, 32);
                $tries-- if ($username eq '');
                last     if ($tries <= 0 || !$self->is_connected());
            } until ($username ne '');
            if ($self->is_connected()) {
                if (uc($username) eq 'NEW') {
                    $valid = $self->create_account();
                } elsif ($username eq 'sysop' && !$self->{'local_mode'}) {
                    $self->output("\n\nSysOp cannot connect remotely\n\n");
                } else {
                    $self->output("\n\nPlease enter your password > ");
                    my $password = $self->get_line(PASSWORD, 64);
                    $valid = $self->users_load($username, $password);
                }
                if ($valid) {
                    $self->output("\n\nWelcome " . $self->{'fullname'} . ' (' . $self->{'username'} . ")\n\n");
                } else {
                    $self->output("\n\nLogin incorrect\n\n");
                    $tries--;
                }
            }
            last unless ($self->{'CACHE'}->get('RUNNING'));
            last unless ($self->is_connected());
        } until ($valid || $tries <= 0);
    }
    return ($valid);
}

sub create_account {
    my $self = shift;
    return (FALSE);
}

sub is_connected {
    my $self = shift;

	if ($self->{'local_mode'}) {
		return(TRUE);
	} elsif ($self->{'CACHE'}->get('RUNNING') && ($self->{'sysop'} || defined($self->{'cl_socket'}))) {
        $self->{'CACHE'}->set(sprintf('SERVER_%02d', $self->{'thread_number'}), 'CONNECTED');
        $self->{'CACHE'}->set('UPDATE', TRUE);
        return (TRUE);
    } else {
        $self->{'CACHE'}->set(sprintf('SERVER_%02d', $self->{'thread_number'}), 'IDLE');
        $self->{'CACHE'}->set('UPDATE', TRUE);
        return (FALSE);
    }
}

sub decision {
    my $self = shift;

    my $response = uc($self->get_key(SILENT, BLOCKING));
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
        $response = '(' . colored(['bright_yellow'],$self->{'USER'}->{'username'}) . ') ' . $text . chr(31) . ' ';
    } elsif ($self->{'USER'}->{'text_mode'} eq 'PETSCII') {
        $response = '(' . $self->{'USER'}->{'username'} . ') ' . "$text > ";
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $response = '(' . colored(['bright_yellow'],$self->{'USER'}->{'username'}) . ') ' . $text . ' ' . $self->{'ansi_characters'}->{'BLACK RIGHT-POINTING TRIANGLE'} . ' ';
    } else {
        $response = '(' . $self->{'USER'}->{'username'} . ') ' . "$text > ";
    }
    return ($response);
}

sub menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

    if ($self->{'USER'}->{'text_mode'} eq 'ATASCII') {
        $self->output(" $choice " . chr(31) . " $desc");
    } elsif ($self->{'USER'}->{'text_mode'} eq 'PETSCII') {
        $self->output(" $choice > $desc");
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $self->output(
			$self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT VERTICAL'} .
			'[% ' . $color . ' %]' . $choice . '[% RESET %]' .
			$self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT VERTICAL'} .
			'[% ' . $color . ' %]' . $self->{'ansi_characters'}->{'BLACK RIGHT-POINTING TRIANGLE'} . '[% RESET %]' .
			" $desc"
		);
    } else {
        $self->output(" $choice > $desc");
    }
}

sub show_choices {
    my $self    = shift;
    my $mapping = shift;

    my $keys = '';
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $self->output($self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC DOWN AND RIGHT'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT HORIZONTAL'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC DOWN AND LEFT'} . "\n");
    }
	my $odd = 0;
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
		if ($self->{'access_level'}->{$mapping->{$kmenu}->{'access_level'}} <= $self->{'access_level'}->{$self->{'USER'}->{'access_level'}} ) {
			$self->menu_choice($kmenu, $mapping->{$kmenu}->{'color'}, $mapping->{$kmenu}->{'text'});
			$self->output("\n");
		}
    }
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $self->output($self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC UP AND RIGHT'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT HORIZONTAL'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC UP AND LEFT'});
    }
}

sub header {
    my $self = shift;

    my $width = $self->{'USER'}->{'max_columns'};
    my $name  = ' ' . $self->{'CONF'}->{'BBS NAME'} . ' ';

    my $text = '#' x int(($width - length($name)) / 2);
    $text .= $name;
    $text .= '#' x ($width - length($text));
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        my $char = '[% BOX DRAWINGS HEAVY HORIZONTAL %]';
        $text =~ s/\#/$char/g;
    }
    return ($self->detokenize_text('[% CLS %]' . $text));
}

sub load_menu {
    my $self = shift;
    my $file = shift;

    my $orig    = $self->files_load_file($file);
    my @Text    = split(/\n/, $orig);
    my $mapping = { 'TEXT' => '' };
    my $mode    = TRUE;
    my $text    = '';
    foreach my $line (@Text) {
        if ($mode) {
			next if ($line =~ /^\#/);
            if ($line !~ /^---/) {
                my ($k, $cmd, $color, $access, $t) = split(/\|/, $line);
                $k     = uc($k);
                $cmd   = uc($cmd);
                $color = uc($color);
                if (exists($self->{'COMMANDS'}->{$cmd})) {
                    $mapping->{$k} = {
                        'command'      => $cmd,
                        'color'        => $color,
						'access_level' => $access,
                        'text'         => $t,
                    };
                } else {
                    $self->{'debug'}->ERROR(["Command Missing!  $cmd"]);
                }
            } else {
                $mode = FALSE;
            }
        } else {
            $mapping->{'TEXT'} .= $self->detokenize_text($line) . "\n";
        }
    }
    $mapping->{'TEXT'} = $self->header() . "\n" . $mapping->{'TEXT'};
    return ($mapping);
}

sub main_menu {
    my $self = shift;
    my $file = shift;

    my $connected = TRUE;
    my $command   = '';
    my $mapping = $self->load_menu($file);
    while ($connected && $self->is_connected()) {
        $self->output($mapping->{'TEXT'});
        $self->show_choices($mapping);
        $self->output("\n" . $self->prompt('Choose'));
        my $key;
        do {
            $key = uc($self->get_key(SILENT, FALSE));
        } until (exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
        $self->output($mapping->{$key}->{'command'} . "\n");
        if ($key eq chr(3)) {
            $command = 'DISCONNECT';
        } else {
            $command = $mapping->{$key}->{'command'};
        }
        $mapping = $self->{'COMMANDS'}->{$command}->($self);
        if (ref($mapping) ne 'HASH' || !$self->is_connected()) {
            $connected = FALSE;
        }
    }
}

sub disconnect {
    my $self = shift;

    # Load and print disconnect message here
    my $text = $self->files_load_file('files/main/disconnect');
    $self->output($text);
    return (TRUE);
}

sub categories_menu {    # Handle categories menu
    my $self = shift;
    return (TRUE);
}

sub parse_telnet_escape {
	my $self    = shift;
	my $command = shift;
	my $option  = shift;
	my $handle  = $self->{'cl_socket'};

	if ($command == WILL) {
		if ($option == ECHO) { # WON'T ECHO
			print $handle chr(IAC) . chr(WONT) . chr(ECHO);
		} elsif ($option == LINEMODE) {
			print $handle chr(IAC) . chr(WONT) . chr(LINEMODE);
		}
	} elsif ($command == DO) {
		if ($option == ECHO) { # DON'T ECHO
			print $handle chr(IAC) . chr(DONT) . chr(ECHO);
		} elsif ($option == LINEMODE) {
			print $handle chr(IAC) . chr(DONT) . chr(LINEMODE);
		}
	} else {
		$self->{'debug'}->DEBUG(['Recreived IAC Request - ' . $self->{'telnet_commands'}->[$command - 240] . ' : ' . $self->{'telnet_options'}->[$option]]);
	}
	return(TRUE);
}

sub flush_input {
	my $self = shift;

	my $key;
	unless ($self->{'local_mode'} || $self->{'sysop'}) {
		my $handle = $self->{'cl_socket'};
		ReadMode 'noecho', $handle;
		do {
			$key = ReadKey(-1,$handle);
		} until (! defined($key) || $key eq '');
		ReadMode 'restore', $handle;
	} else {
		ReadMode 'ultra-raw';
		do {
			$key = ReadKey(-1);
		} until (! defined($key) || $key eq '');
		ReadMode 'restore';
	}
	return(TRUE);
}

sub get_key {
    my $self     = shift;
    my $echo     = shift;
    my $blocking = shift;

    my $key = undef;
	my $timeout = $self->{'USER'}->{'timeout'} * 60;
    local $/ = "\x{00}";
    if ($self->{'local_mode'}) {
        ReadMode 'ultra-raw';
        $key = ($blocking) ? ReadKey($timeout) : ReadKey(-1);
        ReadMode 'restore';
    } elsif ($self->is_connected()) {
		my $handle = $self->{'cl_socket'};
		ReadMode 'ultra-raw', $self->{'cl_socket'};
		my $escape;
		do {
			$escape = FALSE;
			$key = ($blocking) ? ReadKey($timeout, $handle) : ReadKey(-1, $handle);
			if ($key eq chr(255)) { # IAC sequence
				my $command = ReadKey($timeout, $handle);
				my $option  = ReadKey($timeout, $handle);
				$self->parse_telnet_escape(ord($command),ord($option));
				$escape = TRUE;
			}
		} until (! $escape || $self->is_connected());
		ReadMode 'restore', $self->{'cl_socket'};
    }
	return($key) if ($key eq chr(13));
	$key = $self->{'backspace'} if ($key eq chr(127));
	if ($echo == NUMERIC && defined($key)) {
		if ($key =~ /[0-9]/ || $key eq $self->{'backspace'}) {
			$self->send_char($key);
		} else {
			$key = '';
		}
    } elsif ($echo == ECHO && defined($key)) {
        $self->send_char($key);
    } elsif ($echo == PASSWORD && defined($key)) {
        $self->send_char('*');
    }
    return ($key);
}

sub get_line {
    my $self  = shift;
    my $echo  = shift;
    my $limit = (scalar(@_)) ? min(shift, 65535) : 65535;
    my $line  = (scalar(@_)) ? shift : '';
    my $key;

	$self->flush_input();
	$self->output($line) if ($line ne '');
    while ($self->is_connected() && $key ne chr(13) && $key ne chr(3)) {
		if (length($line) < $limit) {
			$key = $self->get_key($echo, BLOCKING);
			return('') if (defined($key) && $key eq chr(3));
			if (defined($key) && $key ne '' && $self->is_connected()) {
				if ($key eq $self->{'backspace'} || $key eq chr(127)) {
					$self->output(" $key");
					my $len = length($line);
					if ($len > 0) {
						$line = substr($line,0, $len - 1);
					}
				} elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && ord($key) > 31 && ord($key) < 127) {
					$line .= $key;
				}
			}
		} else {
			$key = $self->get_key(SILENT, BLOCKING);
			if (defined($key) && $key eq chr(3)) {
				return('');
			 }
			if (defined($key) && $key eq $self->{'backspace'} || $key eq chr(127)) {
				$key = $self->{'backspace'};
				$self->output("$key $key");
				chop($line);
			} else {
				$self->output('[% RING BELL %]');
			}
		}
        threads->yield();
    }

	$line = '' if ($key eq chr(3));
    return ($line);
}

sub detokenize_text {    # Detokenize text markup
    my $self = shift;
    my $text = shift;

    if (defined($text) && length($text) > 1) {
        foreach my $key (keys %{ $self->{'TOKENS'} }) {
			if ($key eq 'VERSIONS' && $text =~ /\[\%\s+$key\s+\%\]/i) {
				my $versions = '';
				foreach my $names (@{ $self->{'VERSIONS'} }) {
					$versions .= $names . "\n";
				}
				$text =~ s/\[\%\s+$key\s+\%\]/$versions/g;
			} elsif (ref($self->{'TOKENS'}->{$key}) eq 'CODE' && $text =~ /\[\%\s+$key\s+\%\]/) {
				my $ch = $self->{'TOKENS'}->{$key}->($self);    # Code call
				$text =~ s/\[\%\s+$key\s+\%\]/$ch/g;
			} else {
				$text =~ s/\[\%\s+$key\s+\%\]/$self->{'TOKENS'}->{$key}/g;
			}
        }
    }
    return ($text);
}

sub output {
    my $self = shift;
    my $text = $self->detokenize_text(shift);

	if (defined($text) && $text ne '') {
		if ($text =~ /\[\%\s+WRAP\s+\%\]/) {
			my $format = Text::Format->new(
				'columns'     => $self->{'USER'}->{'max_columns'} - 1,
				'tabstop'     => 4,
				'extraSpace'  => TRUE,
				'firstIndent' => 0,
			);
			my $header;
			($header, $text) = split(/\[\%\s+WRAP\s+\%\]/, $text);
			if ($text =~ /\[\%\s+JUSTIFY\s+\%\]/) {
				$text =~ s/\[\%\s+JUSTIFY\s+\%\]//g;
				$format->justify(TRUE);
			}
			$text = $format->format($text);
			$text = $header . $text;
		}
		my $mode = $self->{'USER'}->{'text_mode'};
		if ($mode eq 'ATASCII') {
			$self->atascii_output($text);
		} elsif ($mode eq 'PETSCII') {
			$self->petscii_output($text);
		} elsif ($mode eq 'ANSI') {
			$self->ansi_output($text);
		} else {    # ASCII (always the default)
			$self->ascii_output($text);
		}
	} else {
		return(FALSE);
	}
	return (TRUE);
}

sub send_char {
    my $self = shift;
    my $char = shift;

    # This sends one character at a time to the socket to simulate a retro BBS
    if ($self->{'sysop'} || $self->{'local_mode'} || !defined($self->{'cl_socket'})) {
        print STDOUT $char;
		$| = 1;
    } else {
		my $handle = $self->{'cl_socket'};
        print $handle $char;
		$| = 1;
    }

    # Send at the chosen baud rate by delaying the output by a fraction of a second
    # Only delay if the baud_rate is not FULL
    sleep $self->{'SPEEDS'}->{ $self->{'USER'}->{'baud_rate'} } if ($self->{'USER'}->{'baud_rate'} ne 'FULL');
    return (TRUE);
} ## end sub send_char

sub scroll {
    my $self = shift;
    my $nl   = shift;

    my $string;
    if ($self->{'local_mode'}) {
        $string = "\nScroll?  ";
    } else {
        $string = "$nl" . 'Scroll?  ';
    }
    $self->output($string);
    if ($self->get_key(ECHO, BLOCKIMG) =~ /N/i) {
        return (FALSE);
    }
	$self->output('[% BACKSPACE %] [% BACKSPACE %]' x 10);
    return (TRUE);
}

sub static_configuration {
    my $self = shift;
    my $file = shift;

    $self->{'CONF'}->{'STATIC'}->{'AUTHOR NAME'}     = 'Richard Kelsch';
    $self->{'CONF'}->{'STATIC'}->{'AUTHOR EMAIL'}    = 'Richard Kelsch <rich@rk-internet.com>';
    $self->{'CONF'}->{'STATIC'}->{'AUTHOR LOCATION'} = 'Central Utah - USA';
    if (-e $file) {
        open(my $CFG, '<', $file) or die "$file missing!";
        chomp(my @lines = <$CFG>);
        close($CFG);
        foreach my $line (@lines) {
            next if ($line eq '' || $line =~ /^\#/);
            my ($name, $val) = split(/\s+=\s+/, $line);
            $self->{'CONF'}->{'STATIC'}->{$name} = $val;
        }
    }
}

sub choose_file_category {
    my $self = shift;

    my $table;
    my $choices = [qw(0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)];
    my $hchoice = {};
    my @categories;
    if ($self->{'USER'}->{'max_columns'} <= 40) {
        $table = Text::SimpleTable->new(6, 20, 15);
    } else {
        $table = Text::SimpleTable->new(6, 30, 43);
    }
    $table->row('CHOICE', 'TITLE', 'DESCRIPTION');
    $table->hr();
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
    $sth->execute();
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            $table->row($choices->[$row->{'id'} - 1], $row->{'title'}, $row->{'description'});
            $hchoice->{ $choices->[$row->{'id'} - 1] } = $row->{'id'};
            push(@categories, $row->{'title'});
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
            $response = uc($self->get_key(SILENT, BLOCKING));
        } until (exists($hchoice->{$response}) || $response eq '<' || !$self->is_connected());
        if ($response ne '<') {
            $self->{'USER'}->{'file_category'} = $hchoice->{$response};
            $self->output($categories[$hchoice->{$response} - 1] . "\n");
            $sth = $self->{'dbh'}->prepare('UPDATE users SET file_category=? WHERE id=?');
            $sth->execute($hchoice->{$response}, $self->{'USER'}->{'id'});
            $sth->finish();
        } else {
            $self->output("Nevermind\n");
        }
    }
}

sub configuration {
    my $self = shift;

    unless (exists($self->{'CONF'}->{'STATIC'})) {
        my @static_file = ('./conf/bbs.rc', '~/.bbs_universal/bbs.rc', '/etc/bbs.rc');
        my $found       = FALSE;
        foreach my $file (@static_file) {
            if (-e $file) {
                $found = TRUE;
                $self->static_configuration($file);
                last;
            } else {
                $self->{'debug'}->WARNING(["$file not found, trying the next file in the list"]);
            }
        }
        unless ($found) {
            $self->{'debug'}->ERROR(['BBS Static Configuration file not found', join("\n", @static_file)]);
            exit(1);
        }
        $self->db_connect();
    }
    #######################################################
    my $count = scalar(@_);
    if ($count == 1) {    # Get single value
        my $name = shift;

        my $sth    = $self->{'dbh'}->prepare('SELECT config_value FROM config WHERE config_name=?');
        my $result = $sth->execute($name);
        $sth->finish();
        return ($result);
    } elsif ($count == 2) {    # Set a single value
        my $name = shift;
        my $fval = shift;
        my $sth = $self->{'dbh'}->prepare('UPDATE config SET config_value=? WHERE config_name=?');
        my $result = $sth->execute($fval, $name);
        $sth->finish();
        $self->{'CONF'}->{$name} = $fval;
        return (TRUE);
    } elsif ($count == 0) {    # Get entire configuration forces a reload into CONF
        $self->db_connect() unless (exists($self->{'dbh'}));
        my $sth     = $self->{'dbh'}->prepare('SELECT config_name,config_value FROM config');
        my $results = {};
        $sth->execute();
        while (my @row = $sth->fetchrow_array()) {
            $results->{ $row[0] } = $row[1];
            $self->{'CONF'}->{ $row[0] } = $row[1];
        }
        $sth->finish();
        return ($self->{'CONF'});
    }
}

sub parse_versions {
    my $self = shift;

###
    my $versions = [
		"Perl                          $OLD_PERL_VERSION",
		"BBS Executable                $main::VERSION",
		"BBS::Universal                $BBS::Universal::VERSION",
		"BBS::Universal::ASCII         $BBS::Universal::ASCII_VERSION",
		"BBS::Universal::ATASCII       $BBS::Universal::ATASCII_VERSION",
		"BBS::Universal::PETSCII       $BBS::Universal::PETSCII_VERSION",
		"BBS::Universal::ANSI          $BBS::Universal::ANSI_VERSION",
		"BBS::Universal::BBS_List      $BBS::Universal::BBS_LIST_VERSION",
		"BBS::Universal::CPU           $BBS::Universal::CPU_VERSION",
		"BBS::Universal::Messages      $BBS::Universal::MESSAGES_VERSION",
		"BBS::Universal::SysOp         $BBS::Universal::SYSOP_VERSION",
		"BBS::Universal::FileTransfer  $BBS::Universal::FILETRANSFER_VERSION",
		"BBS::Universal::Users         $BBS::Universal::USERS_VERSION",
		"BBS::Universal::DB            $BBS::Universal::DB_VERSION",
		"BBS::Universal::Text_Editor   $BBS::Universal::TEXT_EDITOR_VERSION",
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
###
    return ($versions);
}

sub yes_no {
    my $self  = shift;
    my $bool  = 0 + shift;
    my $color = shift;

    if ($color && $self->{'USER'}->{'text_mode'} eq 'ANSI') {
        if ($bool) {
            return ('[% GREEN %]YES[% RESET %]');
        } else {
            return ('[% RED %]NO[% RESET %]');
        }
    } else {
        if ($bool) {
            return ('YES');
        } else {
            return ('NO');
        }
    }
}

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
    }
    return ($text);
}

sub center {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

	unless (defined($text) && $text ne '') {
		return ($text);
	}
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
}

sub trim {
    my $self = shift;
    my $text = shift;

    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return ($text);
}

sub get_fortune {
	my $self = shift;
	return(($self->{'USER'}->{'play_fortunes'}) ? `fortune -s -u` : '');
}

sub playit {
	my $self = shift;
	my $file = shift;

	unless($self->{'nosound'}) {
		if ((-e '/usr/bin/mplayer' || -e '/usr/local/bin/mplayer') && $self->configuration('PLAY SYSOP SOUNDS') =~ /TRUE|1/i) {
			system("mplayer -really-quiet sysop_sounds/$file 1>/dev/null 2>&1 &");
		}
	}
}

sub check_access_level {
	my $self   = shift;
	my $access = shift;

	if ($self->{'access_levels'}->{$access} <= $self->{'access_levels'}->{$self->{'USER'}->{'access_level'}}) {
		return(TRUE);
	}
	return(FALSE);
}

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the the Artistic License (2.0). You may obtain a copy of the full license at:
  
L<http://www.perlfoundation.org/artistic_license_2_0>
  
Any use, modification, and distribution of the Standard or Modified Versions is governed by this Artistic License. By using, modifying or distributing the Package, you accept this license. Do not use, modify, or distribute the Package, if you do not accept this license.
  
If your Modified Version has been derived from a Modified Version made by someone other than you, you are nevertheless required to ensure that your Modified Version complies with the requirements of this license.
  
This license does not grant you the right to use any trademark, service mark, tradename, or logo of the Copyright Holder.
  
This license includes the non-exclusive, worldwide, free-of-charge patent license to make, have made, use, offer to sell, sell, import and otherwise transfer the Package with respect to any patent claims licensable by the Copyright Holder that are necessarily infringed by the Package. If you institute patent litigation (including a cross-claim or counterclaim) against any party alleging that the Package constitutes direct or contributory patent infringement, then this Artistic License to you shall terminate on the date that such litigation is filed.
  
Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

# package BBS::Universal::ANSI;

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27) . '[';

    $self->{'ansi_prefix'}    = $esc;
    $self->{'ansi_sequences'} = {
        'RETURN'    => chr(13),
        'LINEFEED'  => chr(10),
        'NEWLINE'   => chr(13) . chr(10),
		'RING BELL' => chr(7),
		'BACKSPACE' => chr(8),
		'DELETE'    => chr(127),

        'CLEAR'      => $esc . '2J' . locate(1,1),
        'CLS'        => $esc . '2J' . locate(1,1),
        'CLEAR LINE' => $esc . '0K',
        'CLEAR DOWN' => $esc . '0J',
        'CLEAR UP'   => $esc . '1J',

        # Cursor
        'UP'      => $esc . 'A',
        'DOWN'    => $esc . 'B',
        'RIGHT'   => $esc . 'C',
        'LEFT'    => $esc . 'D',
        'SAVE'    => $esc . 's',
        'RESTORE' => $esc . 'u',
        'RESET'   => $esc . '0m',

        # Attributes
        'BOLD'         => $esc . '1m',
        'FAINT'        => $esc . '2m',
        'ITALIC'       => $esc . '3m',
        'UNDERLINE'    => $esc . '4m',
        'OVERLINE'     => $esc . '53m',
        'SLOW BLINK'   => $esc . '5m',
        'RAPID BLINK'  => $esc . '6m',
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
        'NORMAL' => $esc . '22m',

        # Foreground color
        'BLACK'          => $esc . '30m',
        'RED'            => $esc . '31m',
        'PINK'           => $esc . '38;5;198m',
        'ORANGE'         => $esc . '38;5;202m',
        'NAVY'           => $esc . '38;5;17m',
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
        'B_PINK'           => $esc . '48;5;198m',
        'B_ORANGE'         => $esc . '48;5;202m',
        'B_NAVY'           => $esc . '48;5;17m',
        'BRIGHT B_BLACK'   => $esc . '100m',
        'BRIGHT B_RED'     => $esc . '101m',
        'BRIGHT B_GREEN'   => $esc . '102m',
        'BRIGHT B_YELLOW'  => $esc . '103m',
        'BRIGHT B_BLUE'    => $esc . '104m',
        'BRIGHT B_MAGENTA' => $esc . '105m',
        'BRIGHT B_CYAN'    => $esc . '106m',
        'BRIGHT B_WHITE'   => $esc . '107m',

		# Horizontal Rules
		'HORIZONTAL RULE ORANGE'         => '[% RETURN %]' . $esc . '48;5;202m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE PINK'           => '[% RETURN %]' . $esc . '48;5;198m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE RED'            => '[% RETURN %]' . $esc . '41m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT RED'     => '[% RETURN %]' . $esc . '101m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE GREEN'          => '[% RETURN %]' . $esc . '42m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT GREEN'   => '[% RETURN %]' . $esc . '102m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE YELLOW'         => '[% RETURN %]' . $esc . '43m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT YELLOW'  => '[% RETURN %]' . $esc . '103m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BLUE'           => '[% RETURN %]' . $esc . '44m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT BLUE'    => '[% RETURN %]' . $esc . '104m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE MAGENTA'        => '[% RETURN %]' . $esc . '45m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT MAGENTA' => '[% RETURN %]' . $esc . '105m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE CYAN'           => '[% RETURN %]' . $esc . '46m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT CYAN'    => '[% RETURN %]' . $esc . '106m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE WHITE'          => '[% RETURN %]' . $esc . '47m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT WHITE'   => '[% RETURN %]' . $esc . '107m' . $esc . '0K' . $esc . '0m',
		@_,
	};

    # Generate generic colors
    foreach my $count (0 .. 255) {
        $self->{'ansi_sequences'}->{"ANSI$count"}   = $esc . '38;5;' . $count . 'm';
        $self->{'ansi_sequences'}->{"B_ANSI$count"} = $esc . '48;5;' . $count . 'm';
        if ($count >= 232 && $count <= 255) {
            my $num = $count - 232;
            $self->{'ansi_sequences'}->{"GREY$num"}   = $esc . '38;5;' . $count . 'm';
            $self->{'ansi_sequences'}->{"B_GREY$num"} = $esc . '48;5;' . $count . 'm';
        }
    }

    # Generate symbols
    my $start  = 0x2010;
    my $finish = 0x2BFF;

    my $name = charnames::viacode(0x1F341);    # Maple Leaf
    $self->{'ansi_characters'}->{$name} = charnames::string_vianame($name);
    foreach my $u ($start .. $finish) {
        $name = charnames::viacode($u);
        next if ($name eq '');
        my $char = charnames::string_vianame($name);
        $char = '?' unless (defined($char));
        $self->{'ansi_characters'}->{$name} = $char;
    }
    $start  = 0x1F300;
    $finish = 0x1FBFF;
    foreach my $u ($start .. $finish) {
        $name = charnames::viacode($u);
        next if ($name eq '');
        my $char = charnames::string_vianame($name);
        $char = '?' unless (defined($char));
        $self->{'ansi_characters'}->{$name} = $char;
    }
    return ($self);
}

sub ansi_output {
    my $self   = shift;
    my $text   = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'ansi_sequences'} }) {
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_sequences'}->{$string}/gi;
            }
        }
        foreach my $string (keys %{ $self->{'ansi_characters'} }) {
            $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_characters'}->{$string}/gi;
        }
    }
    my $s_len = length($text);
    my $nl    = $self->{'ansi_sequences'}->{'NEWLINE'};

	# cl_socket
	if ($self->{'local_mode'} || $self->{'sysop'} || $self->{'USER'}->{'baud_rate'} eq 'FULL') {
			$text =~ s/\n/$nl/gs;
		if ($self->{'local_mode'} || $self->{'sysop'}) {
			print STDOUT $text;
		} else {
			my $handle = $self->{'cl_socket'};
			print $handle $text;
		}
		$|=1;
	} else {
		foreach my $count (0 .. $s_len) {
			my $char = substr($text, $count, 1);
			if ($char eq "\n") {
				if ($char eq "\n") {
					if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
						$char = $nl;
					}
					$lines--;
					if ($lines <= 0) {
						$lines = $mlines;
						last unless ($self->scroll($nl));
						next;
					}
				}
			}
			$self->send_char($char);
		}
	}
    return (TRUE);
}

 

# package BBS::Universal::ASCII;

sub ascii_initialize {
    my $self = shift;

    $self->{'ascii_sequences'} = {
        'RETURN'    => chr(13),
        'LINEFEED'  => chr(10),
        'NEWLINE'   => chr(13) . chr(10),
		'BACKSPACE' => chr(8),
		'DELETE'    => chr(127),
        'CLS'       => chr(12), # Formfeed
        'CLEAR'     => chr(12),
		'RING BELL' => chr(7),

		# Color (ASCII doesn't have any, but we have placeholders
		'NORMAL' => '',

		# Foreground color
		'BLACK'          => '',
		'RED'            => '',
		'PINK'           => '',
		'ORANGE'         => '',
		'NAVY'           => '',
		'GREEN'          => '',
		'YELLOW'         => '',
		'BLUE'           => '',
		'MAGENTA'        => '',
		'CYAN'           => '',
		'WHITE'          => '',
		'DEFAULT'        => '',
		'BRIGHT BLACK'   => '',
		'BRIGHT RED'     => '',
		'BRIGHT GREEN'   => '',
		'BRIGHT YELLOW'  => '',
		'BRIGHT BLUE'    => '',
		'BRIGHT MAGENTA' => '',
		'BRIGHT CYAN'    => '',
		'BRIGHT WHITE'   => '',

		# Background color
		'B_BLACK'          => '',
		'B_RED'            => '',
		'B_GREEN'          => '',
		'B_YELLOW'         => '',
		'B_BLUE'           => '',
		'B_MAGENTA'        => '',
		'B_CYAN'           => '',
		'B_WHITE'          => '',
		'B_DEFAULT'        => '',
		'B_PINK'           => '',
		'B_ORANGE'         => '',
		'B_NAVY'           => '',
		'BRIGHT B_BLACK'   => '',
		'BRIGHT B_RED'     => '',
		'BRIGHT B_GREEN'   => '',
		'BRIGHT B_YELLOW'  => '',
		'BRIGHT B_BLUE'    => '',
		'BRIGHT B_MAGENTA' => '',
		'BRIGHT B_CYAN'    => '',
		'BRIGHT B_WHITE'   => '',
    };
    return ($self);
}

sub ascii_output {
    my $self   = shift;
	my $text   = shift;

	my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
	my $lines  = $mlines;
	if (length($text) > 1) {
		foreach my $string (keys %{ $self->{'ascii_sequences'} }) {
			if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
				my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
				$text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
			} else {
				$text =~ s/\[\%\s+$string\s+\%\]/$self->{'ascii_sequences'}->{$string}/gi;
			}
		}
		foreach my $string (keys %{ $self->{'ascii_characters'} }) {
			$text =~ s/\[\%\s+$string\s+\%\]/$self->{'ascii_characters'}->{$string}/gi;
		}
	}
	my $s_len = length($text);
	my $nl    = $self->{'ascii_sequences'}->{'NEWLINE'};
	if ($self->{'local_mode'} || $self->{'sysop'} || $self->{'USER'}->{'baud_rate'} eq 'FULL') {
		$text =~ s/\n/$nl/gs;
		if ($self->{'local_mode'} || $self->{'sysop'}) {
			print STDOUT $text;
		} else {
			my $handle = $self->{'cl_socket'};
			print $handle $text;
		}
		$|=1;
	} else {
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
			}
			$self->send_char($char);
		}
	}
	return (TRUE);
}

 

# package BBS::Universal::ATASCII;

sub atascii_initialize {
    my $self = shift;

    $self->{'atascii_sequences'} = {
        'HEART'                        => chr(0),
        'VERTICAL BAR MIDDLE RIGHT'    => chr(1),
		'VERTICAL BAR'                 => chr(2),
		'BOTTOM RIGHT'                 => chr(3),
		'VERTICAL BAR MIDDLE LEFT'     => chr(4),
		'TOP RIGHT'                    => chr(5),
		'FORWARD SLASH'                => chr(6),
		'RING BELL'                    => chr(253),
		'BACKSLASH'                    => chr(7),
		'TOP LEFT WEDGE'               => chr(8),
		'BOTTOM RIGHT BOX'             => chr(9),
		'TOP RIGHT WEDGE'              => chr(10),
        'LINEFEED'                     => chr(10),
		'TOP RIGHT BOX'                => chr(11),
		'TOP LEFT BOX'                 => chr(12),
        'RETURN'                       => chr(155),
        'NEWLINE'                      => chr(155),
		'OVERLINE BAR'                 => chr(13),
		'UNDERLINE BAR'                => chr(14),
		'BOTTOM LEFT BOX'              => chr(15),
		'CLUB'                         => chr(16),
		'TOP LEFT'                     => chr(17),
		'HORIZONATAL BAR'              => chr(18),
		'CROSS BAR'                    => chr(19),
		'CENTER DOT'                   => chr(20),
		'BOTTOM BOX'                   => chr(21),
		'BOTTOM VERTICAL BAR'          => chr(22),
		'HORIZONTAL BAR MIDDLE BOTTOM' => chr(23),
		'HORIZONTAL BAR MIDDLE TOP'    => chr(24),
		'VERTICAL BAR LEFT'            => chr(25),
		'BOTTOM LEFT'                  => chr(26),
        'ESC'                          => chr(27),
        'UP'                           => chr(28),
        'DOWN'                         => chr(29),
        'LEFT'                         => chr(30),
        'RIGHT'                        => chr(31),
		'SPADE'                        => chr(0x7B),
		'VERTICAL LINE'                => chr(0x7C),
		'BACK ARROW'                   => chr(0x7D),
        'CLEAR'                        => chr(125),
        'BACKSPACE'                    => chr(126),
		'LEFT TRIANGLE'                => chr(126),
        'TAB'                          => chr(127),
		'RIGHT TRIANGLE'               => chr(127),
		'DELETE LINE'                  => chr(156),
		'INSERT LINE'                  => chr(157),
		'CLEAR TAB STOP'               => chr(158),
		'SET TAB STOP'                 => chr(159),
		# Top bit inverts
        'DELETE LINE'                  => chr(156),
        'INSERT LINE'                  => chr(157),
        'BELL'                         => chr(253),
        'DELETE'                       => chr(254),
        'INSERT'                       => chr(255),
    };
    return ($self);
}

sub atascii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
            if ($string eq $self->{'atascii_sequences'}->{'CLEAR'} && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
            }
        }
    }
    my $s_len = length($text);
    my $nl    = $self->{'atascii_sequences'}->{'NEWLINE'};
	if ($self->{'local_mode'} || $self->{'sysop'} || $self->{'USER'}->{'baud_rate'} eq 'FULL') {
		$text =~ s/\n/$nl/gs;
		if ($self->{'local_mode'} || $self->{'sysop'}) {
			print STDOUT $text;
		} else {
			my $handle = $self->{'cl_socket'};
			print $handle $text;
		}
		$|=1;
	} else {
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
			}
			$self->send_char($char);
		}
	}
    return (TRUE);
}

 

# package BBS::Universal::BBS_List;

sub bbs_list_initialize {
    my $self = shift;
    return ($self);
}

sub bbs_list_add {
    my $self  = shift;

    my $index = 0;
    $self->output($self->prompt('What is the BBS Name'));
    my $bbs_name = $self->get_line(ECHO, 50);
    $self->output("\n");
    if ($bbs_name ne '' && length($bbs_name) > 3) {
        $self->output($self->prompt('What is the URL or Hostname'));
        my $bbs_hostname = $self->get_line(ECHO, 50);
        $self->output("\n");
        if ($bbs_hostname ne '' && length($bbs_hostname) > 5) {
            $self->output($self->prompt('What is the Port number'));
            my $bbs_port = $self->get_line(ECHO, 5);
            $self->output("\n");
            if ($bbs_port ne '' && $bbs_port =~ /^\d+$/) {
                $self->output('Adding BBS Entry...');
                my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
                $sth->execute($bbs_name, $bbs_hostname, $bbs_port);
                $sth->finish();
                $self->output("\n");
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
}

sub bbs_list_all {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view ORDER BY bbs_name');
    $sth->execute();
    my @listing;
    my ($name_size, $hostname_size, $poster_size) = (1, 1, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    }
    my $table = Text::SimpleTable->new($name_size, $hostname_size, 5, $poster_size);
    $table->row('NAME', 'HOSTNAME', 'PORT', 'POSTER');
    $table->hr();
    foreach my $line (@listing) {
        $table->row($line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
    }
    my $response;
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $response = $table->boxes->draw();
    } else {
        $response = $table->draw();
    }
    return ($response);
}

 

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
    return ($response);
}

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
            }
        }
    }
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
    }
    $self->{'CPUINFO'} = $response;    # Cache this stuff
    return ($response);
}

 

# package BBS::Universal::DB;

sub db_initialize {
    my $self = shift;

    return ($self);
}

sub db_connect {
    my $self = shift;

    my @dbhosts = split(/\s*,\s*/, $self->{'CONF'}->{'STATIC'}->{'DATABASE HOSTNAME'});
    my $errors  = '';
    foreach my $host (@dbhosts) {
        $errors        = '';
		# This is for the brave that want to try SSL connections.
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
    }
    if ($errors ne '') {
        $self->{'debug'}->ERROR(["Database Host not found!\n$errors"]);
        exit(1);
    }
    return (TRUE);
}

sub db_count_users {
    my $self = shift;

    unless (exists($self->{'dbh'})) {
        $self->db_connect();
    }
    my $response = $self->{'dbh'}->do('SELECT COUNT(id) FROM users');
    return ($response);
}

sub db_disconnect {
    my $self = shift;
    $self->{'dbh'}->disconnect() if (defined($self->{'dbh'}));
    return (TRUE);
}

 

# package BBS::Universal::FileTransfer;

sub filetransfer_initialize {
    my $self = shift;

    return ($self);
}

sub files_load_file {
    my $self = shift;
    my $file = shift;

    my $filename = sprintf('%s.%s', $file, substr($self->{'USER'}->{'text_mode'},0,3));
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    return (join("\n", @text));
}

sub files_list_summary {
    my $self   = shift;
    my $search = shift;

    my $sth;
    my $filter;
    if ($search) {
        $self->output("\n" . $self->prompt('Search for'));
        $filter = $self->get_line(ECHO, 20);
        $sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
        $sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
        $sth->execute($self->{'USER'}->{'file_category'});
    }
    my @files;
    my $max_filename = 10;
    my $max_title    = 20;
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
            $max_filename = max(length($row->{'filename'}), $max_filename);
            $max_title    = max(length($row->{'title'}),    $max_title);
        }
        my $table = Text::SimpleTable->new($max_filename, $max_title);
        $table->row('FILENAME', 'TITLE');
        $table->hr();
        foreach my $record (@files) {
            $table->row($record->{'filename'}, $record->{'title'});
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
    $self->get_key(ECHO, BLOCKING);
    return (TRUE);
}

sub files_list_detailed {
    my $self   = shift;
    my $search = shift;

    my $sth;
    my $filter;
    if ($search) {
        $self->output("\n" . $self->prompt('Search for'));
        $filter = $self->get_line(ECHO, 20);
        $sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
        $sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
        $sth->execute($self->{'USER'}->{'file_category'});
    }
    my @files;
    my $max_filename = 10;
    my $max_title    = 20;
    my $max_uploader = 8;
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
            $max_filename = max(length($row->{'filename'}), $max_filename);
            $max_title    = max(length($row->{'title'}),    $max_title);
            if ($row->{'prefer_nickname'}) {
                $max_uploader = max(length($row->{'nickname'}), $max_uploader);
            } else {
                $max_uploader = max(length($row->{'username'}), $max_uploader);
            }
        }
        my $table = Text::SimpleTable->new($max_filename, $max_title, $max_uploader);
        $table->row('FILENAME', 'TITLE', 'UPLOADER');
        $table->hr();
        foreach my $record (@files) {
            if ($record->{'prefer_nickname'}) {
                $table->row($record->{'filename'}, $record->{'title'}, $record->{'nickname'});
            } else {
                $table->row($record->{'filename'}, $record->{'title'}, $record->{'username'});
            }
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
    $self->get_key(ECHO, BLOCKING);
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

    return ($self);
}

sub messages_forum_categories {
    my $self = shift;

	my $command = '';
	my $id;
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM message_categories WHERE id<>? ORDER BY name');
    $sth->execute($self->{'USER'}->{'forum_category'});
    my $mapping = {
        'TEXT' => '',
        'Z'    => {
            'command'      => 'BACK',
            'color'        => 'WHITE',
            'access_level' => 'USER',
            'text'         => 'Return to Forum Menu',
        },
    };
    my @menu_choices = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y));
    while(my $result = $sth->fetchrow_hashref()) {
        if ($self->check_access_level($result->{'access_level'})) {
			$mapping->{shift(@menu_choices)} = {
                'command'      => $result->{'name'},
				'id'           => $result->{'id'},
                'color'        => 'WHITE',
                'access_level' => $result->{'access_level'},
                'text'         => $result->{'description'},
            };
		}
	}
	$sth->finish();
    $self->show_choices($mapping);
	$self->output("\n" . $self->prompt('Choose Forum Category'));
	my $key;
	do {
		$key = uc($self->get_key(SILENT, BLOCKING));
	} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	if ($key eq chr(3)) {
		$command = 'DISCONNECT';
	} else {
		$id      = $mapping->{$key}->{'id'};
		$command = $mapping->{$key}->{'command'};
	}
	if ($self->is_connected() && $command ne 'DISCONNECT') {
		$self->output($command);
		$sth = $self->{'dbh'}->prepare('UPDATE users SET forum_category=? WHERE id=?');
		$sth->execute($id,$self->{'USER'}->{'id'});
		$sth->finish();
		$self->{'USER'}->{'forum_category'} = $id;
		$command = 'BACK';
	}
    return($command);
}

sub messages_list_messages {
    my $self = shift;

	my $id;
	my $command;
	my $forum_category = $self->{'USER'}->{'forum_category'};
    my $sth = $self->{'dbh'}->prepare('SELECT id,from_id,category,author_fullname,author_nickname,author_username,title,created FROM messages_view WHERE category=? ORDER BY created DESC');
	my @index;
    $sth->execute($forum_category);
	while(my $record = $sth->fetchrow_hashref) {
		push(@index,$record);
	}
	$sth->finish();
	my $result;
	my $count = 0;
    do {
		$result = $index[$count];
		$sth = $self->{'dbh'}->prepare('SELECT message FROM messages_view WHERE id=? ORDER BY created DESC');
		$sth->execute($result->{'id'});
		$result->{'message'} = $sth->fetchrow_array();
		$sth->finish();

		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output('[% CLEAR %][% BRIGHT B_GREEN %][% BLACK %] FORUM CATEGORY [% RESET %] [% MAGENTA %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% FORUM CATEGORY %]' . "\n\n");
			$self->output('[% INVERT %]  Author [% RESET %]  ' . $result->{'author_fullname'} . ' (' . $result->{'author_username'} . ')' . "\n");
			$self->output('[% INVERT %]   Title [% RESET %]  ' . $result->{'title'} . "\n");
			$self->output('[% INVERT %] Created [% RESET %]  ' . $self->users_get_date($result->{'created'}) . "\n\n");
			$self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
		} else {
			$self->output('[% CLEAR %] FORUM CATEGORY > [% FORUM CATEGORY %]' . "\n\n");
			$self->output(' Author:  ' . $result->{'author_fullname'} . ' (' . $result->{'author_username'} . ')' . "\n");
			$self->output('  Title:  ' . $result->{'title'} . "\n");
			$self->output('Created:  ' . $self->users_get_date($result->{'created'}) . "\n\n");
			$self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
		}
		$self->output("\n");
		my $mapping = {
			'Z' => {
				'id'           => $result->{'id'},
				'command'      => 'BACK',
				'color'        => 'WHITE',
				'access_level' => 'USER',
				'text'         => 'Return to the Forum Menu',
			},
			'N' => {
				'id'           => $result->{'id'},
				'command'      => 'NEXT',
				'color'        => 'BRIGHT BLUE',
				'access_level' => 'USER',
				'text'         => 'Next Message',
			},
		};
		if ($self->{'USER'}->{'post_message'}) {
			$mapping->{'R'} = {
				'id'           => $result->{'id'},
				'command'      => 'REPLY',
				'color'        => 'BRIGHT GREEN',
				'access_level' => 'USER',
				'text'         => 'Reply',
			};
		}
		if ($self->{'USER'}->{'remove_message'}) {
			$mapping->{'D'} = {
				'id'           => $result->{'id'},
				'command'      => 'DELETE',
				'color'        => 'RED',
				'access_level' => 'VETERAN',
				'text'         => 'Delete Message',
			};
		}
		$self->show_choices($mapping);
		$self->output("\n" . $self->prompt('Choose'));
		my $key;
		do {
			$key = uc($self->get_key(SILENT, FALSE));
		} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
		if ($key eq chr(3)) {
			$id      = undef;
			$command = 'DISCONNECT';
		} else {
			$id      = $mapping->{$key}->{'id'};
			$command = $mapping->{$key}->{'command'};
		}
		$self->output($command);
		if ($command eq 'REPLY') {
			my $message = $self->messages_edit_message('REPLY',$result);
			push(@index,$message);
			$count = 0;
		} elsif ($command eq 'DELETE') {
			$self->messages_delete_message($result);
			delete($index[$count]);
		} else {
			$count++;
		}
		unless ($self->{'local_mode'} || $self->{'sysop'} || $self->is_connected()) {
			$command = 'DISCONNECT';
		}
    } until ($count >= scalar(@index) || $command =~ /^(DISCONNECT|BACK)$/);
    return(TRUE);
}

sub messages_edit_message {
    my $self        = shift;
    my $mode        = shift;
	my $old_message = (scalar(@_)) ? shift : undef;

	my $message;
    if ($mode eq 'ADD') {
        $self->output("Add New Message\n");
		$self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor();
		if (defined($message)) {
			$message->{'from_id'} = $self->{'USER'}->{'id'};
			$message->{'category'} = $self->{'USER'}->{'forum_category'};
			my $sth = $self->{'dbh'}->prepare('INSERT INTO messages (category, from_id, title, message) VALUES (?, ?, ?, ?)');
			$sth->execute(
				$message->{'category'},
				$message->{'from_id'},
				$message->{'title'},
				$message->{'message'}
			);
			$sth->finish();
			if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
				$self->output('[% GREEN %]Message Saved[% RESET %]');
			} else {
				$self->output('Message Saved');
			}
			$message->{'id'} = $sth->last_insert_id();
			sleep 2;
		}
	} elsif ($mode eq 'REPLY') {
        $self->output("Edit Message\n");
		unless ($old_message->{'title'} =~ /^Re: /) {
			$old_message->{'title'} = 'Re: ' . $old_message->{'title'};
			$old_message->{'message'} =~ s/^(.*)/\> $1/g;
		}
		$self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor($old_message);
		if (defined($message)) {
			$message->{'from_id'}  = $self->{'USER'}->{'id'};
			$message->{'title'}    = $old_message->{'title'};
			$message->{'category'} = $self->{'USER'}->{'forum_category'};
			my $sth = $self->{'dbh'}->prepare('INSERT INTO messages (category, from_id, title, message) VALUES (?, ?, ?, ?)');
			$sth->execute(
				$message->{'category'},
				$message->{'from_id'},
				$message->{'title'},
				$message->{'message'}
			);
			$sth->finish();
			$message->{'id'} = $sth->last_insert_id();
		}
    } else { # EDIT
        $self->output("Edit Message\n");
		$self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor($old_message);
		if (defined($message)) {
			my $sth = $self->{'dbh'}->prepare('UPDATE messages SET category=?, from_id=?, title=?, message=? WHERE id=>');
			$sth->execute(
				$message->{'category'},
				$message->{'from_id'},
				$message->{'title'},
				$message->{'message'},
				$message->{'id'}
			);
			$sth->finish();
			$message->{'id'} = $old_message->{'id'};
		}
    }
    return($message);
}

sub messages_delete_message {
    my $self    = shift;
	my $message = shift;

	$self->output("\n\nReally Delete This Message?  ");
	if ($self->decision() && defined($message)) {
		my $sth = $self->{'dbh'}->prepare('UPDATE messages SET hidden=TRUE WHERE id=?');
		$sth->execute($message->{'id'});
		$sth->finish();
		return(TRUE);
	}
    return(FALSE);
}

sub messages_text_editor {
	my $self    = shift;
	my $message = (scalar(@_)) ? shift : undef;

	my $title = '';
	my $text  = '';
	if ($self->{'local_mode'} || $self->{'sysop'} || $self->is_connected()) {
		if (defined($message)) {
			$title = $message->{'title'};
			$text  = $message->{'message'};
			$self->output($self->prompt('Message'));
			$text  = $self->messages_text_edit($text);
		} else {
			$self->output($self->prompt('Title'));
			$title = $self->get_line(ECHO, 255);
			$self->output($self->prompt('Message'));
			$text  = $self->messages_text_edit();
		}
		if (defined($text) && defined($title)) {
			return(
				{
					'title'   => $title,
					'message' => $text,
				}
			);
		}
	}
	return(undef);
}

sub messages_text_edit {
	my $self = shift;
	my $text = (scalar(@_)) ? shift : undef;

	my $columns = $self->{'USER'}->{'max_columns'};
	my $text_mode = $self->{'USER'}->{'text_mode'};
	my @lines;
	if (defined($text) && $text ne '') {
		@lines = split(/\n/,$text . "\n");
	}
	my $save   = FALSE;
	my $cancel = FALSE;
	do {
		my $counter = 0;
		if ($text_mode eq 'ANSI') {
			$self->output('[% CLEAR %][% BRIGHT GREEN %]' . '=' x $columns . '[% RESET %]' . "\n");
			$self->output("Type a command on a line by itself\n");
			$self->output('  :[% YELLOW %]S[% RESET %] = Save and exit' . "\n");
			$self->output("  :[% RED %]Q[% RESET %] = Cancel, do not save\n");
			$self->output("  :[% BRIGHT BLUE %]E[% RESET %] = Edit a specific line number (:E5 edits line 5)\n");
			$self->output('[% BRIGHT GREEN %]' . '=' x $columns . '[% RESET %]' . "\n");
		} elsif ($text_mode eq 'PETSCII') {
			$self->output('[% CLEAR %]' . '=' x $columns . "\n");
			$self->output("Type a command on a line by itself\n");
			$self->output("  :S = Save and exit\n");
			$self->output("  :Q = Cancel, do not save\n");
			$self->output("  :E = Edit a specific line number (:E5 edits line 5)\n");
			$self->output('=' x $columns . "\n");
		} else {
			$self->output('[% CLEAR %]' . '=' x $columns . "\n");
			$self->output("Type a command on a line by itself\n");
			$self->output("  :S = Save and exit\n");
			$self->output("  :Q = Cancel, do not save\n");
			$self->output("  :E = Edit a specific line number (:E5 edits line 5)\n");
			$self->output('=' x $columns . "\n");
		}

		foreach my $line (@lines) {
			if ($text_mode eq 'ANSI') {
				$self->output(sprintf('%s%03d%s %s', '[% CYAN %]', ($counter + 1), '[% RESET %]', $line) . "\n");
			} else {
				$self->output(sprintf('%03d %s', ($counter + 1), $line) . "\n");
			}
			$counter++;
		}
		my $menu = FALSE;
		do {
			if ($text_mode eq 'ANSI') {
				$self->output(sprintf('%s%03d%s ', '[% CYAN %]', ($counter + 1), '[% RESET %]'));
			} else {
				$self->output(sprintf('%03d ', ($counter + 1)));
			}
			$text = $self->get_line(ECHO,$self->{'USER'}->{'max_columns'});
			$self->output("\n");
			if ($text =~ /^\:(.)(.*)/i) { # Process command
				my $command = uc($1);
				if ($command eq 'E') {
					my $line_number = $2;
					if ($line_number > 0) {
						if ($text_mode eq 'ANSI') {
							$self->output("\n" . sprintf('%s%03d%s ','[% CYAN %]',$line_number, '[% RESET %]'));
						} else {
							$self->output("\n" . sprintf('%03d ',$line_number));
						}
						my $line = $self->get_line(ECHO,$self->{'USER'}->{'max_columns'},$lines[$line_number - 1]);
						$lines[$line_number - 1] = $line;
					}
					$menu = TRUE;
				} elsif ($command eq 'S') {
					$save = TRUE;
				} elsif ($command eq 'Q') {
					$cancel = TRUE;
				}
			} else {
				chomp($text);
				push(@lines, $text);
				$counter++;
			}
		} until ($menu || $save || $cancel || ! $self->is_connected());
	} until($save || $cancel || ! $self->is_connected());
	if ($save) {
		$text = join("\n",@lines);
	} else {
		undef($text);
	}
	return($text);
}

 

# package BBS::Universal::News;

sub news_initialize {
    my $self = shift;

    return ($self);
}

sub news_display {
    my $self = shift;

    my $news   = "\n";
    my $format = Text::Format->new(
        'columns'     => $self->{'USER'}->{'max_columns'} - 1,
        'tabstop'     => 4,
        'extraSpace'  => TRUE,
        'firstIndent' => 2,
    );
    {
        my $dt = DateTime->now;
        if ($dt->month == 7 && $dt->day == 10) {
            my $today;
            if ($self->{'USER'}->{'DATE FORMAT'} eq 'DAY/MONTH/YEAR') {
                $today = $dt->dmy;
            } elsif ($self->{'USER'}->{'DATE FORMAT'} eq 'YEAR/MONTH/DAY') {
                $today = $dt->ymd;
            } else {
                $today = $dt->mdy;
            }
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $news .= "$today - [% B_GREEN %][% BLACK %] Today is the author's birthday! [% RESET %] " . $self->{'ansi_characters'}->{'PARTY POPPER'} . "\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
            } else {
                $news .= "* $today - Today is the author's birthday!\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
            }
            $news .= "\n";
        }
    }
	my $df = $self->{'USER'}->{'date_format'};
	$df =~ s/YEAR/\%Y/;
	$df =~ s/MONTH/\%m/;
	$df =~ s/DAY/\%d/;
    my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,?) AS newsdate
		FROM news
		ORDER BY news_date DESC
	};
    my $sth = $self->{'dbh'}->prepare($sql);
    $sth->execute($df);
    if ($sth->rows > 0) {
        while (my $fields = $sth->fetchrow_hashref()) {
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $news .= $fields->{'newsdate'} . ' - [% B_GREEN %][% BLACK %] ' . $fields->{'news_title'} . " [% RESET %]\n\n" . $format->format($fields->{'news_content'});
            } else {
                $news .= '* ' . $fields->{'newsdate'} . ' - ' . $fields->{'news_title'} . "\n\n" . $format->format($fields->{'news_content'});
            }
            $news .= "\n";
        }
    } else {
        $news = "No News\n\n";
    }
    $sth->finish();
    $self->output($news);
    $self->output("Press a key to continue ... ");
    $self->get_key(SILENT, BLOCKING);
    return (TRUE);
}

sub news_summary {
    my $self = shift;

	my $format = $self->{'USER'}->{'date_format'};
	$format =~ s/YEAR/\%Y/;
	$format =~ s/MONTH/\%m/;
	$format =~ s/DAY/\%d/;
    my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,?) AS newsdate
		FROM news
		ORDER BY news_date DESC};
    my $sth = $self->{'dbh'}->prepare($sql);
    $sth->execute($format);
    if ($sth->rows > 0) {
        my $table = Text::SimpleTable->new(10, $self->{'USER'}->{'max_columns'} - 13);
        $table->row('DATE', 'TITLE');
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            $table->row($row->{'newsdate'}, $row->{'news_title'});
        }
        if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
            my $text = $table->boxes->draw();
			my $ch = colored(['bright_yellow'],'DATE');
			$text =~ s/DATE/$ch/;
			$ch = colored(['bright_yellow'],'TITLE');
			$text =~ s/TITLE/$ch/;
			$self->output($text);
        } else {
            $self->output($table->draw());
        }
    } else {
        $self->output('No News');
    }
    $sth->finish();
    $self->output("\nPress a key to continue ... ");
    $self->get_key(SILENT, BLOCKING);
    return (TRUE);
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
		'BACKSPACE'         => chr(20),
		'DELETE'            => chr(20),
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
        'CYAN'              => chr(hex('0x97')),
        'LIGHT GREY'        => chr(hex('0x98')),
        'LIGHT GREEN'       => chr(hex('0x99')),
        'LIGHT BLUE'        => chr(hex('0x9A')),
        'GRAY'              => chr(hex('0x9B')),
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
        'RING BELL'         => chr(7),
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
    return ($self);
}

sub petscii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'petscii_sequences'} }) {    # Decode macros
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'petscii_sequences'}->{$string}/gi;
            }
        }
    }
    my $s_len = length($text);
    my $nl    = $self->{'petscii_sequences'}->{'NEWLINE'};
    if ($self->{'local_mode'} || $self->{'sysop'} || $self->{'USER'}->{'baud_rate'} eq 'FULL') {
		$text =~ s/\n/$nl/gs;
		if ($self->{'local_mode'} || $self->{'sysop'}) {
			print STDOUT $text;
		} else {
			my $handle = $self->{'cl_socket'};
			print $handle $text;
		}
		$|=1;
	} else {
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
			}
			$self->send_char($char);
		}
    }
    return (TRUE);
}

 

# package BBS::Universal::SysOp;

sub sysop_initialize {
    my $self = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
	$self->{'wsize'} = $wsize;
	$self->{'hsize'} = $hsize;
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
    } else {
		$sections = 6;
	}
    my $versions     = $self->sysop_versions_format($sections, FALSE);
    my $bbs_versions = $self->sysop_versions_format($sections, TRUE);
    my $esc          = chr(27) . '[';

    $self->{'sysop_tokens'} = {

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

        'MIDDLE VERTICAL RULE BLACK'   => $self->sysop_locate_middle('B_BLACK'),
        'MIDDLE VERTICAL RULE RED'     => $self->sysop_locate_middle('B_RED'),
        'MIDDLE VERTICAL RULE GREEN'   => $self->sysop_locate_middle('B_GREEN'),
        'MIDDLE VERTICAL RULE YELLOW'  => $self->sysop_locate_middle('B_YELLOW'),
        'MIDDLE VERTICAL RULE BLUE'    => $self->sysop_locate_middle('B_BLUE'),
        'MIDDLE VERTICAL RULE MAGENTA' => $self->sysop_locate_middle('B_MAGENTA'),
        'MIDDLE VERTICAL RULE CYAN'    => $self->sysop_locate_middle('B_CYAN'),
        'MIDDLE VERTICAL RULE WHITE'   => $self->sysop_locate_middle('B_WHITE'),

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
            my @sys = (sort(keys %{$main::SYSOP_COMMANDS}));
			my @stkn = (sort(keys %{ $self->{'sysop_tokens'} }));
            my @usr = (sort(keys %{ $self->{'COMMANDS'} }));
            my @tkn = (sort(keys %{ $self->{'TOKENS'} }));
            my $x   = 1;
			my $xt  = 1;
            my $y   = 1;
			my $z   = 1;
            foreach my $s (@sys) {
                $x = max(length($s), $x);
            }
            foreach my $st (@stkn) {
                $xt = max(length($st), $xt);
            }
            foreach my $u (@usr) {
                $y = max(length($u), $y);
            }
			foreach my $t (@tkn) {
				$z = max(length($t), $z);
			}
            my $table = Text::SimpleTable->new($x, $xt, $y, $z);
            $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS', 'USER MENU COMMANDS', 'USER TOKENS');
            $table->hr();
            my ($sysop_names, $sysop_tokens, $user_names, $token_names);
            while (scalar(@sys) || scalar(@stkn) || scalar(@usr) || scalar(@tkn)) {
                if (scalar(@sys)) {
                    $sysop_names = shift(@sys);
                } else {
                    $sysop_names = ' ';
                }
                if (scalar(@stkn)) {
                    $sysop_tokens = shift(@stkn);
                } else {
                    $sysop_tokens = ' ';
                }
                if (scalar(@usr)) {
                    $user_names = shift(@usr);
                } else {
                    $user_names = ' ';
                }
                if (scalar(@tkn)) {
                    $token_names = shift(@tkn);
                } else {
                    $token_names = ' ';
                }
                $table->row($sysop_names, $sysop_tokens, $user_names, $token_names);
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
			email
			birthday
			location
			access_level
			date_format
			baud_rate
			text_mode
			max_columns
			max_rows
			timeout
			retro_systems
			accomplishments
			prefer_nickname
			view_files
			upload_files
			download_files
			remove_files
			play_fortunes
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
        'email'           => 20,
        'birthday'        => 10,
        'location'        => 20,
		'date_format'     => 14,
		'access_level'    => 11,
        'baud_rate'       => 4,
        'login_time'      => 10,
        'logout_time'     => 10,
        'text_mode'       => 9,
        'max_rows'        => 5,
        'max_columns'     => 5,
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
		'play_fortunes'   => 2,
        'sysop'           => 2,
        'page_sysop'      => 2,
        'password'        => 64,
    };

    return ($self);
}

sub sysop_online_count {
    my $self = shift;

	my $count = $self->{'CACHE'}->get('ONLINE');
    return ($count);
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
    }
    $heading = colored(['bold bright_yellow on_red'], $heading);
    foreach my $v (@{ $self->{'VERSIONS'} }) {
        next if ($bbs_only && $v !~ /^BBS/);
        $versions .= "\t\t $v";
        $counter--;
        if ($counter <= 1) {
            $counter = $sections;
            $versions .= "\n\t";
        }
    }
    chop($versions) if (substr($versions, -1, 1) eq "\t");
    return ($heading . $versions . "\n");
}

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
            $diskfree .= "\t" . colored(['bold bright_yellow on_blue'], " $line " . ' ' x ($width - length($line))) . "\n";    # Make the heading the right width
        } else {
            $diskfree .= "\t\t\t $line\n";
        }
    }
    return ($diskfree);
}

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
        }
    }
    unless ($found) {
        $self->{'debug'}->ERROR(['Database setup file not found', join("\n", @sql_files)]);
        exit(1);
    }
}

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
    }
    close($FILE);
    return ($mapping);
}

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
    }
    return ($scroll);
}

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown;
    my $scroll = $self->sysop_pager($mapping->{'TEXT'}, 3);
    my $keys   = '';
    print "\r", cldown unless ($scroll);
    $self->sysop_show_choices($mapping);
    print "\n", $self->sysop_prompt('[% B_MAGENTA %][% BLACK %] SYSOP TOOL [% RESET %] Choose');
    my $key;
    do {
        $key = uc($self->sysop_keypress());
    } until (exists($mapping->{$key}));
    print $mapping->{$key}->{'command'}, "\n";
    return ($mapping->{$key}->{'command'});
}

sub sysop_decision {
    my $self = shift;

    my $response;
    do {
        $response = uc($self->sysop_keypress());
    } until ($response =~ /Y|N/i || $response eq chr(13));
    if ($response eq 'Y') {
        print "YES\n";
        return (TRUE);
    }
    print "NO\n";
    return (FALSE);
}

sub sysop_keypress {
    my $self = shift;

    $self->{'CACHE'}->set('SHOW_STATUS', FALSE);
    my $key;
    ReadMode 'ultra-raw';
    do {
        $key = ReadKey(-1);
        threads->yield();
    } until (defined($key));
    ReadMode 'restore';
    $self->{'CACHE'}->set('SHOW_STATUS', TRUE);
    return ($key);
}

sub sysop_ip_address {
    my $self = shift;

    chomp(my $ip = `nice hostname -I`);
    return ($ip);
}

sub sysop_hostname {
    my $self = shift;

    chomp(my $hostname = `nice hostname`);
    return ($hostname);
}

sub sysop_locate_middle {
    my $self  = shift;
    my $color = (scalar(@_)) ? shift : 'B_WHITE';

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $middle = int($wsize / 2);
    my $string = "\r" . $self->{'ansi_sequences'}->{'RIGHT'} x $middle . $self->{'ansi_sequences'}->{$color} . ' ' . $self->{'ansi_sequences'}->{'RESET'};
    return ($string);
}

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
}

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
}

sub sysop_list_users {
    my $self      = shift;
    my $list_mode = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $table;
    my $date_format = $self->configuration('DATE FORMAT');
	$date_format =~ s/YEAR/\%Y/;
	$date_format =~ s/MONTH/\%m/;
	$date_format =~ s/DAY/\%d/;
    my $name_width  = 15;
    my $value_width = $wsize - 22;
    my $sth;
    my @order;
    my $sql;

    if ($list_mode =~ /DETAILED/) {
        $sql = q{ SELECT * FROM users_view };
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
            }
        }
        $sth->finish();
        $sth = $self->{'dbh'}->prepare($sql);
        $sth->execute();
        $table = Text::SimpleTable->new($name_width, $value_width);
        $table->row('NAME', 'VALUE');

        while (my $Row = $sth->fetchrow_hashref()) {
            $table->hr();
            foreach my $name (@order) {
                if ($name !~ /id|time/ && $Row->{$name} =~ /^(0|1)$/) {
                    $Row->{$name} = $self->sysop_true_false($Row->{$name}, 'YN');
                } elsif ($name eq 'timeout') {
                    $Row->{$name} = $Row->{$name} . ' Minutes';
                }
                $self->{'debug'}->DEBUGMAX([$name, $Row->{$name}]);
                $table->row($name . '', $Row->{$name} . '');
            }
        }
        $sth->finish();
        my $string = $table->boxes->draw();
		my $ch = colored(['bright_yellow'],'NAME');
		$string =~ s/ NAME / $ch /;
		$ch = colored(['bright_yellow'],'VALUE');
		$string =~ s/ VALUE / $ch /;
        $self->sysop_pager("$string\n");
    } else {    # Horizontal
        my @hw;
        foreach my $name (@order) {
            push(@hw, $self->{'SYSOP HEADING WIDTHS'}->{$name});
        }
        $table = Text::SimpleTable->new(@hw);
        if ($list_mode =~ /ABBREVIATED/) {
            $table->row(@order);
        } else {
            my @title = ();
            foreach my $heading (@order) {
                push(@title, $self->sysop_vertical_heading($heading));
            }
            $table->row(@title);
        }
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            my @vals = ();
            foreach my $name (@order) {
                push(@vals, $row->{$name} . '');
                $self->{'debug'}->DEBUGMAX([$name, $row->{$name}]);
            }
            $table->row(@vals);
        }
        $sth->finish();
        my $string = $table->boxes->draw();
        $self->sysop_pager("$string\n");
    }
    print 'Press a key to continue ... ';
    return ($self->sysop_keypress(TRUE));
}

sub sysop_delete_files {
    my $self = shift;

    return (TRUE);
}

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
        }
    }
    $sth->finish();
    my $table;
    if ($wsize > 150) {
        $table = Text::SimpleTable->new($sizes->{'filename'}, $sizes->{'title'}, $sizes->{'type'}, $sizes->{'description'}, $sizes->{'username'}, $sizes->{'file_size'}, $sizes->{'uploaded'});
        $table->row('FILENAME', 'TITLE', 'TYPE', 'DESCRIPTION', 'USER', 'SIZE', 'UPLOADED');
    } else {
        $table = Text::SimpleTable->new($sizes->{'filename'}, $sizes->{'title'}, max($sizes->{'extension'}, 4), $sizes->{'description'}, $sizes->{'username'}, $sizes->{'file_size'});
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
}

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
        $line = uc($self->sysop_get_line(ECHO,3));
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
}

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
        $line = uc($self->sysop_get_line(ECHO,3));
    } until ($line =~ /^(\d+|A|\<)/i);
    if ($line eq 'A') {    # Add
        print "\nADD NEW FILE CATEGORY\n";
        $table = Text::SimpleTable->new(11, 80);
        $table->row('TITLE',       "\n" . $self->{'ansi_characters'}->{'OVERLINE'} x 80);
        $table->row('DESCRIPTION', "\n" . $self->{'ansi_characters'}->{'OVERLINE'} x 80);
        print "\n",                                  $table->boxes->draw();
        print $self->{'ansi_sequences'}->{'UP'} x 5, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
        my $title = $self->sysop_get_line(ECHO,80);
        if ($title ne '') {
            print "\r", $self->{'ansi_sequences'}->{'DOWN'}, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
            my $description = $self->sysop_get_line(ECHO,80);
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
}

sub sysop_vertical_heading {
    my $self = shift;
    my $text = shift;

    my $heading = '';
    for (my $count = 0; $count < length($text); $count++) {
        $heading .= substr($text, $count, 1) . "\n";
    }
    return ($heading);
}

sub sysop_view_configuration {
    my $self = shift;
    my $view = shift;

    # Get maximum widths
    my $name_width  = 6;
    my $value_width = 45;
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
    }

    # Assemble table
    my $table = ($view) ? Text::SimpleTable->new($name_width, $value_width) : Text::SimpleTable->new(6, $name_width, $value_width);
    if ($view) {
        $table->row('STATIC NAME', 'STATIC VALUE');
        $table->hr();
    }
    foreach my $conf (sort(keys %{ $self->{'CONF'}->{'STATIC'} })) {
        next if ($conf eq 'DATABASE PASSWORD');
        if ($view) {
            $table->row($conf, $self->{'CONF'}->{'STATIC'}->{$conf});
        }
    }
    if ($view) {
        $table->hr();
        $table->row('CONFIG NAME', 'CONFIG VALUE');
    } else {
        $table->row('CHOICE', 'CONFIG NAME', 'CONFIG VALUE');
    }
    $table->hr();
    my $count = 0;
    foreach my $conf (sort(keys %{ $self->{'CONF'} })) {
        next if ($conf eq 'STATIC');
        my $c = $self->{'CONF'}->{$conf};
        if ($conf eq 'DEFAULT TIMEOUT') {
            $c .= ' Minutes';
        } elsif ($conf eq 'DEFAULT BAUD RATE') {
            $c .= ' bps - 300,1200,2400,4800,9600,19200,FULL';
        } elsif ($conf eq 'THREAD MULTIPLIER') {
            $c .= ' x CPU Cores';
        } elsif ($conf eq 'DEFAULT TEXT MODE') {
            $c .= ' - ANSI,ASCII,ATASCII,PETSCII';
        }
        if ($view) {
            $table->row($conf, $c);
        } else {
            if ($conf =~ /AUTHOR/) {
                $table->row(' ', $conf, $c);
            } else {
                $table->row(uc('  ' . sprintf('%x', $count) . ' '), $conf, $c);
                $count++;
            }
        }
    }
    my $output = $table->boxes->draw();
    foreach my $change ('AUTHOR EMAIL', 'AUTHOR LOCATION', 'AUTHOR NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME', '300,1200,2400,4800,9600,19200,FULL', '%d = day, %m = Month, %Y = Year', 'ANSI,ASCII,ATASCII,PETSCII', 'ANS,ASC,ATA,PET') {
        if ($output =~ /$change/) {
            my $ch = ($change =~ /^(AUTHOR|DATABASE)/) ? colored(['yellow'], $change) : colored(['grey11'], $change);
            $output =~ s/$change/$ch/gs;
        }
    }
    {
        my $ch = colored(['cyan'], 'CHOICE');
        $output =~ s/CHOICE/$ch/gs;
        $ch = colored(['bright_yellow'], 'STATIC NAME');
        $output =~ s/STATIC NAME/$ch/gs;
        $ch = colored(['green'], 'CONFIG NAME');
        $output =~ s/CONFIG NAME/$ch/gs;
        $ch = colored(['cyan'], 'CONFIG VALUE');
        $output =~ s/CONFIG VALUE/$ch/gs;
    }
    print $self->sysop_detokenize($output);
    if ($view) {
        print 'Press a key to continue ... ';
        return ($self->sysop_keypress(TRUE));
    } else {
        print $self->sysop_menu_choice('TOP',    '',    '');
        print $self->sysop_menu_choice('Z',      'RED', 'Return to Settings Menu');
        print $self->sysop_menu_choice('BOTTOM', '',    '');
        print $self->sysop_prompt('[% B_MAGENTA %][% BLACK %] SYSOP TOOL [% RESET %] Choose');
        return (TRUE);
    }
}

sub sysop_edit_configuration {
    my $self = shift;

    $self->sysop_view_configuration(FALSE);
    my $choice;
    do {
        $choice = $self->sysop_keypress(TRUE);
    } until ($choice =~ /\d|[A-F]|Z/i);
    if ($choice =~ /Z/i) {
        print "BACK\n";
        return (FALSE);
    }
    $choice = hex($choice);
    my @conf = grep(!/STATIC|AUTHOR/, sort(keys %{ $self->{'CONF'} }));
    print '(Edit) ', $conf[$choice], ' ', $self->{'ansi_characters'}->{'BLACK RIGHT-POINTING TRIANGLE'}, '  ';
    my $sizes = {
        'BAUD RATE'           => 4,
        'BBS NAME'            => 50,
        'BBS ROOT'            => 60,
        'HOST'                => 20,
        'THREAD MULTIPLIER'   => 2,
        'PORT'                => 5,
        'DEFAULT BAUD RATE'   => 5,
        'DEFAULT TEXT MODE'   => 7,
        'DEFAULT TIMEOUT'     => 3,
        'FILES PATH'          => 60,
        'LOGIN TRIES'         => 1,
        'MEMCACHED HOST'      => 20,
        'MEMCACHED NAMESPACE' => 32,
        'MEMCACHED PORT'      => 5,
        'DATE FORMAT'         => 10,
    };
    my $string = $self->sysop_get_line(ECHO,$sizes->{ $conf[$choice] });
    return (FALSE) if ($string eq '');
    $self->configuration($conf[$choice], $string);
    return (TRUE);
}

sub sysop_get_key {
	my $self     = shift;
	my $echo     = shift;
	my $blocking = shift;

	my $key = undef;
	local $/ = "\x{00}";
	ReadMode 'ultra-raw';
	$key = ($blocking) ? ReadKey(0) : ReadKey(-1);
	ReadMode 'restore';
	return($key) if ($key eq chr(13));
	$key = $self->{'backspace'} if ($key eq chr(127));
	if ($echo == NUMERIC && defined($key)) {
		if ($key =~ /[0-9]/ || $key eq $self->{'backspace'}) {
			$self->{'debug'}->DEBUGMAX(["Echoing $key"]);
			print STDOUT $key;
		} else {
			$key = '';
		}
	} elsif ($echo == ECHO && defined($key)) {
		print STDOUT $key;
	} elsif ($echo == PASSWORD && defined($key)) {
		print STDOUT '*';
	}
	return ($key);
}

sub sysop_get_line {
	my $self  = shift;
	my $echo  = shift;
	my $limit = min(shift, 65535);
	my $line  = shift || '';
	my $key;

    $self->{'CACHE'}->set('SHOW_STATUS', FALSE);
	$self->output($line) if ($line ne '');
	while ($self->is_connected() && $key ne chr(13) && $key ne chr(3)) {
		if (length($line) < $limit) {
			$key = $self->sysop_get_key($echo, BLOCKING);
			return('') if (defined($key) && $key eq chr(3));
			if (defined($key) && $key ne '' && $self->is_connected()) {
				if ($key eq $self->{'backspace'} || $key eq chr(127)) {
					$self->output(" $key");
					my $len = length($line);
					if ($len > 0) {
						$line = substr($line,0, $len - 1);
					}
				} elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && ord($key) > 31 && ord($key) < 127) {
					$line .= $key;
				}
			}
		} else {
			$key = $self->get_key(SILENT, BLOCKING);
			return('') if (defined($key) && $key eq chr(3));
			if (defined($key) && $key eq $self->{'backspace'} || $key eq chr(127)) {
				$key = $self->{'backspace'};
				$self->output("$key $key");
				chop($line);
			} else {
				$self->output('[% RING BELL %]');
			}
		}
		threads->yield();
	}

	$line = '' if ($key eq chr(3));
    $self->{'CACHE'}->set('SHOW_STATUS', TRUE);
	print STDOUT "\n";
	return ($line);
}

sub sysop_user_delete {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my $key;
    print $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(ECHO,20);
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
        }
        if ($self->sysop_pager($table->boxes->draw())) {
            print "Are you sure that you want to delete this user (Y|N)?  ";
            my $answer = $self->sysop_decision();
            if ($answer) {
                print "\n\nDeleting ", $user_row->{'username'}, " ... ";
                $sth = $self->users_delete($user_row->{'id'});
            }
        }
    }
}

sub sysop_user_edit {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
    my $key;
    print $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(ECHO,20);
    return (FALSE) if ($search eq '');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($user_row)) {
		my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
		my $valsize = 1;
		foreach my $fld (keys %{ $user_row }) {
			$valsize = max($valsize,length($user_row->{$fld}));
		}
		$valsize = min($valsize,$wsize - 29);
        my $table = Text::SimpleTable->new(6, 16, $valsize);
        $table->row('CHOICE', 'FIELD', 'VALUE');
        $table->hr();
        my $count = 0;
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
            }
        }
        print $table->boxes->draw(), "\n";
        $self->sysop_show_choices($mapping);
        print "\n", $self->sysop_prompt('[% B_MAGENTA %][% BLACK %] SYSOP TOOL [% RESET %] Choose');
        do {
            $key = uc($self->sysop_keypress());
        } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
        if ($key !~ /$key_exit/i) {
            print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
            my $new = $self->sysop_get_line(ECHO,1 + $self->{'SYSOP HEADING WIDTHS'}->{ $choice{$key} }, $choice{$key});
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
        }
    } elsif ($search ne '') {
        print "User not found!\n\n";
    }
    return (TRUE);
}

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
        'show_email'      => 'No',
    };
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $table = Text::SimpleTable->new(15, 64);
    my $user_template;
    push(@{ $self->{'SYSOP ORDER DETAILED'} }, 'password');

    foreach my $name (@{ $self->{'SYSOP ORDER DETAILED'} }) {
        next if ($name =~ /id|fullname|_time|max_|_category/);
        if ($name eq 'timeout') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Minutes\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name eq 'baud_rate') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (300,1200,2400,4800,9600,FULL)\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /username|given|family|password/) {
            if ($name eq 'given') {
                $table->row("$name (first)", ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            } elsif ($name eq 'family') {
                $table->row("$name (last)", ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            } else {
                $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            }
        } elsif ($name eq 'text_mode') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (ASCII,ATASCII,PETSCII,ANSI)\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name eq 'birthday') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " YEAR-MM-DD\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/) {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (Yes/No or On/Off or 1/0)\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /location|retro_systems|accomplishments/) {
            $table->row($name, "\n" . $self->{'ansi_characters'}->{'OVERLINE'} x ($self->{'SYSOP HEADING WIDTHS'}->{$name} * 4));
        } else {
            $table->row($name, "\n" . $self->{'ansi_characters'}->{'OVERLINE'} x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        }
        $user_template->{$name} = undef;
    }
    print $table->boxes->draw();
    $self->sysop_show_choices($mapping);
    my $column     = 21;
    my $adjustment = 7;
    foreach my $entry (@{ $self->{'SYSOP ORDER DETAILED'} }) {
        next if ($entry =~ /id|fullname|_time/);
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
                }
                print locate($row + $adjustment, $column), $user_template->{$entry};
            } elsif ($entry =~ /prefer_|_files|_message|sysop/) {
                $user_template->{$entry} = ucfirst($user_template->{$entry});
                print locate($row + $adjustment, $column), $user_template->{$entry};
            }
        } until ($self->sysop_validate_fields($entry, $user_template->{$entry}, $row + $adjustment, $column));
        if ($user_template->{$entry} =~ /^(yes|on|true)$/i) {
            $user_template->{$entry} = TRUE;
        } elsif ($user_template->{$entry} =~ /^(no|off|false)$/i) {
            $user_template->{$entry} = FALSE;
        }
        $adjustment += 2;
    }
    pop(@{ $self->{'SYSOP ORDER DETAILED'} });
    if ($self->users_add($user_template)) {
        print "\n\n", colored(['green'], 'SUCCESS'), "\n";
		$self->{'debug'}->DEBUG(['sysop_user_add end']);
        return (TRUE);
    }
    return (FALSE);
}

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
}

sub sysop_validate_fields {
    my $self   = shift;
    my $name   = shift;
    my $val    = shift;
    my $row    = shift;
    my $column = shift;

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
		$self->{'debug'}->DEBUG(['sysop_validate_fields end']);
        return (FALSE);
    }
    return (TRUE);
}

sub sysop_prompt {
    my $self     = shift;
    my $text     = shift;

    my $response = $text . ' [% PINK %]' . $self->{'ansi_characters'}->{'BLACK RIGHTWARDS ARROWHEAD'} . '[% RESET %] ';
    return ($self->sysop_detokenize($response));
}

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    # OPERATION TOKENS
    foreach my $key (keys %{ $self->{'sysop_tokens'} }) {
        my $ch = '';
        if (ref($self->{'sysop_tokens'}->{$key}) eq 'CODE') {
            $ch = $self->{'sysop_tokens'}->{$key}->($self);
        } else {
            $ch = $self->{'sysop_tokens'}->{$key};
        }
        $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
    }

    # ANSI TOKENS
    foreach my $name (keys %{ $self->{'ansi_sequences'} }) {
        my $ch = $self->{'ansi_sequences'}->{$name};
        if ($name eq 'CLEAR') {
            $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
        }
        $text =~ s/\[\%\s+$name\s+\%\]/$ch/sgi;
    }

    # SPECIAL CHARACTERS
    foreach my $char (keys %{ $self->{'ansi_characters'} }) {
        my $ch = $self->{'ansi_characters'}->{$char};
        $text =~ s/\[\%\s+$char\s+\%\]/$ch/sgi;
    }

    return ($text);
}

sub sysop_menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

    my $response;
    if ($choice eq 'TOP') {
        $response = $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC DOWN AND RIGHT'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT HORIZONTAL'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC DOWN AND LEFT'} . "\n";
    } elsif ($choice eq 'BOTTOM') {
        $response = $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC UP AND RIGHT'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT HORIZONTAL'} . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT ARC UP AND LEFT'} . "\n";
    } else {
        $response = $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT VERTICAL'} . colored(["BOLD $color"], $choice) . $self->{'ansi_characters'}->{'BOX DRAWINGS LIGHT VERTICAL'} . ' ' . colored([$color], $self->{'ansi_characters'}->{'BLACK RIGHT-POINTING TRIANGLE'}) . ' ' . $desc . "\n";
    }
    return ($response);
}

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
            }
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
    }
    return ($text);
}

sub sysop_scroll {
    my $self = shift;

    print "Scroll?  ";
    if ($self->sysop_keypress(ECHO, BLOCKING) =~ /N/i) {
		$self->{'debug'}->DEBUG(['sysop_scroll end']);
        return (FALSE);
    }
    print "\r" . clline;
    return (TRUE);
}

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
    }
    my $table = Text::SimpleTable->new($id_size, $name_size, $hostname_size, 5, $poster_size);
    $table->row('ID', 'NAME', 'HOSTNAME', 'PORT', 'POSTER');
    $table->hr();
    foreach my $line (@listing) {
        $table->row($line->{'bbs_id'}, $line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
    }
    print $table->boxes->draw();
    print 'Press a key to continue... ';
    $self->sysop_keypress();
}

sub sysop_edit_bbs {
    my $self = shift;

    my @choices = (qw( bbs_id bbs_name bbs_hostname bbs_port ));
    print $self->prompt('Please enter the ID, the hostname, or the BBS name to edit');
    my $search;
    $search = $self->sysop_get_line(ECHO,50);
    return (FALSE) if ($search eq '');
    print "\r", cldown, "\n";
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
    $sth->execute($search, $search, $search);

    if ($sth->rows() > 0) {
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
        }
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
        my $new   = $self->sysop_get_line(ECHO,$width);
		if ($new eq '') {
			$self->{'debug'}->DEBUG(['sysop_edit_bbs end']);
			return (FALSE);
		}
        $sth = $self->{'dbh'}->prepare('UPDATE bbs_listing SET ' . $choices[$choice] . '=? WHERE bbs_id=?');
        $sth->execute($new, $bbs->{'bbs_id'});
        $sth->finish();
    } else {
        $sth->finish();
    }
}

sub sysop_add_bbs {
    my $self = shift;

    my $table = Text::SimpleTable->new(12, 50);
    foreach my $name (qw(bbs_name bbs_hostname bbs_port)) {
        my $count = ($name eq 'bbs_port') ? 5 : 50;
        $table->row($name, "\n" . $self->{'ansi_characters'}->{'OVERLINE'} x $count);
        $table->hr() unless ($name eq 'bbs_port');
    }
    my @order = (qw(bbs_name bbs_hostname bbs_port));
    my $bbs   = {
        'bbs_name'     => '',
        'bbs_hostname' => '',
        'bbs_port'     => '',
    };
    my $index = 0;
    print $table->boxes->draw();
    print $self->{'ansi_sequences'}->{'UP'} x 9, $self->{'ansi_sequences'}->{'RIGHT'} x 17;
    $bbs->{'bbs_name'} = $self->sysop_get_line(ECHO,50);
    if ($bbs->{'bbs_name'} ne '' && length($bbs->{'bbs_name'}) > 3) {
        print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 17;
        $bbs->{'bbs_hostname'} = $self->sysop_get_line(ECHO,50);
        if ($bbs->{'bbs_hostname'} ne '' && length($bbs->{'bbs_hostname'}) > 5) {
            print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 17;
            $bbs->{'bbs_port'} = $self->sysop_get_line(ECHO,5);
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
}

sub sysop_delete_bbs {
    my $self = shift;

    print $self->prompt('Please enter the ID, the hostname, or the BBS name to delete');
    my $search;
    $search = $self->sysop_get_line(ECHO,50);
	if ($search eq '') {
		return (FALSE);
	}
    print "\r", cldown, "\n";
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
    $sth->execute($search, $search, $search);

    if ($sth->rows() > 0) {
        my $bbs = $sth->fetchrow_hashref();
        $sth->finish();
        my $table = Text::SimpleTable->new(12, 50);
        $table->row('FIELD NAME', 'VALUE');
        $table->hr();
        foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port)) {
            $table->row($name, $bbs->{$name});
        }
        print $table->boxes->draw();
        print 'Are you sure that you want to delete this BBS from the list (Y|N)?  ';
        my $choice = $self->sysop_decision();
        unless ($choice) {
            return (FALSE);
        }
        $sth = $self->{'dbh'}->prepare('DELETE FROM bbs_listing WHERE bbs_id=?');
        $sth->execute($bbs->{'bbs_id'});
    }
    $sth->finish();
    return (TRUE);
}

 

# package BBS::Universal::Text_Editor;

sub text_editor_initialize {
	my $self = shift;

	return ($self);
}

sub text_editor_edit {
	my $self = shift;
}

 

# package BBS::Universal::Users;

sub users_initialize {
    my $self = shift;

    $self->{'USER'}->{'mode'} = ASCII;
    return ($self);
}

sub users_change_access_level {
	my $self = shift;

	my $mapping = {
		'TEXT' => '',
		'Z' => {
			'command'      => 'BACK',
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => 'Back to Account menu',
		},
	};
	foreach my $result (keys %{$self->{'access_levels'}}) {
		if (($self->{'access_levels'}->{$result} < $self->{'access_levels'}->{$self->{'USER'}->{'access_level'}}) || $self->{'USER'}->{'access_level'} eq 'SYSOP') {
			$mapping->{chr(65 + $self->{'access_levels'}->{$result})} = {
				'command'      => $result,
				'color'        => 'WHITE',
				'access_level' => $self->{'USER'}->{'access_level'},
				'text'         => $result,
			};
		}
	}

	$self->show_choices($mapping);
	my $mode = $self->{'USER'}->{'text_mode'};
	if ($mode eq 'ANSI') {
		$self->output("\n" . $self->prompt('(' . colored(['bright_yellow'],$self->{'USER'}->{'username'}) . ') ' . 'Choose'));
	} elsif ($mode eq 'ATASCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} elsif ($mode eq 'PETSCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} else {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	}
	my $key;
	do {
		$key = uc($self->get_key(SILENT, FALSE));
	} until (exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	$self->output($mapping->{$key}->{'command'} . "\n");
	unless ($key eq 'Z' || $key eq chr(3)) {
		my $command = $mapping->{$key}->{'command'};
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET date_format=? WHERE id=?');
		$sth->execute($command,$self->{'USER'}->{'id'});
		$sth->finish;
		$self->{'USER'}->{'date_format'} = $command;
	}
    return (TRUE);
}

sub users_change_date_format {
	my $self = shift;

	my $mapping = {
		'TEXT' => '',
		'Z' => {
			'command'      => 'BACK',
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => 'Back to Account menu',
		},
	};
	my $count = 1;
	foreach my $result ('YEAR/MONTH/DAY','MONTH/DAY/YEAR','DAY/MONTH/YEAR') {
		$mapping->{chr(64 + $count)} = {
			'command'      => $result,
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => $result,
		};
		$count++;
	}

	$self->show_choices($mapping);
	my $mode = $self->{'USER'}->{'text_mode'};
	if ($mode eq 'ANSI') {
		$self->output("\n" . $self->prompt('(' . colored(['bright_yellow'],$self->{'USER'}->{'username'}) . ') ' . 'Choose'));
	} elsif ($mode eq 'ATASCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} elsif ($mode eq 'PETSCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} else {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	}
	my $key;
	do {
		$key = uc($self->get_key(SILENT, FALSE));
	} until (exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	$self->output($mapping->{$key}->{'command'} . "\n");
	unless ($key eq 'Z' || $key eq chr(3)) {
		my $command = $mapping->{$key}->{'command'};
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET date_format=? WHERE id=?');
		$sth->execute($command,$self->{'USER'}->{'id'});
		$sth->finish;
		$self->{'USER'}->{'date_format'} = $command;
	}
    return (TRUE);
}

sub users_change_baud_rate {
	my $self = shift;

	my $mapping = {
		'TEXT' => '',
		'Z' => {
			'command' => 'BACK',
			'color'   => 'WHITE',
			'access_level' => 'USER',
			'text'    => 'Back to Account menu',
		},
	};
	my $count = 1;
	foreach my $result (qw(300 1200 2400 4800 9600 19200 FULL)) {
		$mapping->{chr(64 + $count)} = {
			'command' => $result,
			'color'   => 'WHITE',
			'access_level' => 'USER',
			'text'    => $result,
		};
		$count++;
	}

	$self->show_choices($mapping);
	my $mode = $self->{'USER'}->{'text_mode'};
	if ($mode eq 'ANSI') {
		$self->output("\n" . $self->prompt('(' . colored(['bright_yellow'],$self->{'USER'}->{'username'}) . ') ' . 'Choose'));
	} elsif ($mode eq 'ATASCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} elsif ($mode eq 'PETSCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} else {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	}
	my $key;
	do {
		$key = uc($self->get_key(SILENT, FALSE));
	} until (exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	$self->output($mapping->{$key}->{'command'} . "\n");
	unless ($key eq 'Z' || $key eq chr(3)) {
		my $command = $mapping->{$key}->{'command'};
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET baud_rate=? WHERE id=?');
		$sth->execute($command,$self->{'USER'}->{'id'});
		$sth->finish;
		$self->{'USER'}->{'baud_rate'} = $command;
	}
    return (TRUE);
}

sub users_change_screen_size {
    my $self = shift;

	$self->output($self->prompt("\nColumns"));
	my $columns = 0 + $self->get_line(NUMERIC,3,$self->{'USER'}->{'max_columns'});
	if ($columns >= 32 && $columns ne $self->{'USER'}->{'max_columns'} && $self->is_connected()) {
		$self->{'USER'}->{'max_columns'} = $columns;
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET max_columns=? WHERE id=?');
		$sth->execute($columns,$self->{'USER'}->{'id'});
		$sth->finish;
	}
	$self->output($self->prompt("\nRows"));
	my $rows = 0 + $self->get_line(NUMERIC,3,$self->{'USER'}->{'max_rows'});
	if ($rows >= 25 && $rows ne $self->{'USER'}->{'max_rows'} && $self->is_connected()) {
		$self->{'USER'}->{'max_rows'} = $rows;
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET max_rows=? WHERE id=?');
		$sth->execute($rows,$self->{'USER'}->{'id'});
		$sth->finish;
	}
    return (TRUE);
}

sub users_update_retro_systems {
    my $self = shift;

	$self->output($self->prompt("\nName your retro computers"));
	my $retro = $self->get_line(ECHO,65535,$self->{'USER'}->{'retro_systems'});
	if (length($retro) >= 5 && $retro ne $self->{'USER'}->{'retro_systems'} && $self->is_connected()) {
		$self->{'USER'}->{'retro_systems'} = $retro;
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET retro_systems=? WHERE id=?');
		$sth->execute($retro,$self->{'USER'}->{'id'});
		$sth->finish;
	}
    return (TRUE);
}

sub users_update_email {
    my $self = shift;

	$self->output($self->prompt("\nEnter email address"));
	my $email = $self->get_line(ECHO,255,$self->{'USER'}->{'email'});
	if (length($email) > 5 && $email ne $self->{'USER'}->{'email'} && $self->is_connected()) {
		$self->{'USER'}->{'email'} = $email;
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET email=? WHERE id=?');
		$sth->execute($email,$self->{'USER'}->{'id'});
		$sth->finish;
	}
    return (TRUE);
}

sub users_toggle_permission {
    my $self  = shift;
    my $field = shift;

    if (0 + $self->{'USER'}->{$field}) {
        $self->{'USER'}->{$field} = FALSE;
    } else {
        $self->{'USER'}->{$field} = TRUE;
    }
    my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . $field . '=? WHERE id=?');
    $sth->execute($self->{'USER'}->{$field}, $self->{'USER'}->{'id'});
    $self->{'dbh'}->commit;
    $sth->finish();
    return (TRUE);
}

sub users_update_location {
    my $self = shift;

	$self->output($self->prompt("\nEnter your location"));
	my $location = $self->get_line(ECHO,255,$self->{'USER'}->{'location'});
	if (length($location) >= 4 && $location ne $self->{'USER'}->{'location'} && $self->is_connected()) {
		$self->{'USER'}->{'location'} = $location;
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET location=? WHERE id=?');
		$sth->execute($location,$self->{'USER'}->{'id'});
		$sth->finish;
	}
    return (TRUE);
}

sub users_update_accomplishments {
    my $self = shift;

	$self->output($self->prompt("\nEnter your accomplishments"));
	my $accomplishments = $self->get_line(ECHO,255,$self->{'USER'}->{'accomplishments'});
	if (length($accomplishments) >= 4 && $accomplishments ne $self->{'USER'}->{'accomplishments'} && $self->is_connected()) {
		$self->{'USER'}->{'accomplishments'} = $accomplishments;
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET accomplishments=? WHERE id=?');
		$sth->execute($accomplishments,$self->{'USER'}->{'id'});
		$sth->finish;
	}
    return (TRUE);
}

sub users_update_text_mode {
    my $self = shift;

	my $mapping = {
		'TEXT' => '',
		'Z' => {
			'command' => 'BACK',
			'color'   => 'WHITE',
			'access_level' => 'USER',
			'text'    => 'Back to Account menu',
		},
	};
	my $sth = $self->{'dbh'}->prepare('SELECT * FROM text_modes ORDER BY text_mode');
	$sth->execute();
	my $count = 1;
	while(my $result = $sth->fetchrow_hashref()) {
		$mapping->{chr(64 + $count)} = {
			'command' => $result->{'text_mode'},
			'color'   => 'WHITE',
			'access_level' => 'USER',
			'text'    => $result->{'text_mode'},
		};
		$count++;
	}
	$sth->finish();

	$self->show_choices($mapping);
	my $mode = $self->{'USER'}->{'text_mode'};
	if ($mode eq 'ANSI') {
		$self->output("\n" . $self->prompt('(' . colored(['bright_yellow'],$self->{'USER'}->{'username'}) . ') ' . 'Choose'));
	} elsif ($mode eq 'ATASCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} elsif ($mode eq 'PETSCII') {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	} else {
		$self->output("\n" . $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose'));
	}
	my $key;
	do {
		$key = uc($self->get_key(SILENT, FALSE));
	} until (exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	$self->output($mapping->{$key}->{'command'} . "\n");
	unless ($key eq 'Z' || $key eq chr(3)) {
		my $command = $mapping->{$key}->{'command'};
		my $sth = $self->{'dbh'}->prepare('UPDATE users SET text_mode=? WHERE id=?');
		$sth->execute($command,$self->{'USER'}->{'id'});
		$sth->finish;
		$self->{'USER'}->{'text_mode'} = $command;
	}
    return (TRUE);
}

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
        $self->{'USER'} = $results;
        delete($self->{'USER'}->{'password'});
        foreach my $field (    # For numeric values
            qw(
            show_email
            prefer_nickname
            view_files
            upload_files
            download_files
            remove_files
            read_message
            post_message
            remove_message
            page_sysop
            )
        ) {
            $self->{'USER'}->{$field} = 0 + $self->{'USER'}->{$field};
        }
        return (TRUE);
    }
    return (FALSE);
}

sub users_get_date {
	my $self     = shift;
	my $old_date = shift;

	if ($old_date =~ / /) {
		my $time;
		($old_date,$time) = split(/ /,$old_date);
		my ($year,$month,$day) = split(/-/,$old_date);
		my $date = $self->{'USER'}->{'date_format'};
		$date =~ s/YEAR/$year/;
		$date =~ s/MONTH/$month/;
		$date =~ s/DAY/$day/;
		return("$date $time");
	} else {
		my ($year,$month,$day) = split(/-/,$old_date);
		my $date = $self->{'USER'}->{'date_format'};
		$date =~ s/YEAR/$year/;
		$date =~ s/MONTH/$month/;
		$date =~ s/DAY/$day/;
		return($date);
	}
}

sub users_list {
    my $self = shift;

    $self->{'dbh'}->begin_work;

    my $sth = $self->{'dbh'}->prepare(
        q{
			SELECT
			  username,
			  given,
			  family,
			  nickname,
			  accomplishments,
			  retro_systems,
			  birthday,
			  location
			  FROM users_view
			  ORDER BY username;
		}
    );
    $sth->execute();
    my $columns = $self->{'USER'}->{'max_columns'};
    my $table;
    if ($columns <= 40) {    # Username and Fullname
        $table = Text::SimpleTable->new(10, 36);
        $table->row('USERNAME', 'FULLNAME');
    } elsif ($columns <= 64) {    # Username, Nickname and Fullname
        $table = Text::SimpleTable->new(10, 20, 32);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME');
    } elsif ($columns <= 80) {    # Username, Nickname, Fullname and Location
        $table = Text::SimpleTable->new(10, 20, 32, 32);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION');
    } elsif ($columns <= 132) {    # Username, Nickname, Fullname, Location, Retro Systems
        $table = Text::SimpleTable->new(10, 20, 30, 30, 40);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS');
    } else {                       # Username, Nickname, Fullname, Location, Retro Systems, Birthday and Accomplishments
        $table = Text::SimpleTable->new(10, 20, 32, 32, 40, 5, 100);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS', 'BDAY', 'ACCOMPLISHMENTS');
    }
    while (my $results = $sth->fetchrow_hashref()) {
        $table->hr;
        if ($columns <= 40) {      # Username and Fullname
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-36s', $results->{'given'} . ' ' . $results->{'family'}));
        } elsif ($columns <= 64) {    # Username, Nickname and Fullname
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-32s', $results->{'given'} . ' ' . $results->{'family'}));
        } elsif ($columns <= 80) {    # Username, Nickname, Fullname and Location
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-32s', $results->{'given'} . ' ' . $results->{'family'}), sprintf('%-32s', $results->{'location'}));
        } elsif ($columns <= 132) {    # Username, Nickname, Fullname, Location, Retro Systems
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-30s', $results->{'given'} . ' ' . $results->{'family'}), sprintf('%-30s', $results->{'location'}), sprintf('%-40s', $results->{'retro_systems'}));
        } else {                       # Username, Nickname, Fullname, Location, Retro Systems, Birthday and Accomplishments
            my ($year, $month, $day) = split('-', $results->{'birthday'});
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-32s', $results->{'given'} . ' ' . $results->{'family'}), sprintf('%-32s', $results->{'location'}), sprintf('%-40s', $results->{'retro_systems'}), sprintf('%02d/%02d', $month, $day), sprintf('%-100s', $results->{'accomplishments'}));
        }
    }
    $sth->finish;
    my $text;
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $text = $table->boxes->draw();
        foreach my $orig ('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS', 'BDAY', 'ACCOMPLISHMENTS') {
            my $ch = colored(['bright_yellow'], $orig);
            $text =~ s/$orig/$ch/gs;
        }
    } else {
        $text = $table->draw();
    }
    return ($text);
}

sub users_add {
    my $self          = shift;
    my $user_template = shift;

    $self->{'dbh'}->begin_work;
    my $sth = $self->{'dbh'}->prepare(
        q{
			INSERT INTO users (
				username,
				given,
				family,
				nickname,
                email,
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
    $sth->execute($user_template->{'username'}, $user_template->{'given'}, $user_template->{'family'}, $user_template->{'nickname'}, $user_template->{'email'}, $user_template->{'accomplishments'}, $user_template->{'retro_systems'}, $user_template->{'birthday'}, $user_template->{'location'}, $user_template->{'baud_rate'}, $user_template->{'text_mode'}, $user_template->{'password'});
	$sth->finish;
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
                show_email,
				post_message,
				remove_message,
				sysop,
				page_sysop,
				timeout)
			  VALUES (LAST_INSERT_ID(),?,?,?,?,?,?,?,?,?,?,?);
		}
    );
    $sth->execute($user_template->{'prefer_nickname'}, $user_template->{'view_files'}, $user_template->{'upload_files'}, $user_template->{'download_files'}, $user_template->{'remove_files'}, $user_template->{'read_message'}, $user_template->{'show_email'}, $user_template->{'post_message'}, $user_template->{'remove_message'}, $user_template->{'sysop'}, $user_template->{'page_sysop'}, $user_template->{'timeout'});

    if ($self->{'dbh'}->err) {
        $self->{'dbh'}->rollback;
        $sth->finish();
        return (FALSE);
    } else {
        $self->{'dbh'}->commit;
        $sth->finish();
        return (TRUE);
    }
}

sub users_delete {
    my $self = shift;
    my $id   = shift;

    $self->{'debug'}->WARNING(["Delete user $id"]);
    $self->{'dbh'}->begin_work();
    my $sth = $self->{'dbh'}->prepare('DELETE FROM permissions WHERE id=?');
    $sth->execute($id);
    if ($self->{'dbh'}->err) {
        $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
        $self->{'dbh'}->rollback();
        $sth->finish();
        return (FALSE);
    } else {
        $sth->finish();
        $sth = $self->{'dbh'}->prepare('DELETE FROM users WHERE id=?');
        $sth->execute($id);
        if ($self->{'dbh'}->err) {
            $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
            $self->{'dbh'}->rollback();
            $sth->finish();
            return (FALSE);
        } else {
            $self->{'dbh'}->commit();
            $sth->finish();
            return (TRUE);
        }
    }
}

sub users_file_category {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'file_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    return ($category);
}

sub users_forum_category {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT name FROM message_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'forum_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    return ($category);
}

sub users_find {
    my $self = shift;
	return(TRUE);
}

sub users_count {
    my $self = shift;
    return (0);
}

sub users_info {
    my $self = shift;

    my $table;
    my $text  = '';
    my $width = 1;

    foreach my $field (keys %{ $self->{'USER'} }) {
        $width = max($width, length($self->{'USER'}->{$field}));
    }

	if ($self->{'USER'}->{'max_columns'} <= 40) {
		$table = sprintf('%-15s=%-25s','FIELD','VALUE') . "\n";
		$table .= '-' x $self->{'USER'}->{'max_columns'} . "\n";
		$table .= sprintf('%-15s=%-25s','ACCOUNT NUMBER', $self->{'USER'}->{'id'}) . "\n";
		$table .= sprintf('%-15s=%-25s','USERNAME', $self->{'USER'}->{'username'}) . "\n";
		$table .= sprintf('%-15s=%-25s','FULL NAME', $self->{'USER'}->{'fullname'}) . "\n";
		$table .= sprintf('%-15s=%-25s','NICKNAME', $self->{'USER'}->{'nickname'}) . "\n";
		$table .= sprintf('%-15s=%-25s','EMAIL', $self->{'USER'}->{'email'}) . "\n";
		$table .= sprintf('%-15s=%-25s','DATE FORMAT', $self->{'USER'}->{'date_format'}) . "\n";
		$table .= sprintf('%-15s=%-25s','SCREEN', $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'}) . "\n";
		$table .= sprintf('%-15s=%-25s','BIRTHDAY', $self->users_get_date($self->{'USER'}->{'birthday'})) . "\n";
		$table .= sprintf('%-15s=%-25s','LOCATION', $self->{'USER'}->{'location'}) . "\n";
		$table .= sprintf('%-15s=%-25s','BAUD RATE', $self->{'USER'}->{'baud_rate'}) . "\n";
		$table .= sprintf('%-15s=%-25s','LAST LOGIN', $self->{'USER'}->{'login_time'}) . "\n";
		$table .= sprintf('%-15s=%-25s','LAST LOGOUT', $self->{'USER'}->{'logout_time'}) . "\n";
		$table .= sprintf('%-15s=%-25s','TEXT MODE', $self->{'USER'}->{'text_mode'}) . "\n";
		$table .= sprintf('%-15s=%-25s','IDLE TIMEOUT',    $self->{'USER'}->{'timeout'}) . "\n";
		$table .= sprintf('%-15s=%-25s','SHOW EMAIL',      $self->yes_no($self->{'USER'}->{'show_email'},      FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','PREFER NICKNAME', $self->yes_no($self->{'USER'}->{'prefer_nickname'}, FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','VIEW FILES',      $self->yes_no($self->{'USER'}->{'view_files'},      FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','UPLOAD FILES',    $self->yes_no($self->{'USER'}->{'upload_files'},    FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','DOWNLOAD FILES',  $self->yes_no($self->{'USER'}->{'download_files'},  FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','REMOVE FILES',    $self->yes_no($self->{'USER'}->{'remove_files'},    FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','READ MESSAGES',   $self->yes_no($self->{'USER'}->{'read_message'},    FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','POST MESSAGES',   $self->yes_no($self->{'USER'}->{'post_message'},    FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','REMOVE MESSAGES', $self->yes_no($self->{'USER'}->{'remove_message'},  FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','PLAY FORTUNES',   $self->yes_no($self->{'USER'}->{'play_fortunes'},   FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','PAGE SYSOP',      $self->yes_no($self->{'USER'}->{'page_sysop'},      FALSE)) . "\n";
		$table .= sprintf('%-15s=%-25s','ACCESS LEVEL',    $self->{'USER'}->{'access_level'}) . "\n";
		$table .= sprintf('%-15s=%-25s','RETRO SYSTEMS',   $self->{'USER'}->{'retro_systems'}) . "\n";
		$table .= sprintf('%-15s=%-25s','ACCOMPLISHMENTS', $self->{'USER'}->{'accomplishments'}) . "\n";
    } elsif ((($width + 22) * 2) <= $self->{'USER'}->{'max_columns'}) {
        $table = Text::SimpleTable->new(15, $width, 15, $width);
        $table->row('FIELD', 'VALUE', 'FIELD', 'VALUE');
        $table->hr();
        $table->row('ACCOUNT NUMBER',  $self->{'USER'}->{'id'},                                    'USERNAME',        $self->{'USER'}->{'username'});
        $table->row('FULLNAME',        $self->{'USER'}->{'fullname'},                              'NICKNAME',        $self->{'USER'}->{'nickname'});
        $table->row('EMAIL',           $self->{'USER'}->{'email'},                                 'SCREEN',          $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'});
        $table->row('BIRTHDAY',        $self->users_get_date($self->{'USER'}->{'birthday'}),       'LOCATION',        $self->{'USER'}->{'location'});
        $table->row('BAUD RATE',       $self->{'USER'}->{'baud_rate'},                             'LAST LOGIN',      $self->users_get_date($self->{'USER'}->{'login_time'}));
        $table->row('DATE FORMAT',     $self->{'USER'}->{'date_format'},                           'LAST LOGOUT',     $self->users_get_date($self->{'USER'}->{'logout_time'}));
        $table->row('IDLE TIMEOUT',    $self->{'USER'}->{'timeout'},                               'TEXT MODE',       $self->{'USER'}->{'text_mode'});
        $table->row('PREFER NICKNAME', $self->yes_no($self->{'USER'}->{'prefer_nickname'}, FALSE), 'VIEW FILES',      $self->yes_no($self->{'USER'}->{'view_files'}, FALSE));
        $table->row('UPLOAD FILES',    $self->yes_no($self->{'USER'}->{'upload_files'}, FALSE),    'DOWNLOAD FILES',  $self->yes_no($self->{'USER'}->{'download_files'}, FALSE));
        $table->row('REMOVE FILES',    $self->yes_no($self->{'USER'}->{'remove_files'}, FALSE),    'READ MESSAGES',   $self->yes_no($self->{'USER'}->{'read_message'}, FALSE));
        $table->row('POST MESSAGES',   $self->yes_no($self->{'USER'}->{'post_message'}, FALSE),    'REMOVE MESSAGES', $self->yes_no($self->{'USER'}->{'remove_message'}, FALSE));
        $table->row('PAGE SYSOP',      $self->yes_no($self->{'USER'}->{'page_sysop'}, FALSE),      'SHOW EMAIL',      $self->yes_no($self->{'USER'}->{'show_email'}, FALSE));
		$table->row('ACCESS LEVEL',    $self->{'USER'}->{'access_level'},                          'PLAY FORTUNES',   $self->yes_no($self->{'USER'}->{'play_fortunes'},   FALSE));
        $table->row('ACCOMPLISHMENTS', $self->{'USER'}->{'accomplishments'},                       'RETRO SYSTEMS',   $self->{'USER'}->{'retro_systems'});
    } else {
        $width = min($width + 7, $self->{'USER'}->{'max_columns'} - 7);
        $table = Text::SimpleTable->new(15, $width);
        $table->row('FIELD', 'VALUE');
        $table->hr();
        $table->row('ACCOUNT NUMBER',  $self->{'USER'}->{'id'});
        $table->row('USERNAME',        $self->{'USER'}->{'username'});
        $table->row('FULLNAME',        $self->{'USER'}->{'fullname'});
        $table->row('NICKNAME',        $self->{'USER'}->{'nickname'});
        $table->row('EMAIL',           $self->{'USER'}->{'email'});
		$table->row('DATE FORMAT',     $self->{'USER'}->{'date_format'});
        $table->row('SCREEN',          $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'});
        $table->row('BIRTHDAY',        $self->users_get_date($self->{'USER'}->{'birthday'}));
        $table->row('LOCATION',        $self->{'USER'}->{'location'});
        $table->row('BAUD RATE',       $self->{'USER'}->{'baud_rate'});
        $table->row('LAST LOGIN',      $self->{'USER'}->{'login_time'});
        $table->row('LAST LOGOUT',     $self->{'USER'}->{'logout_time'});
        $table->row('TEXT MODE',       $self->{'USER'}->{'text_mode'});
        $table->row('IDLE TIMEOUT',    $self->{'USER'}->{'timeout'});
        $table->row('SHOW EMAIL',      $self->yes_no($self->{'USER'}->{'show_email'},      FALSE));
        $table->row('PREFER NICKNAME', $self->yes_no($self->{'USER'}->{'prefer_nickname'}, FALSE));
        $table->row('VIEW FILES',      $self->yes_no($self->{'USER'}->{'view_files'},      FALSE));
        $table->row('UPLOAD FILES',    $self->yes_no($self->{'USER'}->{'upload_files'},    FALSE));
        $table->row('DOWNLOAD FILES',  $self->yes_no($self->{'USER'}->{'download_files'},  FALSE));
        $table->row('REMOVE FILES',    $self->yes_no($self->{'USER'}->{'remove_files'},    FALSE));
        $table->row('READ MESSAGES',   $self->yes_no($self->{'USER'}->{'read_message'},    FALSE));
        $table->row('POST MESSAGES',   $self->yes_no($self->{'USER'}->{'post_message'},    FALSE));
        $table->row('REMOVE MESSAGES', $self->yes_no($self->{'USER'}->{'remove_message'},  FALSE));
		$table->row('PLAY FORTUNES',   $self->yes_no($self->{'USER'}->{'play_fortunes'},   FALSE));
        $table->row('PAGE SYSOP',      $self->yes_no($self->{'USER'}->{'page_sysop'},      FALSE));
		$table->row('ACCESS LEVEL',    $self->{'USER'}->{'access_level'});
        $table->row('RETRO SYSTEMS',   $self->{'USER'}->{'retro_systems'});
        $table->row('ACCOMPLISHMENTS', $self->{'USER'}->{'accomplishments'});
    }

	if ($self->{'USER'}->{'max_columns'} <= 40) {
		$text = $table;
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $text = $table->boxes->draw();
        my $no    = colored(['red'],           'NO');
        my $yes   = colored(['green'],         'YES');
        my $field = colored(['bright_yellow'], 'FIELD');
        my $va    = colored(['bright_yellow'], 'VALUE');
        $text =~ s/ FIELD / $field /gs;
        $text =~ s/ VALUE / $va /gs;
        $text =~ s/ NO / $no /gs;
        $text =~ s/ YES / $yes /gs;

        foreach $field ('PLAY FORTUNES','ACCESS LEVEL','SUFFIX','ACCOUNT NUMBER', 'USERNAME', 'FULLNAME', 'SCREEN', 'BIRTHDAY', 'LOCATION', 'BAUD RATE', 'LAST LOGIN', 'LAST LOGOUT', 'TEXT MODE', 'IDLE TIMEOUT', 'RETRO SYSTEMS', 'ACCOMPLISHMENTS', 'SHOW EMAIL', 'PREFER NICKNAME', 'VIEW FILES', 'UPLOAD FILES', 'DOWNLOAD FILES', 'REMOVE FILES', 'READ MESSAGES', 'POST MESSAGES', 'REMOVE MESSAGES', 'PAGE SYSOP', 'EMAIL', 'NICKNAME','DATE FORMAT') {
            my $ch = colored(['cyan'], $field);
            $text =~ s/$field/$ch/gs;
        }
    } else {
        $text = $table->draw();
    }
    return ($text);
}

 

1;
