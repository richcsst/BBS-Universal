package BBS::Universal;

# Pragmas
use 5.010;
use strict;
no strict 'subs';
no warnings;

# use Carp::Always;
use utf8;
use constant {
    TRUE        =>  1,
    FALSE       =>  0,
    YES         =>  1,
    NO          =>  0,
    BLOCKING    =>  1,
    NONBLOCKING =>  0,
    PASSWORD    => -1,
    SILENT      =>  0,
    ECHO        =>  1,
    STRING      =>  1,
    NUMERIC     =>  2,
    RADIO       =>  3,
    TOGGLE      =>  4,
    HOST        =>  5,
    DATE        =>  6,

    ASCII   => 0,
    ATASCII => 1,
    PETSCII => 2,
    ANSI    => 3,

    LINEMODE => 34,

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

    PI => (4 * atan2(1, 1)),
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
use Number::Format 'format_number';
use XML::RSS::LibXML;

# The overhead of pulling these into the BBS::Universal namespace was a nightmare, so I just pulled them into the source at build time
# use BBS::Universal::ANSI;
# use BBS::Universal::ASCII;
# use BBS::Universal::ATASCII;
# use BBS::Universal::PETSCII;
# use BBS::Universal::BBS_List;
# use BBS::Universal::CPU;
# use BBS::Universal::DB;
# use BBS::Universal::FileTransfer;
# use BBS::Universal::Messages;
# use BBS::Universal::News;
# use BBS::Universal::SysOp;
# use BBS::Universal::Text_Editor;
# use BBS::Universal::Users;

BEGIN {
    require Exporter;

    our $VERSION = '0.013';
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

        our $ANSI_VERSION = '0.007';
    our $ASCII_VERSION = '0.003';
    our $ATASCII_VERSION = '0.005';
    our $BBS_LIST_VERSION = '0.002';
    our $CPU_VERSION = '0.002';
    our $DB_VERSION = '0.002';
    our $FILETRANSFER_VERSION = '0.003';
    our $MESSAGES_VERSION = '0.002';
    our $NEWS_VERSION = '0.003';
    our $PETSCII_VERSION = '0.004';
    our $SYSOP_VERSION = '0.009';
    our $TEXT_EDITOR_VERSION = '0.001';
    our $USERS_VERSION = '0.003';
} ## end BEGIN

sub DESTROY {
    my $self = shift;

    $self->{'dbh'}->disconnect();
}

sub small_new {
    my $class = shift;
    my $self  = shift;

    bless($self, $class);
    $self->{'debug'}->DEBUG(['Start Small New']);
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
    $self->{'sysop'}      = TRUE;
    $self->{'local_mode'} = TRUE;
    $self->{'debug'}->DEBUG(['End Small New']);
    return ($self);
} ## end sub small_new

sub new {    # Always call with the socket as a parameter
    my $class = shift;

    my $params    = shift;
    my $socket    = (exists($params->{'socket'}))        ? $params->{'socket'}        : undef;
    my $cl_socket = (exists($params->{'client_socket'})) ? $params->{'client_socket'} : undef;
    my $lmode     = (exists($params->{'local_mode'}))    ? $params->{'local_mode'}    : FALSE;

    $params->{'debug'}->DEBUG(['Start New']);
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
        'suffixes'        => [qw( ASCII ATASCII PETSCII ANSI )],
        'host'            => undef,
        'port'            => undef,
        'access_levels'   => {
            'USER'         => 0,
            'VETERAN'      => 1,
            'JUNIOR SYSOP' => 2,
            'SYSOP'        => 65535,
        },
        'telnet_commands' => ['SE (Subnegotiation end)', 'NOP (No operation)', 'Data Mark', 'Break', 'Interrupt Process', 'Abort output', 'Are you there?', 'Erase character', 'Erase Line', 'Go ahead', 'SB (Subnegotiation begin)', 'WILL', "WON'T", 'DO', "DON'T", 'IAC',],
        'telnet_options'  => ['Binary Transmission',     'Echo', 'Reconnection', 'Suppress Go Ahead', 'Approx Message Size Negotiation', 'Status', 'Timing Mark', 'Remote Controlled Trans and Echo', 'Output Line Width', 'Output Page Size', 'Output Carriage-Return Disposition', 'Output Horizontal Tab Stops', 'Output Horizontal Tab Disposition', 'Output Formfeed Disposition', 'Output Vertical Tabstops', 'Output Vertical Tab Disposition', 'Output Linefeed Disposition', 'Extended ASCII', 'Logout', 'Byte Macro', 'Data Entry Terminal', 'RFC 1043', 'RFC 732', 'SUPDUP', 'RFC 736', 'RFC 734', 'SUPDUP Output', 'Send Location', 'Terminal Type', 'End of Record', 'TACACS User Identification', 'Output Marking', 'Terminal Location Number', 'Telnet 3270 Regime', '30X.3 PAD', 'Negotiate About Window Size', 'Terminal Speed', 'Remote Flow Control', 'Linemode', 'X Display Location', 'Environment Option', 'Authentication Option', 'Encryption Option', 'New Environment Option', 'TN3270E', 'XAUTH', 'CHARSET', 'Telnet Remote Serial Port (RSP)', 'Com Port Control Option', 'Telnet Suppress Local Echo', 'Telnet Start TLS', 'KERMIT', 'SEND-URL', 'FORWARD_',],
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
    $self->{'debug'}->DEBUG(['End New']);
    return ($self);
} ## end sub new

sub populate_common {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Populate Common']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    if (exists($ENV{'EDITOR'})) {
        $self->{'EDITOR'} = $ENV{'EDITOR'};
    } else {
        foreach my $editor ('/usr/bin/jed', '/usr/local/bin/jed', '/usr/bin/nano', '/usr/local/bin/nano', '/usr/bin/vim', '/usr/local/bin/vim', '/usr/bin/ed', '/usr/local/bin/ed') {
            if (-e $editor) {
                $self->{'EDITOR'} = $editor;
                last;
            }
        } ## end foreach my $editor ('/usr/bin/jed'...)
    } ## end else [ if (exists($ENV{'EDITOR'...}))]
    $self->{'debug'}->DEBUGMAX(['EDITOR: ' . $self->{'EDITOR'}]);
    $self->{'CPU'}  = $self->cpu_info();
    $self->{'CONF'} = $self->configuration();
    if (exists($self->{'CONF'}->{'EDITOR'})) {    # Configuration override
        $self->{'EDITOR'} = $self->{'CONF'}->{'EDITOR'};
    } else {
        $self->configuration('EDITOR', $self->{'EDITOR'});
    }
    $self->{'VERSIONS'} = $self->parse_versions();
    $self->{'USER'}     = {
        'text_mode'   => $self->{'CONF'}->{'DEFAULT TEXT MODE'},
        'max_columns' => $wsize,
        'max_rows'    => $hsize - 7,
    };
    $self->{'debug'}->DEBUG(['Initializing all libraries']);
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
    $self->{'debug'}->DEBUG(['Libraries initialized']);
    chomp(my $os = `uname -a`);
    $self->{'SPEEDS'} = {    # This depends on the granularity of Time::HiRes
        'FULL'  => 0,
        '300'   => 0.02,
        '600'   => 0.01,
        '1200'  => 0.005,
        '2400'  => 0.0025,
        '4800'  => 0.00125,
        '9600'  => 0.000625,
        '19200' => 0.0003125,
    };

    $self->{'FORTUNE'} = (-e '/usr/bin/fortune' || -e '/usr/local/bin/fortune') ? TRUE : FALSE;
    $self->{'TOKENS'}  = {
        'CPU IDENTITY' => $self->{'CPU'}->{'CPU IDENTITY'},
        'CPU CORES'    => $self->{'CPU'}->{'CPU CORES'},
        'CPU SPEED'    => $self->{'CPU'}->{'CPU SPEED'},
        'CPU THREADS'  => $self->{'CPU'}->{'CPU THREADS'},
        'OS'           => $os,
        'PERL VERSION' => $self->{'VERSIONS'}->{'Perl'},
        'BBS VERSION'  => $self->{'VERSIONS'}->{'BBS Executable'},
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
            return ($self->get_fortune);
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
        'RSS CATEGORY' => sub {
            my $self = shift;
            return ($self->users_rss_category());
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
        'USERS COUNT' => sub {
            my $self = shift;
            return ($self->users_count());
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
            $self->{'debug'}->DEBUG(["Get Uptime $uptime"]);
            return ($uptime);
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
        'SHOW FULL BBS LIST' => sub {
            my $self = shift;
            $self->bbs_list(FALSE);
            return($self->load_menu('files/main/bbs_listing'));
        },
        'SEARCH BBS LIST' => sub {
            my $self = shift;
            $self->bbs_list(TRUE);
            return($self->load_menu('files/main/bbs_listing'));
        },
        'RSS FEEDS' => sub {
            my $self = shift;
            $self->news_rss_feeds();
            return($self->load_menu('files/main/news'));
        },
        'UPDATE ACCOMPLISHMENTS' => sub {
            my $self = shift;
            $self->users_update_accomplishments();
            return ($self->load_menu('files/main/account'));
        },
        'RSS CATEGORIES' => sub {
            my $self = shift;
            $self->news_rss_categories();
            return($self->load_menu('files/main/news'));
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
            return ($self->load_menu('files/main/account'));
        },
        'CHANGE BAUD RATE' => sub {
            my $self = shift;
            $self->users_change_baud_rate();
            return ($self->load_menu('files/main/account'));
        },
        'CHANGE DATE FORMAT' => sub {
            my $self = shift;
            $self->users_change_date_format();
            return ($self->load_menu('files/main/account'));
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
            return ($self->load_menu('files/main/list_users'));
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
    $self->{'debug'}->DEBUG(['End Populate Common']);
} ## end sub populate_common

sub run {
    my $self  = shift;
    my $sysop = shift;

    $self->{'debug'}->DEBUG(['Start Run']);
    $self->{'sysop'} = $sysop;
    $self->{'ERROR'} = undef;

    unless ($self->{'sysop'} || $self->{'local_mode'}) {
        my $handle = $self->{'cl_socket'};
        print $handle chr(IAC) . chr(WONT) . chr(LINEMODE);
    }
    $| = 1;
    $self->greeting();
    if ($self->login()) {
        $self->main_menu('files/main/menu');
    }
    $self->disconnect();
    $self->{'debug'}->DEBUG(['End Run']);
    return (defined($self->{'ERROR'}));
} ## end sub run

sub greeting {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Greeting']);

    # Load and print greetings message here
    $self->output("\n\n");
    my $text = $self->files_load_file('files/main/greeting');
    $self->output($text);
    $self->{'debug'}->DEBUG(['End Greeting']);
    return (TRUE);    # Login will also create new users
} ## end sub greeting

sub login {
    my $self = shift;

    my $valid = FALSE;

    $self->{'debug'}->DEBUG(['Start Login']);
    my $username;
    if ($self->{'sysop'}) {
        $self->{'debug'}->DEBUG(['  Login as SysOp']);
        $username = 'sysop';
        $self->output("\n\nAuto-login of $username successful\n\n");
        $valid = $self->users_load($username, '');
        if ($self->{'sysop'} || $self->{'local_mode'}) {    # override DB values
            my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
            $self->{'USER'}->{'columns'} = $wsize;
        }
    } else {
        $self->{'debug'}->DEBUG(['  Login as User']);
        my $tries = $self->{'CONF'}->{'LOGIN TRIES'} + 0;
        do {
            do {
                $self->output("\n" . 'Please enter your username ("NEW" if you are a new user) > ');
                $username = $self->get_line(ECHO, 32);
                $tries-- if ($username eq '');
                last     if ($tries <= 0 || !$self->is_connected());
            } until ($username ne '');
            $self->{'debug'}->debug(["User = $username"]);
            if ($self->is_connected()) {
                if (uc($username) eq 'NEW') {
                    $self->{'debug'}->DEBUG(['    New user']);
                    $valid = $self->create_account();
                } elsif ($username eq 'sysop' && !$self->{'local_mode'}) {
                    $self->{'debug'}->WARNING(['    Login as SysOp attempted!']);
                    $self->output("\n\nSysOp cannot connect remotely\n\n");
                } else {
                    $self->{'debug'}->DEBUG(['    Asking for password']);
                    $self->output("\n\nPlease enter your password > ");
                    my $password = $self->get_line(PASSWORD, 64);
                    $valid = $self->users_load($username, $password);
                    if ($self->{'USER'}->{'banned'}) {
                        $valid = FALSE;
                    }
                } ## end else [ if (uc($username) eq 'NEW')]
                if ($valid) {
                    $self->{'debug'}->DEBUG(['  Password valid']);
                    $self->output("\n\nWelcome " . $self->{'fullname'} . ' (' . $self->{'username'} . ")\n\n");
                } else {
                    $self->{'debug'}->WARNING(['  Password incorrect, try ' . $tries]);
                    $self->output("\n\nLogin incorrect\n\n");
                    $tries--;
                }
            } ## end if ($self->is_connected...)
            last unless ($self->{'CACHE'}->get('RUNNING') && $self->is_connected());
        } until ($valid || $tries <= 0);
    } ## end else [ if ($self->{'sysop'}) ]
    $self->{'debug'}->DEBUG(['End Login']);
    return ($valid);
} ## end sub login

sub create_account {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Create account']);
    my $heading = '[% CLS %]CREATE ACCOUNT' . "\n\n";
    $self->output($heading);

    my $username;
    my $given;
    my $family;
    my $nickname;
    my $max_columns;
    my $max_rows;
    my $text_mode;
    my $birthday;
    my $location;
    my $date_format;
    my $accomplishments;
    my $email;
    my $baud_rate;
    my $password;
    my $password2;

    $self->output('Desired username:  ');

    if ($self->is_connected()) {
        $username = $self->get_line({ 'type' => HOST, 'max' => 132 }, '');
        $self->{'debug'}->DEBUG(["  New username:  $username"]);

        $self->output("\nFirst (given) name:  ");
        $given = $self->get_line({ 'type' => STRING, 'max' => 132 }, '');
        $self->{'debug'}->DEBUG(["  New First Name:  $given"]); 

        $self->output("\nLast (family) name:  ");
        $family = $self->get_line({ 'type' => STRING, 'max' => 132 }, '');
        $self->{'debug'}->DEBUG(["  New Last Name:  $family"]);

        $self->output("\nWould you like to use a nickname/alias (Y/N)?  ");
        if ($self->decision()) {
            $self->output("\nNickname:  ");
            $nickname = $self->get_line({ 'type' => STRING, 'max' => 132 }, '');
            $self->{'debug'}->DEBUG(["  New Nickname:  $nickname"]);
        }
        $self->output("\nScreen width (in columns):  ");
        $max_columns = $self->get_line({ 'type' => NUMERIC, 'max' => 3 }, 40);
        $self->{'debug'}->DEBUG(["  New Screen Width:  $max_columns"]);

        $self->output("\nScreen height (in rows):  ");
        $max_rows = $self->get_line({ 'type' => NUMERIC, 'max' => 3 }, 25);
        $self->{'debug'}->DEBUG(["  New Screen Height:  $max_rows"]);

        $self->output("\nTerminal emulations available:\n\n* ASCII\n* ANSI\n* ATASCII\n* PETSCII\n\nWhich one (type it as you see it?  ");
        $text_mode = $self->get_line({ 'type' => RADIO, 'max' => 7, 'choices' => ['ASCII', 'ANSI', 'ATASCII', 'PETSCII'] }, 'ASCII');
        $self->{'debug'}->DEBUG(["  New Text Mode:  $text_mode"]);

        $self->output("\nBirthdays can be with the year or use\n0000 for the year if you wish the year\nto be anonymous, but please enter the\nmonth and day (YEAR/MM/DD):  ");
        $birthday = $self->get_line({ 'type' => DATE, 'max' => 10 }, '');
        $self->{'debug'}->DEBUG(["  New Birthday:  $birthday"]);

        $self->output("\nPlease describe your location (you can\nbe as vague or specific as you want, or\nleave blank:  ");
        $location = $self->get_line({ 'type' => STRING, 'max' => 255 }, '');
        $self->{'debug'}->DEBUG(["  New Location:  $location"]);

        $self->output("\nDate formats:\n\n* YEAR/MONTH/DAY\n* DAY/MONTH/YEAR\n* MONTH/DAY/YEAR\n\nWhich date format do you prefer?  ");
        $date_format = $self->get_line({ 'type' => RADIO, 'max' => 15, 'choices' => ['YEAR/MONTH/DAY', 'MONTH/DAY/YEAR', 'DAY/MONTH/YEAR'] }, 'YEAR/MONTH/DAY');
        $self->{'debug'}->DEBUG(["  New Date Format:  $date_format"]);

        $self->output("\nYou can have a simulated baud rate for\nnostalgia.  Rates available:\n\n* 300\n* 600\n* 1200\n* 2400\n* 4800\n* 9600\n* 19200\n* FULL\n\nWhich one (FULL=full speed)?  ");
        $baud_rate = $self->get_line({ 'type' => RADIO, 'max' => 5, 'choices' => ['300', '600', '1200', '2400', '4800', '9600', '19200', 'FULL'] }, 'FULL');
        $self->{'debug'}->DEBUG(["  New Baud Rate:  $baud_rate"]);

        my $tries = 3;
        do {
            $self->output("\nPlease enter your password:  ");
            $password = $self->get_line({ 'type' => PASSWORD, 'max' => 64 }, '');
            $self->{'debug'}->DEBUG(['  New Password']);

            $self->output("\nEnter it again:  ");
            $password2 = $self->get_line({ 'type' => PASSWORD, 'max' => 64 }, '');
            $self->{'debug'}->DEBUG(['  New Password2']);

            $self->output("\nPasswords do not match!  Try again\n");
            $tries--;
        } until (($self->is_connected() && $password eq $password2) || $tries <= 0);
        if ($self->is_connected() && $password eq $password2) {
            my $tree = {
                'username'    => $username,
                'given'       => $given,
                'family'      => $family,
                'nickname'    => $nickname . '',
                'max_columns' => $max_columns,
                'max_rows'    => $max_rows,
                'text_mode'   => $text_mode,
                'birthday'    => $birthday,
                'location'    => $location,
                'date_format' => $date_format,
                'baud_rate'   => $baud_rate,
                'password'    => $password,
            };
            $self->{'debug'}->DEBUGMAX([$tree]);
            if ($self->users_add($tree)) {
                return ($self->users_load($username, $password));
            }
        } ## end if ($self->is_connected...)
    } ## end if ($self->is_connected...)
    $self->{'debug'}->DEBUG(['End Create Account']);
    return (FALSE);
} ## end sub create_account

sub is_connected {
    my $self = shift;

    if ($self->{'sysop'} || $self->{'local_mode'}) {
        return (TRUE);
    } elsif ($self->{'CACHE'}->get('RUNNING') && defined($self->{'cl_socket'})) {
        $self->{'CACHE'}->set(sprintf('SERVER_%02d', $self->{'thread_number'}), 'CONNECTED');
        $self->{'CACHE'}->set('UPDATE',                                         TRUE);
        return (TRUE);
    } else {
        $self->{'debug'}->WARNING(['User disconnected']);
        $self->{'CACHE'}->set(sprintf('SERVER_%02d', $self->{'thread_number'}), 'IDLE');
        $self->{'CACHE'}->set('UPDATE',                                         TRUE);
        return (FALSE);
    } ## end else [ if ($self->{'sysop'} ||...)]
} ## end sub is_connected

sub decision {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Decision']);
    my $response = uc($self->get_key(SILENT, BLOCKING));
    if ($response eq 'Y') {
        $self->output("YES\n");
        $self->{'debug'}->DEBUG(['  Decision YES']);
        return (TRUE);
    }
    $self->{'debug'}->DEBUG(['  Decision NO']);
    $self->output("NO\n");
    $self->{'debug'}->DEBUG(['End Decision']);
    return (FALSE);
} ## end sub decision

sub prompt {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start Prompt', "  Prompt > $text"]);
    my $response = "\n";
    if ($self->{'USER'}->{'text_mode'} eq 'ATASCII') {
        $response .= '(' . colored(['bright_yellow'], $self->{'USER'}->{'username'}) . ') ' . $text . chr(31) . ' ';
    } elsif ($self->{'USER'}->{'text_mode'} eq 'PETSCII') {
        $response .= '(' . $self->{'USER'}->{'username'} . ') ' . "$text > ";
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $response .= '(' . colored(['bright_yellow'], $self->{'USER'}->{'username'}) . ') ' . $text . ' [% BLACK RIGHT-POINTING TRIANGLE %] ';
    } else {
        $response .= '(' . $self->{'USER'}->{'username'} . ') ' . "$text > ";
    }
    $self->output($response);
    $self->{'debug'}->DEBUG(['End Prompt']);
    return (TRUE);
} ## end sub prompt

sub menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

    $self->{'debug'}->DEBUG(['Start Menu Choice']);
    if ($self->{'USER'}->{'text_mode'} eq 'ATASCII') {
        $self->output(" $choice " . chr(31) . " $desc");
    } elsif ($self->{'USER'}->{'text_mode'} eq 'PETSCII') {
        $self->output(" $choice > $desc");
    } elsif ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $self->output(charnames::string_vianame('BOX DRAWINGS LIGHT VERTICAL') . '[% ' . $color . ' %]' . $choice . '[% RESET %]' . charnames::string_vianame('BOX DRAWINGS LIGHT VERTICAL') . '[% ' . $color . ' %]' . charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE') . '[% RESET %]' . " $desc");
    } else {
        $self->output(" $choice > $desc");
    }
    $self->{'debug'}->DEBUG(['End Menu Choice']);
} ## end sub menu_choice

sub show_choices {
    my $self    = shift;
    my $mapping = shift;

    $self->{'debug'}->DEBUG(['Start Show Choices']);
    my $keys = '';
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $self->output(charnames::string_vianame('BOX DRAWINGS LIGHT ARC DOWN AND RIGHT') . charnames::string_vianame('BOX DRAWINGS LIGHT HORIZONTAL') . charnames::string_vianame('BOX DRAWINGS LIGHT ARC DOWN AND LEFT') . "\n");
    }
    my $odd = 0;
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        if ($self->{'access_level'}->{ $mapping->{$kmenu}->{'access_level'} } <= $self->{'access_level'}->{ $self->{'USER'}->{'access_level'} }) {
            $self->menu_choice($kmenu, $mapping->{$kmenu}->{'color'}, $mapping->{$kmenu}->{'text'});
            $self->output("\n");
        }
    } ## end foreach my $kmenu (sort(keys...))
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $self->output(charnames::string_vianame('BOX DRAWINGS LIGHT ARC UP AND RIGHT') . charnames::string_vianame('BOX DRAWINGS LIGHT HORIZONTAL') . charnames::string_vianame('BOX DRAWINGS LIGHT ARC UP AND LEFT'));
    }
    $self->{'debug'}->DEBUG(['End Show Choices']);
} ## end sub show_choices

sub header {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Header']);
    my $width = $self->{'USER'}->{'max_columns'};
    my $name  = ' ' . $self->{'CONF'}->{'BBS NAME'} . ' ';

    my $text = '#' x int(($width - length($name)) / 2);
    $text .= $name;
    $text .= '#' x ($width - length($text));
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        my $char = '[% BOX DRAWINGS HEAVY HORIZONTAL %]';
        $text =~ s/\#/$char/g;
    }
    $self->{'debug'}->DEBUG(['End Header']);
    return ($self->detokenize_text('[% CLS %]' . $text));
} ## end sub header

sub load_menu {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start Load Menu', "  Load Menu $file"]);
    my $orig    = $self->files_load_file($file);
    my @Text    = split(/\n/, $orig);
    my $mapping = { 'TEXT' => '' };
    my $mode    = TRUE;
    my $text    = '';
    $self->{'debug'}->DEBUG(['  Parse Menu']);
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
    } ## end foreach my $line (@Text)
    $mapping->{'TEXT'} = $self->header() . "\n" . $mapping->{'TEXT'};
    $self->{'debug'}->DEBUG(['End Load Menu']);
    return ($mapping);
} ## end sub load_menu

sub main_menu {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start Main Menu']);
    my $connected = TRUE;
    my $command   = '';
    my $mapping   = $self->load_menu($file);
    while ($connected && $self->is_connected()) {
        $self->output($mapping->{'TEXT'});
        $self->show_choices($mapping);
        $self->prompt('Choose');
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
    } ## end while ($connected && $self...)
    $self->{'debug'}->DEBUG(['End Main Menu']);
} ## end sub main_menu

sub disconnect {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Disconnect']);

    # Load and print disconnect message here
    my $text = $self->files_load_file('files/main/disconnect');
    $self->output($text);
    $self->{'debug'}->DEBUG(['End Disconnect']);
    return (TRUE);
} ## end sub disconnect

sub parse_telnet_escape {
    my $self    = shift;
    my $command = shift;
    my $option  = shift;
    my $handle  = $self->{'cl_socket'};

    $self->{'debug'}->DEBUG(['Start Parse Telnet Escape']);
    if ($command == WILL) {
        if ($option == ECHO) {    # WON'T ECHO
            print $handle chr(IAC) . chr(WONT) . chr(ECHO);
        } elsif ($option == LINEMODE) {
            print $handle chr(IAC) . chr(WONT) . chr(LINEMODE);
        }
    } elsif ($command == DO) {
        if ($option == ECHO) {    # DON'T ECHO
            print $handle chr(IAC) . chr(DONT) . chr(ECHO);
        } elsif ($option == LINEMODE) {
            print $handle chr(IAC) . chr(DONT) . chr(LINEMODE);
        }
    } else {
        $self->{'debug'}->DEBUG(['Recreived IAC Request - ' . $self->{'telnet_commands'}->[$command - 240] . ' : ' . $self->{'telnet_options'}->[$option]]);
    }
    $self->{'debug'}->DEBUG(['End Parse Telnet Escape']);
    return (TRUE);
} ## end sub parse_telnet_escape

sub flush_input {
    my $self = shift;

    my $key;
    unless ($self->{'sysop'} || $self->{'local_mode'}) {
        my $handle = $self->{'cl_socket'};
        ReadMode 'noecho', $handle;
        do {
            $key = ReadKey(-1, $handle);
        } until (!defined($key) || $key eq '');
        ReadMode 'restore', $handle;
    } else {
        ReadMode 'ultra-raw';
        do {
            $key = ReadKey(-1);
        } until (!defined($key) || $key eq '');
        ReadMode 'restore';
    } ## end else
    return (TRUE);
} ## end sub flush_input

sub get_key {
    my $self     = shift;
    my $echo     = shift;
    my $blocking = shift;

    my $key     = undef;
    my $mode    = $self->{'USER'}->{'text_mode'};
    my $timeout = $self->{'USER'}->{'timeout'} * 60;
    local $/ = "\x{00}";
    if ($self->{'sysop'} || $self->{'local_mode'}) {
        ReadMode 'ultra-raw';
        $key = ($blocking) ? ReadKey($timeout) : ReadKey(-1);
        ReadMode 'restore';
        threads->yield;
    } elsif ($self->is_connected()) {
        my $handle = $self->{'cl_socket'};
        ReadMode 'ultra-raw', $self->{'cl_socket'};
        my $escape;
        do {
            $escape = FALSE;
            $key    = ($blocking) ? ReadKey($timeout, $handle) : ReadKey(-1, $handle);
            if ($key eq chr(255)) {    # IAC sequence
                my $command = ReadKey($timeout, $handle);
                my $option  = ReadKey($timeout, $handle);
                $self->parse_telnet_escape(ord($command), ord($option));
                $escape = TRUE;
            } ## end if ($key eq chr(255))
        } until (!$escape || $self->is_connected());
        ReadMode 'restore', $self->{'cl_socket'};
        threads->yield;
    } ## end elsif ($self->is_connected...)
    return ($key) if ($key eq chr(13));
    if ($key eq chr(127)) {
        if ($mode eq 'ANSI') {
            $key = $self->{'ansi_sequences'}->{'BACKSPACE'};
        } elsif ($mode eq 'ATASCII') {
            $key = $self->{'atascii_sequences'}->{'BACKSPACE'};
        } elsif ($mode eq 'PETSCII') {
            $key = $self->{'petscii_sequences'}->{'BACKSPACE'};
        } else {
            $key = $self->{'ascii_sequences'}->{'BACKSPACE'};
        }
        $self->output("$key $key") if ($echo);
    } ## end if ($key eq chr(127))
    if ($echo == NUMERIC && defined($key)) {
        if ($key =~ /[0-9]/) {
            $self->output("$key");
        } else {
            $key = '';
        }
    } elsif ($echo == ECHO && defined($key)) {
        $self->send_char($key);
    } elsif ($echo == PASSWORD && defined($key)) {
        $self->send_char('*');
    }
    threads->yield;
    return ($key);
} ## end sub get_key

sub get_line {
    my $self = shift;
    my $echo = shift;
    my $type = $echo;

    my $line;
    my $limit;
    my $choices;
    my $key;

    $self->{'debug'}->DEBUG(['Start Get Line']);
    $self->flush_input();

    if (ref($type) eq 'HASH') {
        $limit = $type->{'max'};
        if (exists($type->{'choices'})) {
            $choices = $type->{'choices'};
            if (exists($type->{'default'})) {
                $line = $type->{'default'};
            } else {
                $line = shift;
            }
        } ## end if (exists($type->{'choices'...}))
        $echo = $type->{'type'};
    } else {
        if ($echo == STRING || $echo == ECHO || $echo == NUMERIC || $echo == HOST) {
            $limit = shift;
        }
        $line = shift;
    } ## end else [ if (ref($type) eq 'HASH')]

    my $key;

    $self->output($line) if ($line ne '');
    my $mode = $self->{'USER'}->{'text_mode'};
    my $bs;
    if ($mode eq 'ANSI') {
        $bs = $self->{'ansi_sequences'}->{'BACKSPACE'};
    } elsif ($mode eq 'ATASCII') {
        $bs = $self->{'atascii_sequences'}->{'BACKSPACE'};
    } elsif ($mode eq 'PETSCII') {
        $bs = $self->{'petscii_sequences'}->{'BACKSPACE'};
    } else {
        $bs = $self->{'ascii_sequences'}->{'BACKSPACE'};
    }

    if ($echo == RADIO) {
        $self->{'debug'}->DEBUG(['  Mode:  RADIO']);
        my $regexp = join('', @{ $type->{'choices'} });
        $self->{'debug'}->DEBUGMAX([$regexp]);
        while (($self->is_connected() || $self->{'local_mode'}) && $key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($regexp =~ /$key/i) {
                        $self->output(uc($key));
                        $line .= uc($key);
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while (($self->is_connected...))
    } elsif ($echo == NUMERIC) {
        $self->{'debug'}->DEBUG(['  Mode:  NUMERIC']);
        while (($self->is_connected() || $self->{'local_mode'}) && $key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[0-9]/) {
                        $self->output($key);
                        $line .= $key;
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while (($self->is_connected...))
    } elsif ($echo == DATE) {
        $self->{'debug'}->DEBUG(['  Mode:  DATE']);
        while (($self->is_connected() || $self->{'local_mode'}) && $key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[0-9]|\//) {
                        $self->output($key);
                        $line .= $key;
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while (($self->is_connected...))
    } elsif ($echo == HOST) {
        $self->{'debug'}->DEBUG(['  Mode:  HOST']);
        while (($self->is_connected() || $self->{'local_mode'}) && $key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[a-z]|[0-9]|\./) {
                        $self->output(lc($key));
                        $line .= lc($key);
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while (($self->is_connected...))
    } elsif ($type == PASSWORD) {
        $self->{'debug'}->DEBUG(['  Mode:  PASSWORD']);
        while (($self->is_connected() || $self->{'local_mode'}) && $key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && ord($key) > 31 && ord($key) < 127) {
                        $self->output('*');
                        $line .= $key;
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while (($self->is_connected...))
    } else {
        $self->{'debug'}->DEBUG(['  Mode:  NORMAL']);
        while (($self->is_connected() || $self->{'local_mode'}) && $key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && ord($key) > 31 && ord($key) < 127) {
                        $self->output($key);
                        $line .= $key;
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while (($self->is_connected...))
    } ## end else [ if ($echo == RADIO) ]
    threads->yield();
    $line = '' if ($key eq chr(3));
    $self->output("\n");
    $self->{'debug'}->DEBUG(['End Get Line']);
    return ($line);
} ## end sub get_line

sub detokenize_text {    # Detokenize text markup
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start Detokenize Text']);
    if (defined($text) && length($text) > 1) {
        foreach my $key (keys %{ $self->{'TOKENS'} }) {
            if ($key eq 'VERSIONS' && $text =~ /\[\%\s+$key\s+\%\]/i) {
                my $versions = '';
                foreach my $names (keys %{ $self->{'VERSIONS'} }) {
                    $versions .= sprintf('%-28s %.03f', $names, $self->{'VERSIONS'}->{$names}) . "\n";
                }
                $text =~ s/\[\%\s+$key\s+\%\]/$versions/g;
            } elsif (ref($self->{'TOKENS'}->{$key}) eq 'CODE' && $text =~ /\[\%\s+$key\s+\%\]/) {
                my $ch = $self->{'TOKENS'}->{$key}->($self);    # Code call
                $text =~ s/\[\%\s+$key\s+\%\]/$ch/g;
            } else {
                $text =~ s/\[\%\s+$key\s+\%\]/$self->{'TOKENS'}->{$key}/g;
            }
        } ## end foreach my $key (keys %{ $self...})
    } ## end if (defined($text) && ...)
    $self->{'debug'}->DEBUG(['End Detokenize Text']);
    return ($text);
} ## end sub detokenize_text

sub output {
    my $self = shift;
    $|=1;
    $self->{'debug'}->DEBUG(['Start Output']);
    my $text = $self->detokenize_text(shift);

    my $response = TRUE;
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
        } ## end if ($text =~ /\[\%\s+WRAP\s+\%\]/)
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
        $response = FALSE;
    }
    $self->{'debug'}->DEBUG(['End Output']);
    return ($response);
} ## end sub output

sub send_char {
    my $self = shift;
    my $char = shift;

    # This sends one character at a time to the socket to simulate a retro BBS
    if ($self->{'local_mode'} || !defined($self->{'cl_socket'})) {
        print STDOUT $char;
    } else {
        my $handle = $self->{'cl_socket'};
        print $handle $char;
    }

    # Send at the chosen baud rate by delaying the output by a fraction of a second
    # Only delay if the baud_rate is not FULL
    sleep $self->{'SPEEDS'}->{ $self->{'USER'}->{'baud_rate'} } if ($self->{'USER'}->{'baud_rate'} ne 'FULL');
    return (TRUE);
} ## end sub send_char

sub scroll {
    my $self = shift;
    my $nl   = shift;

    $self->{'debug'}->DEBUG(['Start Scroll']);
    my $string;
    $string = "$nl" . 'Scroll?  ';
    $self->output($string);
    if ($self->get_key(ECHO, BLOCKIMG) =~ /N|Q/i) {
        $self->output("\n");
        return (FALSE);
    }
    $self->output('[% BACKSPACE %] [% BACKSPACE %]' x 10);
    $self->{'debug'}->DEBUG(['End Scroll']);
    return (TRUE);
} ## end sub scroll

sub static_configuration {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start Static Configuration']);
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
    } ## end if (-e $file)
    $self->{'debug'}->DEBUG(['End Static Configuration']);
} ## end sub static_configuration

sub choose_file_category {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Choose File Category']);
    my $table;
    my $choices = [qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y 0 1 2 3 4 5 6 7 8 9)];
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
        $self->prompt('Choose Category (Z = Nevermind)');
        my $response;
        do {
            $response = uc($self->get_key(SILENT, BLOCKING));
        } until (exists($hchoice->{$response}) || $response =~ /^\<|Z$/ || !$self->is_connected());
        if ($response !~ /\<|Z/) {
            $self->{'USER'}->{'file_category'} = $hchoice->{$response};
            $self->output($categories[$hchoice->{$response} - 1] . "\n");
            $sth = $self->{'dbh'}->prepare('UPDATE users SET file_category=? WHERE id=?');
            $sth->execute($hchoice->{$response}, $self->{'USER'}->{'id'});
            $sth->finish();
        } else {
            $self->output("Nevermind\n");
        }
    } ## end if ($sth->rows > 0)
    $self->{'debug'}->DEBUG(['End Choose File Category']);
} ## end sub choose_file_category

sub configuration {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Configuration']);
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
        } ## end foreach my $file (@static_file)
        unless ($found) {
            $self->{'debug'}->ERROR(['BBS Static Configuration file not found', join("\n", @static_file)]);
            exit(1);
        }
        $self->db_connect();
    } ## end unless (exists($self->{'CONF'...}))
    #######################################################
    my $count = scalar(@_);
    if ($count == 1) {    # Get single value
        my $name = shift;

        $self->{'debug'}->DEBUG(['  Get Single Value']);
        my $sth = $self->{'dbh'}->prepare('SELECT config_value FROM config WHERE config_name=?');
        $sth->execute($name);
        my ($result) = $sth->fetchrow_array();
        $sth->finish();
        return ($result);
    } elsif ($count == 2) {    # Set a single value
        my $name = shift;
        my $fval = shift;
        $self->{'debug'}->DEBUG(['  Set a Single Value']);
        my $sth  = $self->{'dbh'}->prepare('REPLACE INTO config (config_value, config_name) VALUES (?,?)');
        $sth->execute($fval, $name);
        $sth->finish();
        $self->{'CONF'}->{$name} = $fval;
        return (TRUE);
    } elsif ($count == 0) {    # Get entire configuration forces a reload into CONF
        $self->{'debug'}->DEBUG(['  Get Entire Configuration']);
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
    } ## end elsif ($count == 0)
    $self->{'debug'}->DEBUG(['End Configuration']);
} ## end sub configuration

sub parse_versions {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Parse Versions']);
###
    my $versions = {
        'Perl'                         => $OLD_PERL_VERSION,
        'BBS Executable'               => $main::VERSION,
        'BBS::Universal'               => $BBS::Universal::VERSION,
        'BBS::Universal::ASCII'        => $BBS::Universal::ASCII_VERSION,
        'BBS::Universal::ATASCII'      => $BBS::Universal::ATASCII_VERSION,
        'BBS::Universal::PETSCII'      => $BBS::Universal::PETSCII_VERSION,
        'BBS::Universal::ANSI'         => $BBS::Universal::ANSI_VERSION,
        'BBS::Universal::BBS_List'     => $BBS::Universal::BBS_LIST_VERSION,
        'BBS::Universal::CPU'          => $BBS::Universal::CPU_VERSION,
        'BBS::Universal::Messages'     => $BBS::Universal::MESSAGES_VERSION,
        'BBS::Universal::SysOp'        => $BBS::Universal::SYSOP_VERSION,
        'BBS::Universal::FileTransfer' => $BBS::Universal::FILETRANSFER_VERSION,
        'BBS::Universal::Users'        => $BBS::Universal::USERS_VERSION,
        'BBS::Universal::DB'           => $BBS::Universal::DB_VERSION,
        'BBS::Universal::Text_Editor'  => $BBS::Universal::TEXT_EDITOR_VERSION,
        'DBI'                          => $DBI::VERSION,
        'DBD::mysql'                   => $DBD::mysql::VERSION,
        'DateTime'                     => $DateTime::VERSION,
        'Debug::Easy'                  => $Debug::Easy::VERSION,
        'File::Basename'               => $File::Basename::VERSION,
        'Time::HiRes'                  => $Time::HiRes::VERSION,
        'Term::ReadKey'                => $Term::ReadKey::VERSION,
        'Term::ANSIScreen'             => $Term::ANSIScreen::VERSION,
        'Text::Format'                 => $Text::Format::VERSION,
        'Text::SimpleTable'            => $Text::SimpleTable::VERSION,
        'IO::Socket'                   => $IO::Socket::VERSION,
    };
###
    $self->{'debug'}->DEBUG(['End Parse Versions']);
    return ($versions);
} ## end sub parse_versions

sub yes_no {
    my $self  = shift;
    my $bool  = 0 + shift;
    my $color = shift;

    my $response;
    $self->{'debug'}->DEBUG(['Start Yes No']);
    if ($color && $self->{'USER'}->{'text_mode'} eq 'ANSI') {
        if ($bool) {
            $response = '[% GREEN %]YES[% RESET %]';
        } else {
            $response = '[% RED %]NO[% RESET %]';
        }
    } else {
        if ($bool) {
            $response = 'YES';
        } else {
            $response = 'NO';
        }
    } ## end else [ if ($color && $self->{...})]
    $self->{'debug'}->DEBUG(['End Yes No']);
    return($response);
} ## end sub yes_no

sub pad_center {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

    $self->{'debug'}->DEBUG(['Start Pad Center']);
    if (defined($text) && $text ne '') {
        my $size    = length($text);
        my $padding = int(($width - $size) / 2);
        if ($padding > 0) {
            $text = ' ' x $padding . $text;
        }
    } ## end if (defined($text) && ...)
    $self->{'debug'}->DEBUG(['End Pad Center']);
    return ($text);
} ## end sub pad_center

sub center {
    my $self  = shift;
    my $text  = shift;
    my $width = shift;

    $self->{'debug'}->DEBUG(['Start Center']);
    my $response;
    unless (defined($text) && $text ne '') {
        return ($text);
    }
    if ($text =~ /\n/s) {
        chomp(my @lines = split(/\n$/, $text));
        $text = '';
        foreach my $line (@lines) {
            $text .= $self->pad_center($line, $width) . "\n";
        }
        $response = $text;
    } else {
        $response = $self->pad_center($text, $width);
    }
    $self->{'debug'}->DEBUG(['End Center']);
    return($response);
} ## end sub center

sub trim {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start Trim']);
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $self->{'debug'}->DEBUG(['End Trim']);
    return ($text);
} ## end sub trim

sub get_fortune {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Get Fortune']);
    $self->{'debug'}->DEBUG(['Get Fortune']);
    $self->{'debug'}->DEBUG(['End Get Fortune']);

    return (($self->{'USER'}->{'play_fortunes'}) ? `fortune -s -u` : '');
}

sub playit {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start Playit']);
    unless ($self->{'nosound'}) {
        $self->{'debug'}->DEBUG(["  Play Sound $file"]);
        if ((-e '/usr/bin/mplayer' || -e '/usr/local/bin/mplayer') && $self->configuration('PLAY SYSOP SOUNDS') =~ /TRUE|1/i) {
            system("nice -20 mplayer -really-quiet sysop_sounds/$file 1>/dev/null 2>&1 &");
        }
    } ## end unless ($self->{'nosound'})
    $self->{'debug'}->DEBUG(['End Playit']);
} ## end sub playit

sub check_access_level {
    my $self   = shift;
    my $access = shift;

    if ($self->{'access_levels'}->{$access} <= $self->{'access_levels'}->{ $self->{'USER'}->{'access_level'} }) {
        return (TRUE);
    }
    return (FALSE);
} ## end sub check_access_level

sub color_border {
    my $self  = shift;
    my $tbl   = shift;
    my $color = shift;

    $self->{'debug'}->DEBUG(['Start Color Border']);
    my $mode = $self->{'USER'}->{'text_mode'};
    $tbl =~ s/\n/[% NEWLINE %]/gs;
    if ($mode eq 'ANSI') {
        if ($tbl =~ /(─+?)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(│)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┌)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC DOWN AND RIGHT %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(└)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC UP AND RIGHT %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┬)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┐)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC DOWN AND LEFT %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(├)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┘)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC UP AND LEFT %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┼)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┤)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┴)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
    } elsif ($mode eq 'ATASCII') {
        if ($tbl =~ /(─)/) {
            my $ch = $1;
            my $new = '[% HORIZONTAL BAR %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(│)/) {
            my $ch = $1;
            my $new = '[% MIDDLE VERTICAL BAR %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┌)/) {
            my $ch = $1;
            my $new = '[% TOP LEFT CORNER %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(└)/) {
            my $ch = $1;
            my $new = '[% BOTTOM LEFT CORNER %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┬)/) {
            my $ch = $1;
            my $new = '[% HORIZONTAL BAR MIDDLE TOP %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┐)/) {
            my $ch = $1;
            my $new = '[% TOP RIGHT CORNER %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(├)/) {
            my $ch = $1;
            my $new = '[% VERTICAL BAR MIDDLE RIGHT %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┘)/) {
            my $ch = $1;
            my $new = '[% BOTTOM RIGHT CORNER %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┼)/) {
            my $ch = $1;
            my $new = '[% CROSS BAR %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┤)/) {
            my $ch = $1;
            my $new = '[% VERTICAL BAR MIDDLE RIGHT %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┴)/) {
            my $ch = $1;
            my $new = '[% HORIZONTAL BAR MIDDLE BOTTOM %]';
            $tbl =~ s/$ch/$new/gs;
        }
    } elsif ($mode eq 'PETSCII') {
        $color = 'BROWN' if ($color eq 'ORANGE');
        if ($tbl =~ /(─)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% HORIZONTAL BAR %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(│)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% VERTICAL BAR %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┌)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% TOP LEFT CORNER %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(└)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% BOTTOM LEFT CORNER %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┬)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% HORIZONTAL BAR MIDDLE TOP %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┐)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% TOP RIGHT CORNER %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(├)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% VERTICAL BAR MIDDLE LEFT %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┘)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% BOTTOM RIGHT CORNER %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┼)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% CROSS BAR %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┤)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% HORIZONTAL BAR MIDDLE RIGHT %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
        if ($tbl =~ /(┴)/) {
            my $ch = $1;
            my $new = '[% ' . $color . ' %][% HORIZONTAL BAR MIDDLE BOTTOM %][% RESET %]';
            $tbl =~ s/$ch/$new/gs;
        }
    }
    $self->{'debug'}->DEBUG(['End Color Border']);
    return($tbl);
}

sub html_to_text {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start HTML To Text']);
    $text =~ s/(\n\n\n)+/\n/gs;
    my %entity = (
        lt     => '<',     #a less-than
        gt     => '>',     #a greater-than
        amp    => '&',     #a nampersand
        quot   => '"',     #a (verticle) double-quote

        nbsp   => chr 160, # no-break space
        iexcl  => chr 161, # inverted exclamation mark
        cent   => chr 162, # cent sign
        pound  => chr 163, # pound sterling sign CURRENCY NOT WEIGHT
        curren => chr 164, # general currency sign
        yen    => chr 165, # yen sign
        brvbar => chr 166, # broken (vertical) bar
        sect   => chr 167, # section sign
        uml    => chr 168, # umlaut (dieresis)
        copy   => chr 169, # copyright sign
        ordf   => chr 170, # ordinal indicator, feminine
        laquo  => chr 171, # angle quotation mark, left
        not    => chr 172, # not sign
        shy    => chr 173, # soft hyphen
        reg    => chr 174, # registered sign
        macr   => chr 175, # macron
        deg    => chr 176, # degree sign
        plusmn => chr 177, # plus-or-minus sign
        sup2   => chr 178, # superscript two
        sup3   => chr 179, # superscript three
        acute  => chr 180, # acute accent
        micro  => chr 181, # micro sign
        para   => chr 182, # pilcrow (paragraph sign)
        middot => chr 183, # middle dot
        cedil  => chr 184, # cedilla
        sup1   => chr 185, # superscript one
        ordm   => chr 186, # ordinal indicator, masculine
        raquo  => chr 187, # angle quotation mark, right
        frac14 => chr 188, # fraction one-quarter
        frac12 => chr 189, # fraction one-half
        frac34 => chr 190, # fraction three-quarters
        iquest => chr 191, # inverted question mark
        Agrave => chr 192, # capital A, grave accent
        Aacute => chr 193, # capital A, acute accent
        Acirc  => chr 194, # capital A, circumflex accent
        Atilde => chr 195, # capital A, tilde
        Auml   => chr 196, # capital A, dieresis or umlaut mark
        Aring  => chr 197, # capital A, ring
        AElig  => chr 198, # capital AE diphthong (ligature)
        Ccedil => chr 199, # capital C, cedilla
        Egrave => chr 200, # capital E, grave accent
        Eacute => chr 201, # capital E, acute accent
        Ecirc  => chr 202, # capital E, circumflex accent
        Euml   => chr 203, # capital E, dieresis or umlaut mark
        Igrave => chr 204, # capital I, grave accent
        Iacute => chr 205, # capital I, acute accent
        Icirc  => chr 206, # capital I, circumflex accent
        Iuml   => chr 207, # capital I, dieresis or umlaut mark
        ETH    => chr 208, # capital Eth, Icelandic
        Ntilde => chr 209, # capital N, tilde
        Ograve => chr 210, # capital O, grave accent
        Oacute => chr 211, # capital O, acute accent
        Ocirc  => chr 212, # capital O, circumflex accent
        Otilde => chr 213, # capital O, tilde
        Ouml   => chr 214, # capital O, dieresis or umlaut mark
        times  => chr 215, # multiply sign
        Oslash => chr 216, # capital O, slash
        Ugrave => chr 217, # capital U, grave accent
        Uacute => chr 218, # capital U, acute accent
        Ucirc  => chr 219, # capital U, circumflex accent
        Uuml   => chr 220, # capital U, dieresis or umlaut mark
        Yacute => chr 221, # capital Y, acute accent
        THORN  => chr 222, # capital THORN, Icelandic
        szlig  => chr 223, # small sharp s, German (sz ligature)
        agrave => chr 224, # small a, grave accent
        aacute => chr 225, # small a, acute accent
        acirc  => chr 226, # small a, circumflex accent
        atilde => chr 227, # small a, tilde
        auml   => chr 228, # small a, dieresis or umlaut mark
        aring  => chr 229, # small a, ring
        aelig  => chr 230, # small ae diphthong (ligature)
        ccedil => chr 231, # small c, cedilla
        egrave => chr 232, # small e, grave accent
        eacute => chr 233, # small e, acute accent
        ecirc  => chr 234, # small e, circumflex accent
        euml   => chr 235, # small e, dieresis or umlaut mark
        igrave => chr 236, # small i, grave accent
        iacute => chr 237, # small i, acute accent
        icirc  => chr 238, # small i, circumflex accent
        iuml   => chr 239, # small i, dieresis or umlaut mark
        eth    => chr 240, # small eth, Icelandic
        ntilde => chr 241, # small n, tilde
        ograve => chr 242, # small o, grave accent
        oacute => chr 243, # small o, acute accent
        ocirc  => chr 244, # small o, circumflex accent
        otilde => chr 245, # small o, tilde
        ouml   => chr 246, # small o, dieresis or umlaut mark
        divide => chr 247, # divide sign
        oslash => chr 248, # small o, slash
        ugrave => chr 249, # small u, grave accent
        uacute => chr 250, # small u, acute accent
        ucirc  => chr 251, # small u, circumflex accent
        uuml   => chr 252, # small u, dieresis or umlaut mark
        yacute => chr 253, # small y, acute accent
        thorn  => chr 254, # small thorn, Icelandic
        yuml   => chr 255, # small y, dieresis or umlaut mark
    );

    for my $chr ( 0 .. 255 ) {
        $entity{ '#' . $chr } = chr $chr;
    }
###
    $text =~ s{ <!               # comments begin with a `<!'
                                 # followed by 0 or more comments;

                    (.*?)        # this is actually to eat up comments in non 
                                 # random places

              (                  # not suppose to have any white space here

                                 # just a quick start; 
               --                # each comment starts with a `--'
                 .*?             # and includes all text up to and including
               --                # the *next* occurrence of `--'
                 \s*             # and may have trailing while space
                                 #   (albeit not leading white space XXX)
              )+                 # repetire ad libitum  XXX should be * not +
                    (.*?)        # trailing non comment text
            >                    # up to a `>'
    }{
        if ($1 || $3) {    # this silliness for embedded comments in tags
            "<!$1 $3>";
        }
    }gesx;                 # mutate into nada, nothing, and niente

    $text =~ s{ <                    # opening angle bracket

                 (?:                 # Non-backreffing grouping paren
                      [^>'"] *       # 0 or more things that are neither > nor ' nor "
                         |           #    or else
                      ".*?"          # a section between double quotes (stingy match)
                         |           #    or else
                      '.*?'          # a section between single quotes (stingy match)
                 ) +                 # repetire ad libitum
                                     #  hm.... are null tags <> legal? XXX
                >                    # closing angle bracket
             }{}gsx;                 # mutate into nada, nothing, and niente

    $ text =~ s{ (
                      &              # an entity starts with a semicolon
                      ( 
                          \x23\d+    # and is either a pound (#) and numbers
                         |           #   or else
                          \w+        # has alphanumunders up to a semi
                      )
                      ;?             # a semi terminates AS DOES ANYTHING ELSE (XXX)
                 )
    } {

        $entity{$2}        # if it's a known entity use that
            ||             #   but otherwise
            $1             # leave what we'd found; NO WARNINGS (XXX)

    }gex;                  # execute replacement -- that's code not a string
###
    $self->{'debug'}->DEBUG(['End HTML To Text']);
    return($text);
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

sub ansi_decode {
    my $self = shift;
    my $text = shift;

	$self->{'debug'}->DEBUG(['Start ANSI Decode']);
    if (length($text) > 1) {
        while ($text =~ /\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/) {
            my $color = $1;
            $color =~ s/_/ /;
            my $new = '[% RETURN %][% B_' . $color . ' %][% CLEAR LINE %][% RESET %]';
            $text =~ s/\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/$new/;
        } ## end while ($text =~ /\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/)
        while ($text =~ /\[\%\s+LOCATE (\d+),(\d+)\s+\%\]/) {
            my ($c, $r) = ($1, $2);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "$r;$c" . 'H';
            $text =~ s/\[\%\s+LOCATE $r,$c\s+\%\]/$replace/g;
        }
        while ($text =~ /\[\%\s+SCROLL UP (\d+)\s+\%\]/) {
            my $s       = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . $s . 'S';
            $text =~ s/\[\%\s+SCROLL UP $s\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+SCROLL DOWN (\d+)\s+\%\]/) {
            my $s       = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . $s . 'T';
            $text =~ s/\[\%\s+SCROLL DOWN $s\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+RGB (\d+),(\d+),(\d+)\s+\%\]/) {
            my ($r, $g, $b) = ($1 & 255, $2 & 255, $3 & 255);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "38:2:$r:$g:$b" . 'm';
            $text =~ s/\[\%\s+RGB $r,$g,$b\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+B_RGB (\d+),(\d+),(\d+)\s+\%\]/) {
            my ($r, $g, $b) = ($1 & 255, $2 & 255, $3 & 255);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "48:2:$r:$g:$b" . 'm';
            $text =~ s/\[\%\s+B_RGB $r,$g,$b\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+BOX (.*?),(\d+),(\d+),(\d+),(\d+),(.*?)\s+\%\](.*?)\[\%\s+ENDBOX\s+\%\]/i) {
            my $replace = $self->box($1, $2, $3, $4, $5, $6, $7);
            $text =~ s/\[\%\s+BOX.*?\%\].*?\[\%\s+ENDBOX.*?\%\]/$replace/i;
        }
        while ($text =~ /\[\%\s+(.*?)\s+\%\]/ && (exists($self->{'ansi_sequences'}->{$1}) || defined(charnames::string_vianame($1)))) {
            my $string = $1;
            if (exists($self->{'ansi_sequences'}->{$string})) {
                if ($string =~ /CLS/i && $self->{'local_mode'}) {
                    my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                    $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
                } else {
                    $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_sequences'}->{$string}/gi;
                }
            } else {
                my $char = charnames::string_vianame($string);
                $char = '?' unless (defined($char));
                $text =~ s/\[\%\s+$string\s+\%\]/$char/gi;
            }
        } ## end while ($text =~ /\[\%\s+(.*?)\s+\%\]/...)
    } ## end if (length($text) > 1)
	$self->{'debug'}->DEBUG(['End ANSI Decode']);
    return ($text);
} ## end sub ansi_decode

sub ansi_output {
    my $self = shift;
    my $text = shift;

	$self->{'debug'}->DEBUG(['Start ANSI Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $text = $self->ansi_decode($text);
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
                next;
            }
        } ## end if ($char eq "\n")
        $self->send_char($char);
    } ## end foreach my $count (0 .. $s_len)
	$self->{'debug'}->DEBUG(['End ANSI Output']);
    return (TRUE);
} ## end sub ansi_output

sub box {
    my $self   = shift;
    my $color  = '[% ' . shift . ' %]';
    my $x      = shift;
    my $y      = shift;
    my $w      = shift;
    my $h      = shift;
    my $type   = shift;
    my $string = shift;

	$self->{'debug'}->DEBUG(['Start Box']);
    my $tl  = '╔';
    my $tr  = '╗';
    my $bl  = '╚';
    my $br  = '╝';
    my $top = '═';
    my $bot = '═';
    my $vl  = '║';
    my $vr  = '║';

    if ($type eq 'THIN') {
        $tl  = '┌';
        $tr  = '┐';
        $bl  = '└';
        $br  = '┘';
        $top = '─';
        $bot = '─';
        $vl  = '│';
        $vr  = '│';
    } elsif ($type eq 'ROUND') {
        $tl  = '╭';
        $tr  = '╮';
        $bl  = '╰';
        $br  = '╯';
        $top = '─';
        $bot = '─';
        $vl  = '│';
        $vr  = '│';
    } elsif ($type eq 'THICK') {
        $tl  = '┏';
        $tr  = '┓';
        $bl  = '┗';
        $br  = '┛';
        $top = '━';
        $bot = '━';
        $vl  = '┃';
        $vl  = '┃';
    } elsif ($type eq 'BLOCK') {
        $tl  = '🬚';
        $tr  = '🬩';
        $bl  = '🬌';
        $br  = '🬍';
        $top = '🬋';
        $bot = '🬋';
        $vl  = '▌';
        $vr  = '▐';
    } elsif ($type eq 'WEDGE') {
        $tl  = '🭊';
        $tr  = '🬿';
        $bl  = '🭥';
        $br  = '🭚';
        $top = '▅';
        $bot = '🮄';
        $vl  = '█';
        $vr  = '█';
    } elsif ($type eq 'BIG WEDGE') {
        $tl  = '◢';
        $tr  = '◣';
        $bl  = '◥';
        $br  = '◤';
        $top = '█';
        $bot = '█';
        $vl  = '█';
        $vr  = '█';
    } elsif ($type eq 'DOTS') {
        $tl  = '🞄';
        $tr  = '🞄';
        $bl  = '🞄';
        $br  = '🞄';
        $top = '🞄';
        $bot = '🞄';
        $vl  = '🞄';
        $vr  = '🞄';
    } elsif ($type eq 'DIAMOND') {
        $tl  = '⧫';
        $tr  = '⧫';
        $bl  = '⧫';
        $br  = '⧫';
        $top = '⧫';
        $bot = '⧫';
        $vl  = '⧫';
        $vr  = '⧫';
    } elsif ($type eq 'STAR') {
        $tl  = '⭑';
        $tr  = '⭑';
        $bl  = '⭑';
        $br  = '⭑';
        $top = '⭑';
        $bot = '⭑';
        $vl  = '⭑';
        $vr  = '⭑';
    } elsif ($type eq 'CIRCLE') {
        $tl  = '○';
        $tr  = '○';
        $bl  = '○';
        $br  = '○';
        $top = '○';
        $bot = '○';
        $vl  = '○';
        $vr  = '○';
    } elsif ($type eq 'SQUARE') {
        $tl  = '∎';
        $tr  = '∎';
        $bl  = '∎';
        $br  = '∎';
        $top = '∎';
        $bot = '∎';
        $vl  = '∎';
        $vr  = '∎';
    } elsif ($type eq 'DITHERED') {
        $tl  = '▒';
        $tr  = '▒';
        $bl  = '▒';
        $br  = '▒';
        $top = '▒';
        $bot = '▒';
        $vl  = '▒';
        $vr  = '▒';
    } elsif ($type eq 'HEART') {
        $tl  = '♥';
        $tr  = '♥';
        $bl  = '♥';
        $br  = '♥';
        $top = '♥';
        $bot = '♥';
        $vl  = '♥';
        $vr  = '♥';
    } elsif ($type eq 'CHRISTIAN') {
        $tl  = '🕇';
        $tr  = '🕇';
        $bl  = '🕇';
        $br  = '🕇';
        $top = '🕇';
        $bot = '🕇';
        $vl  = '🕇';
        $vr  = '🕇';
    } elsif ($type eq 'NOTES') {
        $tl  = '♪';
        $tr  = '♪';
        $bl  = '♪';
        $br  = '♪';
        $top = '♪';
        $bot = '♪';
        $vl  = '♪';
        $vr  = '♪';
    } elsif ($type eq 'PARALLELOGRAM') {
        $tl  = '▰';
        $tr  = '▰';
        $bl  = '▰';
        $br  = '▰';
        $top = '▰';
        $bot = '▰';
        $vl  = '▰';
        $vr  = '▰';
    } elsif ($type eq 'BIG ARROWS') {
        $tl  = '▶';
        $tr  = '▶';
        $bl  = '◀';
        $br  = '◀';
        $top = '▶';
        $bot = '◀';
        $vl  = '▲';
        $vr  = '▼';
    } elsif ($type eq 'ARROWS') {
        $tl  = '🡕';
        $tr  = '🡖';
        $bl  = '🡔';
        $br  = '🡗';
        $top = '🡒';
        $bot = '🡐';
        $vl  = '🡑';
        $vr  = '🡓';
    } ## end elsif ($type eq 'ARROWS')

    my $text = '';
    my $xx   = $x;
    my $yy   = $y;
    $text .= locate($yy++, $xx) . $color . $tl . $top x ($w - 2) . $tr . '[% RESET %]';
    foreach my $count (1 .. ($h - 2)) {
        $text .= locate($yy++, $xx) . $color . $vl . '[% RESET %]' . ' ' x ($w - 2) . $color . $vr . '[% RESET %]';
    }
    $text .= locate($yy++,  $xx) . $color . $bl . $bot x ($w - 2) . $br . '[% RESET %]' . $self->{'ansi_sequences'}->{'SAVE'};
    $text .= locate($y + 1, $x + 1);
    chomp(my @lines = fuzzy_wrap($string, ($w - 3)));
    $xx = $x + 1;
    $yy = $y + 1;
    foreach my $line (@lines) {
        $text .= locate($yy++, $xx) . $line;
    }
    $text .= $self->{'ansi_sequences'}->{'RESTORE'};
	$self->{'debug'}->DEBUG(['End Box']);
    return ($text);
} ## end sub box

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27);
    my $csi = $esc . '[';

	$self->{'debug'}->DEBUG(['Start ANSI Initialize']);
    $self->{'ansi_prefix'} = $csi;

    $self->{'ansi_meta'} = {
        'special' => {
            'FONT DOUBLE-HEIGHT TOP' => {
                'out'  => $esc . '#3',
                'desc' => 'Double-Height Font Top Portion',
            },
            'FONT DOUBLE-HEIGHT BOTTOM' => {
                'out'  => $esc . '#4',
                'desc' => 'Double-Height Font Bottom Portion',
            },
            'FONT DOUBLE-WIDTH' => {
                'out'  => $esc . '#6',
                'desc' => 'Double-Width Font',
            },
            'FONT DEFAULT' => {
                'out'  => $esc . '#5',
                'desc' => 'Default Font Size',
            },
            'APC' => {
                'out'  => $esc . '_',
                'desc' => 'Application Program Command',
            },
            'SS2' => {
                'out'  => $esc . 'N',
                'desc' => 'Single Shift 2',
            },
            'SS3' => {
                'out'  => $esc . 'O',
                'desc' => 'Single Shift 3',
            },
            'CSI' => {
                'out'  => $esc . '[',
                'desc' => 'Control Sequence Introducer',
            },
            'OSC' => {
                'out'  => $esc . ']',
                'desc' => 'Operating System Command',
            },
            'SOS' => {
                'out'  => $esc . 'X',
                'desc' => 'Start Of String',
            },
            'ST' => {
                'out'  => $esc . "\\",
                'desc' => 'String Terminator',
            },
            'DCS' => {
                'out'  => $esc . 'P',
                'desc' => 'Device Control String',
            },
        },

        'clear' => {
            'CLS' => {
                'out'  => $csi . '2J' . $csi . 'H',
                'desc' => 'Clear screen and place cursor at the top of the screen',
            },
            'CLEAR' => {
                'out'  => $csi . '2J',
                'desc' => 'Clear screen and keep cursor location',
            },
            'CLEAR LINE' => {
                'out'  => $csi . '0K',
                'desc' => 'Clear the current line from cursor',
            },
            'CLEAR DOWN' => {
                'out'  => $csi . '0J',
                'desc' => 'Clear from cursor position to bottom of the screen',
            },
            'CLEAR UP' => {
                'out'  => $csi . '1J',
                'desc' => 'Clear to the top of the screen from cursor position',
            },
        },

        'cursor' => {
            'RETURN' => {
                'out'  => chr(13),
                'desc' => 'Carriage Return (ASCII 13)',
            },
            'LINEFEED' => {
                'out'  => chr(10),
                'desc' => 'Line feed (ASCII 10)',
            },
            'NEWLINE' => {
                'out'  => chr(13) . chr(10),
                'desc' => 'New line (ASCII 13 and ASCII 10)',
            },
            'HOME' => {
                'out'  => $csi . 'H',
                'desc' => 'Place cursor at top left of the screen',
            },
            'UP' => {
                'out'  => $csi . 'A',
                'desc' => 'Move cursor up one line',
            },
            'DOWN' => {
                'out'  => $csi . 'B',
                'desc' => 'Move cursor down one line',
            },
            'RIGHT' => {
                'out'  => $csi . 'C',
                'desc' => 'Move cursor right one space non-destructively',
            },
            'LEFT' => {
                'out'  => $csi . 'D',
                'desc' => 'Move cursor left one space non-destructively',
            },
            'NEXT LINE' => {
                'out'  => $csi . 'E',
                'desc' => 'Place the cursor at the beginning of the next line',
            },
            'PREVIOUS LINE' => {
                'out'  => $csi . 'F',
                'desc' => 'Place the cursor at the beginning of the previous line',
            },
            'SAVE' => {
                'out'  => $csi . 's',
                'desc' => 'Save cureent cursor position',
            },
            'RESTORE' => {
                'out'  => $csi . 'u',
                'desc' => 'Restore the cursor to the saved position',
            },
            'CURSOR ON' => {
                'out'  => $csi . '?25h',
                'desc' => 'Turn the cursor on',
            },
            'CURSOR OFF' => {
                'out'  => $csi . '?25l',
                'desc' => 'Turn the cursor off',
            },
            'SCREEN 1' => {
                'out'  => $csi . '?1049l',
                'desc' => 'Set display to screen 1',
            },
            'SCREEN 2' => {
                'out'  => $csi . '?1049h',
                'desc' => 'Set display to screen 2',
            },
        },

        'attributes' => {
            'RESET' => {
                'out'  => $csi . '0m',
                'desc' => 'Restore all attributes and colors to their defaults',
            },
            'BOLD' => {
                'out'  => $csi . '1m',
                'desc' => 'Set to bold text',
            },
            'NORMAL' => {
                'out'  => $csi . '22m',
                'desc' => 'Turn off all attributes',
            },
            'FAINT' => {
                'out'  => $csi . '2m',
                'desc' => 'Set to faint (light) text',
            },
            'ITALIC' => {
                'out'  => $csi . '3m',
                'desc' => 'Set to italic text',
            },
            'UNDERLINE' => {
                'out'  => $csi . '4m',
                'desc' => 'Set to underlined text',
            },
            'FRAMED' => {
                'out'  => $csi . '51m',
                'desc' => 'Turn on framed text',
            },
            'FRAMED OFF' => {
                'out'  => $csi . '54m',
                'desc' => 'Turn off framed text',
            },
            'ENCIRCLED' => {
                'out'  => $csi . '52m',
                'desc' => 'Turn on encircled letters',
            },
            'ENCIRCLED OFF' => {
                'out'  => $csi . '54m',
                'desc' => 'Turn off encircled letters',
            },
            'OVERLINED' => {
                'out'  => $csi . '53m',
                'desc' => 'Turn on overlined text',
            },
            'OVERLINED OFF' => {
                'out'  => $csi . '55m',
                'desc' => 'Turn off overlined text',
            },
            'DEFAULT UNDERLINE COLOR' => {
                'out'  => $csi . '59m',
                'desc' => 'Set underline color to the default',
            },
            'SUPERSCRIPT' => {
                'out'  => $csi . '73m',
                'desc' => 'Turn on superscript',
            },
            'SUBSCRIPT' => {
                'out'  => $csi . '74m',
                'desc' => 'Turn on superscript',
            },
            'SUPERSCRIPT OFF' => {
                'out'  => $csi . '75m',
                'desc' => 'Turn off superscript',
            },
            'SUBSCRIPT OFF' => {
                'out'  => $csi . '75m',
                'desc' => 'Turn off subscript',
            },
            'SLOW BLINK' => {
                'out'  => $csi . '5m',
                'desc' => 'Set slow blink',
            },
            'RAPID BLINK' => {
                'out'  => $csi . '6m',
                'desc' => 'Set rapid blink',
            },
            'INVERT' => {
                'out'  => $csi . '7m',
                'desc' => 'Invert text',
            },
            'REVERSE' => {
                'out'  => $csi . '7m',
                'desc' => 'Invert text',
            },
            'HIDE' => {
                'out'  => $csi . '8m',
                'desc' => 'Hide enclosed text',
            },
            'REVEAL' => {
                'out'  => $csi . '28m',
                'desc' => 'Reveal hidden text',
            },
            'CROSSED OUT' => {
                'out'  => $csi . '9m',
                'desc' => 'Crossed out text',
            },
            'DEFAULT FONT' => {
                'out'  => $csi . '10m',
                'desc' => 'Set default font',
            },
            'PROPORTIONAL ON' => {
                'out'  => $csi . '26m',
                'desc' => 'Turn on proportional text',
            },
            'PROPORTIONAL OFF' => {
                'out'  => $csi . '50m',
                'desc' => 'Turn off proportional text',
            },
        },

        # Color

        'foreground' => {
            'DEFAULT' => {
                'out'  => $csi . '39m',
                'desc' => 'Default foreground color',
            },
            'BLACK' => {
                'out'  => $csi . '30m',
                'desc' => 'Black',
            },
            'RED' => {
                'out'  => $csi . '31m',
                'desc' => 'Red',
            },
            'DARK RED' => {
                'out'  => $csi . '38:2:139:0:0m',
                'desc' => 'Dark red',
            },
            'PINK' => {
                'out'  => $csi . '38;5;198m',
                'desc' => 'Pink',
            },
            'ORANGE' => {
                'out'  => $csi . '38;5;202m',
                'desc' => 'Orange',
            },
            'NAVY' => {
                'out'  => $csi . '38;5;17m',
                'desc' => 'Navy',
            },
            'BROWN' => {
                'out'  => $csi . '38:2:165:42:42m',
                'desc' => 'Brown',
            },
            'MAROON' => {
                'out'  => $csi . '38:2:128:0:0m',
                'desc' => 'Maroon',
            },
            'OLIVE' => {
                'out'  => $csi . '38:2:128:128:0m',
                'desc' => 'Olive',
            },
            'PURPLE' => {
                'out'  => $csi . '38:2:128:0:128m',
                'desc' => 'Purple',
            },
            'TEAL' => {
                'out'  => $csi . '38:2:0:128:128m',
                'desc' => 'Teal',
            },
            'GREEN' => {
                'out'  => $csi . '32m',
                'desc' => 'Green',
            },
            'YELLOW' => {
                'out'  => $csi . '33m',
                'desc' => 'Yellow',
            },
            'BLUE' => {
                'out'  => $csi . '34m',
                'desc' => 'Blue',
            },
            'MAGENTA' => {
                'out'  => $csi . '35m',
                'desc' => 'Magenta',
            },
            'CYAN' => {
                'out'  => $csi . '36m',
                'desc' => 'Cyan',
            },
            'WHITE' => {
                'out'  => $csi . '37m',
                'desc' => 'White',
            },
            'BRIGHT BLACK' => {
                'out'  => $csi . '90m',
                'desc' => 'Bright black',
            },
            'BRIGHT RED' => {
                'out'  => $csi . '91m',
                'desc' => 'Bright red',
            },
            'BRIGHT GREEN' => {
                'out'  => $csi . '92m',
                'desc' => 'Bright green',
            },
            'BRIGHT YELLOW' => {
                'out'  => $csi . '93m',
                'desc' => 'Bright yellow',
            },
            'BRIGHT BLUE' => {
                'out'  => $csi . '94m',
                'desc' => 'Bright blue',
            },
            'BRIGHT MAGENTA' => {
                'out'  => $csi . '95m',
                'desc' => 'Bright magenta',
            },
            'BRIGHT CYAN' => {
                'out'  => $csi . '96m',
                'desc' => 'Bright cyan',
            },
            'BRIGHT WHITE' => {
                'out'  => $csi . '97m',
                'desc' => 'Bright white',
            },
            'FIREBRICK' => {
                'out'  => $csi . '38:2:178:34:34m',
                'desc' => 'Firebrick',
            },
            'CRIMSON' => {
                'out'  => $csi . '38:2:220:20:60m',
                'desc' => 'Crimson',
            },
            'TOMATO' => {
                'out'  => $csi . '38:2:255:99:71m',
                'desc' => 'Tomato',
            },
            'CORAL' => {
                'out'  => $csi . '38:2:255:127:80m',
                'desc' => 'Coral',
            },
            'INDIAN RED' => {
                'out'  => $csi . '38:2:205:92:92m',
                'desc' => 'Indian red',
            },
            'LIGHT CORAL' => {
                'out'  => $csi . '38:2:240:128:128m',
                'desc' => 'Light coral',
            },
            'DARK SALMON' => {
                'out'  => $csi . '38:2:233:150:122m',
                'desc' => 'Dark salmon',
            },
            'SALMON' => {
                'out'  => $csi . '38:2:250:128:114m',
                'desc' => 'Salmon',
            },
            'LIGHT SALMON' => {
                'out'  => $csi . '38:2:255:160:122m',
                'desc' => 'Light salmon',
            },
            'ORANGE RED' => {
                'out'  => $csi . '38:2:255:69:0m',
                'desc' => 'Orange red',
            },
            'DARK ORANGE' => {
                'out'  => $csi . '38:2:255:140:0m',
                'desc' => 'Dark orange',
            },
            'GOLD' => {
                'out'  => $csi . '38:2:255:215:0m',
                'desc' => 'Gold',
            },
            'DARK GOLDEN ROD' => {
                'out'  => $csi . '38:2:184:134:11m',
                'desc' => 'Dark golden rod',
            },
            'GOLDEN ROD' => {
                'out'  => $csi . '38:2:218:165:32m',
                'desc' => 'Golden rod',
            },
            'PALE GOLDEN ROD' => {
                'out'  => $csi . '38:2:238:232:170m',
                'desc' => 'Pale golden rod',
            },
            'DARK KHAKI' => {
                'out'  => $csi . '38:2:189:183:107m',
                'desc' => 'Dark khaki',
            },
            'KHAKI' => {
                'out'  => $csi . '38:2:240:230:140m',
                'desc' => 'Khaki',
            },
            'YELLOW GREEN' => {
                'out'  => $csi . '38:2:154:205:50m',
                'desc' => 'Yellow green',
            },
            'DARK OLIVE GREEN' => {
                'out'  => $csi . '38:2:85:107:47m',
                'desc' => 'Dark olive green',
            },
            'OLIVE DRAB' => {
                'out'  => $csi . '38:2:107:142:35m',
                'desc' => 'Olive drab',
            },
            'LAWN GREEN' => {
                'out'  => $csi . '38:2:124:252:0m',
                'desc' => 'Lawn green',
            },
            'CHARTREUSE' => {
                'out'  => $csi . '38:2:127:255:0m',
                'desc' => 'Chartreuse',
            },
            'GREEN YELLOW' => {
                'out'  => $csi . '38:2:173:255:47m',
                'desc' => 'Green yellow',
            },
            'DARK GREEN' => {
                'out'  => $csi . '38:2:0:100:0m',
                'desc' => 'Dark green',
            },
            'FOREST GREEN' => {
                'out'  => $csi . '38:2:34:139:34m',
                'desc' => 'Forest green',
            },
            'LIME GREEN' => {
                'out'  => $csi . '38:2:50:205:50m',
                'desc' => 'Lime Green',
            },
            'LIGHT GREEN' => {
                'out'  => $csi . '38:2:144:238:144m',
                'desc' => 'Light green',
            },
            'PALE GREEN' => {
                'out'  => $csi . '38:2:152:251:152m',
                'desc' => 'Pale green',
            },
            'DARK SEA GREEN' => {
                'out'  => $csi . '38:2:143:188:143m',
                'desc' => 'Dark sea green',
            },
            'MEDIUM SPRING GREEN' => {
                'out'  => $csi . '38:2:0:250:154m',
                'desc' => 'Medium spring green',
            },
            'SPRING GREEN' => {
                'out'  => $csi . '38:2:0:255:127m',
                'desc' => 'Spring green',
            },
            'SEA GREEN' => {
                'out'  => $csi . '38:2:46:139:87m',
                'desc' => 'Sea green',
            },
            'MEDIUM AQUA MARINE' => {
                'out'  => $csi . '38:2:102:205:170m',
                'desc' => 'Medium aqua marine',
            },
            'MEDIUM SEA GREEN' => {
                'out'  => $csi . '38:2:60:179:113m',
                'desc' => 'Medium sea green',
            },
            'LIGHT SEA GREEN' => {
                'out'  => $csi . '38:2:32:178:170m',
                'desc' => 'Light sea green',
            },
            'DARK SLATE GRAY' => {
                'out'  => $csi . '38:2:47:79:79m',
                'desc' => 'Dark slate gray',
            },
            'DARK CYAN' => {
                'out'  => $csi . '38:2:0:139:139m',
                'desc' => 'Dark cyan',
            },
            'AQUA' => {
                'out'  => $csi . '38:2:0:255:255m',
                'desc' => 'Aqua',
            },
            'LIGHT CYAN' => {
                'out'  => $csi . '38:2:224:255:255m',
                'desc' => 'Light cyan',
            },
            'DARK TURQUOISE' => {
                'out'  => $csi . '38:2:0:206:209m',
                'desc' => 'Dark turquoise',
            },
            'TURQUOISE' => {
                'out'  => $csi . '38:2:64:224:208m',
                'desc' => 'Turquoise',
            },
            'MEDIUM TURQUOISE' => {
                'out'  => $csi . '38:2:72:209:204m',
                'desc' => 'Medium turquoise',
            },
            'PALE TURQUOISE' => {
                'out'  => $csi . '38:2:175:238:238m',
                'desc' => 'Pale turquoise',
            },
            'AQUA MARINE' => {
                'out'  => $csi . '38:2:127:255:212m',
                'desc' => 'Aqua marine',
            },
            'POWDER BLUE' => {
                'out'  => $csi . '38:2:176:224:230m',
                'desc' => 'Powder blue',
            },
            'CADET BLUE' => {
                'out'  => $csi . '38:2:95:158:160m',
                'desc' => 'Cadet blue',
            },
            'STEEL BLUE' => {
                'out'  => $csi . '38:2:70:130:180m',
                'desc' => 'Steel blue',
            },
            'CORN FLOWER BLUE' => {
                'out'  => $csi . '38:2:100:149:237m',
                'desc' => 'Corn flower blue',
            },
            'DEEP SKY BLUE' => {
                'out'  => $csi . '38:2:0:191:255m',
                'desc' => 'Deep sky blue',
            },
            'DODGER BLUE' => {
                'out'  => $csi . '38:2:30:144:255m',
                'desc' => 'Dodger blue',
            },
            'LIGHT BLUE' => {
                'out'  => $csi . '38:2:173:216:230m',
                'desc' => 'Light blue',
            },
            'SKY BLUE' => {
                'out'  => $csi . '38:2:135:206:235m',
                'desc' => 'Sky blue',
            },
            'LIGHT SKY BLUE' => {
                'out'  => $csi . '38:2:135:206:250m',
                'desc' => 'Light sky blue',
            },
            'MIDNIGHT BLUE' => {
                'out'  => $csi . '38:2:25:25:112m',
                'desc' => 'Midnight blue',
            },
            'DARK BLUE' => {
                'out'  => $csi . '38:2:0:0:139m',
                'desc' => 'Dark blue',
            },
            'MEDIUM BLUE' => {
                'out'  => $csi . '38:2:0:0:205m',
                'desc' => 'Medium blue',
            },
            'ROYAL BLUE' => {
                'out'  => $csi . '38:2:65:105:225m',
                'desc' => 'Royal blue',
            },
            'BLUE VIOLET' => {
                'out'  => $csi . '38:2:138:43:226m',
                'desc' => 'Blue violet',
            },
            'INDIGO' => {
                'out'  => $csi . '38:2:75:0:130m',
                'desc' => 'Indigo',
            },
            'DARK SLATE BLUE' => {
                'out'  => $csi . '38:2:72:61:139m',
                'desc' => 'Dark slate blue',
            },
            'SLATE BLUE' => {
                'out'  => $csi . '38:2:106:90:205m',
                'desc' => 'Slate blue',
            },
            'MEDIUM SLATE BLUE' => {
                'out'  => $csi . '38:2:123:104:238m',
                'desc' => 'Medium slate blue',
            },
            'MEDIUM PURPLE' => {
                'out'  => $csi . '38:2:147:112:219m',
                'desc' => 'Medium purple',
            },
            'DARK MAGENTA' => {
                'out'  => $csi . '38:2:139:0:139m',
                'desc' => 'Dark magenta',
            },
            'DARK VIOLET' => {
                'out'  => $csi . '38:2:148:0:211m',
                'desc' => 'Dark violet',
            },
            'DARK ORCHID' => {
                'out'  => $csi . '38:2:153:50:204m',
                'desc' => 'Dark orchid',
            },
            'MEDIUM ORCHID' => {
                'out'  => $csi . '38:2:186:85:211m',
                'desc' => 'Medium orchid',
            },
            'THISTLE' => {
                'out'  => $csi . '38:2:216:191:216m',
                'desc' => 'Thistle',
            },
            'PLUM' => {
                'out'  => $csi . '38:2:221:160:221m',
                'desc' => 'Plum',
            },
            'VIOLET' => {
                'out'  => $csi . '38:2:238:130:238m',
                'desc' => 'Violet',
            },
            'ORCHID' => {
                'out'  => $csi . '38:2:218:112:214m',
                'desc' => 'Orchid',
            },
            'MEDIUM VIOLET RED' => {
                'out'  => $csi . '38:2:199:21:133m',
                'desc' => 'Medium violet red',
            },
            'PALE VIOLET RED' => {
                'out'  => $csi . '38:2:219:112:147m',
                'desc' => 'Pale violet red',
            },
            'DEEP PINK' => {
                'out'  => $csi . '38:2:255:20:147m',
                'desc' => 'Deep pink',
            },
            'HOT PINK' => {
                'out'  => $csi . '38:2:255:105:180m',
                'desc' => 'Hot pink',
            },
            'LIGHT PINK' => {
                'out'  => $csi . '38:2:255:182:193m',
                'desc' => 'Light pink',
            },
            'ANTIQUE WHITE' => {
                'out'  => $csi . '38:2:250:235:215m',
                'desc' => 'Antique white',
            },
            'BEIGE' => {
                'out'  => $csi . '38:2:245:245:220m',
                'desc' => 'Beige',
            },
            'BISQUE' => {
                'out'  => $csi . '38:2:255:228:196m',
                'desc' => 'Bisque',
            },
            'BLANCHED ALMOND' => {
                'out'  => $csi . '38:2:255:235:205m',
                'desc' => 'Blanched almond',
            },
            'WHEAT' => {
                'out'  => $csi . '38:2:245:222:179m',
                'desc' => 'Wheat',
            },
            'CORN SILK' => {
                'out'  => $csi . '38:2:255:248:220m',
                'desc' => 'Corn silk',
            },
            'LEMON CHIFFON' => {
                'out'  => $csi . '38:2:255:250:205m',
                'desc' => 'Lemon chiffon',
            },
            'LIGHT GOLDEN ROD YELLOW' => {
                'out'  => $csi . '38:2:250:250:210m',
                'desc' => 'Light golden rod yellow',
            },
            'LIGHT YELLOW' => {
                'out'  => $csi . '38:2:255:255:224m',
                'desc' => 'Light yellow',
            },
            'SADDLE BROWN' => {
                'out'  => $csi . '38:2:139:69:19m',
                'desc' => 'Saddle brown',
            },
            'SIENNA' => {
                'out'  => $csi . '38:2:160:82:45m',
                'desc' => 'Sienna',
            },
            'CHOCOLATE' => {
                'out'  => $csi . '38:2:210:105:30m',
                'desc' => 'Chocolate',
            },
            'PERU' => {
                'out'  => $csi . '38:2:205:133:63m',
                'desc' => 'Peru',
            },
            'SANDY BROWN' => {
                'out'  => $csi . '38:2:244:164:96m',
                'desc' => 'Sandy brown',
            },
            'BURLY WOOD' => {
                'out'  => $csi . '38:2:222:184:135m',
                'desc' => 'Burly wood',
            },
            'TAN' => {
                'out'  => $csi . '38:2:210:180:140m',
                'desc' => 'Tan',
            },
            'ROSY BROWN' => {
                'out'  => $csi . '38:2:188:143:143m',
                'desc' => 'Rosy brown',
            },
            'MOCCASIN' => {
                'out'  => $csi . '38:2:255:228:181m',
                'desc' => 'Moccasin',
            },
            'NAVAJO WHITE' => {
                'out'  => $csi . '38:2:255:222:173m',
                'desc' => 'Navajo white',
            },
            'PEACH PUFF' => {
                'out'  => $csi . '38:2:255:218:185m',
                'desc' => 'Peach puff',
            },
            'MISTY ROSE' => {
                'out'  => $csi . '38:2:255:228:225m',
                'desc' => 'Misty rose',
            },
            'LAVENDER BLUSH' => {
                'out'  => $csi . '38:2:255:240:245m',
                'desc' => 'Lavender blush',
            },
            'LINEN' => {
                'out'  => $csi . '38:2:250:240:230m',
                'desc' => 'Linen',
            },
            'OLD LACE' => {
                'out'  => $csi . '38:2:253:245:230m',
                'desc' => 'Old lace',
            },
            'PAPAYA WHIP' => {
                'out'  => $csi . '38:2:255:239:213m',
                'desc' => 'Papaya whip',
            },
            'SEA SHELL' => {
                'out'  => $csi . '38:2:255:245:238m',
                'desc' => 'Sea shell',
            },
            'MINT CREAM' => {
                'out'  => $csi . '38:2:245:255:250m',
                'desc' => 'Mint green',
            },
            'SLATE GRAY' => {
                'out'  => $csi . '38:2:112:128:144m',
                'desc' => 'Slate gray',
            },
            'LIGHT SLATE GRAY' => {
                'out'  => $csi . '38:2:119:136:153m',
                'desc' => 'Lisght slate gray',
            },
            'LIGHT STEEL BLUE' => {
                'out'  => $csi . '38:2:176:196:222m',
                'desc' => 'Light steel blue',
            },
            'LAVENDER' => {
                'out'  => $csi . '38:2:230:230:250m',
                'desc' => 'Lavender',
            },
            'FLORAL WHITE' => {
                'out'  => $csi . '38:2:255:250:240m',
                'desc' => 'Floral white',
            },
            'ALICE BLUE' => {
                'out'  => $csi . '38:2:240:248:255m',
                'desc' => 'Alice blue',
            },
            'GHOST WHITE' => {
                'out'  => $csi . '38:2:248:248:255m',
                'desc' => 'Ghost white',
            },
            'HONEYDEW' => {
                'out'  => $csi . '38:2:240:255:240m',
                'desc' => 'Honeydew',
            },
            'IVORY' => {
                'out'  => $csi . '38:2:255:255:240m',
                'desc' => 'Ivory',
            },
            'AZURE' => {
                'out'  => $csi . '38:2:240:255:255m',
                'desc' => 'Azure',
            },
            'SNOW' => {
                'out'  => $csi . '38:2:255:250:250m',
                'desc' => 'Snow',
            },
            'DIM GRAY' => {
                'out'  => $csi . '38:2:105:105:105m',
                'desc' => 'Dim gray',
            },
            'DARK GRAY' => {
                'out'  => $csi . '38:2:169:169:169m',
                'desc' => 'Dark gray',
            },
            'SILVER' => {
                'out'  => $csi . '38:2:192:192:192m',
                'desc' => 'Silver',
            },
            'LIGHT GRAY' => {
                'out'  => $csi . '38:2:211:211:211m',
                'desc' => 'Light gray',
            },
            'GAINSBORO' => {
                'out'  => $csi . '38:2:220:220:220m',
                'desc' => 'Gainsboro',
            },
            'WHITE SMOKE' => {
                'out'  => $csi . '38:2:245:245:245m',
                'desc' => 'White smoke',
            },
            'AIR FORCE BLUE' => {
                'desc' => 'Air Force blue',
                'out'  => $csi . '38:2:93:138:168m',
            },
            'ALICE BLUE' => {
                'desc' => 'Alice blue',
                'out'  => $csi . '38:2:240:248:255m',
            },
            'ALIZARIN CRIMSON' => {
                'desc' => 'Alizarin crimson',
                'out'  => $csi . '38:2:227:38:54m',
            },
            'ALMOND' => {
                'desc' => 'Almond',
                'out'  => $csi . '38:2:239:222:205m',
            },
            'AMARANTH' => {
                'desc' => 'Amaranth',
                'out'  => $csi . '38:2:229:43:80m',
            },
            'AMBER' => {
                'desc' => 'Amber',
                'out'  => $csi . '38:2:255:191:0m',
            },
            'AMERICAN ROSE' => {
                'desc' => 'American rose',
                'out'  => $csi . '38:2:255:3:62m',
            },
            'AMETHYST' => {
                'desc' => 'Amethyst',
                'out'  => $csi . '38:2:153:102:204m',
            },
            'ANDROID GREEN' => {
                'desc' => 'Android Green',
                'out'  => $csi . '38:2:164:198:57m',
            },
            'ANTI-FLASH WHITE' => {
                'desc' => 'Anti-flash white',
                'out'  => $csi . '38:2:242:243:244m',
            },
            'ANTIQUE BRASS' => {
                'desc' => 'Antique brass',
                'out'  => $csi . '38:2:205:149:117m',
            },
            'ANTIQUE FUCHSIA' => {
                'desc' => 'Antique fuchsia',
                'out'  => $csi . '38:2:145:92:131m',
            },
            'ANTIQUE WHITE' => {
                'desc' => 'Antique white',
                'out'  => $csi . '38:2:250:235:215m',
            },
            'AO' => {
                'desc' => 'Ao',
                'out'  => $csi . '38:2:0:128:0m',
            },
            'APPLE GREEN' => {
                'desc' => 'Apple green',
                'out'  => $csi . '38:2:141:182:0m',
            },
            'APRICOT' => {
                'desc' => 'Apricot',
                'out'  => $csi . '38:2:251:206:177m',
            },
            'AQUA' => {
                'desc' => 'Aqua',
                'out'  => $csi . '38:2:0:255:255m',
            },
            'AQUAMARINE' => {
                'desc' => 'Aquamarine',
                'out'  => $csi . '38:2:127:255:212m',
            },
            'ARMY GREEN' => {
                'desc' => 'Army green',
                'out'  => $csi . '38:2:75:83:32m',
            },
            'ARYLIDE YELLOW' => {
                'desc' => 'Arylide yellow',
                'out'  => $csi . '38:2:233:214:107m',
            },
            'ASH GRAY' => {
                'desc' => 'Ash grey',
                'out'  => $csi . '38:2:178:190:181m',
            },
            'ASPARAGUS' => {
                'desc' => 'Asparagus',
                'out'  => $csi . '38:2:135:169:107m',
            },
            'ATOMIC TANGERINE' => {
                'desc' => 'Atomic tangerine',
                'out'  => $csi . '38:2:255:153:102m',
            },
            'AUBURN' => {
                'desc' => 'Auburn',
                'out'  => $csi . '38:2:165:42:42m',
            },
            'AUREOLIN' => {
                'desc' => 'Aureolin',
                'out'  => $csi . '38:2:253:238:0m',
            },
            'AUROMETALSAURUS' => {
                'desc' => 'AuroMetalSaurus',
                'out'  => $csi . '38:2:110:127:128m',
            },
            'AWESOME' => {
                'desc' => 'Awesome',
                'out'  => $csi . '38:2:255:32:82m',
            },
            'AZURE' => {
                'desc' => 'Azure',
                'out'  => $csi . '38:2:0:127:255m',
            },
            'AZURE MIST' => {
                'desc' => 'Azure mist',
                'out'  => $csi . '38:2:240:255:255m',
            },
            'BABY BLUE' => {
                'desc' => 'Baby blue',
                'out'  => $csi . '38:2:137:207:240m',
            },
            'BABY BLUE EYES' => {
                'desc' => 'Baby blue eyes',
                'out'  => $csi . '38:2:161:202:241m',
            },
            'BABY PINK' => {
                'desc' => 'Baby pink',
                'out'  => $csi . '38:2:244:194:194m',
            },
            'BALL BLUE' => {
                'desc' => 'Ball Blue',
                'out'  => $csi . '38:2:33:171:205m',
            },
            'BANANA MANIA' => {
                'desc' => 'Banana Mania',
                'out'  => $csi . '38:2:250:231:181m',
            },
            'BANANA YELLOW' => {
                'desc' => 'Banana yellow',
                'out'  => $csi . '38:2:255:225:53m',
            },
            'BATTLESHIP GRAY' => {
                'desc' => 'Battleship grey',
                'out'  => $csi . '38:2:132:132:130m',
            },
            'BAZAAR' => {
                'desc' => 'Bazaar',
                'out'  => $csi . '38:2:152:119:123m',
            },
            'BEAU BLUE' => {
                'desc' => 'Beau blue',
                'out'  => $csi . '38:2:188:212:230m',
            },
            'BEAVER' => {
                'desc' => 'Beaver',
                'out'  => $csi . '38:2:159:129:112m',
            },
            'BEIGE' => {
                'desc' => 'Beige',
                'out'  => $csi . '38:2:245:245:220m',
            },
            'BISQUE' => {
                'desc' => 'Bisque',
                'out'  => $csi . '38:2:255:228:196m',
            },
            'BISTRE' => {
                'desc' => 'Bistre',
                'out'  => $csi . '38:2:61:43:31m',
            },
            'BITTERSWEET' => {
                'desc' => 'Bittersweet',
                'out'  => $csi . '38:2:254:111:94m',
            },
            'BLANCHED ALMOND' => {
                'desc' => 'Blanched Almond',
                'out'  => $csi . '38:2:255:235:205m',
            },
            'BLEU DE FRANCE' => {
                'desc' => 'Bleu de France',
                'out'  => $csi . '38:2:49:140:231m',
            },
            'BLIZZARD BLUE' => {
                'desc' => 'Blizzard Blue',
                'out'  => $csi . '38:2:172:229:238m',
            },
            'BLOND' => {
                'desc' => 'Blond',
                'out'  => $csi . '38:2:250:240:190m',
            },
            'BLUE BELL' => {
                'desc' => 'Blue Bell',
                'out'  => $csi . '38:2:162:162:208m',
            },
            'BLUE GRAY' => {
                'desc' => 'Blue Gray',
                'out'  => $csi . '38:2:102:153:204m',
            },
            'BLUE GREEN' => {
                'desc' => 'Blue green',
                'out'  => $csi . '38:2:13:152:186m',
            },
            'BLUE PURPLE' => {
                'desc' => 'Blue purple',
                'out'  => $csi . '38:2:138:43:226m',
            },
            'BLUE VIOLET' => {
                'desc' => 'Blue violet',
                'out'  => $csi . '38:2:138:43:226m',
            },
            'BLUSH' => {
                'desc' => 'Blush',
                'out'  => $csi . '38:2:222:93:131m',
            },
            'BOLE' => {
                'desc' => 'Bole',
                'out'  => $csi . '38:2:121:68:59m',
            },
            'BONDI BLUE' => {
                'desc' => 'Bondi blue',
                'out'  => $csi . '38:2:0:149:182m',
            },
            'BONE' => {
                'desc' => 'Bone',
                'out'  => $csi . '38:2:227:218:201m',
            },
            'BOSTON UNIVERSITY RED' => {
                'desc' => 'Boston University Red',
                'out'  => $csi . '38:2:204:0:0m',
            },
            'BOTTLE GREEN' => {
                'desc' => 'Bottle green',
                'out'  => $csi . '38:2:0:106:78m',
            },
            'BOYSENBERRY' => {
                'desc' => 'Boysenberry',
                'out'  => $csi . '38:2:135:50:96m',
            },
            'BRANDEIS BLUE' => {
                'desc' => 'Brandeis blue',
                'out'  => $csi . '38:2:0:112:255m',
            },
            'BRASS' => {
                'desc' => 'Brass',
                'out'  => $csi . '38:2:181:166:66m',
            },
            'BRICK RED' => {
                'desc' => 'Brick red',
                'out'  => $csi . '38:2:203:65:84m',
            },
            'BRIGHT CERULEAN' => {
                'desc' => 'Bright cerulean',
                'out'  => $csi . '38:2:29:172:214m',
            },
            'BRIGHT GREEN' => {
                'desc' => 'Bright green',
                'out'  => $csi . '38:2:102:255:0m',
            },
            'BRIGHT LAVENDER' => {
                'desc' => 'Bright lavender',
                'out'  => $csi . '38:2:191:148:228m',
            },
            'BRIGHT MAROON' => {
                'desc' => 'Bright maroon',
                'out'  => $csi . '38:2:195:33:72m',
            },
            'BRIGHT PINK' => {
                'desc' => 'Bright pink',
                'out'  => $csi . '38:2:255:0:127m',
            },
            'BRIGHT TURQUOISE' => {
                'desc' => 'Bright turquoise',
                'out'  => $csi . '38:2:8:232:222m',
            },
            'BRIGHT UBE' => {
                'desc' => 'Bright ube',
                'out'  => $csi . '38:2:209:159:232m',
            },
            'BRILLIANT LAVENDER' => {
                'desc' => 'Brilliant lavender',
                'out'  => $csi . '38:2:244:187:255m',
            },
            'BRILLIANT ROSE' => {
                'desc' => 'Brilliant rose',
                'out'  => $csi . '38:2:255:85:163m',
            },
            'BRINK PINK' => {
                'desc' => 'Brink pink',
                'out'  => $csi . '38:2:251:96:127m',
            },
            'BRITISH RACING GREEN' => {
                'desc' => 'British racing green',
                'out'  => $csi . '38:2:0:66:37m',
            },
            'BRONZE' => {
                'desc' => 'Bronze',
                'out'  => $csi . '38:2:205:127:50m',
            },
            'BROWN' => {
                'desc' => 'Brown',
                'out'  => $csi . '38:2:165:42:42m',
            },
            'BUBBLE GUM' => {
                'desc' => 'Bubble gum',
                'out'  => $csi . '38:2:255:193:204m',
            },
            'BUBBLES' => {
                'desc' => 'Bubbles',
                'out'  => $csi . '38:2:231:254:255m',
            },
            'BUFF' => {
                'desc' => 'Buff',
                'out'  => $csi . '38:2:240:220:130m',
            },
            'BULGARIAN ROSE' => {
                'desc' => 'Bulgarian rose',
                'out'  => $csi . '38:2:72:6:7m',
            },
            'BURGUNDY' => {
                'desc' => 'Burgundy',
                'out'  => $csi . '38:2:128:0:32m',
            },
            'BURLYWOOD' => {
                'desc' => 'Burlywood',
                'out'  => $csi . '38:2:222:184:135m',
            },
            'BURNT ORANGE' => {
                'desc' => 'Burnt orange',
                'out'  => $csi . '38:2:204:85:0m',
            },
            'BURNT SIENNA' => {
                'desc' => 'Burnt sienna',
                'out'  => $csi . '38:2:233:116:81m',
            },
            'BURNT UMBER' => {
                'desc' => 'Burnt umber',
                'out'  => $csi . '38:2:138:51:36m',
            },
            'BYZANTINE' => {
                'desc' => 'Byzantine',
                'out'  => $csi . '38:2:189:51:164m',
            },
            'BYZANTIUM' => {
                'desc' => 'Byzantium',
                'out'  => $csi . '38:2:112:41:99m',
            },
            'CADET' => {
                'desc' => 'Cadet',
                'out'  => $csi . '38:2:83:104:114m',
            },
            'CADET BLUE' => {
                'desc' => 'Cadet blue',
                'out'  => $csi . '38:2:95:158:160m',
            },
            'CADET GRAY' => {
                'desc' => 'Cadet grey',
                'out'  => $csi . '38:2:145:163:176m',
            },
            'CADMIUM GREEN' => {
                'desc' => 'Cadmium green',
                'out'  => $csi . '38:2:0:107:60m',
            },
            'CADMIUM ORANGE' => {
                'desc' => 'Cadmium orange',
                'out'  => $csi . '38:2:237:135:45m',
            },
            'CADMIUM RED' => {
                'desc' => 'Cadmium red',
                'out'  => $csi . '38:2:227:0:34m',
            },
            'CADMIUM YELLOW' => {
                'desc' => 'Cadmium yellow',
                'out'  => $csi . '38:2:255:246:0m',
            },
            'CAFE AU LAIT' => {
                'desc' => 'Caf\303\251 au lait',
                'out'  => $csi . '38:2:166:123:91m',
            },
            'CAFE NOIR' => {
                'desc' => 'Caf\303\251 noir',
                'out'  => $csi . '38:2:75:54:33m',
            },
            'CAL POLY POMONA GREEN' => {
                'desc' => 'Cal Poly Pomona green',
                'out'  => $csi . '38:2:30:77:43m',
            },
            'UNIVERSITY OF CALIFORNIA GOLD' => {
                'desc' => 'University of California Gold',
                'out'  => $csi . '38:2:183:135:39m',
            },
            'CAMBRIDGE BLUE' => {
                'desc' => 'Cambridge Blue',
                'out'  => $csi . '38:2:163:193:173m',
            },
            'CAMEL' => {
                'desc' => 'Camel',
                'out'  => $csi . '38:2:193:154:107m',
            },
            'CAMOUFLAGE GREEN' => {
                'desc' => 'Camouflage green',
                'out'  => $csi . '38:2:120:134:107m',
            },
            'CANARY' => {
                'desc' => 'Canary',
                'out'  => $csi . '38:2:255:255:153m',
            },
            'CANARY YELLOW' => {
                'desc' => 'Canary yellow',
                'out'  => $csi . '38:2:255:239:0m',
            },
            'CANDY APPLE RED' => {
                'desc' => 'Candy apple red',
                'out'  => $csi . '38:2:255:8:0m',
            },
            'CANDY PINK' => {
                'desc' => 'Candy pink',
                'out'  => $csi . '38:2:228:113:122m',
            },
            'CAPRI' => {
                'desc' => 'Capri',
                'out'  => $csi . '38:2:0:191:255m',
            },
            'CAPUT MORTUUM' => {
                'desc' => 'Caput mortuum',
                'out'  => $csi . '38:2:89:39:32m',
            },
            'CARDINAL' => {
                'desc' => 'Cardinal',
                'out'  => $csi . '38:2:196:30:58m',
            },
            'CARIBBEAN GREEN' => {
                'desc' => 'Caribbean green',
                'out'  => $csi . '38:2:0:204:153m',
            },
            'CARMINE' => {
                'desc' => 'Carmine',
                'out'  => $csi . '38:2:255:0:64m',
            },
            'CARMINE PINK' => {
                'desc' => 'Carmine pink',
                'out'  => $csi . '38:2:235:76:66m',
            },
            'CARMINE RED' => {
                'desc' => 'Carmine red',
                'out'  => $csi . '38:2:255:0:56m',
            },
            'CARNATION PINK' => {
                'desc' => 'Carnation pink',
                'out'  => $csi . '38:2:255:166:201m',
            },
            'CARNELIAN' => {
                'desc' => 'Carnelian',
                'out'  => $csi . '38:2:179:27:27m',
            },
            'CAROLINA BLUE' => {
                'desc' => 'Carolina blue',
                'out'  => $csi . '38:2:153:186:221m',
            },
            'CARROT ORANGE' => {
                'desc' => 'Carrot orange',
                'out'  => $csi . '38:2:237:145:33m',
            },
            'CELADON' => {
                'desc' => 'Celadon',
                'out'  => $csi . '38:2:172:225:175m',
            },
            'CELESTE' => {
                'desc' => 'Celeste',
                'out'  => $csi . '38:2:178:255:255m',
            },
            'CELESTIAL BLUE' => {
                'desc' => 'Celestial blue',
                'out'  => $csi . '38:2:73:151:208m',
            },
            'CERISE' => {
                'desc' => 'Cerise',
                'out'  => $csi . '38:2:222:49:99m',
            },
            'CERISE PINK' => {
                'desc' => 'Cerise pink',
                'out'  => $csi . '38:2:236:59:131m',
            },
            'CERULEAN' => {
                'desc' => 'Cerulean',
                'out'  => $csi . '38:2:0:123:167m',
            },
            'CERULEAN BLUE' => {
                'desc' => 'Cerulean blue',
                'out'  => $csi . '38:2:42:82:190m',
            },
            'CG BLUE' => {
                'desc' => 'CG Blue',
                'out'  => $csi . '38:2:0:122:165m',
            },
            'CG RED' => {
                'desc' => 'CG Red',
                'out'  => $csi . '38:2:224:60:49m',
            },
            'CHAMOISEE' => {
                'desc' => 'Chamoisee',
                'out'  => $csi . '38:2:160:120:90m',
            },
            'CHAMPAGNE' => {
                'desc' => 'Champagne',
                'out'  => $csi . '38:2:250:214:165m',
            },
            'CHARCOAL' => {
                'desc' => 'Charcoal',
                'out'  => $csi . '38:2:54:69:79m',
            },
            'CHARTREUSE' => {
                'desc' => 'Chartreuse',
                'out'  => $csi . '38:2:127:255:0m',
            },
            'CHERRY' => {
                'desc' => 'Cherry',
                'out'  => $csi . '38:2:222:49:99m',
            },
            'CHERRY BLOSSOM PINK' => {
                'desc' => 'Cherry blossom pink',
                'out'  => $csi . '38:2:255:183:197m',
            },
            'CHESTNUT' => {
                'desc' => 'Chestnut',
                'out'  => $csi . '38:2:205:92:92m',
            },
            'CHOCOLATE' => {
                'desc' => 'Chocolate',
                'out'  => $csi . '38:2:210:105:30m',
            },
            'CHROME YELLOW' => {
                'desc' => 'Chrome yellow',
                'out'  => $csi . '38:2:255:167:0m',
            },
            'CINEREOUS' => {
                'desc' => 'Cinereous',
                'out'  => $csi . '38:2:152:129:123m',
            },
            'CINNABAR' => {
                'desc' => 'Cinnabar',
                'out'  => $csi . '38:2:227:66:52m',
            },
            'CINNAMON' => {
                'desc' => 'Cinnamon',
                'out'  => $csi . '38:2:210:105:30m',
            },
            'CITRINE' => {
                'desc' => 'Citrine',
                'out'  => $csi . '38:2:228:208:10m',
            },
            'CLASSIC ROSE' => {
                'desc' => 'Classic rose',
                'out'  => $csi . '38:2:251:204:231m',
            },
            'COBALT' => {
                'desc' => 'Cobalt',
                'out'  => $csi . '38:2:0:71:171m',
            },
            'COCOA BROWN' => {
                'desc' => 'Cocoa brown',
                'out'  => $csi . '38:2:210:105:30m',
            },
            'COFFEE' => {
                'desc' => 'Coffee',
                'out'  => $csi . '38:2:111:78:55m',
            },
            'COLUMBIA BLUE' => {
                'desc' => 'Columbia blue',
                'out'  => $csi . '38:2:155:221:255m',
            },
            'COOL BLACK' => {
                'desc' => 'Cool black',
                'out'  => $csi . '38:2:0:46:99m',
            },
            'COOL GRAY' => {
                'desc' => 'Cool grey',
                'out'  => $csi . '38:2:140:146:172m',
            },
            'COPPER' => {
                'desc' => 'Copper',
                'out'  => $csi . '38:2:184:115:51m',
            },
            'COPPER ROSE' => {
                'desc' => 'Copper rose',
                'out'  => $csi . '38:2:153:102:102m',
            },
            'COQUELICOT' => {
                'desc' => 'Coquelicot',
                'out'  => $csi . '38:2:255:56:0m',
            },
            'CORAL' => {
                'desc' => 'Coral',
                'out'  => $csi . '38:2:255:127:80m',
            },
            'CORAL PINK' => {
                'desc' => 'Coral pink',
                'out'  => $csi . '38:2:248:131:121m',
            },
            'CORAL RED' => {
                'desc' => 'Coral red',
                'out'  => $csi . '38:2:255:64:64m',
            },
            'CORDOVAN' => {
                'desc' => 'Cordovan',
                'out'  => $csi . '38:2:137:63:69m',
            },
            'CORN' => {
                'desc' => 'Corn',
                'out'  => $csi . '38:2:251:236:93m',
            },
            'CORNELL RED' => {
                'desc' => 'Cornell Red',
                'out'  => $csi . '38:2:179:27:27m',
            },
            'CORNFLOWER' => {
                'desc' => 'Cornflower',
                'out'  => $csi . '38:2:154:206:235m',
            },
            'CORNFLOWER BLUE' => {
                'desc' => 'Cornflower blue',
                'out'  => $csi . '38:2:100:149:237m',
            },
            'CORNSILK' => {
                'desc' => 'Cornsilk',
                'out'  => $csi . '38:2:255:248:220m',
            },
            'COSMIC LATTE' => {
                'desc' => 'Cosmic latte',
                'out'  => $csi . '38:2:255:248:231m',
            },
            'COTTON CANDY' => {
                'desc' => 'Cotton candy',
                'out'  => $csi . '38:2:255:188:217m',
            },
            'CREAM' => {
                'desc' => 'Cream',
                'out'  => $csi . '38:2:255:253:208m',
            },
            'CRIMSON' => {
                'desc' => 'Crimson',
                'out'  => $csi . '38:2:220:20:60m',
            },
            'CRIMSON GLORY' => {
                'desc' => 'Crimson glory',
                'out'  => $csi . '38:2:190:0:50m',
            },
            'CRIMSON RED' => {
                'desc' => 'Crimson Red',
                'out'  => $csi . '38:2:153:0:0m',
            },
            'DAFFODIL' => {
                'desc' => 'Daffodil',
                'out'  => $csi . '38:2:255:255:49m',
            },
            'DANDELION' => {
                'desc' => 'Dandelion',
                'out'  => $csi . '38:2:240:225:48m',
            },
            'DARK BLUE' => {
                'desc' => 'Dark blue',
                'out'  => $csi . '38:2:0:0:139m',
            },
            'DARK BROWN' => {
                'desc' => 'Dark brown',
                'out'  => $csi . '38:2:101:67:33m',
            },
            'DARK BYZANTIUM' => {
                'desc' => 'Dark byzantium',
                'out'  => $csi . '38:2:93:57:84m',
            },
            'DARK CANDY APPLE RED' => {
                'desc' => 'Dark candy apple red',
                'out'  => $csi . '38:2:164:0:0m',
            },
            'DARK CERULEAN' => {
                'desc' => 'Dark cerulean',
                'out'  => $csi . '38:2:8:69:126m',
            },
            'DARK CHESTNUT' => {
                'desc' => 'Dark chestnut',
                'out'  => $csi . '38:2:152:105:96m',
            },
            'DARK CORAL' => {
                'desc' => 'Dark coral',
                'out'  => $csi . '38:2:205:91:69m',
            },
            'DARK CYAN' => {
                'desc' => 'Dark cyan',
                'out'  => $csi . '38:2:0:139:139m',
            },
            'DARK ELECTRIC BLUE' => {
                'desc' => 'Dark electric blue',
                'out'  => $csi . '38:2:83:104:120m',
            },
            'DARK GOLDENROD' => {
                'desc' => 'Dark goldenrod',
                'out'  => $csi . '38:2:184:134:11m',
            },
            'DARK GRAY' => {
                'desc' => 'Dark gray',
                'out'  => $csi . '38:2:169:169:169m',
            },
            'DARK GREEN' => {
                'desc' => 'Dark green',
                'out'  => $csi . '38:2:1:50:32m',
            },
            'DARK JUNGLE GREEN' => {
                'desc' => 'Dark jungle green',
                'out'  => $csi . '38:2:26:36:33m',
            },
            'DARK KHAKI' => {
                'desc' => 'Dark khaki',
                'out'  => $csi . '38:2:189:183:107m',
            },
            'DARK LAVA' => {
                'desc' => 'Dark lava',
                'out'  => $csi . '38:2:72:60:50m',
            },
            'DARK LAVENDER' => {
                'desc' => 'Dark lavender',
                'out'  => $csi . '38:2:115:79:150m',
            },
            'DARK MAGENTA' => {
                'desc' => 'Dark magenta',
                'out'  => $csi . '38:2:139:0:139m',
            },
            'DARK MIDNIGHT BLUE' => {
                'desc' => 'Dark midnight blue',
                'out'  => $csi . '38:2:0:51:102m',
            },
            'DARK OLIVE GREEN' => {
                'desc' => 'Dark olive green',
                'out'  => $csi . '38:2:85:107:47m',
            },
            'DARK ORANGE' => {
                'desc' => 'Dark orange',
                'out'  => $csi . '38:2:255:140:0m',
            },
            'DARK ORCHID' => {
                'desc' => 'Dark orchid',
                'out'  => $csi . '38:2:153:50:204m',
            },
            'DARK PASTEL BLUE' => {
                'desc' => 'Dark pastel blue',
                'out'  => $csi . '38:2:119:158:203m',
            },
            'DARK PASTEL GREEN' => {
                'desc' => 'Dark pastel green',
                'out'  => $csi . '38:2:3:192:60m',
            },
            'DARK PASTEL PURPLE' => {
                'desc' => 'Dark pastel purple',
                'out'  => $csi . '38:2:150:111:214m',
            },
            'DARK PASTEL RED' => {
                'desc' => 'Dark pastel red',
                'out'  => $csi . '38:2:194:59:34m',
            },
            'DARK PINK' => {
                'desc' => 'Dark pink',
                'out'  => $csi . '38:2:231:84:128m',
            },
            'DARK POWDER BLUE' => {
                'desc' => 'Dark powder blue',
                'out'  => $csi . '38:2:0:51:153m',
            },
            'DARK RASPBERRY' => {
                'desc' => 'Dark raspberry',
                'out'  => $csi . '38:2:135:38:87m',
            },
            'DARK RED' => {
                'desc' => 'Dark red',
                'out'  => $csi . '38:2:139:0:0m',
            },
            'DARK SALMON' => {
                'desc' => 'Dark salmon',
                'out'  => $csi . '38:2:233:150:122m',
            },
            'DARK SCARLET' => {
                'desc' => 'Dark scarlet',
                'out'  => $csi . '38:2:86:3:25m',
            },
            'DARK SEA GREEN' => {
                'desc' => 'Dark sea green',
                'out'  => $csi . '38:2:143:188:143m',
            },
            'DARK SIENNA' => {
                'desc' => 'Dark sienna',
                'out'  => $csi . '38:2:60:20:20m',
            },
            'DARK SLATE BLUE' => {
                'desc' => 'Dark slate blue',
                'out'  => $csi . '38:2:72:61:139m',
            },
            'DARK SLATE GRAY' => {
                'desc' => 'Dark slate gray',
                'out'  => $csi . '38:2:47:79:79m',
            },
            'DARK SPRING GREEN' => {
                'desc' => 'Dark spring green',
                'out'  => $csi . '38:2:23:114:69m',
            },
            'DARK TAN' => {
                'desc' => 'Dark tan',
                'out'  => $csi . '38:2:145:129:81m',
            },
            'DARK TANGERINE' => {
                'desc' => 'Dark tangerine',
                'out'  => $csi . '38:2:255:168:18m',
            },
            'DARK TAUPE' => {
                'desc' => 'Dark taupe',
                'out'  => $csi . '38:2:72:60:50m',
            },
            'DARK TERRA COTTA' => {
                'desc' => 'Dark terra cotta',
                'out'  => $csi . '38:2:204:78:92m',
            },
            'DARK TURQUOISE' => {
                'desc' => 'Dark turquoise',
                'out'  => $csi . '38:2:0:206:209m',
            },
            'DARK VIOLET' => {
                'desc' => 'Dark violet',
                'out'  => $csi . '38:2:148:0:211m',
            },
            'DARTMOUTH GREEN' => {
                'desc' => 'Dartmouth green',
                'out'  => $csi . '38:2:0:105:62m',
            },
            'DAVY GRAY' => {
                'desc' => 'Davy grey',
                'out'  => $csi . '38:2:85:85:85m',
            },
            'DEBIAN RED' => {
                'desc' => 'Debian red',
                'out'  => $csi . '38:2:215:10:83m',
            },
            'DEEP CARMINE' => {
                'desc' => 'Deep carmine',
                'out'  => $csi . '38:2:169:32:62m',
            },
            'DEEP CARMINE PINK' => {
                'desc' => 'Deep carmine pink',
                'out'  => $csi . '38:2:239:48:56m',
            },
            'DEEP CARROT ORANGE' => {
                'desc' => 'Deep carrot orange',
                'out'  => $csi . '38:2:233:105:44m',
            },
            'DEEP CERISE' => {
                'desc' => 'Deep cerise',
                'out'  => $csi . '38:2:218:50:135m',
            },
            'DEEP CHAMPAGNE' => {
                'desc' => 'Deep champagne',
                'out'  => $csi . '38:2:250:214:165m',
            },
            'DEEP CHESTNUT' => {
                'desc' => 'Deep chestnut',
                'out'  => $csi . '38:2:185:78:72m',
            },
            'DEEP COFFEE' => {
                'desc' => 'Deep coffee',
                'out'  => $csi . '38:2:112:66:65m',
            },
            'DEEP FUCHSIA' => {
                'desc' => 'Deep fuchsia',
                'out'  => $csi . '38:2:193:84:193m',
            },
            'DEEP JUNGLE GREEN' => {
                'desc' => 'Deep jungle green',
                'out'  => $csi . '38:2:0:75:73m',
            },
            'DEEP LILAC' => {
                'desc' => 'Deep lilac',
                'out'  => $csi . '38:2:153:85:187m',
            },
            'DEEP MAGENTA' => {
                'desc' => 'Deep magenta',
                'out'  => $csi . '38:2:204:0:204m',
            },
            'DEEP PEACH' => {
                'desc' => 'Deep peach',
                'out'  => $csi . '38:2:255:203:164m',
            },
            'DEEP PINK' => {
                'desc' => 'Deep pink',
                'out'  => $csi . '38:2:255:20:147m',
            },
            'DEEP SAFFRON' => {
                'desc' => 'Deep saffron',
                'out'  => $csi . '38:2:255:153:51m',
            },
            'DEEP SKY BLUE' => {
                'desc' => 'Deep sky blue',
                'out'  => $csi . '38:2:0:191:255m',
            },
            'DENIM' => {
                'desc' => 'Denim',
                'out'  => $csi . '38:2:21:96:189m',
            },
            'DESERT' => {
                'desc' => 'Desert',
                'out'  => $csi . '38:2:193:154:107m',
            },
            'DESERT SAND' => {
                'desc' => 'Desert sand',
                'out'  => $csi . '38:2:237:201:175m',
            },
            'DIM GRAY' => {
                'desc' => 'Dim gray',
                'out'  => $csi . '38:2:105:105:105m',
            },
            'DODGER BLUE' => {
                'desc' => 'Dodger blue',
                'out'  => $csi . '38:2:30:144:255m',
            },
            'DOGWOOD ROSE' => {
                'desc' => 'Dogwood rose',
                'out'  => $csi . '38:2:215:24:104m',
            },
            'DOLLAR BILL' => {
                'desc' => 'Dollar bill',
                'out'  => $csi . '38:2:133:187:101m',
            },
            'DRAB' => {
                'desc' => 'Drab',
                'out'  => $csi . '38:2:150:113:23m',
            },
            'DUKE BLUE' => {
                'desc' => 'Duke blue',
                'out'  => $csi . '38:2:0:0:156m',
            },
            'EARTH YELLOW' => {
                'desc' => 'Earth yellow',
                'out'  => $csi . '38:2:225:169:95m',
            },
            'ECRU' => {
                'desc' => 'Ecru',
                'out'  => $csi . '38:2:194:178:128m',
            },
            'EGGPLANT' => {
                'desc' => 'Eggplant',
                'out'  => $csi . '38:2:97:64:81m',
            },
            'EGGSHELL' => {
                'desc' => 'Eggshell',
                'out'  => $csi . '38:2:240:234:214m',
            },
            'EGYPTIAN BLUE' => {
                'desc' => 'Egyptian blue',
                'out'  => $csi . '38:2:16:52:166m',
            },
            'ELECTRIC BLUE' => {
                'desc' => 'Electric blue',
                'out'  => $csi . '38:2:125:249:255m',
            },
            'ELECTRIC CRIMSON' => {
                'desc' => 'Electric crimson',
                'out'  => $csi . '38:2:255:0:63m',
            },
            'ELECTRIC CYAN' => {
                'desc' => 'Electric cyan',
                'out'  => $csi . '38:2:0:255:255m',
            },
            'ELECTRIC GREEN' => {
                'desc' => 'Electric green',
                'out'  => $csi . '38:2:0:255:0m',
            },
            'ELECTRIC INDIGO' => {
                'desc' => 'Electric indigo',
                'out'  => $csi . '38:2:111:0:255m',
            },
            'ELECTRIC LAVENDER' => {
                'desc' => 'Electric lavender',
                'out'  => $csi . '38:2:244:187:255m',
            },
            'ELECTRIC LIME' => {
                'desc' => 'Electric lime',
                'out'  => $csi . '38:2:204:255:0m',
            },
            'ELECTRIC PURPLE' => {
                'desc' => 'Electric purple',
                'out'  => $csi . '38:2:191:0:255m',
            },
            'ELECTRIC ULTRAMARINE' => {
                'desc' => 'Electric ultramarine',
                'out'  => $csi . '38:2:63:0:255m',
            },
            'ELECTRIC VIOLET' => {
                'desc' => 'Electric violet',
                'out'  => $csi . '38:2:143:0:255m',
            },
            'ELECTRIC YELLOW' => {
                'desc' => 'Electric yellow',
                'out'  => $csi . '38:2:255:255:0m',
            },
            'EMERALD' => {
                'desc' => 'Emerald',
                'out'  => $csi . '38:2:80:200:120m',
            },
            'ETON BLUE' => {
                'desc' => 'Eton blue',
                'out'  => $csi . '38:2:150:200:162m',
            },
            'FALLOW' => {
                'desc' => 'Fallow',
                'out'  => $csi . '38:2:193:154:107m',
            },
            'FALU RED' => {
                'desc' => 'Falu red',
                'out'  => $csi . '38:2:128:24:24m',
            },
            'FAMOUS' => {
                'desc' => 'Famous',
                'out'  => $csi . '38:2:255:0:255m',
            },
            'FANDANGO' => {
                'desc' => 'Fandango',
                'out'  => $csi . '38:2:181:51:137m',
            },
            'FASHION FUCHSIA' => {
                'desc' => 'Fashion fuchsia',
                'out'  => $csi . '38:2:244:0:161m',
            },
            'FAWN' => {
                'desc' => 'Fawn',
                'out'  => $csi . '38:2:229:170:112m',
            },
            'FELDGRAU' => {
                'desc' => 'Feldgrau',
                'out'  => $csi . '38:2:77:93:83m',
            },
            'FERN' => {
                'desc' => 'Fern',
                'out'  => $csi . '38:2:113:188:120m',
            },
            'FERN GREEN' => {
                'desc' => 'Fern green',
                'out'  => $csi . '38:2:79:121:66m',
            },
            'FERRARI RED' => {
                'desc' => 'Ferrari Red',
                'out'  => $csi . '38:2:255:40:0m',
            },
            'FIELD DRAB' => {
                'desc' => 'Field drab',
                'out'  => $csi . '38:2:108:84:30m',
            },
            'FIRE ENGINE RED' => {
                'desc' => 'Fire engine red',
                'out'  => $csi . '38:2:206:32:41m',
            },
            'FIREBRICK' => {
                'desc' => 'Firebrick',
                'out'  => $csi . '38:2:178:34:34m',
            },
            'FLAME' => {
                'desc' => 'Flame',
                'out'  => $csi . '38:2:226:88:34m',
            },
            'FLAMINGO PINK' => {
                'desc' => 'Flamingo pink',
                'out'  => $csi . '38:2:252:142:172m',
            },
            'FLAVESCENT' => {
                'desc' => 'Flavescent',
                'out'  => $csi . '38:2:247:233:142m',
            },
            'FLAX' => {
                'desc' => 'Flax',
                'out'  => $csi . '38:2:238:220:130m',
            },
            'FLORAL WHITE' => {
                'desc' => 'Floral white',
                'out'  => $csi . '38:2:255:250:240m',
            },
            'FLUORESCENT ORANGE' => {
                'desc' => 'Fluorescent orange',
                'out'  => $csi . '38:2:255:191:0m',
            },
            'FLUORESCENT PINK' => {
                'desc' => 'Fluorescent pink',
                'out'  => $csi . '38:2:255:20:147m',
            },
            'FLUORESCENT YELLOW' => {
                'desc' => 'Fluorescent yellow',
                'out'  => $csi . '38:2:204:255:0m',
            },
            'FOLLY' => {
                'desc' => 'Folly',
                'out'  => $csi . '38:2:255:0:79m',
            },
            'FOREST GREEN' => {
                'desc' => 'Forest green',
                'out'  => $csi . '38:2:34:139:34m',
            },
            'FRENCH BEIGE' => {
                'desc' => 'French beige',
                'out'  => $csi . '38:2:166:123:91m',
            },
            'FRENCH BLUE' => {
                'desc' => 'French blue',
                'out'  => $csi . '38:2:0:114:187m',
            },
            'FRENCH LILAC' => {
                'desc' => 'French lilac',
                'out'  => $csi . '38:2:134:96:142m',
            },
            'FRENCH ROSE' => {
                'desc' => 'French rose',
                'out'  => $csi . '38:2:246:74:138m',
            },
            'FUCHSIA' => {
                'desc' => 'Fuchsia',
                'out'  => $csi . '38:2:255:0:255m',
            },
            'FUCHSIA PINK' => {
                'desc' => 'Fuchsia pink',
                'out'  => $csi . '38:2:255:119:255m',
            },
            'FULVOUS' => {
                'desc' => 'Fulvous',
                'out'  => $csi . '38:2:228:132:0m',
            },
            'FUZZY WUZZY' => {
                'desc' => 'Fuzzy Wuzzy',
                'out'  => $csi . '38:2:204:102:102m',
            },
            'GAINSBORO' => {
                'desc' => 'Gainsboro',
                'out'  => $csi . '38:2:220:220:220m',
            },
            'GAMBOGE' => {
                'desc' => 'Gamboge',
                'out'  => $csi . '38:2:228:155:15m',
            },
            'GHOST WHITE' => {
                'desc' => 'Ghost white',
                'out'  => $csi . '38:2:248:248:255m',
            },
            'GINGER' => {
                'desc' => 'Ginger',
                'out'  => $csi . '38:2:176:101:0m',
            },
            'GLAUCOUS' => {
                'desc' => 'Glaucous',
                'out'  => $csi . '38:2:96:130:182m',
            },
            'GLITTER' => {
                'desc' => 'Glitter',
                'out'  => $csi . '38:2:230:232:250m',
            },
            'GOLD' => {
                'desc' => 'Gold',
                'out'  => $csi . '38:2:255:215:0m',
            },
            'GOLDEN BROWN' => {
                'desc' => 'Golden brown',
                'out'  => $csi . '38:2:153:101:21m',
            },
            'GOLDEN POPPY' => {
                'desc' => 'Golden poppy',
                'out'  => $csi . '38:2:252:194:0m',
            },
            'GOLDEN YELLOW' => {
                'desc' => 'Golden yellow',
                'out'  => $csi . '38:2:255:223:0m',
            },
            'GOLDENROD' => {
                'desc' => 'Goldenrod',
                'out'  => $csi . '38:2:218:165:32m',
            },
            'GRANNY SMITH APPLE' => {
                'desc' => 'Granny Smith Apple',
                'out'  => $csi . '38:2:168:228:160m',
            },
            'GRAY' => {
                'desc' => 'Gray',
                'out'  => $csi . '38:2:128:128:128m',
            },
            'GRAY ASPARAGUS' => {
                'desc' => 'Gray asparagus',
                'out'  => $csi . '38:2:70:89:69m',
            },
            'GREEN BLUE' => {
                'desc' => 'Green Blue',
                'out'  => $csi . '38:2:17:100:180m',
            },
            'GREEN YELLOW' => {
                'desc' => 'Green yellow',
                'out'  => $csi . '38:2:173:255:47m',
            },
            'GRULLO' => {
                'desc' => 'Grullo',
                'out'  => $csi . '38:2:169:154:134m',
            },
            'GUPPIE GREEN' => {
                'desc' => 'Guppie green',
                'out'  => $csi . '38:2:0:255:127m',
            },
            'HALAYA UBE' => {
                'desc' => 'Halaya ube',
                'out'  => $csi . '38:2:102:56:84m',
            },
            'HAN BLUE' => {
                'desc' => 'Han blue',
                'out'  => $csi . '38:2:68:108:207m',
            },
            'HAN PURPLE' => {
                'desc' => 'Han purple',
                'out'  => $csi . '38:2:82:24:250m',
            },
            'HANSA YELLOW' => {
                'desc' => 'Hansa yellow',
                'out'  => $csi . '38:2:233:214:107m',
            },
            'HARLEQUIN' => {
                'desc' => 'Harlequin',
                'out'  => $csi . '38:2:63:255:0m',
            },
            'HARVARD CRIMSON' => {
                'desc' => 'Harvard crimson',
                'out'  => $csi . '38:2:201:0:22m',
            },
            'HARVEST GOLD' => {
                'desc' => 'Harvest Gold',
                'out'  => $csi . '38:2:218:145:0m',
            },
            'HEART GOLD' => {
                'desc' => 'Heart Gold',
                'out'  => $csi . '38:2:128:128:0m',
            },
            'HELIOTROPE' => {
                'desc' => 'Heliotrope',
                'out'  => $csi . '38:2:223:115:255m',
            },
            'HOLLYWOOD CERISE' => {
                'desc' => 'Hollywood cerise',
                'out'  => $csi . '38:2:244:0:161m',
            },
            'HONEYDEW' => {
                'desc' => 'Honeydew',
                'out'  => $csi . '38:2:240:255:240m',
            },
            'HOOKER GREEN' => {
                'desc' => 'Hooker green',
                'out'  => $csi . '38:2:73:121:107m',
            },
            'HOT MAGENTA' => {
                'desc' => 'Hot magenta',
                'out'  => $csi . '38:2:255:29:206m',
            },
            'HOT PINK' => {
                'desc' => 'Hot pink',
                'out'  => $csi . '38:2:255:105:180m',
            },
            'HUNTER GREEN' => {
                'desc' => 'Hunter green',
                'out'  => $csi . '38:2:53:94:59m',
            },
            'ICTERINE' => {
                'desc' => 'Icterine',
                'out'  => $csi . '38:2:252:247:94m',
            },
            'INCHWORM' => {
                'desc' => 'Inchworm',
                'out'  => $csi . '38:2:178:236:93m',
            },
            'INDIA GREEN' => {
                'desc' => 'India green',
                'out'  => $csi . '38:2:19:136:8m',
            },
            'INDIAN RED' => {
                'desc' => 'Indian red',
                'out'  => $csi . '38:2:205:92:92m',
            },
            'INDIAN YELLOW' => {
                'desc' => 'Indian yellow',
                'out'  => $csi . '38:2:227:168:87m',
            },
            'INDIGO' => {
                'desc' => 'Indigo',
                'out'  => $csi . '38:2:75:0:130m',
            },
            'INTERNATIONAL KLEIN' => {
                'desc' => 'International Klein',
                'out'  => $csi . '38:2:0:47:167m',
            },
            'INTERNATIONAL ORANGE' => {
                'desc' => 'International orange',
                'out'  => $csi . '38:2:255:79:0m',
            },
            'IRIS' => {
                'desc' => 'Iris',
                'out'  => $csi . '38:2:90:79:207m',
            },
            'ISABELLINE' => {
                'desc' => 'Isabelline',
                'out'  => $csi . '38:2:244:240:236m',
            },
            'ISLAMIC GREEN' => {
                'desc' => 'Islamic green',
                'out'  => $csi . '38:2:0:144:0m',
            },
            'IVORY' => {
                'desc' => 'Ivory',
                'out'  => $csi . '38:2:255:255:240m',
            },
            'JADE' => {
                'desc' => 'Jade',
                'out'  => $csi . '38:2:0:168:107m',
            },
            'JASMINE' => {
                'desc' => 'Jasmine',
                'out'  => $csi . '38:2:248:222:126m',
            },
            'JASPER' => {
                'desc' => 'Jasper',
                'out'  => $csi . '38:2:215:59:62m',
            },
            'JAZZBERRY JAM' => {
                'desc' => 'Jazzberry jam',
                'out'  => $csi . '38:2:165:11:94m',
            },
            'JONQUIL' => {
                'desc' => 'Jonquil',
                'out'  => $csi . '38:2:250:218:94m',
            },
            'JUNE BUD' => {
                'desc' => 'June bud',
                'out'  => $csi . '38:2:189:218:87m',
            },
            'JUNGLE GREEN' => {
                'desc' => 'Jungle green',
                'out'  => $csi . '38:2:41:171:135m',
            },
            'KELLY GREEN' => {
                'desc' => 'Kelly green',
                'out'  => $csi . '38:2:76:187:23m',
            },
            'KHAKI' => {
                'desc' => 'Khaki',
                'out'  => $csi . '38:2:195:176:145m',
            },
            'KU CRIMSON' => {
                'desc' => 'KU Crimson',
                'out'  => $csi . '38:2:232:0:13m',
            },
            'LA SALLE GREEN' => {
                'desc' => 'La Salle Green',
                'out'  => $csi . '38:2:8:120:48m',
            },
            'LANGUID LAVENDER' => {
                'desc' => 'Languid lavender',
                'out'  => $csi . '38:2:214:202:221m',
            },
            'LAPIS LAZULI' => {
                'desc' => 'Lapis lazuli',
                'out'  => $csi . '38:2:38:97:156m',
            },
            'LASER LEMON' => {
                'desc' => 'Laser Lemon',
                'out'  => $csi . '38:2:254:254:34m',
            },
            'LAUREL GREEN' => {
                'desc' => 'Laurel green',
                'out'  => $csi . '38:2:169:186:157m',
            },
            'LAVA' => {
                'desc' => 'Lava',
                'out'  => $csi . '38:2:207:16:32m',
            },
            'LAVENDER' => {
                'desc' => 'Lavender',
                'out'  => $csi . '38:2:230:230:250m',
            },
            'LAVENDER BLUE' => {
                'desc' => 'Lavender blue',
                'out'  => $csi . '38:2:204:204:255m',
            },
            'LAVENDER BLUSH' => {
                'desc' => 'Lavender blush',
                'out'  => $csi . '38:2:255:240:245m',
            },
            'LAVENDER GRAY' => {
                'desc' => 'Lavender gray',
                'out'  => $csi . '38:2:196:195:208m',
            },
            'LAVENDER INDIGO' => {
                'desc' => 'Lavender indigo',
                'out'  => $csi . '38:2:148:87:235m',
            },
            'LAVENDER MAGENTA' => {
                'desc' => 'Lavender magenta',
                'out'  => $csi . '38:2:238:130:238m',
            },
            'LAVENDER MIST' => {
                'desc' => 'Lavender mist',
                'out'  => $csi . '38:2:230:230:250m',
            },
            'LAVENDER PINK' => {
                'desc' => 'Lavender pink',
                'out'  => $csi . '38:2:251:174:210m',
            },
            'LAVENDER PURPLE' => {
                'desc' => 'Lavender purple',
                'out'  => $csi . '38:2:150:123:182m',
            },
            'LAVENDER ROSE' => {
                'desc' => 'Lavender rose',
                'out'  => $csi . '38:2:251:160:227m',
            },
            'LAWN GREEN' => {
                'desc' => 'Lawn green',
                'out'  => $csi . '38:2:124:252:0m',
            },
            'LEMON' => {
                'desc' => 'Lemon',
                'out'  => $csi . '38:2:255:247:0m',
            },
            'LEMON CHIFFON' => {
                'desc' => 'Lemon chiffon',
                'out'  => $csi . '38:2:255:250:205m',
            },
            'LEMON LIME' => {
                'desc' => 'Lemon lime',
                'out'  => $csi . '38:2:191:255:0m',
            },
            'LEMON YELLOW' => {
                'desc' => 'Lemon Yellow',
                'out'  => $csi . '38:2:255:244:79m',
            },
            'LIGHT APRICOT' => {
                'desc' => 'Light apricot',
                'out'  => $csi . '38:2:253:213:177m',
            },
            'LIGHT BLUE' => {
                'desc' => 'Light blue',
                'out'  => $csi . '38:2:173:216:230m',
            },
            'LIGHT BROWN' => {
                'desc' => 'Light brown',
                'out'  => $csi . '38:2:181:101:29m',
            },
            'LIGHT CARMINE PINK' => {
                'desc' => 'Light carmine pink',
                'out'  => $csi . '38:2:230:103:113m',
            },
            'LIGHT CORAL' => {
                'desc' => 'Light coral',
                'out'  => $csi . '38:2:240:128:128m',
            },
            'LIGHT CORNFLOWER BLUE' => {
                'desc' => 'Light cornflower blue',
                'out'  => $csi . '38:2:147:204:234m',
            },
            'LIGHT CRIMSON' => {
                'desc' => 'Light Crimson',
                'out'  => $csi . '38:2:245:105:145m',
            },
            'LIGHT CYAN' => {
                'desc' => 'Light cyan',
                'out'  => $csi . '38:2:224:255:255m',
            },
            'LIGHT FUCHSIA PINK' => {
                'desc' => 'Light fuchsia pink',
                'out'  => $csi . '38:2:249:132:239m',
            },
            'LIGHT GOLDENROD YELLOW' => {
                'desc' => 'Light goldenrod yellow',
                'out'  => $csi . '38:2:250:250:210m',
            },
            'LIGHT GRAY' => {
                'desc' => 'Light gray',
                'out'  => $csi . '38:2:211:211:211m',
            },
            'LIGHT GREEN' => {
                'desc' => 'Light green',
                'out'  => $csi . '38:2:144:238:144m',
            },
            'LIGHT KHAKI' => {
                'desc' => 'Light khaki',
                'out'  => $csi . '38:2:240:230:140m',
            },
            'LIGHT PASTEL PURPLE' => {
                'desc' => 'Light pastel purple',
                'out'  => $csi . '38:2:177:156:217m',
            },
            'LIGHT PINK' => {
                'desc' => 'Light pink',
                'out'  => $csi . '38:2:255:182:193m',
            },
            'LIGHT SALMON' => {
                'desc' => 'Light salmon',
                'out'  => $csi . '38:2:255:160:122m',
            },
            'LIGHT SALMON PINK' => {
                'desc' => 'Light salmon pink',
                'out'  => $csi . '38:2:255:153:153m',
            },
            'LIGHT SEA GREEN' => {
                'desc' => 'Light sea green',
                'out'  => $csi . '38:2:32:178:170m',
            },
            'LIGHT SKY BLUE' => {
                'desc' => 'Light sky blue',
                'out'  => $csi . '38:2:135:206:250m',
            },
            'LIGHT SLATE GRAY' => {
                'desc' => 'Light slate gray',
                'out'  => $csi . '38:2:119:136:153m',
            },
            'LIGHT TAUPE' => {
                'desc' => 'Light taupe',
                'out'  => $csi . '38:2:179:139:109m',
            },
            'LIGHT THULIAN PINK' => {
                'desc' => 'Light Thulian pink',
                'out'  => $csi . '38:2:230:143:172m',
            },
            'LIGHT YELLOW' => {
                'desc' => 'Light yellow',
                'out'  => $csi . '38:2:255:255:237m',
            },
            'LILAC' => {
                'desc' => 'Lilac',
                'out'  => $csi . '38:2:200:162:200m',
            },
            'LIME' => {
                'desc' => 'Lime',
                'out'  => $csi . '38:2:191:255:0m',
            },
            'LIME GREEN' => {
                'desc' => 'Lime green',
                'out'  => $csi . '38:2:50:205:50m',
            },
            'LINCOLN GREEN' => {
                'desc' => 'Lincoln green',
                'out'  => $csi . '38:2:25:89:5m',
            },
            'LINEN' => {
                'desc' => 'Linen',
                'out'  => $csi . '38:2:250:240:230m',
            },
            'LION' => {
                'desc' => 'Lion',
                'out'  => $csi . '38:2:193:154:107m',
            },
            'LIVER' => {
                'desc' => 'Liver',
                'out'  => $csi . '38:2:83:75:79m',
            },
            'LUST' => {
                'desc' => 'Lust',
                'out'  => $csi . '38:2:230:32:32m',
            },
            'MACARONI AND CHEESE' => {
                'desc' => 'Macaroni and Cheese',
                'out'  => $csi . '38:2:255:189:136m',
            },
            'MAGIC MINT' => {
                'desc' => 'Magic mint',
                'out'  => $csi . '38:2:170:240:209m',
            },
            'MAGNOLIA' => {
                'desc' => 'Magnolia',
                'out'  => $csi . '38:2:248:244:255m',
            },
            'MAHOGANY' => {
                'desc' => 'Mahogany',
                'out'  => $csi . '38:2:192:64:0m',
            },
            'MAIZE' => {
                'desc' => 'Maize',
                'out'  => $csi . '38:2:251:236:93m',
            },
            'MAJORELLE BLUE' => {
                'desc' => 'Majorelle Blue',
                'out'  => $csi . '38:2:96:80:220m',
            },
            'MALACHITE' => {
                'desc' => 'Malachite',
                'out'  => $csi . '38:2:11:218:81m',
            },
            'MANATEE' => {
                'desc' => 'Manatee',
                'out'  => $csi . '38:2:151:154:170m',
            },
            'MANGO TANGO' => {
                'desc' => 'Mango Tango',
                'out'  => $csi . '38:2:255:130:67m',
            },
            'MANTIS' => {
                'desc' => 'Mantis',
                'out'  => $csi . '38:2:116:195:101m',
            },
            'MAROON' => {
                'desc' => 'Maroon',
                'out'  => $csi . '38:2:128:0:0m',
            },
            'MAUVE' => {
                'desc' => 'Mauve',
                'out'  => $csi . '38:2:224:176:255m',
            },
            'MAUVE TAUPE' => {
                'desc' => 'Mauve taupe',
                'out'  => $csi . '38:2:145:95:109m',
            },
            'MAUVELOUS' => {
                'desc' => 'Mauvelous',
                'out'  => $csi . '38:2:239:152:170m',
            },
            'MAYA BLUE' => {
                'desc' => 'Maya blue',
                'out'  => $csi . '38:2:115:194:251m',
            },
            'MEAT BROWN' => {
                'desc' => 'Meat brown',
                'out'  => $csi . '38:2:229:183:59m',
            },
            'MEDIUM AQUAMARINE' => {
                'desc' => 'Medium aquamarine',
                'out'  => $csi . '38:2:102:221:170m',
            },
            'MEDIUM BLUE' => {
                'desc' => 'Medium blue',
                'out'  => $csi . '38:2:0:0:205m',
            },
            'MEDIUM CANDY APPLE RED' => {
                'desc' => 'Medium candy apple red',
                'out'  => $csi . '38:2:226:6:44m',
            },
            'MEDIUM CARMINE' => {
                'desc' => 'Medium carmine',
                'out'  => $csi . '38:2:175:64:53m',
            },
            'MEDIUM CHAMPAGNE' => {
                'desc' => 'Medium champagne',
                'out'  => $csi . '38:2:243:229:171m',
            },
            'MEDIUM ELECTRIC BLUE' => {
                'desc' => 'Medium electric blue',
                'out'  => $csi . '38:2:3:80:150m',
            },
            'MEDIUM JUNGLE GREEN' => {
                'desc' => 'Medium jungle green',
                'out'  => $csi . '38:2:28:53:45m',
            },
            'MEDIUM LAVENDER MAGENTA' => {
                'desc' => 'Medium lavender magenta',
                'out'  => $csi . '38:2:221:160:221m',
            },
            'MEDIUM ORCHID' => {
                'desc' => 'Medium orchid',
                'out'  => $csi . '38:2:186:85:211m',
            },
            'MEDIUM PERSIAN BLUE' => {
                'desc' => 'Medium Persian blue',
                'out'  => $csi . '38:2:0:103:165m',
            },
            'MEDIUM PURPLE' => {
                'desc' => 'Medium purple',
                'out'  => $csi . '38:2:147:112:219m',
            },
            'MEDIUM RED VIOLET' => {
                'desc' => 'Medium red violet',
                'out'  => $csi . '38:2:187:51:133m',
            },
            'MEDIUM SEA GREEN' => {
                'desc' => 'Medium sea green',
                'out'  => $csi . '38:2:60:179:113m',
            },
            'MEDIUM SLATE BLUE' => {
                'desc' => 'Medium slate blue',
                'out'  => $csi . '38:2:123:104:238m',
            },
            'MEDIUM SPRING BUD' => {
                'desc' => 'Medium spring bud',
                'out'  => $csi . '38:2:201:220:135m',
            },
            'MEDIUM SPRING GREEN' => {
                'desc' => 'Medium spring green',
                'out'  => $csi . '38:2:0:250:154m',
            },
            'MEDIUM TAUPE' => {
                'desc' => 'Medium taupe',
                'out'  => $csi . '38:2:103:76:71m',
            },
            'MEDIUM TEAL BLUE' => {
                'desc' => 'Medium teal blue',
                'out'  => $csi . '38:2:0:84:180m',
            },
            'MEDIUM TURQUOISE' => {
                'desc' => 'Medium turquoise',
                'out'  => $csi . '38:2:72:209:204m',
            },
            'MEDIUM VIOLET RED' => {
                'desc' => 'Medium violet red',
                'out'  => $csi . '38:2:199:21:133m',
            },
            'MELON' => {
                'desc' => 'Melon',
                'out'  => $csi . '38:2:253:188:180m',
            },
            'MIDNIGHT BLUE' => {
                'desc' => 'Midnight blue',
                'out'  => $csi . '38:2:25:25:112m',
            },
            'MIDNIGHT GREEN' => {
                'desc' => 'Midnight green',
                'out'  => $csi . '38:2:0:73:83m',
            },
            'MIKADO YELLOW' => {
                'desc' => 'Mikado yellow',
                'out'  => $csi . '38:2:255:196:12m',
            },
            'MINT' => {
                'desc' => 'Mint',
                'out'  => $csi . '38:2:62:180:137m',
            },
            'MINT CREAM' => {
                'desc' => 'Mint cream',
                'out'  => $csi . '38:2:245:255:250m',
            },
            'MINT GREEN' => {
                'desc' => 'Mint green',
                'out'  => $csi . '38:2:152:255:152m',
            },
            'MISTY ROSE' => {
                'desc' => 'Misty rose',
                'out'  => $csi . '38:2:255:228:225m',
            },
            'MOCCASIN' => {
                'desc' => 'Moccasin',
                'out'  => $csi . '38:2:250:235:215m',
            },
            'MODE BEIGE' => {
                'desc' => 'Mode beige',
                'out'  => $csi . '38:2:150:113:23m',
            },
            'MOONSTONE BLUE' => {
                'desc' => 'Moonstone blue',
                'out'  => $csi . '38:2:115:169:194m',
            },
            'MORDANT RED 19' => {
                'desc' => 'Mordant red 19',
                'out'  => $csi . '38:2:174:12:0m',
            },
            'MOSS GREEN' => {
                'desc' => 'Moss green',
                'out'  => $csi . '38:2:173:223:173m',
            },
            'MOUNTAIN MEADOW' => {
                'desc' => 'Mountain Meadow',
                'out'  => $csi . '38:2:48:186:143m',
            },
            'MOUNTBATTEN PINK' => {
                'desc' => 'Mountbatten pink',
                'out'  => $csi . '38:2:153:122:141m',
            },
            'MSU GREEN' => {
                'desc' => 'MSU Green',
                'out'  => $csi . '38:2:24:69:59m',
            },
            'MULBERRY' => {
                'desc' => 'Mulberry',
                'out'  => $csi . '38:2:197:75:140m',
            },
            'MUNSELL' => {
                'desc' => 'Munsell',
                'out'  => $csi . '38:2:242:243:244m',
            },
            'MUSTARD' => {
                'desc' => 'Mustard',
                'out'  => $csi . '38:2:255:219:88m',
            },
            'MYRTLE' => {
                'desc' => 'Myrtle',
                'out'  => $csi . '38:2:33:66:30m',
            },
            'NADESHIKO PINK' => {
                'desc' => 'Nadeshiko pink',
                'out'  => $csi . '38:2:246:173:198m',
            },
            'NAPIER GREEN' => {
                'desc' => 'Napier green',
                'out'  => $csi . '38:2:42:128:0m',
            },
            'NAPLES YELLOW' => {
                'desc' => 'Naples yellow',
                'out'  => $csi . '38:2:250:218:94m',
            },
            'NAVAJO WHITE' => {
                'desc' => 'Navajo white',
                'out'  => $csi . '38:2:255:222:173m',
            },
            'NAVY BLUE' => {
                'desc' => 'Navy blue',
                'out'  => $csi . '38:2:0:0:128m',
            },
            'NEON CARROT' => {
                'desc' => 'Neon Carrot',
                'out'  => $csi . '38:2:255:163:67m',
            },
            'NEON FUCHSIA' => {
                'desc' => 'Neon fuchsia',
                'out'  => $csi . '38:2:254:89:194m',
            },
            'NEON GREEN' => {
                'desc' => 'Neon green',
                'out'  => $csi . '38:2:57:255:20m',
            },
            'NON-PHOTO BLUE' => {
                'desc' => 'Non-photo blue',
                'out'  => $csi . '38:2:164:221:237m',
            },
            'NORTH TEXAS GREEN' => {
                'desc' => 'North Texas Green',
                'out'  => $csi . '38:2:5:144:51m',
            },
            'OCEAN BOAT BLUE' => {
                'desc' => 'Ocean Boat Blue',
                'out'  => $csi . '38:2:0:119:190m',
            },
            'OCHRE' => {
                'desc' => 'Ochre',

                'out' => $csi . '38:2:204:119:34m',
            },
            'OFFICE GREEN' => {
                'desc' => 'Office green',

                'out' => $csi . '38:2:0:128:0m',
            },
            'OLD GOLD' => {
                'desc' => 'Old gold',

                'out' => $csi . '38:2:207:181:59m',
            },
            'OLD LACE' => {
                'desc' => 'Old lace',

                'out' => $csi . '38:2:253:245:230m',
            },
            'OLD LAVENDER' => {
                'desc' => 'Old lavender',

                'out' => $csi . '38:2:121:104:120m',
            },
            'OLD MAUVE' => {
                'desc' => 'Old mauve',

                'out' => $csi . '38:2:103:49:71m',
            },
            'OLD ROSE' => {
                'desc' => 'Old rose',

                'out' => $csi . '38:2:192:128:129m',
            },
            'OLIVE' => {
                'desc' => 'Olive',

                'out' => $csi . '38:2:128:128:0m',
            },
            'OLIVE DRAB' => {
                'desc' => 'Olive Drab',

                'out' => $csi . '38:2:107:142:35m',
            },
            'OLIVE GREEN' => {
                'desc' => 'Olive Green',

                'out' => $csi . '38:2:186:184:108m',
            },
            'OLIVINE' => {
                'desc' => 'Olivine',

                'out' => $csi . '38:2:154:185:115m',
            },
            'ONYX' => {
                'desc' => 'Onyx',

                'out' => $csi . '38:2:15:15:15m',
            },
            'OPERA MAUVE' => {
                'desc' => 'Opera mauve',

                'out' => $csi . '38:2:183:132:167m',
            },
            'ORANGE PEEL' => {
                'desc' => 'Orange peel',

                'out' => $csi . '38:2:255:159:0m',
            },
            'ORANGE RED' => {
                'desc' => 'Orange red',

                'out' => $csi . '38:2:255:69:0m',
            },
            'ORANGE YELLOW' => {
                'desc' => 'Orange Yellow',

                'out' => $csi . '38:2:248:213:104m',
            },
            'ORCHID' => {
                'desc' => 'Orchid',

                'out' => $csi . '38:2:218:112:214m',
            },
            'OTTER BROWN' => {
                'desc' => 'Otter brown',

                'out' => $csi . '38:2:101:67:33m',
            },
            'OUTER SPACE' => {
                'desc' => 'Outer Space',

                'out' => $csi . '38:2:65:74:76m',
            },
            'OUTRAGEOUS ORANGE' => {
                'desc' => 'Outrageous Orange',

                'out' => $csi . '38:2:255:110:74m',
            },
            'OXFORD BLUE' => {
                'desc' => 'Oxford Blue',

                'out' => $csi . '38:2:0:33:71m',
            },
            'PACIFIC BLUE' => {
                'desc' => 'Pacific Blue',

                'out' => $csi . '38:2:28:169:201m',
            },
            'PAKISTAN GREEN' => {
                'desc' => 'Pakistan green',

                'out' => $csi . '38:2:0:102:0m',
            },
            'PALATINATE BLUE' => {
                'desc' => 'Palatinate blue',

                'out' => $csi . '38:2:39:59:226m',
            },
            'PALATINATE PURPLE' => {
                'desc' => 'Palatinate purple',

                'out' => $csi . '38:2:104:40:96m',
            },
            'PALE AQUA' => {
                'desc' => 'Pale aqua',

                'out' => $csi . '38:2:188:212:230m',
            },
            'PALE BLUE' => {
                'desc' => 'Pale blue',

                'out' => $csi . '38:2:175:238:238m',
            },
            'PALE BROWN' => {
                'desc' => 'Pale brown',

                'out' => $csi . '38:2:152:118:84m',
            },
            'PALE CARMINE' => {
                'desc' => 'Pale carmine',

                'out' => $csi . '38:2:175:64:53m',
            },
            'PALE CERULEAN' => {
                'desc' => 'Pale cerulean',

                'out' => $csi . '38:2:155:196:226m',
            },
            'PALE CHESTNUT' => {
                'desc' => 'Pale chestnut',

                'out' => $csi . '38:2:221:173:175m',
            },
            'PALE COPPER' => {
                'desc' => 'Pale copper',

                'out' => $csi . '38:2:218:138:103m',
            },
            'PALE CORNFLOWER BLUE' => {
                'desc' => 'Pale cornflower blue',

                'out' => $csi . '38:2:171:205:239m',
            },
            'PALE GOLD' => {
                'desc' => 'Pale gold',

                'out' => $csi . '38:2:230:190:138m',
            },
            'PALE GOLDENROD' => {
                'desc' => 'Pale goldenrod',

                'out' => $csi . '38:2:238:232:170m',
            },
            'PALE GREEN' => {
                'desc' => 'Pale green',

                'out' => $csi . '38:2:152:251:152m',
            },
            'PALE LAVENDER' => {
                'desc' => 'Pale lavender',

                'out' => $csi . '38:2:220:208:255m',
            },
            'PALE MAGENTA' => {
                'desc' => 'Pale magenta',

                'out' => $csi . '38:2:249:132:229m',
            },
            'PALE PINK' => {
                'desc' => 'Pale pink',

                'out' => $csi . '38:2:250:218:221m',
            },
            'PALE PLUM' => {
                'desc' => 'Pale plum',

                'out' => $csi . '38:2:221:160:221m',
            },
            'PALE RED VIOLET' => {
                'desc' => 'Pale red violet',

                'out' => $csi . '38:2:219:112:147m',
            },
            'PALE ROBIN EGG BLUE' => {
                'desc' => 'Pale robin egg blue',

                'out' => $csi . '38:2:150:222:209m',
            },
            'PALE SILVER' => {
                'desc' => 'Pale silver',

                'out' => $csi . '38:2:201:192:187m',
            },
            'PALE SPRING BUD' => {
                'desc' => 'Pale spring bud',

                'out' => $csi . '38:2:236:235:189m',
            },
            'PALE TAUPE' => {
                'desc' => 'Pale taupe',

                'out' => $csi . '38:2:188:152:126m',
            },
            'PALE VIOLET RED' => {
                'desc' => 'Pale violet red',

                'out' => $csi . '38:2:219:112:147m',
            },
            'PANSY PURPLE' => {
                'desc' => 'Pansy purple',

                'out' => $csi . '38:2:120:24:74m',
            },
            'PAPAYA WHIP' => {
                'desc' => 'Papaya whip',

                'out' => $csi . '38:2:255:239:213m',
            },
            'PARIS GREEN' => {
                'desc' => 'Paris Green',

                'out' => $csi . '38:2:80:200:120m',
            },
            'PASTEL BLUE' => {
                'desc' => 'Pastel blue',

                'out' => $csi . '38:2:174:198:207m',
            },
            'PASTEL BROWN' => {
                'desc' => 'Pastel brown',

                'out' => $csi . '38:2:131:105:83m',
            },
            'PASTEL GRAY' => {
                'desc' => 'Pastel gray',

                'out' => $csi . '38:2:207:207:196m',
            },
            'PASTEL GREEN' => {
                'desc' => 'Pastel green',

                'out' => $csi . '38:2:119:221:119m',
            },
            'PASTEL MAGENTA' => {
                'desc' => 'Pastel magenta',

                'out' => $csi . '38:2:244:154:194m',
            },
            'PASTEL ORANGE' => {
                'desc' => 'Pastel orange',

                'out' => $csi . '38:2:255:179:71m',
            },
            'PASTEL PINK' => {
                'desc' => 'Pastel pink',

                'out' => $csi . '38:2:255:209:220m',
            },
            'PASTEL PURPLE' => {
                'desc' => 'Pastel purple',

                'out' => $csi . '38:2:179:158:181m',
            },
            'PASTEL RED' => {
                'desc' => 'Pastel red',

                'out' => $csi . '38:2:255:105:97m',
            },
            'PASTEL VIOLET' => {
                'desc' => 'Pastel violet',

                'out' => $csi . '38:2:203:153:201m',
            },
            'PASTEL YELLOW' => {
                'desc' => 'Pastel yellow',

                'out' => $csi . '38:2:253:253:150m',
            },
            'PATRIARCH' => {
                'desc' => 'Patriarch',

                'out' => $csi . '38:2:128:0:128m',
            },
            'PAYNE GRAY' => {
                'desc' => 'Payne grey',

                'out' => $csi . '38:2:83:104:120m',
            },
            'PEACH' => {
                'desc' => 'Peach',

                'out' => $csi . '38:2:255:229:180m',
            },
            'PEACH PUFF' => {
                'desc' => 'Peach puff',

                'out' => $csi . '38:2:255:218:185m',
            },
            'PEACH YELLOW' => {
                'desc' => 'Peach yellow',

                'out' => $csi . '38:2:250:223:173m',
            },
            'PEAR' => {
                'desc' => 'Pear',

                'out' => $csi . '38:2:209:226:49m',
            },
            'PEARL' => {
                'desc' => 'Pearl',

                'out' => $csi . '38:2:234:224:200m',
            },
            'PEARL AQUA' => {
                'desc' => 'Pearl Aqua',

                'out' => $csi . '38:2:136:216:192m',
            },
            'PERIDOT' => {
                'desc' => 'Peridot',

                'out' => $csi . '38:2:230:226:0m',
            },
            'PERIWINKLE' => {
                'desc' => 'Periwinkle',

                'out' => $csi . '38:2:204:204:255m',
            },
            'PERSIAN BLUE' => {
                'desc' => 'Persian blue',

                'out' => $csi . '38:2:28:57:187m',
            },
            'PERSIAN INDIGO' => {
                'desc' => 'Persian indigo',

                'out' => $csi . '38:2:50:18:122m',
            },
            'PERSIAN ORANGE' => {
                'desc' => 'Persian orange',

                'out' => $csi . '38:2:217:144:88m',
            },
            'PERSIAN PINK' => {
                'desc' => 'Persian pink',

                'out' => $csi . '38:2:247:127:190m',
            },
            'PERSIAN PLUM' => {
                'desc' => 'Persian plum',

                'out' => $csi . '38:2:112:28:28m',
            },
            'PERSIAN RED' => {
                'desc' => 'Persian red',

                'out' => $csi . '38:2:204:51:51m',
            },
            'PERSIAN ROSE' => {
                'desc' => 'Persian rose',

                'out' => $csi . '38:2:254:40:162m',
            },
            'PHLOX' => {
                'desc' => 'Phlox',

                'out' => $csi . '38:2:223:0:255m',
            },
            'PHTHALO BLUE' => {
                'desc' => 'Phthalo blue',

                'out' => $csi . '38:2:0:15:137m',
            },
            'PHTHALO GREEN' => {
                'desc' => 'Phthalo green',

                'out' => $csi . '38:2:18:53:36m',
            },
            'PIGGY PINK' => {
                'desc' => 'Piggy pink',

                'out' => $csi . '38:2:253:221:230m',
            },
            'PINE GREEN' => {
                'desc' => 'Pine green',

                'out' => $csi . '38:2:1:121:111m',
            },
            'PINK FLAMINGO' => {
                'desc' => 'Pink Flamingo',

                'out' => $csi . '38:2:252:116:253m',
            },
            'PINK PEARL' => {
                'desc' => 'Pink pearl',

                'out' => $csi . '38:2:231:172:207m',
            },
            'PINK SHERBET' => {
                'desc' => 'Pink Sherbet',

                'out' => $csi . '38:2:247:143:167m',
            },
            'PISTACHIO' => {
                'desc' => 'Pistachio',

                'out' => $csi . '38:2:147:197:114m',
            },
            'PLATINUM' => {
                'desc' => 'Platinum',

                'out' => $csi . '38:2:229:228:226m',
            },
            'PLUM' => {
                'desc' => 'Plum',

                'out' => $csi . '38:2:221:160:221m',
            },
            'PORTLAND ORANGE' => {
                'desc' => 'Portland Orange',

                'out' => $csi . '38:2:255:90:54m',
            },
            'POWDER BLUE' => {
                'desc' => 'Powder blue',

                'out' => $csi . '38:2:176:224:230m',
            },
            'PRINCETON ORANGE' => {
                'desc' => 'Princeton orange',

                'out' => $csi . '38:2:255:143:0m',
            },
            'PRUSSIAN BLUE' => {
                'desc' => 'Prussian blue',

                'out' => $csi . '38:2:0:49:83m',
            },
            'PSYCHEDELIC PURPLE' => {
                'desc' => 'Psychedelic purple',

                'out' => $csi . '38:2:223:0:255m',
            },
            'PUCE' => {
                'desc' => 'Puce',

                'out' => $csi . '38:2:204:136:153m',
            },
            'PUMPKIN' => {
                'desc' => 'Pumpkin',

                'out' => $csi . '38:2:255:117:24m',
            },
            'PURPLE' => {
                'desc' => 'Purple',

                'out' => $csi . '38:2:128:0:128m',
            },
            'PURPLE HEART' => {
                'desc' => 'Purple Heart',

                'out' => $csi . '38:2:105:53:156m',
            },
            'PURPLE MOUNTAIN MAJESTY' => {
                'desc' => 'Purple mountain majesty',

                'out' => $csi . '38:2:150:120:182m',
            },
            'PURPLE MOUNTAINS' => {
                'desc' => 'Purple Mountains',

                'out' => $csi . '38:2:157:129:186m',
            },
            'PURPLE PIZZAZZ' => {
                'desc' => 'Purple pizzazz',

                'out' => $csi . '38:2:254:78:218m',
            },
            'PURPLE TAUPE' => {
                'desc' => 'Purple taupe',

                'out' => $csi . '38:2:80:64:77m',
            },
            'RACKLEY' => {
                'desc' => 'Rackley',

                'out' => $csi . '38:2:93:138:168m',
            },
            'RADICAL RED' => {
                'desc' => 'Radical Red',

                'out' => $csi . '38:2:255:53:94m',
            },
            'RASPBERRY' => {
                'desc' => 'Raspberry',

                'out' => $csi . '38:2:227:11:93m',
            },
            'RASPBERRY GLACE' => {
                'desc' => 'Raspberry glace',

                'out' => $csi . '38:2:145:95:109m',
            },
            'RASPBERRY PINK' => {
                'desc' => 'Raspberry pink',

                'out' => $csi . '38:2:226:80:152m',
            },
            'RASPBERRY ROSE' => {
                'desc' => 'Raspberry rose',

                'out' => $csi . '38:2:179:68:108m',
            },
            'RAW SIENNA' => {
                'desc' => 'Raw Sienna',

                'out' => $csi . '38:2:214:138:89m',
            },
            'RAZZLE DAZZLE ROSE' => {
                'desc' => 'Razzle dazzle rose',

                'out' => $csi . '38:2:255:51:204m',
            },
            'RAZZMATAZZ' => {
                'desc' => 'Razzmatazz',

                'out' => $csi . '38:2:227:37:107m',
            },
            'RED BROWN' => {
                'desc' => 'Red brown',

                'out' => $csi . '38:2:165:42:42m',
            },
            'RED ORANGE' => {
                'desc' => 'Red Orange',

                'out' => $csi . '38:2:255:83:73m',
            },
            'RED VIOLET' => {
                'desc' => 'Red violet',

                'out' => $csi . '38:2:199:21:133m',
            },
            'RICH BLACK' => {
                'desc' => 'Rich black',

                'out' => $csi . '38:2:0:64:64m',
            },
            'RICH CARMINE' => {
                'desc' => 'Rich carmine',

                'out' => $csi . '38:2:215:0:64m',
            },
            'RICH ELECTRIC BLUE' => {
                'desc' => 'Rich electric blue',

                'out' => $csi . '38:2:8:146:208m',
            },
            'RICH LILAC' => {
                'desc' => 'Rich lilac',

                'out' => $csi . '38:2:182:102:210m',
            },
            'RICH MAROON' => {
                'desc' => 'Rich maroon',

                'out' => $csi . '38:2:176:48:96m',
            },
            'RIFLE GREEN' => {
                'desc' => 'Rifle green',

                'out' => $csi . '38:2:65:72:51m',
            },
            'ROBINS EGG BLUE' => {
                'desc' => 'Robins Egg Blue',

                'out' => $csi . '38:2:31:206:203m',
            },
            'ROSE' => {
                'desc' => 'Rose',

                'out' => $csi . '38:2:255:0:127m',
            },
            'ROSE BONBON' => {
                'desc' => 'Rose bonbon',

                'out' => $csi . '38:2:249:66:158m',
            },
            'ROSE EBONY' => {
                'desc' => 'Rose ebony',

                'out' => $csi . '38:2:103:72:70m',
            },
            'ROSE GOLD' => {
                'desc' => 'Rose gold',

                'out' => $csi . '38:2:183:110:121m',
            },
            'ROSE MADDER' => {
                'desc' => 'Rose madder',

                'out' => $csi . '38:2:227:38:54m',
            },
            'ROSE PINK' => {
                'desc' => 'Rose pink',

                'out' => $csi . '38:2:255:102:204m',
            },
            'ROSE QUARTZ' => {
                'desc' => 'Rose quartz',

                'out' => $csi . '38:2:170:152:169m',
            },
            'ROSE TAUPE' => {
                'desc' => 'Rose taupe',

                'out' => $csi . '38:2:144:93:93m',
            },
            'ROSE VALE' => {
                'desc' => 'Rose vale',

                'out' => $csi . '38:2:171:78:82m',
            },
            'ROSEWOOD' => {
                'desc' => 'Rosewood',

                'out' => $csi . '38:2:101:0:11m',
            },
            'ROSSO CORSA' => {
                'desc' => 'Rosso corsa',

                'out' => $csi . '38:2:212:0:0m',
            },
            'ROSY BROWN' => {
                'desc' => 'Rosy brown',

                'out' => $csi . '38:2:188:143:143m',
            },
            'ROYAL AZURE' => {
                'desc' => 'Royal azure',

                'out' => $csi . '38:2:0:56:168m',
            },
            'ROYAL BLUE' => {
                'desc' => 'Royal blue',

                'out' => $csi . '38:2:65:105:225m',
            },
            'ROYAL FUCHSIA' => {
                'desc' => 'Royal fuchsia',

                'out' => $csi . '38:2:202:44:146m',
            },
            'ROYAL PURPLE' => {
                'desc' => 'Royal purple',

                'out' => $csi . '38:2:120:81:169m',
            },
            'RUBY' => {
                'desc' => 'Ruby',

                'out' => $csi . '38:2:224:17:95m',
            },
            'RUDDY' => {
                'desc' => 'Ruddy',

                'out' => $csi . '38:2:255:0:40m',
            },
            'RUDDY BROWN' => {
                'desc' => 'Ruddy brown',

                'out' => $csi . '38:2:187:101:40m',
            },
            'RUDDY PINK' => {
                'desc' => 'Ruddy pink',

                'out' => $csi . '38:2:225:142:150m',
            },
            'RUFOUS' => {
                'desc' => 'Rufous',

                'out' => $csi . '38:2:168:28:7m',
            },
            'RUSSET' => {
                'desc' => 'Russet',

                'out' => $csi . '38:2:128:70:27m',
            },
            'RUST' => {
                'desc' => 'Rust',

                'out' => $csi . '38:2:183:65:14m',
            },
            'SACRAMENTO STATE GREEN' => {
                'desc' => 'Sacramento State green',

                'out' => $csi . '38:2:0:86:63m',
            },
            'SADDLE BROWN' => {
                'desc' => 'Saddle brown',

                'out' => $csi . '38:2:139:69:19m',
            },
            'SAFETY ORANGE' => {
                'desc' => 'Safety orange',

                'out' => $csi . '38:2:255:103:0m',
            },
            'SAFFRON' => {
                'desc' => 'Saffron',

                'out' => $csi . '38:2:244:196:48m',
            },
            'SAINT PATRICK BLUE' => {
                'desc' => 'Saint Patrick Blue',

                'out' => $csi . '38:2:35:41:122m',
            },
            'SALMON' => {
                'desc' => 'Salmon',

                'out' => $csi . '38:2:255:140:105m',
            },
            'SALMON PINK' => {
                'desc' => 'Salmon pink',

                'out' => $csi . '38:2:255:145:164m',
            },
            'SAND' => {
                'desc' => 'Sand',

                'out' => $csi . '38:2:194:178:128m',
            },
            'SAND DUNE' => {
                'desc' => 'Sand dune',

                'out' => $csi . '38:2:150:113:23m',
            },
            'SANDSTORM' => {
                'desc' => 'Sandstorm',

                'out' => $csi . '38:2:236:213:64m',
            },
            'SANDY BROWN' => {
                'desc' => 'Sandy brown',

                'out' => $csi . '38:2:244:164:96m',
            },
            'SANDY TAUPE' => {
                'desc' => 'Sandy taupe',

                'out' => $csi . '38:2:150:113:23m',
            },
            'SAP GREEN' => {
                'desc' => 'Sap green',

                'out' => $csi . '38:2:80:125:42m',
            },
            'SAPPHIRE' => {
                'desc' => 'Sapphire',

                'out' => $csi . '38:2:15:82:186m',
            },
            'SATIN SHEEN GOLD' => {
                'desc' => 'Satin sheen gold',

                'out' => $csi . '38:2:203:161:53m',
            },
            'SCARLET' => {
                'desc' => 'Scarlet',

                'out' => $csi . '38:2:255:36:0m',
            },
            'SCHOOL BUS YELLOW' => {
                'desc' => 'School bus yellow',

                'out' => $csi . '38:2:255:216:0m',
            },
            'SCREAMIN GREEN' => {
                'desc' => 'Screamin Green',

                'out' => $csi . '38:2:118:255:122m',
            },
            'SEA BLUE' => {
                'desc' => 'Sea blue',

                'out' => $csi . '38:2:0:105:148m',
            },
            'SEA GREEN' => {
                'desc' => 'Sea green',

                'out' => $csi . '38:2:46:139:87m',
            },
            'SEAL BROWN' => {
                'desc' => 'Seal brown',

                'out' => $csi . '38:2:50:20:20m',
            },
            'SEASHELL' => {
                'desc' => 'Seashell',

                'out' => $csi . '38:2:255:245:238m',
            },
            'SELECTIVE YELLOW' => {
                'desc' => 'Selective yellow',

                'out' => $csi . '38:2:255:186:0m',
            },
            'SEPIA' => {
                'desc' => 'Sepia',

                'out' => $csi . '38:2:112:66:20m',
            },
            'SHADOW' => {
                'desc' => 'Shadow',

                'out' => $csi . '38:2:138:121:93m',
            },
            'SHAMROCK' => {
                'desc' => 'Shamrock',

                'out' => $csi . '38:2:69:206:162m',
            },
            'SHAMROCK GREEN' => {
                'desc' => 'Shamrock green',

                'out' => $csi . '38:2:0:158:96m',
            },
            'SHOCKING PINK' => {
                'desc' => 'Shocking pink',

                'out' => $csi . '38:2:252:15:192m',
            },
            'SIENNA' => {
                'desc' => 'Sienna',

                'out' => $csi . '38:2:136:45:23m',
            },
            'SILVER' => {
                'desc' => 'Silver',

                'out' => $csi . '38:2:192:192:192m',
            },
            'SINOPIA' => {
                'desc' => 'Sinopia',

                'out' => $csi . '38:2:203:65:11m',
            },
            'SKOBELOFF' => {
                'desc' => 'Skobeloff',

                'out' => $csi . '38:2:0:116:116m',
            },
            'SKY BLUE' => {
                'desc' => 'Sky blue',

                'out' => $csi . '38:2:135:206:235m',
            },
            'SKY MAGENTA' => {
                'desc' => 'Sky magenta',

                'out' => $csi . '38:2:207:113:175m',
            },
            'SLATE BLUE' => {
                'desc' => 'Slate blue',

                'out' => $csi . '38:2:106:90:205m',
            },
            'SLATE GRAY' => {
                'desc' => 'Slate gray',

                'out' => $csi . '38:2:112:128:144m',
            },
            'SMALT' => {
                'desc' => 'Smalt',

                'out' => $csi . '38:2:0:51:153m',
            },
            'SMOKEY TOPAZ' => {
                'desc' => 'Smokey topaz',

                'out' => $csi . '38:2:147:61:65m',
            },
            'SMOKY BLACK' => {
                'desc' => 'Smoky black',

                'out' => $csi . '38:2:16:12:8m',
            },
            'SNOW' => {
                'desc' => 'Snow',

                'out' => $csi . '38:2:255:250:250m',
            },
            'SPIRO DISCO BALL' => {
                'desc' => 'Spiro Disco Ball',

                'out' => $csi . '38:2:15:192:252m',
            },
            'SPRING BUD' => {
                'desc' => 'Spring bud',

                'out' => $csi . '38:2:167:252:0m',
            },
            'SPRING GREEN' => {
                'desc' => 'Spring green',

                'out' => $csi . '38:2:0:255:127m',
            },
            'STEEL BLUE' => {
                'desc' => 'Steel blue',

                'out' => $csi . '38:2:70:130:180m',
            },
            'STIL DE GRAIN YELLOW' => {
                'desc' => 'Stil de grain yellow',

                'out' => $csi . '38:2:250:218:94m',
            },
            'STIZZA' => {
                'desc' => 'Stizza',

                'out' => $csi . '38:2:153:0:0m',
            },
            'STORMCLOUD' => {
                'desc' => 'Stormcloud',

                'out' => $csi . '38:2:0:128:128m',
            },
            'STRAW' => {
                'desc' => 'Straw',

                'out' => $csi . '38:2:228:217:111m',
            },
            'SUNGLOW' => {
                'desc' => 'Sunglow',

                'out' => $csi . '38:2:255:204:51m',
            },
            'SUNSET' => {
                'desc' => 'Sunset',

                'out' => $csi . '38:2:250:214:165m',
            },
            'SUNSET ORANGE' => {
                'desc' => 'Sunset Orange',

                'out' => $csi . '38:2:253:94:83m',
            },
            'TAN' => {
                'desc' => 'Tan',

                'out' => $csi . '38:2:210:180:140m',
            },
            'TANGELO' => {
                'desc' => 'Tangelo',

                'out' => $csi . '38:2:249:77:0m',
            },
            'TANGERINE' => {
                'desc' => 'Tangerine',

                'out' => $csi . '38:2:242:133:0m',
            },
            'TANGERINE YELLOW' => {
                'desc' => 'Tangerine yellow',

                'out' => $csi . '38:2:255:204:0m',
            },
            'TAUPE' => {
                'desc' => 'Taupe',

                'out' => $csi . '38:2:72:60:50m',
            },
            'TAUPE GRAY' => {
                'desc' => 'Taupe gray',

                'out' => $csi . '38:2:139:133:137m',
            },
            'TAWNY' => {
                'desc' => 'Tawny',

                'out' => $csi . '38:2:205:87:0m',
            },
            'TEA GREEN' => {
                'desc' => 'Tea green',

                'out' => $csi . '38:2:208:240:192m',
            },
            'TEA ROSE' => {
                'desc' => 'Tea rose',

                'out' => $csi . '38:2:244:194:194m',
            },
            'TEAL' => {
                'desc' => 'Teal',

                'out' => $csi . '38:2:0:128:128m',
            },
            'TEAL BLUE' => {
                'desc' => 'Teal blue',

                'out' => $csi . '38:2:54:117:136m',
            },
            'TEAL GREEN' => {
                'desc' => 'Teal green',

                'out' => $csi . '38:2:0:109:91m',
            },
            'TERRA COTTA' => {
                'desc' => 'Terra cotta',

                'out' => $csi . '38:2:226:114:91m',
            },
            'THISTLE' => {
                'desc' => 'Thistle',

                'out' => $csi . '38:2:216:191:216m',
            },
            'THULIAN PINK' => {
                'desc' => 'Thulian pink',

                'out' => $csi . '38:2:222:111:161m',
            },
            'TICKLE ME PINK' => {
                'desc' => 'Tickle Me Pink',

                'out' => $csi . '38:2:252:137:172m',
            },
            'TIFFANY BLUE' => {
                'desc' => 'Tiffany Blue',

                'out' => $csi . '38:2:10:186:181m',
            },
            'TIGER EYE' => {
                'desc' => 'Tiger eye',

                'out' => $csi . '38:2:224:141:60m',
            },
            'TIMBERWOLF' => {
                'desc' => 'Timberwolf',

                'out' => $csi . '38:2:219:215:210m',
            },
            'TITANIUM YELLOW' => {
                'desc' => 'Titanium yellow',

                'out' => $csi . '38:2:238:230:0m',
            },
            'TOMATO' => {
                'desc' => 'Tomato',

                'out' => $csi . '38:2:255:99:71m',
            },
            'TOOLBOX' => {
                'desc' => 'Toolbox',

                'out' => $csi . '38:2:116:108:192m',
            },
            'TOPAZ' => {
                'desc' => 'Topaz',

                'out' => $csi . '38:2:255:200:124m',
            },
            'TRACTOR RED' => {
                'desc' => 'Tractor red',

                'out' => $csi . '38:2:253:14:53m',
            },
            'TROLLEY GRAY' => {
                'desc' => 'Trolley Grey',

                'out' => $csi . '38:2:128:128:128m',
            },
            'TROPICAL RAIN FOREST' => {
                'desc' => 'Tropical rain forest',

                'out' => $csi . '38:2:0:117:94m',
            },
            'TRUE BLUE' => {
                'desc' => 'True Blue',

                'out' => $csi . '38:2:0:115:207m',
            },
            'TUFTS BLUE' => {
                'desc' => 'Tufts Blue',

                'out' => $csi . '38:2:65:125:193m',
            },
            'TUMBLEWEED' => {
                'desc' => 'Tumbleweed',

                'out' => $csi . '38:2:222:170:136m',
            },
            'TURKISH ROSE' => {
                'desc' => 'Turkish rose',

                'out' => $csi . '38:2:181:114:129m',
            },
            'TURQUOISE' => {
                'desc' => 'Turquoise',

                'out' => $csi . '38:2:48:213:200m',
            },
            'TURQUOISE BLUE' => {
                'desc' => 'Turquoise blue',

                'out' => $csi . '38:2:0:255:239m',
            },
            'TURQUOISE GREEN' => {
                'desc' => 'Turquoise green',

                'out' => $csi . '38:2:160:214:180m',
            },
            'TUSCAN RED' => {
                'desc' => 'Tuscan red',

                'out' => $csi . '38:2:102:66:77m',
            },
            'TWILIGHT LAVENDER' => {
                'desc' => 'Twilight lavender',

                'out' => $csi . '38:2:138:73:107m',
            },
            'TYRIAN PURPLE' => {
                'desc' => 'Tyrian purple',

                'out' => $csi . '38:2:102:2:60m',
            },
            'UA BLUE' => {
                'desc' => 'UA blue',

                'out' => $csi . '38:2:0:51:170m',
            },
            'UA RED' => {
                'desc' => 'UA red',

                'out' => $csi . '38:2:217:0:76m',
            },
            'UBE' => {
                'desc' => 'Ube',

                'out' => $csi . '38:2:136:120:195m',
            },
            'UCLA BLUE' => {
                'desc' => 'UCLA Blue',

                'out' => $csi . '38:2:83:104:149m',
            },
            'UCLA GOLD' => {
                'desc' => 'UCLA Gold',

                'out' => $csi . '38:2:255:179:0m',
            },
            'UFO GREEN' => {
                'desc' => 'UFO Green',

                'out' => $csi . '38:2:60:208:112m',
            },
            'ULTRA PINK' => {
                'desc' => 'Ultra pink',

                'out' => $csi . '38:2:255:111:255m',
            },
            'ULTRAMARINE' => {
                'desc' => 'Ultramarine',

                'out' => $csi . '38:2:18:10:143m',
            },
            'ULTRAMARINE BLUE' => {
                'desc' => 'Ultramarine blue',

                'out' => $csi . '38:2:65:102:245m',
            },
            'UMBER' => {
                'desc' => 'Umber',

                'out' => $csi . '38:2:99:81:71m',
            },
            'UNITED NATIONS BLUE' => {
                'desc' => 'United Nations blue',

                'out' => $csi . '38:2:91:146:229m',
            },
            'UNIVERSITY OF' => {
                'desc' => 'University of',

                'out' => $csi . '38:2:183:135:39m',
            },
            'UNMELLOW YELLOW' => {
                'desc' => 'Unmellow Yellow',

                'out' => $csi . '38:2:255:255:102m',
            },
            'UP FOREST GREEN' => {
                'desc' => 'UP Forest green',

                'out' => $csi . '38:2:1:68:33m',
            },
            'UP MAROON' => {
                'desc' => 'UP Maroon',

                'out' => $csi . '38:2:123:17:19m',
            },
            'UPSDELL RED' => {
                'desc' => 'Upsdell red',

                'out' => $csi . '38:2:174:32:41m',
            },
            'UROBILIN' => {
                'desc' => 'Urobilin',

                'out' => $csi . '38:2:225:173:33m',
            },
            'USC CARDINAL' => {
                'desc' => 'USC Cardinal',

                'out' => $csi . '38:2:153:0:0m',
            },
            'USC GOLD' => {
                'desc' => 'USC Gold',

                'out' => $csi . '38:2:255:204:0m',
            },
            'UTAH CRIMSON' => {
                'desc' => 'Utah Crimson',

                'out' => $csi . '38:2:211:0:63m',
            },
            'VANILLA' => {
                'desc' => 'Vanilla',

                'out' => $csi . '38:2:243:229:171m',
            },
            'VEGAS GOLD' => {
                'desc' => 'Vegas gold',

                'out' => $csi . '38:2:197:179:88m',
            },
            'VENETIAN RED' => {
                'desc' => 'Venetian red',

                'out' => $csi . '38:2:200:8:21m',
            },
            'VERDIGRIS' => {
                'desc' => 'Verdigris',

                'out' => $csi . '38:2:67:179:174m',
            },
            'VERMILION' => {
                'desc' => 'Vermilion',

                'out' => $csi . '38:2:227:66:52m',
            },
            'VERONICA' => {
                'desc' => 'Veronica',

                'out' => $csi . '38:2:160:32:240m',
            },
            'VIOLET' => {
                'desc' => 'Violet',

                'out' => $csi . '38:2:238:130:238m',
            },
            'VIOLET BLUE' => {
                'desc' => 'Violet Blue',

                'out' => $csi . '38:2:50:74:178m',
            },
            'VIOLET RED' => {
                'desc' => 'Violet Red',

                'out' => $csi . '38:2:247:83:148m',
            },
            'VIRIDIAN' => {
                'desc' => 'Viridian',

                'out' => $csi . '38:2:64:130:109m',
            },
            'VIVID AUBURN' => {
                'desc' => 'Vivid auburn',

                'out' => $csi . '38:2:146:39:36m',
            },
            'VIVID BURGUNDY' => {
                'desc' => 'Vivid burgundy',

                'out' => $csi . '38:2:159:29:53m',
            },
            'VIVID CERISE' => {
                'desc' => 'Vivid cerise',

                'out' => $csi . '38:2:218:29:129m',
            },
            'VIVID TANGERINE' => {
                'desc' => 'Vivid tangerine',

                'out' => $csi . '38:2:255:160:137m',
            },
            'VIVID VIOLET' => {
                'desc' => 'Vivid violet',

                'out' => $csi . '38:2:159:0:255m',
            },
            'WARM BLACK' => {
                'desc' => 'Warm black',

                'out' => $csi . '38:2:0:66:66m',
            },
            'WATERSPOUT' => {
                'desc' => 'Waterspout',

                'out' => $csi . '38:2:0:255:255m',
            },
            'WENGE' => {
                'desc' => 'Wenge',

                'out' => $csi . '38:2:100:84:82m',
            },
            'WHEAT' => {
                'desc' => 'Wheat',

                'out' => $csi . '38:2:245:222:179m',
            },
            'WHITE SMOKE' => {
                'desc' => 'White smoke',

                'out' => $csi . '38:2:245:245:245m',
            },
            'WILD BLUE YONDER' => {
                'desc' => 'Wild blue yonder',

                'out' => $csi . '38:2:162:173:208m',
            },
            'WILD STRAWBERRY' => {
                'desc' => 'Wild Strawberry',

                'out' => $csi . '38:2:255:67:164m',
            },
            'WILD WATERMELON' => {
                'desc' => 'Wild Watermelon',

                'out' => $csi . '38:2:252:108:133m',
            },
            'WINE' => {
                'desc' => 'Wine',

                'out' => $csi . '38:2:114:47:55m',
            },
            'WISTERIA' => {
                'desc' => 'Wisteria',

                'out' => $csi . '38:2:201:160:220m',
            },
            'XANADU' => {
                'desc' => 'Xanadu',

                'out' => $csi . '38:2:115:134:120m',
            },
            'YALE BLUE' => {
                'desc' => 'Yale Blue',

                'out' => $csi . '38:2:15:77:146m',
            },
            'YELLOW GREEN' => {
                'desc' => 'Yellow green',

                'out' => $csi . '38:2:154:205:50m',
            },
            'YELLOW ORANGE' => {
                'desc' => 'Yellow Orange',

                'out' => $csi . '38:2:255:174:66m',
            },
            'ZAFFRE' => {
                'desc' => 'Zaffre',

                'out' => $csi . '38:2:0:20:168m',
            },
            'ZINNWALDITE BROWN' => {
                'desc' => 'Zinnwaldite brown',

                'out' => $csi . '38:2:44:22:8m',
            },
        },

        'background' => {
            'B_DEFAULT' => {
                'out'  => $csi . '49m',
                'desc' => 'Default background color',

            },
            'B_BLACK' => {
                'out'  => $csi . '40m',
                'desc' => 'Black',

            },
            'B_RED' => {
                'out'  => $csi . '41m',
                'desc' => 'Red',

            },
            'B_DARK RED' => {
                'out'  => $csi . '48:2:139:0:0m',
                'desc' => 'Dark red',

            },
            'B_PINK' => {
                'out'  => $csi . '48;5;198m',
                'desc' => 'Pink',

            },
            'B_ORANGE' => {
                'out'  => $csi . '48;5;202m',
                'desc' => 'Orange',

            },
            'B_NAVY' => {
                'out'  => $csi . '48;5;17m',
                'desc' => 'Navy',

            },
            'B_BROWN' => {
                'out'  => $csi . '48:2:165:42:42m',
                'desc' => 'Brown',

            },
            'B_MAROON' => {
                'out'  => $csi . '48:2:128:0:0m',
                'desc' => 'Maroon',

            },
            'B_OLIVE' => {
                'out'  => $csi . '48:2:128:128:0m',
                'desc' => 'Olive',

            },
            'B_PURPLE' => {
                'out'  => $csi . '48:2:128:0:128m',
                'desc' => 'Purple',

            },
            'B_TEAL' => {
                'out'  => $csi . '48:2:0:128:128m',
                'desc' => 'Teal',

            },
            'B_GREEN' => {
                'out'  => $csi . '42m',
                'desc' => 'Green',

            },
            'B_YELLOW' => {
                'out'  => $csi . '43m',
                'desc' => 'Yellow',

            },
            'B_BLUE' => {
                'out'  => $csi . '44m',
                'desc' => 'Blue',

            },
            'B_MAGENTA' => {
                'out'  => $csi . '45m',
                'desc' => 'Magenta',

            },
            'B_CYAN' => {
                'out'  => $csi . '46m',
                'desc' => 'Cyan',

            },
            'B_WHITE' => {
                'out'  => $csi . '47m',
                'desc' => 'White',

            },
            'B_BRIGHT BLACK' => {
                'out'  => $csi . '100m',
                'desc' => 'Bright black',

            },
            'B_BRIGHT RED' => {
                'out'  => $csi . '101m',
                'desc' => 'Bright red',

            },
            'B_BRIGHT GREEN' => {
                'out'  => $csi . '102m',
                'desc' => 'Bright green',

            },
            'B_BRIGHT YELLOW' => {
                'out'  => $csi . '103m',
                'desc' => 'Bright yellow',

            },
            'B_BRIGHT BLUE' => {
                'out'  => $csi . '104m',
                'desc' => 'Bright blue',

            },
            'B_BRIGHT MAGENTA' => {
                'out'  => $csi . '105m',
                'desc' => 'Bright magenta',

            },
            'B_BRIGHT CYAN' => {
                'out'  => $csi . '106m',
                'desc' => 'Bright cyan',

            },
            'B_BRIGHT WHITE' => {
                'out'  => $csi . '107m',
                'desc' => 'Bright white',

            },
            'B_FIREBRICK' => {
                'out'  => $csi . '48:2:178:34:34m',
                'desc' => 'Firebrick',

            },
            'B_CRIMSON' => {
                'out'  => $csi . '48:2:220:20:60m',
                'desc' => 'Crimson',

            },
            'B_TOMATO' => {
                'out'  => $csi . '48:2:255:99:71m',
                'desc' => 'Tomato',

            },
            'B_CORAL' => {
                'out'  => $csi . '48:2:255:127:80m',
                'desc' => 'Coral',

            },
            'B_INDIAN RED' => {
                'out'  => $csi . '48:2:205:92:92m',
                'desc' => 'Indian red',

            },
            'B_LIGHT CORAL' => {
                'out'  => $csi . '48:2:240:128:128m',
                'desc' => 'Light coral',

            },
            'B_DARK SALMON' => {
                'out'  => $csi . '48:2:233:150:122m',
                'desc' => 'Dark salmon',

            },
            'B_SALMON' => {
                'out'  => $csi . '48:2:250:128:114m',
                'desc' => 'Salmon',

            },
            'B_LIGHT SALMON' => {
                'out'  => $csi . '48:2:255:160:122m',
                'desc' => 'Light salmon',

            },
            'B_ORANGE RED' => {
                'out'  => $csi . '48:2:255:69:0m',
                'desc' => 'Orange red',

            },
            'B_DARK ORANGE' => {
                'out'  => $csi . '48:2:255:140:0m',
                'desc' => 'Dark orange',

            },
            'B_GOLD' => {
                'out'  => $csi . '48:2:255:215:0m',
                'desc' => 'Gold',

            },
            'B_DARK GOLDEN ROD' => {
                'out'  => $csi . '48:2:184:134:11m',
                'desc' => 'Dark golden rod',

            },
            'B_GOLDEN ROD' => {
                'out'  => $csi . '48:2:218:165:32m',
                'desc' => 'Golden rod',

            },
            'B_PALE GOLDEN ROD' => {
                'out'  => $csi . '48:2:238:232:170m',
                'desc' => 'Pale golden rod',

            },
            'B_DARK KHAKI' => {
                'out'  => $csi . '48:2:189:183:107m',
                'desc' => 'Dark khaki',

            },
            'B_KHAKI' => {
                'out'  => $csi . '48:2:240:230:140m',
                'desc' => 'Khaki',

            },
            'B_YELLOW GREEN' => {
                'out'  => $csi . '48:2:154:205:50m',
                'desc' => 'Yellow green',

            },
            'B_DARK OLIVE GREEN' => {
                'out'  => $csi . '48:2:85:107:47m',
                'desc' => 'Dark olive green',

            },
            'B_OLIVE DRAB' => {
                'out'  => $csi . '48:2:107:142:35m',
                'desc' => 'Olive drab',

            },
            'B_LAWN GREEN' => {
                'out'  => $csi . '48:2:124:252:0m',
                'desc' => 'Lawn green',

            },
            'B_CHARTREUSE' => {
                'out'  => $csi . '48:2:127:255:0m',
                'desc' => 'Chartreuse',

            },
            'B_GREEN YELLOW' => {
                'out'  => $csi . '48:2:173:255:47m',
                'desc' => 'Green yellow',

            },
            'B_DARK GREEN' => {
                'out'  => $csi . '48:2:0:100:0m',
                'desc' => 'Dark green',

            },
            'B_FOREST GREEN' => {
                'out'  => $csi . '48:2:34:139:34m',
                'desc' => 'Forest green',

            },
            'B_LIME GREEN' => {
                'out'  => $csi . '48:2:50:205:50m',
                'desc' => 'Lime Green',

            },
            'B_LIGHT GREEN' => {
                'out'  => $csi . '48:2:144:238:144m',
                'desc' => 'Light green',

            },
            'B_PALE GREEN' => {
                'out'  => $csi . '48:2:152:251:152m',
                'desc' => 'Pale green',

            },
            'B_DARK SEA GREEN' => {
                'out'  => $csi . '48:2:143:188:143m',
                'desc' => 'Dark sea green',

            },
            'B_MEDIUM SPRING GREEN' => {
                'out'  => $csi . '48:2:0:250:154m',
                'desc' => 'Medium spring green',

            },
            'B_SPRING GREEN' => {
                'out'  => $csi . '48:2:0:255:127m',
                'desc' => 'Spring green',

            },
            'B_SEA GREEN' => {
                'out'  => $csi . '48:2:46:139:87m',
                'desc' => 'Sea green',

            },
            'B_MEDIUM AQUA MARINE' => {
                'out'  => $csi . '48:2:102:205:170m',
                'desc' => 'Medium aqua marine',

            },
            'B_MEDIUM SEA GREEN' => {
                'out'  => $csi . '48:2:60:179:113m',
                'desc' => 'Medium sea green',

            },
            'B_LIGHT SEA GREEN' => {
                'out'  => $csi . '48:2:32:178:170m',
                'desc' => 'Light sea green',

            },
            'B_DARK SLATE GRAY' => {
                'out'  => $csi . '48:2:47:79:79m',
                'desc' => 'Dark slate gray',

            },
            'B_DARK CYAN' => {
                'out'  => $csi . '48:2:0:139:139m',
                'desc' => 'Dark cyan',

            },
            'B_AQUA' => {
                'out'  => $csi . '48:2:0:255:255m',
                'desc' => 'Aqua',

            },
            'B_LIGHT CYAN' => {
                'out'  => $csi . '48:2:224:255:255m',
                'desc' => 'Light cyan',

            },
            'B_DARK TURQUOISE' => {
                'out'  => $csi . '48:2:0:206:209m',
                'desc' => 'Dark turquoise',

            },
            'B_TURQUOISE' => {
                'out'  => $csi . '48:2:64:224:208m',
                'desc' => 'Turquoise',

            },
            'B_MEDIUM TURQUOISE' => {
                'out'  => $csi . '48:2:72:209:204m',
                'desc' => 'Medium turquoise',

            },
            'B_PALE TURQUOISE' => {
                'out'  => $csi . '48:2:175:238:238m',
                'desc' => 'Pale turquoise',

            },
            'B_AQUA MARINE' => {
                'out'  => $csi . '48:2:127:255:212m',
                'desc' => 'Aqua marine',

            },
            'B_POWDER BLUE' => {
                'out'  => $csi . '48:2:176:224:230m',
                'desc' => 'Powder blue',

            },
            'B_CADET BLUE' => {
                'out'  => $csi . '48:2:95:158:160m',
                'desc' => 'Cadet blue',

            },
            'B_STEEL BLUE' => {
                'out'  => $csi . '48:2:70:130:180m',
                'desc' => 'Steel blue',

            },
            'B_CORN FLOWER BLUE' => {
                'out'  => $csi . '48:2:100:149:237m',
                'desc' => 'Corn flower blue',

            },
            'B_DEEP SKY BLUE' => {
                'out'  => $csi . '48:2:0:191:255m',
                'desc' => 'Deep sky blue',

            },
            'B_DODGER BLUE' => {
                'out'  => $csi . '48:2:30:144:255m',
                'desc' => 'Dodger blue',

            },
            'B_LIGHT BLUE' => {
                'out'  => $csi . '48:2:173:216:230m',
                'desc' => 'Light blue',

            },
            'B_SKY BLUE' => {
                'out'  => $csi . '48:2:135:206:235m',
                'desc' => 'Sky blue',

            },
            'B_LIGHT SKY BLUE' => {
                'out'  => $csi . '48:2:135:206:250m',
                'desc' => 'Light sky blue',

            },
            'B_MIDNIGHT BLUE' => {
                'out'  => $csi . '48:2:25:25:112m',
                'desc' => 'Midnight blue',

            },
            'B_DARK BLUE' => {
                'out'  => $csi . '48:2:0:0:139m',
                'desc' => 'Dark blue',

            },
            'B_MEDIUM BLUE' => {
                'out'  => $csi . '48:2:0:0:205m',
                'desc' => 'Medium blue',

            },
            'B_ROYAL BLUE' => {
                'out'  => $csi . '48:2:65:105:225m',
                'desc' => 'Royal blue',

            },
            'B_BLUE VIOLET' => {
                'out'  => $csi . '48:2:138:43:226m',
                'desc' => 'Blue violet',

            },
            'B_INDIGO' => {
                'out'  => $csi . '48:2:75:0:130m',
                'desc' => 'Indigo',

            },
            'B_DARK SLATE BLUE' => {
                'out'  => $csi . '48:2:72:61:139m',
                'desc' => 'Dark slate blue',

            },
            'B_SLATE BLUE' => {
                'out'  => $csi . '48:2:106:90:205m',
                'desc' => 'Slate blue',

            },
            'B_MEDIUM SLATE BLUE' => {
                'out'  => $csi . '48:2:123:104:238m',
                'desc' => 'Medium slate blue',

            },
            'B_MEDIUM PURPLE' => {
                'out'  => $csi . '48:2:147:112:219m',
                'desc' => 'Medium purple',

            },
            'B_DARK MAGENTA' => {
                'out'  => $csi . '48:2:139:0:139m',
                'desc' => 'Dark magenta',

            },
            'B_DARK VIOLET' => {
                'out'  => $csi . '48:2:148:0:211m',
                'desc' => 'Dark violet',

            },
            'B_DARK ORCHID' => {
                'out'  => $csi . '48:2:153:50:204m',
                'desc' => 'Dark orchid',

            },
            'B_MEDIUM ORCHID' => {
                'out'  => $csi . '48:2:186:85:211m',
                'desc' => 'Medium orchid',

            },
            'B_THISTLE' => {
                'out'  => $csi . '48:2:216:191:216m',
                'desc' => 'Thistle',

            },
            'B_PLUM' => {
                'out'  => $csi . '48:2:221:160:221m',
                'desc' => 'Plum',

            },
            'B_VIOLET' => {
                'out'  => $csi . '48:2:238:130:238m',
                'desc' => 'Violet',

            },
            'B_ORCHID' => {
                'out'  => $csi . '48:2:218:112:214m',
                'desc' => 'Orchid',

            },
            'B_MEDIUM VIOLET RED' => {
                'out'  => $csi . '48:2:199:21:133m',
                'desc' => 'Medium violet red',

            },
            'B_PALE VIOLET RED' => {
                'out'  => $csi . '48:2:219:112:147m',
                'desc' => 'Pale violet red',

            },
            'B_DEEP PINK' => {
                'out'  => $csi . '48:2:255:20:147m',
                'desc' => 'Deep pink',

            },
            'B_HOT PINK' => {
                'out'  => $csi . '48:2:255:105:180m',
                'desc' => 'Hot pink',

            },
            'B_LIGHT PINK' => {
                'out'  => $csi . '48:2:255:182:193m',
                'desc' => 'Light pink',

            },
            'B_ANTIQUE WHITE' => {
                'out'  => $csi . '48:2:250:235:215m',
                'desc' => 'Antique white',

            },
            'B_BEIGE' => {
                'out'  => $csi . '48:2:245:245:220m',
                'desc' => 'Beige',

            },
            'B_BISQUE' => {
                'out'  => $csi . '48:2:255:228:196m',
                'desc' => 'Bisque',

            },
            'B_BLANCHED ALMOND' => {
                'out'  => $csi . '48:2:255:235:205m',
                'desc' => 'Blanched almond',

            },
            'B_WHEAT' => {
                'out'  => $csi . '48:2:245:222:179m',
                'desc' => 'Wheat',

            },
            'B_CORN SILK' => {
                'out'  => $csi . '48:2:255:248:220m',
                'desc' => 'Corn silk',

            },
            'B_LEMON CHIFFON' => {
                'out'  => $csi . '48:2:255:250:205m',
                'desc' => 'Lemon chiffon',

            },
            'B_LIGHT GOLDEN ROD YELLOW' => {
                'out'  => $csi . '48:2:250:250:210m',
                'desc' => 'Light golden rod yellow',

            },
            'B_LIGHT YELLOW' => {
                'out'  => $csi . '48:2:255:255:224m',
                'desc' => 'Light yellow',

            },
            'B_SADDLE BROWN' => {
                'out'  => $csi . '48:2:139:69:19m',
                'desc' => 'Saddle brown',

            },
            'B_SIENNA' => {
                'out'  => $csi . '48:2:160:82:45m',
                'desc' => 'Sienna',

            },
            'B_CHOCOLATE' => {
                'out'  => $csi . '48:2:210:105:30m',
                'desc' => 'Chocolate',

            },
            'B_PERU' => {
                'out'  => $csi . '48:2:205:133:63m',
                'desc' => 'Peru',

            },
            'B_SANDY BROWN' => {
                'out'  => $csi . '48:2:244:164:96m',
                'desc' => 'Sandy brown',

            },
            'B_BURLY WOOD' => {
                'out'  => $csi . '48:2:222:184:135m',
                'desc' => 'Burly wood',

            },
            'B_TAN' => {
                'out'  => $csi . '48:2:210:180:140m',
                'desc' => 'Tan',

            },
            'B_ROSY BROWN' => {
                'out'  => $csi . '48:2:188:143:143m',
                'desc' => 'Rosy brown',

            },
            'B_MOCCASIN' => {
                'out'  => $csi . '48:2:255:228:181m',
                'desc' => 'Moccasin',

            },
            'B_NAVAJO WHITE' => {
                'out'  => $csi . '48:2:255:222:173m',
                'desc' => 'Navajo white',

            },
            'B_PEACH PUFF' => {
                'out'  => $csi . '48:2:255:218:185m',
                'desc' => 'Peach puff',

            },
            'B_MISTY ROSE' => {
                'out'  => $csi . '48:2:255:228:225m',
                'desc' => 'Misty rose',

            },
            'B_LAVENDER BLUSH' => {
                'out'  => $csi . '48:2:255:240:245m',
                'desc' => 'Lavender blush',

            },
            'B_LINEN' => {
                'out'  => $csi . '48:2:250:240:230m',
                'desc' => 'Linen',

            },
            'B_OLD LACE' => {
                'out'  => $csi . '48:2:253:245:230m',
                'desc' => 'Old lace',

            },
            'B_PAPAYA WHIP' => {
                'out'  => $csi . '48:2:255:239:213m',
                'desc' => 'Papaya whip',

            },
            'B_SEA SHELL' => {
                'out'  => $csi . '48:2:255:245:238m',
                'desc' => 'Sea shell',

            },
            'B_MINT CREAM' => {
                'out'  => $csi . '48:2:245:255:250m',
                'desc' => 'Mint green',

            },
            'B_SLATE GRAY' => {
                'out'  => $csi . '48:2:112:128:144m',
                'desc' => 'Slate gray',

            },
            'B_LIGHT SLATE GRAY' => {
                'out'  => $csi . '48:2:119:136:153m',
                'desc' => 'Lisght slate gray',

            },
            'B_LIGHT STEEL BLUE' => {
                'out'  => $csi . '48:2:176:196:222m',
                'desc' => 'Light steel blue',

            },
            'B_LAVENDER' => {
                'out'  => $csi . '48:2:230:230:250m',
                'desc' => 'Lavender',

            },
            'B_FLORAL WHITE' => {
                'out'  => $csi . '48:2:255:250:240m',
                'desc' => 'Floral white',

            },
            'B_ALICE BLUE' => {
                'out'  => $csi . '48:2:240:248:255m',
                'desc' => 'Alice blue',

            },
            'B_GHOST WHITE' => {
                'out'  => $csi . '48:2:248:248:255m',
                'desc' => 'Ghost white',

            },
            'B_HONEYDEW' => {
                'out'  => $csi . '48:2:240:255:240m',
                'desc' => 'Honeydew',

            },
            'B_IVORY' => {
                'out'  => $csi . '48:2:255:255:240m',
                'desc' => 'Ivory',

            },
            'B_AZURE' => {
                'out'  => $csi . '48:2:240:255:255m',
                'desc' => 'Azure',

            },
            'B_SNOW' => {
                'out'  => $csi . '48:2:255:250:250m',
                'desc' => 'Snow',

            },
            'B_DIM GRAY' => {
                'out'  => $csi . '48:2:105:105:105m',
                'desc' => 'Dim gray',

            },
            'B_DARK GRAY' => {
                'out'  => $csi . '48:2:169:169:169m',
                'desc' => 'Dark gray',

            },
            'B_SILVER' => {
                'out'  => $csi . '48:2:192:192:192m',
                'desc' => 'Silver',

            },
            'B_LIGHT GRAY' => {
                'out'  => $csi . '48:2:211:211:211m',
                'desc' => 'Light gray',

            },
            'B_GAINSBORO' => {
                'out'  => $csi . '48:2:220:220:220m',
                'desc' => 'Gainsboro',

            },
            'B_WHITE SMOKE' => {
                'out'  => $csi . '48:2:245:245:245m',
                'desc' => 'White smoke',

            },
            'B_AIR FORCE BLUE' => {
                'desc' => 'Air Force blue',

                'out' => $csi . '48:2:93:138:168m',
            },
            'B_ALICE BLUE' => {
                'desc' => 'Alice blue',

                'out' => $csi . '48:2:240:248:255m',
            },
            'B_ALIZARIN CRIMSON' => {
                'desc' => 'Alizarin crimson',

                'out' => $csi . '48:2:227:38:54m',
            },
            'B_ALMOND' => {
                'desc' => 'Almond',

                'out' => $csi . '48:2:239:222:205m',
            },
            'B_AMARANTH' => {
                'desc' => 'Amaranth',

                'out' => $csi . '48:2:229:43:80m',
            },
            'B_AMBER' => {
                'desc' => 'Amber',

                'out' => $csi . '48:2:255:191:0m',
            },
            'B_AMERICAN ROSE' => {
                'desc' => 'American rose',

                'out' => $csi . '48:2:255:3:62m',
            },
            'B_AMETHYST' => {
                'desc' => 'Amethyst',

                'out' => $csi . '48:2:153:102:204m',
            },
            'B_ANDROID GREEN' => {
                'desc' => 'Android Green',

                'out' => $csi . '48:2:164:198:57m',
            },
            'B_ANTI-FLASH WHITE' => {
                'desc' => 'Anti-flash white',

                'out' => $csi . '48:2:242:243:244m',
            },
            'B_ANTIQUE BRASS' => {
                'desc' => 'Antique brass',

                'out' => $csi . '48:2:205:149:117m',
            },
            'B_ANTIQUE FUCHSIA' => {
                'desc' => 'Antique fuchsia',

                'out' => $csi . '48:2:145:92:131m',
            },
            'B_ANTIQUE WHITE' => {
                'desc' => 'Antique white',

                'out' => $csi . '48:2:250:235:215m',
            },
            'B_AO' => {
                'desc' => 'Ao',

                'out' => $csi . '48:2:0:128:0m',
            },
            'B_APPLE GREEN' => {
                'desc' => 'Apple green',

                'out' => $csi . '48:2:141:182:0m',
            },
            'B_APRICOT' => {
                'desc' => 'Apricot',

                'out' => $csi . '48:2:251:206:177m',
            },
            'B_AQUA' => {
                'desc' => 'Aqua',

                'out' => $csi . '48:2:0:255:255m',
            },
            'B_AQUAMARINE' => {
                'desc' => 'Aquamarine',

                'out' => $csi . '48:2:127:255:212m',
            },
            'B_ARMY GREEN' => {
                'desc' => 'Army green',

                'out' => $csi . '48:2:75:83:32m',
            },
            'B_ARYLIDE YELLOW' => {
                'desc' => 'Arylide yellow',

                'out' => $csi . '48:2:233:214:107m',
            },
            'B_ASH GRAY' => {
                'desc' => 'Ash grey',

                'out' => $csi . '48:2:178:190:181m',
            },
            'B_ASPARAGUS' => {
                'desc' => 'Asparagus',

                'out' => $csi . '48:2:135:169:107m',
            },
            'B_ATOMIC TANGERINE' => {
                'desc' => 'Atomic tangerine',

                'out' => $csi . '48:2:255:153:102m',
            },
            'B_AUBURN' => {
                'desc' => 'Auburn',

                'out' => $csi . '48:2:165:42:42m',
            },
            'B_AUREOLIN' => {
                'desc' => 'Aureolin',

                'out' => $csi . '48:2:253:238:0m',
            },
            'B_AUROMETALSAURUS' => {
                'desc' => 'AuroMetalSaurus',

                'out' => $csi . '48:2:110:127:128m',
            },
            'B_AWESOME' => {
                'desc' => 'Awesome',

                'out' => $csi . '48:2:255:32:82m',
            },
            'B_AZURE' => {
                'desc' => 'Azure',

                'out' => $csi . '48:2:0:127:255m',
            },
            'B_AZURE MIST' => {
                'desc' => 'Azure mist',

                'out' => $csi . '48:2:240:255:255m',
            },
            'B_BABY BLUE' => {
                'desc' => 'Baby blue',

                'out' => $csi . '48:2:137:207:240m',
            },
            'B_BABY BLUE EYES' => {
                'desc' => 'Baby blue eyes',

                'out' => $csi . '48:2:161:202:241m',
            },
            'B_BABY PINK' => {
                'desc' => 'Baby pink',

                'out' => $csi . '48:2:244:194:194m',
            },
            'B_BALL BLUE' => {
                'desc' => 'Ball Blue',

                'out' => $csi . '48:2:33:171:205m',
            },
            'B_BANANA MANIA' => {
                'desc' => 'Banana Mania',

                'out' => $csi . '48:2:250:231:181m',
            },
            'B_BANANA YELLOW' => {
                'desc' => 'Banana yellow',

                'out' => $csi . '48:2:255:225:53m',
            },
            'B_BATTLESHIP GRAY' => {
                'desc' => 'Battleship grey',

                'out' => $csi . '48:2:132:132:130m',
            },
            'B_BAZAAR' => {
                'desc' => 'Bazaar',

                'out' => $csi . '48:2:152:119:123m',
            },
            'B_BEAU BLUE' => {
                'desc' => 'Beau blue',

                'out' => $csi . '48:2:188:212:230m',
            },
            'B_BEAVER' => {
                'desc' => 'Beaver',

                'out' => $csi . '48:2:159:129:112m',
            },
            'B_BEIGE' => {
                'desc' => 'Beige',

                'out' => $csi . '48:2:245:245:220m',
            },
            'B_BISQUE' => {
                'desc' => 'Bisque',

                'out' => $csi . '48:2:255:228:196m',
            },
            'B_BISTRE' => {
                'desc' => 'Bistre',

                'out' => $csi . '48:2:61:43:31m',
            },
            'B_BITTERSWEET' => {
                'desc' => 'Bittersweet',

                'out' => $csi . '48:2:254:111:94m',
            },
            'B_BLANCHED ALMOND' => {
                'desc' => 'Blanched Almond',

                'out' => $csi . '48:2:255:235:205m',
            },
            'B_BLEU DE FRANCE' => {
                'desc' => 'Bleu de France',

                'out' => $csi . '48:2:49:140:231m',
            },
            'B_BLIZZARD BLUE' => {
                'desc' => 'Blizzard Blue',

                'out' => $csi . '48:2:172:229:238m',
            },
            'B_BLOND' => {
                'desc' => 'Blond',

                'out' => $csi . '48:2:250:240:190m',
            },
            'B_BLUE BELL' => {
                'desc' => 'Blue Bell',

                'out' => $csi . '48:2:162:162:208m',
            },
            'B_BLUE GRAY' => {
                'desc' => 'Blue Gray',

                'out' => $csi . '48:2:102:153:204m',
            },
            'B_BLUE GREEN' => {
                'desc' => 'Blue green',

                'out' => $csi . '48:2:13:152:186m',
            },
            'B_BLUE PURPLE' => {
                'desc' => 'Blue purple',

                'out' => $csi . '48:2:138:43:226m',
            },
            'B_BLUE VIOLET' => {
                'desc' => 'Blue violet',

                'out' => $csi . '48:2:138:43:226m',
            },
            'B_BLUSH' => {
                'desc' => 'Blush',

                'out' => $csi . '48:2:222:93:131m',
            },
            'B_BOLE' => {
                'desc' => 'Bole',

                'out' => $csi . '48:2:121:68:59m',
            },
            'B_BONDI BLUE' => {
                'desc' => 'Bondi blue',

                'out' => $csi . '48:2:0:149:182m',
            },
            'B_BONE' => {
                'desc' => 'Bone',

                'out' => $csi . '48:2:227:218:201m',
            },
            'B_BOSTON UNIVERSITY RED' => {
                'desc' => 'Boston University Red',

                'out' => $csi . '48:2:204:0:0m',
            },
            'B_BOTTLE GREEN' => {
                'desc' => 'Bottle green',

                'out' => $csi . '48:2:0:106:78m',
            },
            'B_BOYSENBERRY' => {
                'desc' => 'Boysenberry',

                'out' => $csi . '48:2:135:50:96m',
            },
            'B_BRANDEIS BLUE' => {
                'desc' => 'Brandeis blue',

                'out' => $csi . '48:2:0:112:255m',
            },
            'B_BRASS' => {
                'desc' => 'Brass',

                'out' => $csi . '48:2:181:166:66m',
            },
            'B_BRICK RED' => {
                'desc' => 'Brick red',

                'out' => $csi . '48:2:203:65:84m',
            },
            'B_BRIGHT CERULEAN' => {
                'desc' => 'Bright cerulean',

                'out' => $csi . '48:2:29:172:214m',
            },
            'B_BRIGHT GREEN' => {
                'desc' => 'Bright green',

                'out' => $csi . '48:2:102:255:0m',
            },
            'B_BRIGHT LAVENDER' => {
                'desc' => 'Bright lavender',

                'out' => $csi . '48:2:191:148:228m',
            },
            'B_BRIGHT MAROON' => {
                'desc' => 'Bright maroon',

                'out' => $csi . '48:2:195:33:72m',
            },
            'B_BRIGHT PINK' => {
                'desc' => 'Bright pink',

                'out' => $csi . '48:2:255:0:127m',
            },
            'B_BRIGHT TURQUOISE' => {
                'desc' => 'Bright turquoise',

                'out' => $csi . '48:2:8:232:222m',
            },
            'B_BRIGHT UBE' => {
                'desc' => 'Bright ube',

                'out' => $csi . '48:2:209:159:232m',
            },
            'B_BRILLIANT LAVENDER' => {
                'desc' => 'Brilliant lavender',

                'out' => $csi . '48:2:244:187:255m',
            },
            'B_BRILLIANT ROSE' => {
                'desc' => 'Brilliant rose',

                'out' => $csi . '48:2:255:85:163m',
            },
            'B_BRINK PINK' => {
                'desc' => 'Brink pink',

                'out' => $csi . '48:2:251:96:127m',
            },
            'B_BRITISH RACING GREEN' => {
                'desc' => 'British racing green',

                'out' => $csi . '48:2:0:66:37m',
            },
            'B_BRONZE' => {
                'desc' => 'Bronze',

                'out' => $csi . '48:2:205:127:50m',
            },
            'B_BROWN' => {
                'desc' => 'Brown',

                'out' => $csi . '48:2:165:42:42m',
            },
            'B_BUBBLE GUM' => {
                'desc' => 'Bubble gum',

                'out' => $csi . '48:2:255:193:204m',
            },
            'B_BUBBLES' => {
                'desc' => 'Bubbles',

                'out' => $csi . '48:2:231:254:255m',
            },
            'B_BUFF' => {
                'desc' => 'Buff',

                'out' => $csi . '48:2:240:220:130m',
            },
            'B_BULGARIAN ROSE' => {
                'desc' => 'Bulgarian rose',

                'out' => $csi . '48:2:72:6:7m',
            },
            'B_BURGUNDY' => {
                'desc' => 'Burgundy',

                'out' => $csi . '48:2:128:0:32m',
            },
            'B_BURLYWOOD' => {
                'desc' => 'Burlywood',

                'out' => $csi . '48:2:222:184:135m',
            },
            'B_BURNT ORANGE' => {
                'desc' => 'Burnt orange',

                'out' => $csi . '48:2:204:85:0m',
            },
            'B_BURNT SIENNA' => {
                'desc' => 'Burnt sienna',

                'out' => $csi . '48:2:233:116:81m',
            },
            'B_BURNT UMBER' => {
                'desc' => 'Burnt umber',

                'out' => $csi . '48:2:138:51:36m',
            },
            'B_BYZANTINE' => {
                'desc' => 'Byzantine',

                'out' => $csi . '48:2:189:51:164m',
            },
            'B_BYZANTIUM' => {
                'desc' => 'Byzantium',

                'out' => $csi . '48:2:112:41:99m',
            },
            'B_CADET' => {
                'desc' => 'Cadet',

                'out' => $csi . '48:2:83:104:114m',
            },
            'B_CADET BLUE' => {
                'desc' => 'Cadet blue',

                'out' => $csi . '48:2:95:158:160m',
            },
            'B_CADET GRAY' => {
                'desc' => 'Cadet grey',

                'out' => $csi . '48:2:145:163:176m',
            },
            'B_CADMIUM GREEN' => {
                'desc' => 'Cadmium green',

                'out' => $csi . '48:2:0:107:60m',
            },
            'B_CADMIUM ORANGE' => {
                'desc' => 'Cadmium orange',

                'out' => $csi . '48:2:237:135:45m',
            },
            'B_CADMIUM RED' => {
                'desc' => 'Cadmium red',

                'out' => $csi . '48:2:227:0:34m',
            },
            'B_CADMIUM YELLOW' => {
                'desc' => 'Cadmium yellow',

                'out' => $csi . '48:2:255:246:0m',
            },
            'B_CAFE AU LAIT' => {
                'desc' => 'Caf\303\251 au lait',

                'out' => $csi . '48:2:166:123:91m',
            },
            'B_CAFE NOIR' => {
                'desc' => 'Caf\303\251 noir',

                'out' => $csi . '48:2:75:54:33m',
            },
            'B_CAL POLY POMONA GREEN' => {
                'desc' => 'Cal Poly Pomona green',

                'out' => $csi . '48:2:30:77:43m',
            },
            'B_UNIVERSITY OF CALIFORNIA GOLD' => {
                'desc' => 'University of California Gold',
                'out'  => $csi . '48:2:183:135:39m',
            },
            'B_CAMBRIDGE BLUE' => {
                'desc' => 'Cambridge Blue',

                'out' => $csi . '48:2:163:193:173m',
            },
            'B_CAMEL' => {
                'desc' => 'Camel',

                'out' => $csi . '48:2:193:154:107m',
            },
            'B_CAMOUFLAGE GREEN' => {
                'desc' => 'Camouflage green',

                'out' => $csi . '48:2:120:134:107m',
            },
            'B_CANARY' => {
                'desc' => 'Canary',

                'out' => $csi . '48:2:255:255:153m',
            },
            'B_CANARY YELLOW' => {
                'desc' => 'Canary yellow',

                'out' => $csi . '48:2:255:239:0m',
            },
            'B_CANDY APPLE RED' => {
                'desc' => 'Candy apple red',

                'out' => $csi . '48:2:255:8:0m',
            },
            'B_CANDY PINK' => {
                'desc' => 'Candy pink',

                'out' => $csi . '48:2:228:113:122m',
            },
            'B_CAPRI' => {
                'desc' => 'Capri',

                'out' => $csi . '48:2:0:191:255m',
            },
            'B_CAPUT MORTUUM' => {
                'desc' => 'Caput mortuum',

                'out' => $csi . '48:2:89:39:32m',
            },
            'B_CARDINAL' => {
                'desc' => 'Cardinal',

                'out' => $csi . '48:2:196:30:58m',
            },
            'B_CARIBBEAN GREEN' => {
                'desc' => 'Caribbean green',

                'out' => $csi . '48:2:0:204:153m',
            },
            'B_CARMINE' => {
                'desc' => 'Carmine',

                'out' => $csi . '48:2:255:0:64m',
            },
            'B_CARMINE PINK' => {
                'desc' => 'Carmine pink',

                'out' => $csi . '48:2:235:76:66m',
            },
            'B_CARMINE RED' => {
                'desc' => 'Carmine red',

                'out' => $csi . '48:2:255:0:56m',
            },
            'B_CARNATION PINK' => {
                'desc' => 'Carnation pink',

                'out' => $csi . '48:2:255:166:201m',
            },
            'B_CARNELIAN' => {
                'desc' => 'Carnelian',

                'out' => $csi . '48:2:179:27:27m',
            },
            'B_CAROLINA BLUE' => {
                'desc' => 'Carolina blue',

                'out' => $csi . '48:2:153:186:221m',
            },
            'B_CARROT ORANGE' => {
                'desc' => 'Carrot orange',

                'out' => $csi . '48:2:237:145:33m',
            },
            'B_CELADON' => {
                'desc' => 'Celadon',

                'out' => $csi . '48:2:172:225:175m',
            },
            'B_CELESTE' => {
                'desc' => 'Celeste',

                'out' => $csi . '48:2:178:255:255m',
            },
            'B_CELESTIAL BLUE' => {
                'desc' => 'Celestial blue',

                'out' => $csi . '48:2:73:151:208m',
            },
            'B_CERISE' => {
                'desc' => 'Cerise',

                'out' => $csi . '48:2:222:49:99m',
            },
            'B_CERISE PINK' => {
                'desc' => 'Cerise pink',

                'out' => $csi . '48:2:236:59:131m',
            },
            'B_CERULEAN' => {
                'desc' => 'Cerulean',

                'out' => $csi . '48:2:0:123:167m',
            },
            'B_CERULEAN BLUE' => {
                'desc' => 'Cerulean blue',

                'out' => $csi . '48:2:42:82:190m',
            },
            'B_CG BLUE' => {
                'desc' => 'CG Blue',

                'out' => $csi . '48:2:0:122:165m',
            },
            'B_CG RED' => {
                'desc' => 'CG Red',

                'out' => $csi . '48:2:224:60:49m',
            },
            'B_CHAMOISEE' => {
                'desc' => 'Chamoisee',

                'out' => $csi . '48:2:160:120:90m',
            },
            'B_CHAMPAGNE' => {
                'desc' => 'Champagne',

                'out' => $csi . '48:2:250:214:165m',
            },
            'B_CHARCOAL' => {
                'desc' => 'Charcoal',

                'out' => $csi . '48:2:54:69:79m',
            },
            'B_CHARTREUSE' => {
                'desc' => 'Chartreuse',

                'out' => $csi . '48:2:127:255:0m',
            },
            'B_CHERRY' => {
                'desc' => 'Cherry',

                'out' => $csi . '48:2:222:49:99m',
            },
            'B_CHERRY BLOSSOM PINK' => {
                'desc' => 'Cherry blossom pink',

                'out' => $csi . '48:2:255:183:197m',
            },
            'B_CHESTNUT' => {
                'desc' => 'Chestnut',

                'out' => $csi . '48:2:205:92:92m',
            },
            'B_CHOCOLATE' => {
                'desc' => 'Chocolate',

                'out' => $csi . '48:2:210:105:30m',
            },
            'B_CHROME YELLOW' => {
                'desc' => 'Chrome yellow',

                'out' => $csi . '48:2:255:167:0m',
            },
            'B_CINEREOUS' => {
                'desc' => 'Cinereous',

                'out' => $csi . '48:2:152:129:123m',
            },
            'B_CINNABAR' => {
                'desc' => 'Cinnabar',

                'out' => $csi . '48:2:227:66:52m',
            },
            'B_CINNAMON' => {
                'desc' => 'Cinnamon',

                'out' => $csi . '48:2:210:105:30m',
            },
            'B_CITRINE' => {
                'desc' => 'Citrine',

                'out' => $csi . '48:2:228:208:10m',
            },
            'B_CLASSIC ROSE' => {
                'desc' => 'Classic rose',

                'out' => $csi . '48:2:251:204:231m',
            },
            'B_COBALT' => {
                'desc' => 'Cobalt',

                'out' => $csi . '48:2:0:71:171m',
            },
            'B_COCOA BROWN' => {
                'desc' => 'Cocoa brown',

                'out' => $csi . '48:2:210:105:30m',
            },
            'B_COFFEE' => {
                'desc' => 'Coffee',

                'out' => $csi . '48:2:111:78:55m',
            },
            'B_COLUMBIA BLUE' => {
                'desc' => 'Columbia blue',

                'out' => $csi . '48:2:155:221:255m',
            },
            'B_COOL BLACK' => {
                'desc' => 'Cool black',

                'out' => $csi . '48:2:0:46:99m',
            },
            'B_COOL GRAY' => {
                'desc' => 'Cool grey',

                'out' => $csi . '48:2:140:146:172m',
            },
            'B_COPPER' => {
                'desc' => 'Copper',

                'out' => $csi . '48:2:184:115:51m',
            },
            'B_COPPER ROSE' => {
                'desc' => 'Copper rose',

                'out' => $csi . '48:2:153:102:102m',
            },
            'B_COQUELICOT' => {
                'desc' => 'Coquelicot',

                'out' => $csi . '48:2:255:56:0m',
            },
            'B_CORAL' => {
                'desc' => 'Coral',

                'out' => $csi . '48:2:255:127:80m',
            },
            'B_CORAL PINK' => {
                'desc' => 'Coral pink',

                'out' => $csi . '48:2:248:131:121m',
            },
            'B_CORAL RED' => {
                'desc' => 'Coral red',

                'out' => $csi . '48:2:255:64:64m',
            },
            'B_CORDOVAN' => {
                'desc' => 'Cordovan',

                'out' => $csi . '48:2:137:63:69m',
            },
            'B_CORN' => {
                'desc' => 'Corn',

                'out' => $csi . '48:2:251:236:93m',
            },
            'B_CORNELL RED' => {
                'desc' => 'Cornell Red',

                'out' => $csi . '48:2:179:27:27m',
            },
            'B_CORNFLOWER' => {
                'desc' => 'Cornflower',

                'out' => $csi . '48:2:154:206:235m',
            },
            'B_CORNFLOWER BLUE' => {
                'desc' => 'Cornflower blue',

                'out' => $csi . '48:2:100:149:237m',
            },
            'B_CORNSILK' => {
                'desc' => 'Cornsilk',

                'out' => $csi . '48:2:255:248:220m',
            },
            'B_COSMIC LATTE' => {
                'desc' => 'Cosmic latte',

                'out' => $csi . '48:2:255:248:231m',
            },
            'B_COTTON CANDY' => {
                'desc' => 'Cotton candy',

                'out' => $csi . '48:2:255:188:217m',
            },
            'B_CREAM' => {
                'desc' => 'Cream',

                'out' => $csi . '48:2:255:253:208m',
            },
            'B_CRIMSON' => {
                'desc' => 'Crimson',

                'out' => $csi . '48:2:220:20:60m',
            },
            'B_CRIMSON GLORY' => {
                'desc' => 'Crimson glory',

                'out' => $csi . '48:2:190:0:50m',
            },
            'B_CRIMSON RED' => {
                'desc' => 'Crimson Red',

                'out' => $csi . '48:2:153:0:0m',
            },
            'B_DAFFODIL' => {
                'desc' => 'Daffodil',

                'out' => $csi . '48:2:255:255:49m',
            },
            'B_DANDELION' => {
                'desc' => 'Dandelion',

                'out' => $csi . '48:2:240:225:48m',
            },
            'B_DARK BLUE' => {
                'desc' => 'Dark blue',

                'out' => $csi . '48:2:0:0:139m',
            },
            'B_DARK BROWN' => {
                'desc' => 'Dark brown',

                'out' => $csi . '48:2:101:67:33m',
            },
            'B_DARK BYZANTIUM' => {
                'desc' => 'Dark byzantium',

                'out' => $csi . '48:2:93:57:84m',
            },
            'B_DARK CANDY APPLE RED' => {
                'desc' => 'Dark candy apple red',

                'out' => $csi . '48:2:164:0:0m',
            },
            'B_DARK CERULEAN' => {
                'desc' => 'Dark cerulean',

                'out' => $csi . '48:2:8:69:126m',
            },
            'B_DARK CHESTNUT' => {
                'desc' => 'Dark chestnut',

                'out' => $csi . '48:2:152:105:96m',
            },
            'B_DARK CORAL' => {
                'desc' => 'Dark coral',

                'out' => $csi . '48:2:205:91:69m',
            },
            'B_DARK CYAN' => {
                'desc' => 'Dark cyan',

                'out' => $csi . '48:2:0:139:139m',
            },
            'B_DARK ELECTRIC BLUE' => {
                'desc' => 'Dark electric blue',

                'out' => $csi . '48:2:83:104:120m',
            },
            'B_DARK GOLDENROD' => {
                'desc' => 'Dark goldenrod',

                'out' => $csi . '48:2:184:134:11m',
            },
            'B_DARK GRAY' => {
                'desc' => 'Dark gray',

                'out' => $csi . '48:2:169:169:169m',
            },
            'B_DARK GREEN' => {
                'desc' => 'Dark green',

                'out' => $csi . '48:2:1:50:32m',
            },
            'B_DARK JUNGLE GREEN' => {
                'desc' => 'Dark jungle green',

                'out' => $csi . '48:2:26:36:33m',
            },
            'B_DARK KHAKI' => {
                'desc' => 'Dark khaki',

                'out' => $csi . '48:2:189:183:107m',
            },
            'B_DARK LAVA' => {
                'desc' => 'Dark lava',

                'out' => $csi . '48:2:72:60:50m',
            },
            'B_DARK LAVENDER' => {
                'desc' => 'Dark lavender',

                'out' => $csi . '48:2:115:79:150m',
            },
            'B_DARK MAGENTA' => {
                'desc' => 'Dark magenta',

                'out' => $csi . '48:2:139:0:139m',
            },
            'B_DARK MIDNIGHT BLUE' => {
                'desc' => 'Dark midnight blue',

                'out' => $csi . '48:2:0:51:102m',
            },
            'B_DARK OLIVE GREEN' => {
                'desc' => 'Dark olive green',

                'out' => $csi . '48:2:85:107:47m',
            },
            'B_DARK ORANGE' => {
                'desc' => 'Dark orange',

                'out' => $csi . '48:2:255:140:0m',
            },
            'B_DARK ORCHID' => {
                'desc' => 'Dark orchid',

                'out' => $csi . '48:2:153:50:204m',
            },
            'B_DARK PASTEL BLUE' => {
                'desc' => 'Dark pastel blue',

                'out' => $csi . '48:2:119:158:203m',
            },
            'B_DARK PASTEL GREEN' => {
                'desc' => 'Dark pastel green',

                'out' => $csi . '48:2:3:192:60m',
            },
            'B_DARK PASTEL PURPLE' => {
                'desc' => 'Dark pastel purple',

                'out' => $csi . '48:2:150:111:214m',
            },
            'B_DARK PASTEL RED' => {
                'desc' => 'Dark pastel red',

                'out' => $csi . '48:2:194:59:34m',
            },
            'B_DARK PINK' => {
                'desc' => 'Dark pink',

                'out' => $csi . '48:2:231:84:128m',
            },
            'B_DARK POWDER BLUE' => {
                'desc' => 'Dark powder blue',

                'out' => $csi . '48:2:0:51:153m',
            },
            'B_DARK RASPBERRY' => {
                'desc' => 'Dark raspberry',

                'out' => $csi . '48:2:135:38:87m',
            },
            'B_DARK RED' => {
                'desc' => 'Dark red',

                'out' => $csi . '48:2:139:0:0m',
            },
            'B_DARK SALMON' => {
                'desc' => 'Dark salmon',

                'out' => $csi . '48:2:233:150:122m',
            },
            'B_DARK SCARLET' => {
                'desc' => 'Dark scarlet',

                'out' => $csi . '48:2:86:3:25m',
            },
            'B_DARK SEA GREEN' => {
                'desc' => 'Dark sea green',

                'out' => $csi . '48:2:143:188:143m',
            },
            'B_DARK SIENNA' => {
                'desc' => 'Dark sienna',

                'out' => $csi . '48:2:60:20:20m',
            },
            'B_DARK SLATE BLUE' => {
                'desc' => 'Dark slate blue',

                'out' => $csi . '48:2:72:61:139m',
            },
            'B_DARK SLATE GRAY' => {
                'desc' => 'Dark slate gray',

                'out' => $csi . '48:2:47:79:79m',
            },
            'B_DARK SPRING GREEN' => {
                'desc' => 'Dark spring green',

                'out' => $csi . '48:2:23:114:69m',
            },
            'B_DARK TAN' => {
                'desc' => 'Dark tan',

                'out' => $csi . '48:2:145:129:81m',
            },
            'B_DARK TANGERINE' => {
                'desc' => 'Dark tangerine',

                'out' => $csi . '48:2:255:168:18m',
            },
            'B_DARK TAUPE' => {
                'desc' => 'Dark taupe',

                'out' => $csi . '48:2:72:60:50m',
            },
            'B_DARK TERRA COTTA' => {
                'desc' => 'Dark terra cotta',

                'out' => $csi . '48:2:204:78:92m',
            },
            'B_DARK TURQUOISE' => {
                'desc' => 'Dark turquoise',

                'out' => $csi . '48:2:0:206:209m',
            },
            'B_DARK VIOLET' => {
                'desc' => 'Dark violet',

                'out' => $csi . '48:2:148:0:211m',
            },
            'B_DARTMOUTH GREEN' => {
                'desc' => 'Dartmouth green',

                'out' => $csi . '48:2:0:105:62m',
            },
            'B_DAVY GRAY' => {
                'desc' => 'Davy grey',

                'out' => $csi . '48:2:85:85:85m',
            },
            'B_DEBIAN RED' => {
                'desc' => 'Debian red',

                'out' => $csi . '48:2:215:10:83m',
            },
            'B_DEEP CARMINE' => {
                'desc' => 'Deep carmine',

                'out' => $csi . '48:2:169:32:62m',
            },
            'B_DEEP CARMINE PINK' => {
                'desc' => 'Deep carmine pink',

                'out' => $csi . '48:2:239:48:56m',
            },
            'B_DEEP CARROT ORANGE' => {
                'desc' => 'Deep carrot orange',

                'out' => $csi . '48:2:233:105:44m',
            },
            'B_DEEP CERISE' => {
                'desc' => 'Deep cerise',

                'out' => $csi . '48:2:218:50:135m',
            },
            'B_DEEP CHAMPAGNE' => {
                'desc' => 'Deep champagne',

                'out' => $csi . '48:2:250:214:165m',
            },
            'B_DEEP CHESTNUT' => {
                'desc' => 'Deep chestnut',

                'out' => $csi . '48:2:185:78:72m',
            },
            'B_DEEP COFFEE' => {
                'desc' => 'Deep coffee',

                'out' => $csi . '48:2:112:66:65m',
            },
            'B_DEEP FUCHSIA' => {
                'desc' => 'Deep fuchsia',

                'out' => $csi . '48:2:193:84:193m',
            },
            'B_DEEP JUNGLE GREEN' => {
                'desc' => 'Deep jungle green',

                'out' => $csi . '48:2:0:75:73m',
            },
            'B_DEEP LILAC' => {
                'desc' => 'Deep lilac',

                'out' => $csi . '48:2:153:85:187m',
            },
            'B_DEEP MAGENTA' => {
                'desc' => 'Deep magenta',

                'out' => $csi . '48:2:204:0:204m',
            },
            'B_DEEP PEACH' => {
                'desc' => 'Deep peach',

                'out' => $csi . '48:2:255:203:164m',
            },
            'B_DEEP PINK' => {
                'desc' => 'Deep pink',

                'out' => $csi . '48:2:255:20:147m',
            },
            'B_DEEP SAFFRON' => {
                'desc' => 'Deep saffron',

                'out' => $csi . '48:2:255:153:51m',
            },
            'B_DEEP SKY BLUE' => {
                'desc' => 'Deep sky blue',

                'out' => $csi . '48:2:0:191:255m',
            },
            'B_DENIM' => {
                'desc' => 'Denim',

                'out' => $csi . '48:2:21:96:189m',
            },
            'B_DESERT' => {
                'desc' => 'Desert',

                'out' => $csi . '48:2:193:154:107m',
            },
            'B_DESERT SAND' => {
                'desc' => 'Desert sand',

                'out' => $csi . '48:2:237:201:175m',
            },
            'B_DIM GRAY' => {
                'desc' => 'Dim gray',

                'out' => $csi . '48:2:105:105:105m',
            },
            'B_DODGER BLUE' => {
                'desc' => 'Dodger blue',

                'out' => $csi . '48:2:30:144:255m',
            },
            'B_DOGWOOD ROSE' => {
                'desc' => 'Dogwood rose',

                'out' => $csi . '48:2:215:24:104m',
            },
            'B_DOLLAR BILL' => {
                'desc' => 'Dollar bill',

                'out' => $csi . '48:2:133:187:101m',
            },
            'B_DRAB' => {
                'desc' => 'Drab',

                'out' => $csi . '48:2:150:113:23m',
            },
            'B_DUKE BLUE' => {
                'desc' => 'Duke blue',

                'out' => $csi . '48:2:0:0:156m',
            },
            'B_EARTH YELLOW' => {
                'desc' => 'Earth yellow',

                'out' => $csi . '48:2:225:169:95m',
            },
            'B_ECRU' => {
                'desc' => 'Ecru',

                'out' => $csi . '48:2:194:178:128m',
            },
            'B_EGGPLANT' => {
                'desc' => 'Eggplant',

                'out' => $csi . '48:2:97:64:81m',
            },
            'B_EGGSHELL' => {
                'desc' => 'Eggshell',

                'out' => $csi . '48:2:240:234:214m',
            },
            'B_EGYPTIAN BLUE' => {
                'desc' => 'Egyptian blue',

                'out' => $csi . '48:2:16:52:166m',
            },
            'B_ELECTRIC BLUE' => {
                'desc' => 'Electric blue',

                'out' => $csi . '48:2:125:249:255m',
            },
            'B_ELECTRIC CRIMSON' => {
                'desc' => 'Electric crimson',

                'out' => $csi . '48:2:255:0:63m',
            },
            'B_ELECTRIC CYAN' => {
                'desc' => 'Electric cyan',

                'out' => $csi . '48:2:0:255:255m',
            },
            'B_ELECTRIC GREEN' => {
                'desc' => 'Electric green',

                'out' => $csi . '48:2:0:255:0m',
            },
            'B_ELECTRIC INDIGO' => {
                'desc' => 'Electric indigo',

                'out' => $csi . '48:2:111:0:255m',
            },
            'B_ELECTRIC LAVENDER' => {
                'desc' => 'Electric lavender',

                'out' => $csi . '48:2:244:187:255m',
            },
            'B_ELECTRIC LIME' => {
                'desc' => 'Electric lime',

                'out' => $csi . '48:2:204:255:0m',
            },
            'B_ELECTRIC PURPLE' => {
                'desc' => 'Electric purple',

                'out' => $csi . '48:2:191:0:255m',
            },
            'B_ELECTRIC ULTRAMARINE' => {
                'desc' => 'Electric ultramarine',

                'out' => $csi . '48:2:63:0:255m',
            },
            'B_ELECTRIC VIOLET' => {
                'desc' => 'Electric violet',

                'out' => $csi . '48:2:143:0:255m',
            },
            'B_ELECTRIC YELLOW' => {
                'desc' => 'Electric yellow',

                'out' => $csi . '48:2:255:255:0m',
            },
            'B_EMERALD' => {
                'desc' => 'Emerald',

                'out' => $csi . '48:2:80:200:120m',
            },
            'B_ETON BLUE' => {
                'desc' => 'Eton blue',

                'out' => $csi . '48:2:150:200:162m',
            },
            'B_FALLOW' => {
                'desc' => 'Fallow',

                'out' => $csi . '48:2:193:154:107m',
            },
            'B_FALU RED' => {
                'desc' => 'Falu red',

                'out' => $csi . '48:2:128:24:24m',
            },
            'B_FAMOUS' => {
                'desc' => 'Famous',

                'out' => $csi . '48:2:255:0:255m',
            },
            'B_FANDANGO' => {
                'desc' => 'Fandango',

                'out' => $csi . '48:2:181:51:137m',
            },
            'B_FASHION FUCHSIA' => {
                'desc' => 'Fashion fuchsia',

                'out' => $csi . '48:2:244:0:161m',
            },
            'B_FAWN' => {
                'desc' => 'Fawn',

                'out' => $csi . '48:2:229:170:112m',
            },
            'B_FELDGRAU' => {
                'desc' => 'Feldgrau',

                'out' => $csi . '48:2:77:93:83m',
            },
            'B_FERN' => {
                'desc' => 'Fern',

                'out' => $csi . '48:2:113:188:120m',
            },
            'B_FERN GREEN' => {
                'desc' => 'Fern green',

                'out' => $csi . '48:2:79:121:66m',
            },
            'B_FERRARI RED' => {
                'desc' => 'Ferrari Red',

                'out' => $csi . '48:2:255:40:0m',
            },
            'B_FIELD DRAB' => {
                'desc' => 'Field drab',

                'out' => $csi . '48:2:108:84:30m',
            },
            'B_FIRE ENGINE RED' => {
                'desc' => 'Fire engine red',

                'out' => $csi . '48:2:206:32:41m',
            },
            'B_FIREBRICK' => {
                'desc' => 'Firebrick',

                'out' => $csi . '48:2:178:34:34m',
            },
            'B_FLAME' => {
                'desc' => 'Flame',

                'out' => $csi . '48:2:226:88:34m',
            },
            'B_FLAMINGO PINK' => {
                'desc' => 'Flamingo pink',

                'out' => $csi . '48:2:252:142:172m',
            },
            'B_FLAVESCENT' => {
                'desc' => 'Flavescent',

                'out' => $csi . '48:2:247:233:142m',
            },
            'B_FLAX' => {
                'desc' => 'Flax',

                'out' => $csi . '48:2:238:220:130m',
            },
            'B_FLORAL WHITE' => {
                'desc' => 'Floral white',

                'out' => $csi . '48:2:255:250:240m',
            },
            'B_FLUORESCENT ORANGE' => {
                'desc' => 'Fluorescent orange',

                'out' => $csi . '48:2:255:191:0m',
            },
            'B_FLUORESCENT PINK' => {
                'desc' => 'Fluorescent pink',

                'out' => $csi . '48:2:255:20:147m',
            },
            'B_FLUORESCENT YELLOW' => {
                'desc' => 'Fluorescent yellow',

                'out' => $csi . '48:2:204:255:0m',
            },
            'B_FOLLY' => {
                'desc' => 'Folly',

                'out' => $csi . '48:2:255:0:79m',
            },
            'B_FOREST GREEN' => {
                'desc' => 'Forest green',

                'out' => $csi . '48:2:34:139:34m',
            },
            'B_FRENCH BEIGE' => {
                'desc' => 'French beige',

                'out' => $csi . '48:2:166:123:91m',
            },
            'B_FRENCH BLUE' => {
                'desc' => 'French blue',

                'out' => $csi . '48:2:0:114:187m',
            },
            'B_FRENCH LILAC' => {
                'desc' => 'French lilac',

                'out' => $csi . '48:2:134:96:142m',
            },
            'B_FRENCH ROSE' => {
                'desc' => 'French rose',

                'out' => $csi . '48:2:246:74:138m',
            },
            'B_FUCHSIA' => {
                'desc' => 'Fuchsia',

                'out' => $csi . '48:2:255:0:255m',
            },
            'B_FUCHSIA PINK' => {
                'desc' => 'Fuchsia pink',

                'out' => $csi . '48:2:255:119:255m',
            },
            'B_FULVOUS' => {
                'desc' => 'Fulvous',

                'out' => $csi . '48:2:228:132:0m',
            },
            'B_FUZZY WUZZY' => {
                'desc' => 'Fuzzy Wuzzy',

                'out' => $csi . '48:2:204:102:102m',
            },
            'B_GAINSBORO' => {
                'desc' => 'Gainsboro',

                'out' => $csi . '48:2:220:220:220m',
            },
            'B_GAMBOGE' => {
                'desc' => 'Gamboge',

                'out' => $csi . '48:2:228:155:15m',
            },
            'B_GHOST WHITE' => {
                'desc' => 'Ghost white',

                'out' => $csi . '48:2:248:248:255m',
            },
            'B_GINGER' => {
                'desc' => 'Ginger',

                'out' => $csi . '48:2:176:101:0m',
            },
            'B_GLAUCOUS' => {
                'desc' => 'Glaucous',

                'out' => $csi . '48:2:96:130:182m',
            },
            'B_GLITTER' => {
                'desc' => 'Glitter',

                'out' => $csi . '48:2:230:232:250m',
            },
            'B_GOLD' => {
                'desc' => 'Gold',

                'out' => $csi . '48:2:255:215:0m',
            },
            'B_GOLDEN BROWN' => {
                'desc' => 'Golden brown',

                'out' => $csi . '48:2:153:101:21m',
            },
            'B_GOLDEN POPPY' => {
                'desc' => 'Golden poppy',

                'out' => $csi . '48:2:252:194:0m',
            },
            'B_GOLDEN YELLOW' => {
                'desc' => 'Golden yellow',

                'out' => $csi . '48:2:255:223:0m',
            },
            'B_GOLDENROD' => {
                'desc' => 'Goldenrod',

                'out' => $csi . '48:2:218:165:32m',
            },
            'B_GRANNY SMITH APPLE' => {
                'desc' => 'Granny Smith Apple',

                'out' => $csi . '48:2:168:228:160m',
            },
            'B_GRAY' => {
                'desc' => 'Gray',

                'out' => $csi . '48:2:128:128:128m',
            },
            'B_GRAY ASPARAGUS' => {
                'desc' => 'Gray asparagus',

                'out' => $csi . '48:2:70:89:69m',
            },
            'B_GREEN BLUE' => {
                'desc' => 'Green Blue',

                'out' => $csi . '48:2:17:100:180m',
            },
            'B_GREEN YELLOW' => {
                'desc' => 'Green yellow',

                'out' => $csi . '48:2:173:255:47m',
            },
            'B_GRULLO' => {
                'desc' => 'Grullo',

                'out' => $csi . '48:2:169:154:134m',
            },
            'B_GUPPIE GREEN' => {
                'desc' => 'Guppie green',

                'out' => $csi . '48:2:0:255:127m',
            },
            'B_HALAYA UBE' => {
                'desc' => 'Halaya ube',

                'out' => $csi . '48:2:102:56:84m',
            },
            'B_HAN BLUE' => {
                'desc' => 'Han blue',

                'out' => $csi . '48:2:68:108:207m',
            },
            'B_HAN PURPLE' => {
                'desc' => 'Han purple',

                'out' => $csi . '48:2:82:24:250m',
            },
            'B_HANSA YELLOW' => {
                'desc' => 'Hansa yellow',

                'out' => $csi . '48:2:233:214:107m',
            },
            'B_HARLEQUIN' => {
                'desc' => 'Harlequin',

                'out' => $csi . '48:2:63:255:0m',
            },
            'B_HARVARD CRIMSON' => {
                'desc' => 'Harvard crimson',

                'out' => $csi . '48:2:201:0:22m',
            },
            'B_HARVEST GOLD' => {
                'desc' => 'Harvest Gold',

                'out' => $csi . '48:2:218:145:0m',
            },
            'B_HEART GOLD' => {
                'desc' => 'Heart Gold',

                'out' => $csi . '48:2:128:128:0m',
            },
            'B_HELIOTROPE' => {
                'desc' => 'Heliotrope',

                'out' => $csi . '48:2:223:115:255m',
            },
            'B_HOLLYWOOD CERISE' => {
                'desc' => 'Hollywood cerise',

                'out' => $csi . '48:2:244:0:161m',
            },
            'B_HONEYDEW' => {
                'desc' => 'Honeydew',

                'out' => $csi . '48:2:240:255:240m',
            },
            'B_HOOKER GREEN' => {
                'desc' => 'Hooker green',

                'out' => $csi . '48:2:73:121:107m',
            },
            'B_HOT MAGENTA' => {
                'desc' => 'Hot magenta',

                'out' => $csi . '48:2:255:29:206m',
            },
            'B_HOT PINK' => {
                'desc' => 'Hot pink',

                'out' => $csi . '48:2:255:105:180m',
            },
            'B_HUNTER GREEN' => {
                'desc' => 'Hunter green',

                'out' => $csi . '48:2:53:94:59m',
            },
            'B_ICTERINE' => {
                'desc' => 'Icterine',

                'out' => $csi . '48:2:252:247:94m',
            },
            'B_INCHWORM' => {
                'desc' => 'Inchworm',

                'out' => $csi . '48:2:178:236:93m',
            },
            'B_INDIA GREEN' => {
                'desc' => 'India green',

                'out' => $csi . '48:2:19:136:8m',
            },
            'B_INDIAN RED' => {
                'desc' => 'Indian red',

                'out' => $csi . '48:2:205:92:92m',
            },
            'B_INDIAN YELLOW' => {
                'desc' => 'Indian yellow',

                'out' => $csi . '48:2:227:168:87m',
            },
            'B_INDIGO' => {
                'desc' => 'Indigo',

                'out' => $csi . '48:2:75:0:130m',
            },
            'B_INTERNATIONAL KLEIN' => {
                'desc' => 'International Klein',

                'out' => $csi . '48:2:0:47:167m',
            },
            'B_INTERNATIONAL ORANGE' => {
                'desc' => 'International orange',

                'out' => $csi . '48:2:255:79:0m',
            },
            'B_IRIS' => {
                'desc' => 'Iris',

                'out' => $csi . '48:2:90:79:207m',
            },
            'B_ISABELLINE' => {
                'desc' => 'Isabelline',

                'out' => $csi . '48:2:244:240:236m',
            },
            'B_ISLAMIC GREEN' => {
                'desc' => 'Islamic green',

                'out' => $csi . '48:2:0:144:0m',
            },
            'B_IVORY' => {
                'desc' => 'Ivory',

                'out' => $csi . '48:2:255:255:240m',
            },
            'B_JADE' => {
                'desc' => 'Jade',

                'out' => $csi . '48:2:0:168:107m',
            },
            'B_JASMINE' => {
                'desc' => 'Jasmine',

                'out' => $csi . '48:2:248:222:126m',
            },
            'B_JASPER' => {
                'desc' => 'Jasper',

                'out' => $csi . '48:2:215:59:62m',
            },
            'B_JAZZBERRY JAM' => {
                'desc' => 'Jazzberry jam',

                'out' => $csi . '48:2:165:11:94m',
            },
            'B_JONQUIL' => {
                'desc' => 'Jonquil',

                'out' => $csi . '48:2:250:218:94m',
            },
            'B_JUNE BUD' => {
                'desc' => 'June bud',

                'out' => $csi . '48:2:189:218:87m',
            },
            'B_JUNGLE GREEN' => {
                'desc' => 'Jungle green',

                'out' => $csi . '48:2:41:171:135m',
            },
            'B_KELLY GREEN' => {
                'desc' => 'Kelly green',

                'out' => $csi . '48:2:76:187:23m',
            },
            'B_KHAKI' => {
                'desc' => 'Khaki',

                'out' => $csi . '48:2:195:176:145m',
            },
            'B_KU CRIMSON' => {
                'desc' => 'KU Crimson',

                'out' => $csi . '48:2:232:0:13m',
            },
            'B_LA SALLE GREEN' => {
                'desc' => 'La Salle Green',

                'out' => $csi . '48:2:8:120:48m',
            },
            'B_LANGUID LAVENDER' => {
                'desc' => 'Languid lavender',

                'out' => $csi . '48:2:214:202:221m',
            },
            'B_LAPIS LAZULI' => {
                'desc' => 'Lapis lazuli',

                'out' => $csi . '48:2:38:97:156m',
            },
            'B_LASER LEMON' => {
                'desc' => 'Laser Lemon',

                'out' => $csi . '48:2:254:254:34m',
            },
            'B_LAUREL GREEN' => {
                'desc' => 'Laurel green',

                'out' => $csi . '48:2:169:186:157m',
            },
            'B_LAVA' => {
                'desc' => 'Lava',

                'out' => $csi . '48:2:207:16:32m',
            },
            'B_LAVENDER' => {
                'desc' => 'Lavender',

                'out' => $csi . '48:2:230:230:250m',
            },
            'B_LAVENDER BLUE' => {
                'desc' => 'Lavender blue',

                'out' => $csi . '48:2:204:204:255m',
            },
            'B_LAVENDER BLUSH' => {
                'desc' => 'Lavender blush',

                'out' => $csi . '48:2:255:240:245m',
            },
            'B_LAVENDER GRAY' => {
                'desc' => 'Lavender gray',

                'out' => $csi . '48:2:196:195:208m',
            },
            'B_LAVENDER INDIGO' => {
                'desc' => 'Lavender indigo',

                'out' => $csi . '48:2:148:87:235m',
            },
            'B_LAVENDER MAGENTA' => {
                'desc' => 'Lavender magenta',

                'out' => $csi . '48:2:238:130:238m',
            },
            'B_LAVENDER MIST' => {
                'desc' => 'Lavender mist',

                'out' => $csi . '48:2:230:230:250m',
            },
            'B_LAVENDER PINK' => {
                'desc' => 'Lavender pink',

                'out' => $csi . '48:2:251:174:210m',
            },
            'B_LAVENDER PURPLE' => {
                'desc' => 'Lavender purple',

                'out' => $csi . '48:2:150:123:182m',
            },
            'B_LAVENDER ROSE' => {
                'desc' => 'Lavender rose',

                'out' => $csi . '48:2:251:160:227m',
            },
            'B_LAWN GREEN' => {
                'desc' => 'Lawn green',

                'out' => $csi . '48:2:124:252:0m',
            },
            'B_LEMON' => {
                'desc' => 'Lemon',

                'out' => $csi . '48:2:255:247:0m',
            },
            'B_LEMON CHIFFON' => {
                'desc' => 'Lemon chiffon',

                'out' => $csi . '48:2:255:250:205m',
            },
            'B_LEMON LIME' => {
                'desc' => 'Lemon lime',

                'out' => $csi . '48:2:191:255:0m',
            },
            'B_LEMON YELLOW' => {
                'desc' => 'Lemon Yellow',

                'out' => $csi . '48:2:255:244:79m',
            },
            'B_LIGHT APRICOT' => {
                'desc' => 'Light apricot',

                'out' => $csi . '48:2:253:213:177m',
            },
            'B_LIGHT BLUE' => {
                'desc' => 'Light blue',

                'out' => $csi . '48:2:173:216:230m',
            },
            'B_LIGHT BROWN' => {
                'desc' => 'Light brown',

                'out' => $csi . '48:2:181:101:29m',
            },
            'B_LIGHT CARMINE PINK' => {
                'desc' => 'Light carmine pink',

                'out' => $csi . '48:2:230:103:113m',
            },
            'B_LIGHT CORAL' => {
                'desc' => 'Light coral',

                'out' => $csi . '48:2:240:128:128m',
            },
            'B_LIGHT CORNFLOWER BLUE' => {
                'desc' => 'Light cornflower blue',

                'out' => $csi . '48:2:147:204:234m',
            },
            'B_LIGHT CRIMSON' => {
                'desc' => 'Light Crimson',

                'out' => $csi . '48:2:245:105:145m',
            },
            'B_LIGHT CYAN' => {
                'desc' => 'Light cyan',

                'out' => $csi . '48:2:224:255:255m',
            },
            'B_LIGHT FUCHSIA PINK' => {
                'desc' => 'Light fuchsia pink',

                'out' => $csi . '48:2:249:132:239m',
            },
            'B_LIGHT GOLDENROD YELLOW' => {
                'desc' => 'Light goldenrod yellow',

                'out' => $csi . '48:2:250:250:210m',
            },
            'B_LIGHT GRAY' => {
                'desc' => 'Light gray',

                'out' => $csi . '48:2:211:211:211m',
            },
            'B_LIGHT GREEN' => {
                'desc' => 'Light green',

                'out' => $csi . '48:2:144:238:144m',
            },
            'B_LIGHT KHAKI' => {
                'desc' => 'Light khaki',

                'out' => $csi . '48:2:240:230:140m',
            },
            'B_LIGHT PASTEL PURPLE' => {
                'desc' => 'Light pastel purple',

                'out' => $csi . '48:2:177:156:217m',
            },
            'B_LIGHT PINK' => {
                'desc' => 'Light pink',

                'out' => $csi . '48:2:255:182:193m',
            },
            'B_LIGHT SALMON' => {
                'desc' => 'Light salmon',

                'out' => $csi . '48:2:255:160:122m',
            },
            'B_LIGHT SALMON PINK' => {
                'desc' => 'Light salmon pink',

                'out' => $csi . '48:2:255:153:153m',
            },
            'B_LIGHT SEA GREEN' => {
                'desc' => 'Light sea green',

                'out' => $csi . '48:2:32:178:170m',
            },
            'B_LIGHT SKY BLUE' => {
                'desc' => 'Light sky blue',

                'out' => $csi . '48:2:135:206:250m',
            },
            'B_LIGHT SLATE GRAY' => {
                'desc' => 'Light slate gray',

                'out' => $csi . '48:2:119:136:153m',
            },
            'B_LIGHT TAUPE' => {
                'desc' => 'Light taupe',

                'out' => $csi . '48:2:179:139:109m',
            },
            'B_LIGHT THULIAN PINK' => {
                'desc' => 'Light Thulian pink',

                'out' => $csi . '48:2:230:143:172m',
            },
            'B_LIGHT YELLOW' => {
                'desc' => 'Light yellow',

                'out' => $csi . '48:2:255:255:237m',
            },
            'B_LILAC' => {
                'desc' => 'Lilac',

                'out' => $csi . '48:2:200:162:200m',
            },
            'B_LIME' => {
                'desc' => 'Lime',

                'out' => $csi . '48:2:191:255:0m',
            },
            'B_LIME GREEN' => {
                'desc' => 'Lime green',

                'out' => $csi . '48:2:50:205:50m',
            },
            'B_LINCOLN GREEN' => {
                'desc' => 'Lincoln green',

                'out' => $csi . '48:2:25:89:5m',
            },
            'B_LINEN' => {
                'desc' => 'Linen',

                'out' => $csi . '48:2:250:240:230m',
            },
            'B_LION' => {
                'desc' => 'Lion',

                'out' => $csi . '48:2:193:154:107m',
            },
            'B_LIVER' => {
                'desc' => 'Liver',

                'out' => $csi . '48:2:83:75:79m',
            },
            'B_LUST' => {
                'desc' => 'Lust',

                'out' => $csi . '48:2:230:32:32m',
            },
            'B_MACARONI AND CHEESE' => {
                'desc' => 'Macaroni and Cheese',

                'out' => $csi . '48:2:255:189:136m',
            },
            'B_MAGENTA' => {
                'desc' => 'Magenta',

                'out' => $csi . '48:2:255:0:255m',
            },
            'B_MAGIC MINT' => {
                'desc' => 'Magic mint',

                'out' => $csi . '48:2:170:240:209m',
            },
            'B_MAGNOLIA' => {
                'desc' => 'Magnolia',

                'out' => $csi . '48:2:248:244:255m',
            },
            'B_MAHOGANY' => {
                'desc' => 'Mahogany',

                'out' => $csi . '48:2:192:64:0m',
            },
            'B_MAIZE' => {
                'desc' => 'Maize',

                'out' => $csi . '48:2:251:236:93m',
            },
            'B_MAJORELLE BLUE' => {
                'desc' => 'Majorelle Blue',

                'out' => $csi . '48:2:96:80:220m',
            },
            'B_MALACHITE' => {
                'desc' => 'Malachite',

                'out' => $csi . '48:2:11:218:81m',
            },
            'B_MANATEE' => {
                'desc' => 'Manatee',

                'out' => $csi . '48:2:151:154:170m',
            },
            'B_MANGO TANGO' => {
                'desc' => 'Mango Tango',

                'out' => $csi . '48:2:255:130:67m',
            },
            'B_MANTIS' => {
                'desc' => 'Mantis',

                'out' => $csi . '48:2:116:195:101m',
            },
            'B_MAROON' => {
                'desc' => 'Maroon',

                'out' => $csi . '48:2:128:0:0m',
            },
            'B_MAUVE' => {
                'desc' => 'Mauve',

                'out' => $csi . '48:2:224:176:255m',
            },
            'B_MAUVE TAUPE' => {
                'desc' => 'Mauve taupe',

                'out' => $csi . '48:2:145:95:109m',
            },
            'B_MAUVELOUS' => {
                'desc' => 'Mauvelous',

                'out' => $csi . '48:2:239:152:170m',
            },
            'B_MAYA BLUE' => {
                'desc' => 'Maya blue',

                'out' => $csi . '48:2:115:194:251m',
            },
            'B_MEAT BROWN' => {
                'desc' => 'Meat brown',

                'out' => $csi . '48:2:229:183:59m',
            },
            'B_MEDIUM AQUAMARINE' => {
                'desc' => 'Medium aquamarine',

                'out' => $csi . '48:2:102:221:170m',
            },
            'B_MEDIUM BLUE' => {
                'desc' => 'Medium blue',

                'out' => $csi . '48:2:0:0:205m',
            },
            'B_MEDIUM CANDY APPLE RED' => {
                'desc' => 'Medium candy apple red',

                'out' => $csi . '48:2:226:6:44m',
            },
            'B_MEDIUM CARMINE' => {
                'desc' => 'Medium carmine',

                'out' => $csi . '48:2:175:64:53m',
            },
            'B_MEDIUM CHAMPAGNE' => {
                'desc' => 'Medium champagne',

                'out' => $csi . '48:2:243:229:171m',
            },
            'B_MEDIUM ELECTRIC BLUE' => {
                'desc' => 'Medium electric blue',

                'out' => $csi . '48:2:3:80:150m',
            },
            'B_MEDIUM JUNGLE GREEN' => {
                'desc' => 'Medium jungle green',

                'out' => $csi . '48:2:28:53:45m',
            },
            'B_MEDIUM LAVENDER MAGENTA' => {
                'desc' => 'Medium lavender magenta',

                'out' => $csi . '48:2:221:160:221m',
            },
            'B_MEDIUM ORCHID' => {
                'desc' => 'Medium orchid',

                'out' => $csi . '48:2:186:85:211m',
            },
            'B_MEDIUM PERSIAN BLUE' => {
                'desc' => 'Medium Persian blue',

                'out' => $csi . '48:2:0:103:165m',
            },
            'B_MEDIUM PURPLE' => {
                'desc' => 'Medium purple',

                'out' => $csi . '48:2:147:112:219m',
            },
            'B_MEDIUM RED VIOLET' => {
                'desc' => 'Medium red violet',

                'out' => $csi . '48:2:187:51:133m',
            },
            'B_MEDIUM SEA GREEN' => {
                'desc' => 'Medium sea green',

                'out' => $csi . '48:2:60:179:113m',
            },
            'B_MEDIUM SLATE BLUE' => {
                'desc' => 'Medium slate blue',

                'out' => $csi . '48:2:123:104:238m',
            },
            'B_MEDIUM SPRING BUD' => {
                'desc' => 'Medium spring bud',

                'out' => $csi . '48:2:201:220:135m',
            },
            'B_MEDIUM SPRING GREEN' => {
                'desc' => 'Medium spring green',

                'out' => $csi . '48:2:0:250:154m',
            },
            'B_MEDIUM TAUPE' => {
                'desc' => 'Medium taupe',

                'out' => $csi . '48:2:103:76:71m',
            },
            'B_MEDIUM TEAL BLUE' => {
                'desc' => 'Medium teal blue',

                'out' => $csi . '48:2:0:84:180m',
            },
            'B_MEDIUM TURQUOISE' => {
                'desc' => 'Medium turquoise',

                'out' => $csi . '48:2:72:209:204m',
            },
            'B_MEDIUM VIOLET RED' => {
                'desc' => 'Medium violet red',

                'out' => $csi . '48:2:199:21:133m',
            },
            'B_MELON' => {
                'desc' => 'Melon',

                'out' => $csi . '48:2:253:188:180m',
            },
            'B_MIDNIGHT BLUE' => {
                'desc' => 'Midnight blue',

                'out' => $csi . '48:2:25:25:112m',
            },
            'B_MIDNIGHT GREEN' => {
                'desc' => 'Midnight green',

                'out' => $csi . '48:2:0:73:83m',
            },
            'B_MIKADO YELLOW' => {
                'desc' => 'Mikado yellow',

                'out' => $csi . '48:2:255:196:12m',
            },
            'B_MINT' => {
                'desc' => 'Mint',

                'out' => $csi . '48:2:62:180:137m',
            },
            'B_MINT CREAM' => {
                'desc' => 'Mint cream',

                'out' => $csi . '48:2:245:255:250m',
            },
            'B_MINT GREEN' => {
                'desc' => 'Mint green',

                'out' => $csi . '48:2:152:255:152m',
            },
            'B_MISTY ROSE' => {
                'desc' => 'Misty rose',

                'out' => $csi . '48:2:255:228:225m',
            },
            'B_MOCCASIN' => {
                'desc' => 'Moccasin',

                'out' => $csi . '48:2:250:235:215m',
            },
            'B_MODE BEIGE' => {
                'desc' => 'Mode beige',

                'out' => $csi . '48:2:150:113:23m',
            },
            'B_MOONSTONE BLUE' => {
                'desc' => 'Moonstone blue',

                'out' => $csi . '48:2:115:169:194m',
            },
            'B_MORDANT RED 19' => {
                'desc' => 'Mordant red 19',

                'out' => $csi . '48:2:174:12:0m',
            },
            'B_MOSS GREEN' => {
                'desc' => 'Moss green',

                'out' => $csi . '48:2:173:223:173m',
            },
            'B_MOUNTAIN MEADOW' => {
                'desc' => 'Mountain Meadow',

                'out' => $csi . '48:2:48:186:143m',
            },
            'B_MOUNTBATTEN PINK' => {
                'desc' => 'Mountbatten pink',

                'out' => $csi . '48:2:153:122:141m',
            },
            'B_MSU GREEN' => {
                'desc' => 'MSU Green',

                'out' => $csi . '48:2:24:69:59m',
            },
            'B_MULBERRY' => {
                'desc' => 'Mulberry',

                'out' => $csi . '48:2:197:75:140m',
            },
            'B_MUNSELL' => {
                'desc' => 'Munsell',

                'out' => $csi . '48:2:242:243:244m',
            },
            'B_MUSTARD' => {
                'desc' => 'Mustard',

                'out' => $csi . '48:2:255:219:88m',
            },
            'B_MYRTLE' => {
                'desc' => 'Myrtle',

                'out' => $csi . '48:2:33:66:30m',
            },
            'B_NADESHIKO PINK' => {
                'desc' => 'Nadeshiko pink',

                'out' => $csi . '48:2:246:173:198m',
            },
            'B_NAPIER GREEN' => {
                'desc' => 'Napier green',

                'out' => $csi . '48:2:42:128:0m',
            },
            'B_NAPLES YELLOW' => {
                'desc' => 'Naples yellow',

                'out' => $csi . '48:2:250:218:94m',
            },
            'B_NAVAJO WHITE' => {
                'desc' => 'Navajo white',

                'out' => $csi . '48:2:255:222:173m',
            },
            'B_NAVY BLUE' => {
                'desc' => 'Navy blue',

                'out' => $csi . '48:2:0:0:128m',
            },
            'B_NEON CARROT' => {
                'desc' => 'Neon Carrot',

                'out' => $csi . '48:2:255:163:67m',
            },
            'B_NEON FUCHSIA' => {
                'desc' => 'Neon fuchsia',

                'out' => $csi . '48:2:254:89:194m',
            },
            'B_NEON GREEN' => {
                'desc' => 'Neon green',

                'out' => $csi . '48:2:57:255:20m',
            },
            'B_NON-PHOTO BLUE' => {
                'desc' => 'Non-photo blue',

                'out' => $csi . '48:2:164:221:237m',
            },
            'B_NORTH TEXAS GREEN' => {
                'desc' => 'North Texas Green',

                'out' => $csi . '48:2:5:144:51m',
            },
            'B_OCEAN BOAT BLUE' => {
                'desc' => 'Ocean Boat Blue',

                'out' => $csi . '48:2:0:119:190m',
            },
            'B_OCHRE' => {
                'desc' => 'Ochre',

                'out' => $csi . '48:2:204:119:34m',
            },
            'B_OFFICE GREEN' => {
                'desc' => 'Office green',

                'out' => $csi . '48:2:0:128:0m',
            },
            'B_OLD GOLD' => {
                'desc' => 'Old gold',

                'out' => $csi . '48:2:207:181:59m',
            },
            'B_OLD LACE' => {
                'desc' => 'Old lace',

                'out' => $csi . '48:2:253:245:230m',
            },
            'B_OLD LAVENDER' => {
                'desc' => 'Old lavender',

                'out' => $csi . '48:2:121:104:120m',
            },
            'B_OLD MAUVE' => {
                'desc' => 'Old mauve',

                'out' => $csi . '48:2:103:49:71m',
            },
            'B_OLD ROSE' => {
                'desc' => 'Old rose',

                'out' => $csi . '48:2:192:128:129m',
            },
            'B_OLIVE' => {
                'desc' => 'Olive',

                'out' => $csi . '48:2:128:128:0m',
            },
            'B_OLIVE DRAB' => {
                'desc' => 'Olive Drab',

                'out' => $csi . '48:2:107:142:35m',
            },
            'B_OLIVE GREEN' => {
                'desc' => 'Olive Green',

                'out' => $csi . '48:2:186:184:108m',
            },
            'B_OLIVINE' => {
                'desc' => 'Olivine',

                'out' => $csi . '48:2:154:185:115m',
            },
            'B_ONYX' => {
                'desc' => 'Onyx',

                'out' => $csi . '48:2:15:15:15m',
            },
            'B_OPERA MAUVE' => {
                'desc' => 'Opera mauve',

                'out' => $csi . '48:2:183:132:167m',
            },
            'B_ORANGE PEEL' => {
                'desc' => 'Orange peel',

                'out' => $csi . '48:2:255:159:0m',
            },
            'B_ORANGE RED' => {
                'desc' => 'Orange red',

                'out' => $csi . '48:2:255:69:0m',
            },
            'B_ORANGE YELLOW' => {
                'desc' => 'Orange Yellow',

                'out' => $csi . '48:2:248:213:104m',
            },
            'B_ORCHID' => {
                'desc' => 'Orchid',

                'out' => $csi . '48:2:218:112:214m',
            },
            'B_OTTER BROWN' => {
                'desc' => 'Otter brown',

                'out' => $csi . '48:2:101:67:33m',
            },
            'B_OUTER SPACE' => {
                'desc' => 'Outer Space',

                'out' => $csi . '48:2:65:74:76m',
            },
            'B_OUTRAGEOUS ORANGE' => {
                'desc' => 'Outrageous Orange',

                'out' => $csi . '48:2:255:110:74m',
            },
            'B_OXFORD BLUE' => {
                'desc' => 'Oxford Blue',

                'out' => $csi . '48:2:0:33:71m',
            },
            'B_PACIFIC BLUE' => {
                'desc' => 'Pacific Blue',

                'out' => $csi . '48:2:28:169:201m',
            },
            'B_PAKISTAN GREEN' => {
                'desc' => 'Pakistan green',

                'out' => $csi . '48:2:0:102:0m',
            },
            'B_PALATINATE BLUE' => {
                'desc' => 'Palatinate blue',

                'out' => $csi . '48:2:39:59:226m',
            },
            'B_PALATINATE PURPLE' => {
                'desc' => 'Palatinate purple',

                'out' => $csi . '48:2:104:40:96m',
            },
            'B_PALE AQUA' => {
                'desc' => 'Pale aqua',

                'out' => $csi . '48:2:188:212:230m',
            },
            'B_PALE BLUE' => {
                'desc' => 'Pale blue',

                'out' => $csi . '48:2:175:238:238m',
            },
            'B_PALE BROWN' => {
                'desc' => 'Pale brown',

                'out' => $csi . '48:2:152:118:84m',
            },
            'B_PALE CARMINE' => {
                'desc' => 'Pale carmine',

                'out' => $csi . '48:2:175:64:53m',
            },
            'B_PALE CERULEAN' => {
                'desc' => 'Pale cerulean',

                'out' => $csi . '48:2:155:196:226m',
            },
            'B_PALE CHESTNUT' => {
                'desc' => 'Pale chestnut',

                'out' => $csi . '48:2:221:173:175m',
            },
            'B_PALE COPPER' => {
                'desc' => 'Pale copper',

                'out' => $csi . '48:2:218:138:103m',
            },
            'B_PALE CORNFLOWER BLUE' => {
                'desc' => 'Pale cornflower blue',

                'out' => $csi . '48:2:171:205:239m',
            },
            'B_PALE GOLD' => {
                'desc' => 'Pale gold',

                'out' => $csi . '48:2:230:190:138m',
            },
            'B_PALE GOLDENROD' => {
                'desc' => 'Pale goldenrod',

                'out' => $csi . '48:2:238:232:170m',
            },
            'B_PALE GREEN' => {
                'desc' => 'Pale green',

                'out' => $csi . '48:2:152:251:152m',
            },
            'B_PALE LAVENDER' => {
                'desc' => 'Pale lavender',

                'out' => $csi . '48:2:220:208:255m',
            },
            'B_PALE MAGENTA' => {
                'desc' => 'Pale magenta',

                'out' => $csi . '48:2:249:132:229m',
            },
            'B_PALE PINK' => {
                'desc' => 'Pale pink',

                'out' => $csi . '48:2:250:218:221m',
            },
            'B_PALE PLUM' => {
                'desc' => 'Pale plum',

                'out' => $csi . '48:2:221:160:221m',
            },
            'B_PALE RED VIOLET' => {
                'desc' => 'Pale red violet',

                'out' => $csi . '48:2:219:112:147m',
            },
            'B_PALE ROBIN EGG BLUE' => {
                'desc' => 'Pale robin egg blue',

                'out' => $csi . '48:2:150:222:209m',
            },
            'B_PALE SILVER' => {
                'desc' => 'Pale silver',

                'out' => $csi . '48:2:201:192:187m',
            },
            'B_PALE SPRING BUD' => {
                'desc' => 'Pale spring bud',

                'out' => $csi . '48:2:236:235:189m',
            },
            'B_PALE TAUPE' => {
                'desc' => 'Pale taupe',

                'out' => $csi . '48:2:188:152:126m',
            },
            'B_PALE VIOLET RED' => {
                'desc' => 'Pale violet red',

                'out' => $csi . '48:2:219:112:147m',
            },
            'B_PANSY PURPLE' => {
                'desc' => 'Pansy purple',

                'out' => $csi . '48:2:120:24:74m',
            },
            'B_PAPAYA WHIP' => {
                'desc' => 'Papaya whip',

                'out' => $csi . '48:2:255:239:213m',
            },
            'B_PARIS GREEN' => {
                'desc' => 'Paris Green',

                'out' => $csi . '48:2:80:200:120m',
            },
            'B_PASTEL BLUE' => {
                'desc' => 'Pastel blue',

                'out' => $csi . '48:2:174:198:207m',
            },
            'B_PASTEL BROWN' => {
                'desc' => 'Pastel brown',

                'out' => $csi . '48:2:131:105:83m',
            },
            'B_PASTEL GRAY' => {
                'desc' => 'Pastel gray',

                'out' => $csi . '48:2:207:207:196m',
            },
            'B_PASTEL GREEN' => {
                'desc' => 'Pastel green',

                'out' => $csi . '48:2:119:221:119m',
            },
            'B_PASTEL MAGENTA' => {
                'desc' => 'Pastel magenta',

                'out' => $csi . '48:2:244:154:194m',
            },
            'B_PASTEL ORANGE' => {
                'desc' => 'Pastel orange',

                'out' => $csi . '48:2:255:179:71m',
            },
            'B_PASTEL PINK' => {
                'desc' => 'Pastel pink',

                'out' => $csi . '48:2:255:209:220m',
            },
            'B_PASTEL PURPLE' => {
                'desc' => 'Pastel purple',

                'out' => $csi . '48:2:179:158:181m',
            },
            'B_PASTEL RED' => {
                'desc' => 'Pastel red',

                'out' => $csi . '48:2:255:105:97m',
            },
            'B_PASTEL VIOLET' => {
                'desc' => 'Pastel violet',

                'out' => $csi . '48:2:203:153:201m',
            },
            'B_PASTEL YELLOW' => {
                'desc' => 'Pastel yellow',

                'out' => $csi . '48:2:253:253:150m',
            },
            'B_PATRIARCH' => {
                'desc' => 'Patriarch',

                'out' => $csi . '48:2:128:0:128m',
            },
            'B_PAYNE GRAY' => {
                'desc' => 'Payne grey',

                'out' => $csi . '48:2:83:104:120m',
            },
            'B_PEACH' => {
                'desc' => 'Peach',

                'out' => $csi . '48:2:255:229:180m',
            },
            'B_PEACH PUFF' => {
                'desc' => 'Peach puff',

                'out' => $csi . '48:2:255:218:185m',
            },
            'B_PEACH YELLOW' => {
                'desc' => 'Peach yellow',

                'out' => $csi . '48:2:250:223:173m',
            },
            'B_PEAR' => {
                'desc' => 'Pear',

                'out' => $csi . '48:2:209:226:49m',
            },
            'B_PEARL' => {
                'desc' => 'Pearl',

                'out' => $csi . '48:2:234:224:200m',
            },
            'B_PEARL AQUA' => {
                'desc' => 'Pearl Aqua',

                'out' => $csi . '48:2:136:216:192m',
            },
            'B_PERIDOT' => {
                'desc' => 'Peridot',

                'out' => $csi . '48:2:230:226:0m',
            },
            'B_PERIWINKLE' => {
                'desc' => 'Periwinkle',

                'out' => $csi . '48:2:204:204:255m',
            },
            'B_PERSIAN BLUE' => {
                'desc' => 'Persian blue',

                'out' => $csi . '48:2:28:57:187m',
            },
            'B_PERSIAN INDIGO' => {
                'desc' => 'Persian indigo',

                'out' => $csi . '48:2:50:18:122m',
            },
            'B_PERSIAN ORANGE' => {
                'desc' => 'Persian orange',

                'out' => $csi . '48:2:217:144:88m',
            },
            'B_PERSIAN PINK' => {
                'desc' => 'Persian pink',

                'out' => $csi . '48:2:247:127:190m',
            },
            'B_PERSIAN PLUM' => {
                'desc' => 'Persian plum',

                'out' => $csi . '48:2:112:28:28m',
            },
            'B_PERSIAN RED' => {
                'desc' => 'Persian red',

                'out' => $csi . '48:2:204:51:51m',
            },
            'B_PERSIAN ROSE' => {
                'desc' => 'Persian rose',

                'out' => $csi . '48:2:254:40:162m',
            },
            'B_PHLOX' => {
                'desc' => 'Phlox',

                'out' => $csi . '48:2:223:0:255m',
            },
            'B_PHTHALO BLUE' => {
                'desc' => 'Phthalo blue',

                'out' => $csi . '48:2:0:15:137m',
            },
            'B_PHTHALO GREEN' => {
                'desc' => 'Phthalo green',

                'out' => $csi . '48:2:18:53:36m',
            },
            'B_PIGGY PINK' => {
                'desc' => 'Piggy pink',

                'out' => $csi . '48:2:253:221:230m',
            },
            'B_PINE GREEN' => {
                'desc' => 'Pine green',

                'out' => $csi . '48:2:1:121:111m',
            },
            'B_PINK FLAMINGO' => {
                'desc' => 'Pink Flamingo',

                'out' => $csi . '48:2:252:116:253m',
            },
            'B_PINK PEARL' => {
                'desc' => 'Pink pearl',

                'out' => $csi . '48:2:231:172:207m',
            },
            'B_PINK SHERBET' => {
                'desc' => 'Pink Sherbet',

                'out' => $csi . '48:2:247:143:167m',
            },
            'B_PISTACHIO' => {
                'desc' => 'Pistachio',

                'out' => $csi . '48:2:147:197:114m',
            },
            'B_PLATINUM' => {
                'desc' => 'Platinum',

                'out' => $csi . '48:2:229:228:226m',
            },
            'B_PLUM' => {
                'desc' => 'Plum',

                'out' => $csi . '48:2:221:160:221m',
            },
            'B_PORTLAND ORANGE' => {
                'desc' => 'Portland Orange',

                'out' => $csi . '48:2:255:90:54m',
            },
            'B_POWDER BLUE' => {
                'desc' => 'Powder blue',

                'out' => $csi . '48:2:176:224:230m',
            },
            'B_PRINCETON ORANGE' => {
                'desc' => 'Princeton orange',

                'out' => $csi . '48:2:255:143:0m',
            },
            'B_PRUSSIAN BLUE' => {
                'desc' => 'Prussian blue',

                'out' => $csi . '48:2:0:49:83m',
            },
            'B_PSYCHEDELIC PURPLE' => {
                'desc' => 'Psychedelic purple',

                'out' => $csi . '48:2:223:0:255m',
            },
            'B_PUCE' => {
                'desc' => 'Puce',

                'out' => $csi . '48:2:204:136:153m',
            },
            'B_PUMPKIN' => {
                'desc' => 'Pumpkin',

                'out' => $csi . '48:2:255:117:24m',
            },
            'B_PURPLE' => {
                'desc' => 'Purple',

                'out' => $csi . '48:2:128:0:128m',
            },
            'B_PURPLE HEART' => {
                'desc' => 'Purple Heart',

                'out' => $csi . '48:2:105:53:156m',
            },
            'B_PURPLE MOUNTAIN MAJESTY' => {
                'desc' => 'Purple mountain majesty',

                'out' => $csi . '48:2:150:120:182m',
            },
            'B_PURPLE MOUNTAINS' => {
                'desc' => 'Purple Mountains',

                'out' => $csi . '48:2:157:129:186m',
            },
            'B_PURPLE PIZZAZZ' => {
                'desc' => 'Purple pizzazz',

                'out' => $csi . '48:2:254:78:218m',
            },
            'B_PURPLE TAUPE' => {
                'desc' => 'Purple taupe',

                'out' => $csi . '48:2:80:64:77m',
            },
            'B_RACKLEY' => {
                'desc' => 'Rackley',

                'out' => $csi . '48:2:93:138:168m',
            },
            'B_RADICAL RED' => {
                'desc' => 'Radical Red',

                'out' => $csi . '48:2:255:53:94m',
            },
            'B_RASPBERRY' => {
                'desc' => 'Raspberry',

                'out' => $csi . '48:2:227:11:93m',
            },
            'B_RASPBERRY GLACE' => {
                'desc' => 'Raspberry glace',

                'out' => $csi . '48:2:145:95:109m',
            },
            'B_RASPBERRY PINK' => {
                'desc' => 'Raspberry pink',

                'out' => $csi . '48:2:226:80:152m',
            },
            'B_RASPBERRY ROSE' => {
                'desc' => 'Raspberry rose',

                'out' => $csi . '48:2:179:68:108m',
            },
            'B_RAW SIENNA' => {
                'desc' => 'Raw Sienna',

                'out' => $csi . '48:2:214:138:89m',
            },
            'B_RAZZLE DAZZLE ROSE' => {
                'desc' => 'Razzle dazzle rose',

                'out' => $csi . '48:2:255:51:204m',
            },
            'B_RAZZMATAZZ' => {
                'desc' => 'Razzmatazz',

                'out' => $csi . '48:2:227:37:107m',
            },
            'B_RED BROWN' => {
                'desc' => 'Red brown',

                'out' => $csi . '48:2:165:42:42m',
            },
            'B_RED ORANGE' => {
                'desc' => 'Red Orange',

                'out' => $csi . '48:2:255:83:73m',
            },
            'B_RED VIOLET' => {
                'desc' => 'Red violet',

                'out' => $csi . '48:2:199:21:133m',
            },
            'B_RICH BLACK' => {
                'desc' => 'Rich black',

                'out' => $csi . '48:2:0:64:64m',
            },
            'B_RICH CARMINE' => {
                'desc' => 'Rich carmine',

                'out' => $csi . '48:2:215:0:64m',
            },
            'B_RICH ELECTRIC BLUE' => {
                'desc' => 'Rich electric blue',

                'out' => $csi . '48:2:8:146:208m',
            },
            'B_RICH LILAC' => {
                'desc' => 'Rich lilac',

                'out' => $csi . '48:2:182:102:210m',
            },
            'B_RICH MAROON' => {
                'desc' => 'Rich maroon',

                'out' => $csi . '48:2:176:48:96m',
            },
            'B_RIFLE GREEN' => {
                'desc' => 'Rifle green',

                'out' => $csi . '48:2:65:72:51m',
            },
            'B_ROBINS EGG BLUE' => {
                'desc' => 'Robins Egg Blue',

                'out' => $csi . '48:2:31:206:203m',
            },
            'B_ROSE' => {
                'desc' => 'Rose',

                'out' => $csi . '48:2:255:0:127m',
            },
            'B_ROSE BONBON' => {
                'desc' => 'Rose bonbon',

                'out' => $csi . '48:2:249:66:158m',
            },
            'B_ROSE EBONY' => {
                'desc' => 'Rose ebony',

                'out' => $csi . '48:2:103:72:70m',
            },
            'B_ROSE GOLD' => {
                'desc' => 'Rose gold',

                'out' => $csi . '48:2:183:110:121m',
            },
            'B_ROSE MADDER' => {
                'desc' => 'Rose madder',

                'out' => $csi . '48:2:227:38:54m',
            },
            'B_ROSE PINK' => {
                'desc' => 'Rose pink',

                'out' => $csi . '48:2:255:102:204m',
            },
            'B_ROSE QUARTZ' => {
                'desc' => 'Rose quartz',

                'out' => $csi . '48:2:170:152:169m',
            },
            'B_ROSE TAUPE' => {
                'desc' => 'Rose taupe',

                'out' => $csi . '48:2:144:93:93m',
            },
            'B_ROSE VALE' => {
                'desc' => 'Rose vale',

                'out' => $csi . '48:2:171:78:82m',
            },
            'B_ROSEWOOD' => {
                'desc' => 'Rosewood',

                'out' => $csi . '48:2:101:0:11m',
            },
            'B_ROSSO CORSA' => {
                'desc' => 'Rosso corsa',

                'out' => $csi . '48:2:212:0:0m',
            },
            'B_ROSY BROWN' => {
                'desc' => 'Rosy brown',

                'out' => $csi . '48:2:188:143:143m',
            },
            'B_ROYAL AZURE' => {
                'desc' => 'Royal azure',

                'out' => $csi . '48:2:0:56:168m',
            },
            'B_ROYAL BLUE' => {
                'desc' => 'Royal blue',

                'out' => $csi . '48:2:65:105:225m',
            },
            'B_ROYAL FUCHSIA' => {
                'desc' => 'Royal fuchsia',

                'out' => $csi . '48:2:202:44:146m',
            },
            'B_ROYAL PURPLE' => {
                'desc' => 'Royal purple',

                'out' => $csi . '48:2:120:81:169m',
            },
            'B_RUBY' => {
                'desc' => 'Ruby',

                'out' => $csi . '48:2:224:17:95m',
            },
            'B_RUDDY' => {
                'desc' => 'Ruddy',

                'out' => $csi . '48:2:255:0:40m',
            },
            'B_RUDDY BROWN' => {
                'desc' => 'Ruddy brown',

                'out' => $csi . '48:2:187:101:40m',
            },
            'B_RUDDY PINK' => {
                'desc' => 'Ruddy pink',

                'out' => $csi . '48:2:225:142:150m',
            },
            'B_RUFOUS' => {
                'desc' => 'Rufous',

                'out' => $csi . '48:2:168:28:7m',
            },
            'B_RUSSET' => {
                'desc' => 'Russet',

                'out' => $csi . '48:2:128:70:27m',
            },
            'B_RUST' => {
                'desc' => 'Rust',

                'out' => $csi . '48:2:183:65:14m',
            },
            'B_SACRAMENTO STATE GREEN' => {
                'desc' => 'Sacramento State green',

                'out' => $csi . '48:2:0:86:63m',
            },
            'B_SADDLE BROWN' => {
                'desc' => 'Saddle brown',

                'out' => $csi . '48:2:139:69:19m',
            },
            'B_SAFETY ORANGE' => {
                'desc' => 'Safety orange',

                'out' => $csi . '48:2:255:103:0m',
            },
            'B_SAFFRON' => {
                'desc' => 'Saffron',

                'out' => $csi . '48:2:244:196:48m',
            },
            'B_SAINT PATRICK BLUE' => {
                'desc' => 'Saint Patrick Blue',

                'out' => $csi . '48:2:35:41:122m',
            },
            'B_SALMON' => {
                'desc' => 'Salmon',

                'out' => $csi . '48:2:255:140:105m',
            },
            'B_SALMON PINK' => {
                'desc' => 'Salmon pink',

                'out' => $csi . '48:2:255:145:164m',
            },
            'B_SAND' => {
                'desc' => 'Sand',

                'out' => $csi . '48:2:194:178:128m',
            },
            'B_SAND DUNE' => {
                'desc' => 'Sand dune',

                'out' => $csi . '48:2:150:113:23m',
            },
            'B_SANDSTORM' => {
                'desc' => 'Sandstorm',

                'out' => $csi . '48:2:236:213:64m',
            },
            'B_SANDY BROWN' => {
                'desc' => 'Sandy brown',

                'out' => $csi . '48:2:244:164:96m',
            },
            'B_SANDY TAUPE' => {
                'desc' => 'Sandy taupe',

                'out' => $csi . '48:2:150:113:23m',
            },
            'B_SAP GREEN' => {
                'desc' => 'Sap green',

                'out' => $csi . '48:2:80:125:42m',
            },
            'B_SAPPHIRE' => {
                'desc' => 'Sapphire',

                'out' => $csi . '48:2:15:82:186m',
            },
            'B_SATIN SHEEN GOLD' => {
                'desc' => 'Satin sheen gold',

                'out' => $csi . '48:2:203:161:53m',
            },
            'B_SCARLET' => {
                'desc' => 'Scarlet',

                'out' => $csi . '48:2:255:36:0m',
            },
            'B_SCHOOL BUS YELLOW' => {
                'desc' => 'School bus yellow',

                'out' => $csi . '48:2:255:216:0m',
            },
            'B_SCREAMIN GREEN' => {
                'desc' => 'Screamin Green',

                'out' => $csi . '48:2:118:255:122m',
            },
            'B_SEA BLUE' => {
                'desc' => 'Sea blue',

                'out' => $csi . '48:2:0:105:148m',
            },
            'B_SEA GREEN' => {
                'desc' => 'Sea green',

                'out' => $csi . '48:2:46:139:87m',
            },
            'B_SEAL BROWN' => {
                'desc' => 'Seal brown',

                'out' => $csi . '48:2:50:20:20m',
            },
            'B_SEASHELL' => {
                'desc' => 'Seashell',

                'out' => $csi . '48:2:255:245:238m',
            },
            'B_SELECTIVE YELLOW' => {
                'desc' => 'Selective yellow',

                'out' => $csi . '48:2:255:186:0m',
            },
            'B_SEPIA' => {
                'desc' => 'Sepia',

                'out' => $csi . '48:2:112:66:20m',
            },
            'B_SHADOW' => {
                'desc' => 'Shadow',

                'out' => $csi . '48:2:138:121:93m',
            },
            'B_SHAMROCK' => {
                'desc' => 'Shamrock',

                'out' => $csi . '48:2:69:206:162m',
            },
            'B_SHAMROCK GREEN' => {
                'desc' => 'Shamrock green',

                'out' => $csi . '48:2:0:158:96m',
            },
            'B_SHOCKING PINK' => {
                'desc' => 'Shocking pink',

                'out' => $csi . '48:2:252:15:192m',
            },
            'B_SIENNA' => {
                'desc' => 'Sienna',

                'out' => $csi . '48:2:136:45:23m',
            },
            'B_SILVER' => {
                'desc' => 'Silver',

                'out' => $csi . '48:2:192:192:192m',
            },
            'B_SINOPIA' => {
                'desc' => 'Sinopia',

                'out' => $csi . '48:2:203:65:11m',
            },
            'B_SKOBELOFF' => {
                'desc' => 'Skobeloff',

                'out' => $csi . '48:2:0:116:116m',
            },
            'B_SKY BLUE' => {
                'desc' => 'Sky blue',

                'out' => $csi . '48:2:135:206:235m',
            },
            'B_SKY MAGENTA' => {
                'desc' => 'Sky magenta',

                'out' => $csi . '48:2:207:113:175m',
            },
            'B_SLATE BLUE' => {
                'desc' => 'Slate blue',

                'out' => $csi . '48:2:106:90:205m',
            },
            'B_SLATE GRAY' => {
                'desc' => 'Slate gray',

                'out' => $csi . '48:2:112:128:144m',
            },
            'B_SMALT' => {
                'desc' => 'Smalt',

                'out' => $csi . '48:2:0:51:153m',
            },
            'B_SMOKEY TOPAZ' => {
                'desc' => 'Smokey topaz',

                'out' => $csi . '48:2:147:61:65m',
            },
            'B_SMOKY BLACK' => {
                'desc' => 'Smoky black',

                'out' => $csi . '48:2:16:12:8m',
            },
            'B_SNOW' => {
                'desc' => 'Snow',

                'out' => $csi . '48:2:255:250:250m',
            },
            'B_SPIRO DISCO BALL' => {
                'desc' => 'Spiro Disco Ball',

                'out' => $csi . '48:2:15:192:252m',
            },
            'B_SPRING BUD' => {
                'desc' => 'Spring bud',

                'out' => $csi . '48:2:167:252:0m',
            },
            'B_SPRING GREEN' => {
                'desc' => 'Spring green',

                'out' => $csi . '48:2:0:255:127m',
            },
            'B_STEEL BLUE' => {
                'desc' => 'Steel blue',

                'out' => $csi . '48:2:70:130:180m',
            },
            'B_STIL DE GRAIN YELLOW' => {
                'desc' => 'Stil de grain yellow',

                'out' => $csi . '48:2:250:218:94m',
            },
            'B_STIZZA' => {
                'desc' => 'Stizza',

                'out' => $csi . '48:2:153:0:0m',
            },
            'B_STORMCLOUD' => {
                'desc' => 'Stormcloud',

                'out' => $csi . '48:2:0:128:128m',
            },
            'B_STRAW' => {
                'desc' => 'Straw',

                'out' => $csi . '48:2:228:217:111m',
            },
            'B_SUNGLOW' => {
                'desc' => 'Sunglow',

                'out' => $csi . '48:2:255:204:51m',
            },
            'B_SUNSET' => {
                'desc' => 'Sunset',

                'out' => $csi . '48:2:250:214:165m',
            },
            'B_SUNSET ORANGE' => {
                'desc' => 'Sunset Orange',

                'out' => $csi . '48:2:253:94:83m',
            },
            'B_TAN' => {
                'desc' => 'Tan',

                'out' => $csi . '48:2:210:180:140m',
            },
            'B_TANGELO' => {
                'desc' => 'Tangelo',

                'out' => $csi . '48:2:249:77:0m',
            },
            'B_TANGERINE' => {
                'desc' => 'Tangerine',

                'out' => $csi . '48:2:242:133:0m',
            },
            'B_TANGERINE YELLOW' => {
                'desc' => 'Tangerine yellow',

                'out' => $csi . '48:2:255:204:0m',
            },
            'B_TAUPE' => {
                'desc' => 'Taupe',

                'out' => $csi . '48:2:72:60:50m',
            },
            'B_TAUPE GRAY' => {
                'desc' => 'Taupe gray',

                'out' => $csi . '48:2:139:133:137m',
            },
            'B_TAWNY' => {
                'desc' => 'Tawny',

                'out' => $csi . '48:2:205:87:0m',
            },
            'B_TEA GREEN' => {
                'desc' => 'Tea green',

                'out' => $csi . '48:2:208:240:192m',
            },
            'B_TEA ROSE' => {
                'desc' => 'Tea rose',

                'out' => $csi . '48:2:244:194:194m',
            },
            'B_TEAL' => {
                'desc' => 'Teal',

                'out' => $csi . '48:2:0:128:128m',
            },
            'B_TEAL BLUE' => {
                'desc' => 'Teal blue',

                'out' => $csi . '48:2:54:117:136m',
            },
            'B_TEAL GREEN' => {
                'desc' => 'Teal green',

                'out' => $csi . '48:2:0:109:91m',
            },
            'B_TERRA COTTA' => {
                'desc' => 'Terra cotta',

                'out' => $csi . '48:2:226:114:91m',
            },
            'B_THISTLE' => {
                'desc' => 'Thistle',

                'out' => $csi . '48:2:216:191:216m',
            },
            'B_THULIAN PINK' => {
                'desc' => 'Thulian pink',

                'out' => $csi . '48:2:222:111:161m',
            },
            'B_TICKLE ME PINK' => {
                'desc' => 'Tickle Me Pink',

                'out' => $csi . '48:2:252:137:172m',
            },
            'B_TIFFANY BLUE' => {
                'desc' => 'Tiffany Blue',

                'out' => $csi . '48:2:10:186:181m',
            },
            'B_TIGER EYE' => {
                'desc' => 'Tiger eye',

                'out' => $csi . '48:2:224:141:60m',
            },
            'B_TIMBERWOLF' => {
                'desc' => 'Timberwolf',

                'out' => $csi . '48:2:219:215:210m',
            },
            'B_TITANIUM YELLOW' => {
                'desc' => 'Titanium yellow',

                'out' => $csi . '48:2:238:230:0m',
            },
            'B_TOMATO' => {
                'desc' => 'Tomato',

                'out' => $csi . '48:2:255:99:71m',
            },
            'B_TOOLBOX' => {
                'desc' => 'Toolbox',

                'out' => $csi . '48:2:116:108:192m',
            },
            'B_TOPAZ' => {
                'desc' => 'Topaz',

                'out' => $csi . '48:2:255:200:124m',
            },
            'B_TRACTOR RED' => {
                'desc' => 'Tractor red',

                'out' => $csi . '48:2:253:14:53m',
            },
            'B_TROLLEY GRAY' => {
                'desc' => 'Trolley Grey',

                'out' => $csi . '48:2:128:128:128m',
            },
            'B_TROPICAL RAIN FOREST' => {
                'desc' => 'Tropical rain forest',

                'out' => $csi . '48:2:0:117:94m',
            },
            'B_TRUE BLUE' => {
                'desc' => 'True Blue',

                'out' => $csi . '48:2:0:115:207m',
            },
            'B_TUFTS BLUE' => {
                'desc' => 'Tufts Blue',

                'out' => $csi . '48:2:65:125:193m',
            },
            'B_TUMBLEWEED' => {
                'desc' => 'Tumbleweed',

                'out' => $csi . '48:2:222:170:136m',
            },
            'B_TURKISH ROSE' => {
                'desc' => 'Turkish rose',

                'out' => $csi . '48:2:181:114:129m',
            },
            'B_TURQUOISE' => {
                'desc' => 'Turquoise',

                'out' => $csi . '48:2:48:213:200m',
            },
            'B_TURQUOISE BLUE' => {
                'desc' => 'Turquoise blue',

                'out' => $csi . '48:2:0:255:239m',
            },
            'B_TURQUOISE GREEN' => {
                'desc' => 'Turquoise green',

                'out' => $csi . '48:2:160:214:180m',
            },
            'B_TUSCAN RED' => {
                'desc' => 'Tuscan red',

                'out' => $csi . '48:2:102:66:77m',
            },
            'B_TWILIGHT LAVENDER' => {
                'desc' => 'Twilight lavender',

                'out' => $csi . '48:2:138:73:107m',
            },
            'B_TYRIAN PURPLE' => {
                'desc' => 'Tyrian purple',

                'out' => $csi . '48:2:102:2:60m',
            },
            'B_UA BLUE' => {
                'desc' => 'UA blue',

                'out' => $csi . '48:2:0:51:170m',
            },
            'B_UA RED' => {
                'desc' => 'UA red',

                'out' => $csi . '48:2:217:0:76m',
            },
            'B_UBE' => {
                'desc' => 'Ube',

                'out' => $csi . '48:2:136:120:195m',
            },
            'B_UCLA BLUE' => {
                'desc' => 'UCLA Blue',

                'out' => $csi . '48:2:83:104:149m',
            },
            'B_UCLA GOLD' => {
                'desc' => 'UCLA Gold',

                'out' => $csi . '48:2:255:179:0m',
            },
            'B_UFO GREEN' => {
                'desc' => 'UFO Green',

                'out' => $csi . '48:2:60:208:112m',
            },
            'B_ULTRA PINK' => {
                'desc' => 'Ultra pink',

                'out' => $csi . '48:2:255:111:255m',
            },
            'B_ULTRAMARINE' => {
                'desc' => 'Ultramarine',

                'out' => $csi . '48:2:18:10:143m',
            },
            'B_ULTRAMARINE BLUE' => {
                'desc' => 'Ultramarine blue',

                'out' => $csi . '48:2:65:102:245m',
            },
            'B_UMBER' => {
                'desc' => 'Umber',

                'out' => $csi . '48:2:99:81:71m',
            },
            'B_UNITED NATIONS BLUE' => {
                'desc' => 'United Nations blue',

                'out' => $csi . '48:2:91:146:229m',
            },
            'B_UNIVERSITY OF' => {
                'desc' => 'University of',

                'out' => $csi . '48:2:183:135:39m',
            },
            'B_UNMELLOW YELLOW' => {
                'desc' => 'Unmellow Yellow',

                'out' => $csi . '48:2:255:255:102m',
            },
            'B_UP FOREST GREEN' => {
                'desc' => 'UP Forest green',

                'out' => $csi . '48:2:1:68:33m',
            },
            'B_UP MAROON' => {
                'desc' => 'UP Maroon',

                'out' => $csi . '48:2:123:17:19m',
            },
            'B_UPSDELL RED' => {
                'desc' => 'Upsdell red',

                'out' => $csi . '48:2:174:32:41m',
            },
            'B_UROBILIN' => {
                'desc' => 'Urobilin',

                'out' => $csi . '48:2:225:173:33m',
            },
            'B_USC CARDINAL' => {
                'desc' => 'USC Cardinal',

                'out' => $csi . '48:2:153:0:0m',
            },
            'B_USC GOLD' => {
                'desc' => 'USC Gold',

                'out' => $csi . '48:2:255:204:0m',
            },
            'B_UTAH CRIMSON' => {
                'desc' => 'Utah Crimson',

                'out' => $csi . '48:2:211:0:63m',
            },
            'B_VANILLA' => {
                'desc' => 'Vanilla',

                'out' => $csi . '48:2:243:229:171m',
            },
            'B_VEGAS GOLD' => {
                'desc' => 'Vegas gold',

                'out' => $csi . '48:2:197:179:88m',
            },
            'B_VENETIAN RED' => {
                'desc' => 'Venetian red',

                'out' => $csi . '48:2:200:8:21m',
            },
            'B_VERDIGRIS' => {
                'desc' => 'Verdigris',

                'out' => $csi . '48:2:67:179:174m',
            },
            'B_VERMILION' => {
                'desc' => 'Vermilion',

                'out' => $csi . '48:2:227:66:52m',
            },
            'B_VERONICA' => {
                'desc' => 'Veronica',

                'out' => $csi . '48:2:160:32:240m',
            },
            'B_VIOLET' => {
                'desc' => 'Violet',

                'out' => $csi . '48:2:238:130:238m',
            },
            'B_VIOLET BLUE' => {
                'desc' => 'Violet Blue',

                'out' => $csi . '48:2:50:74:178m',
            },
            'B_VIOLET RED' => {
                'desc' => 'Violet Red',

                'out' => $csi . '48:2:247:83:148m',
            },
            'B_VIRIDIAN' => {
                'desc' => 'Viridian',

                'out' => $csi . '48:2:64:130:109m',
            },
            'B_VIVID AUBURN' => {
                'desc' => 'Vivid auburn',

                'out' => $csi . '48:2:146:39:36m',
            },
            'B_VIVID BURGUNDY' => {
                'desc' => 'Vivid burgundy',

                'out' => $csi . '48:2:159:29:53m',
            },
            'B_VIVID CERISE' => {
                'desc' => 'Vivid cerise',

                'out' => $csi . '48:2:218:29:129m',
            },
            'B_VIVID TANGERINE' => {
                'desc' => 'Vivid tangerine',

                'out' => $csi . '48:2:255:160:137m',
            },
            'B_VIVID VIOLET' => {
                'desc' => 'Vivid violet',

                'out' => $csi . '48:2:159:0:255m',
            },
            'B_WARM BLACK' => {
                'desc' => 'Warm black',

                'out' => $csi . '48:2:0:66:66m',
            },
            'B_WATERSPOUT' => {
                'desc' => 'Waterspout',

                'out' => $csi . '48:2:0:255:255m',
            },
            'B_WENGE' => {
                'desc' => 'Wenge',

                'out' => $csi . '48:2:100:84:82m',
            },
            'B_WHEAT' => {
                'desc' => 'Wheat',

                'out' => $csi . '48:2:245:222:179m',
            },
            'B_WHITE SMOKE' => {
                'desc' => 'White smoke',

                'out' => $csi . '48:2:245:245:245m',
            },
            'B_WILD BLUE YONDER' => {
                'desc' => 'Wild blue yonder',

                'out' => $csi . '48:2:162:173:208m',
            },
            'B_WILD STRAWBERRY' => {
                'desc' => 'Wild Strawberry',

                'out' => $csi . '48:2:255:67:164m',
            },
            'B_WILD WATERMELON' => {
                'desc' => 'Wild Watermelon',

                'out' => $csi . '48:2:252:108:133m',
            },
            'B_WINE' => {
                'desc' => 'Wine',

                'out' => $csi . '48:2:114:47:55m',
            },
            'B_WISTERIA' => {
                'desc' => 'Wisteria',

                'out' => $csi . '48:2:201:160:220m',
            },
            'B_XANADU' => {
                'desc' => 'Xanadu',

                'out' => $csi . '48:2:115:134:120m',
            },
            'B_YALE BLUE' => {
                'desc' => 'Yale Blue',
                'out'  => $csi . '48:2:15:77:146m',
            },
            'B_YELLOW GREEN' => {
                'desc' => 'Yellow green',
                'out'  => $csi . '48:2:154:205:50m',
            },
            'B_YELLOW ORANGE' => {
                'desc' => 'Yellow Orange',
                'out'  => $csi . '48:2:255:174:66m',
            },
            'B_ZAFFRE' => {
                'desc' => 'Zaffre',
                'out'  => $csi . '48:2:0:20:168m',
            },
            'B_ZINNWALDITE BROWN' => {
                'desc' => 'Zinnwaldite brown',
                'out'  => $csi . '48:2:44:22:8m',
            },
        },
    };

    $self->{'debug'}->DEBUG(['  Add fonts']);
    foreach my $count (1 .. 9) {
        $self->{'ansi_meta'}->{'special'}->{ 'FONT ' . $count } = {
            'desc' => "ANSI Font $count",
            'out'  => $csi . ($count + 10) . 'm',
        };
    } ## end foreach my $count (1 .. 9)

    $self->{'debug'}->DEBUG(['  Add ANSI256 Colors']);
    foreach my $count (16 .. 231) {
        $self->{'ansi_meta'}->{'foreground'}->{ 'COLOR ' . $count } = {
            'desc' => "ANSI256 Color $count",
            'out'  => $csi . "38;5;$count" . 'm',
        };
        $self->{'ansi_meta'}->{'background'}->{ 'B_COLOR ' . $count } = {
            'desc' => "ANSI256 Color $count",
            'out'  => $csi . "48;5;$count" . 'm',
        };
    } ## end foreach my $count (16 .. 231)

    $self->{'debug'}->DEBUG(['  Add ANSI256 Grays']);
    foreach my $count (232 .. 255) {
        $self->{'ansi_meta'}->{'foreground'}->{ 'GRAY ' . ($count - 232) } = {
            'desc' => "ANSI256 grey level " . ($count - 232),
            'out'  => $csi . "38;5;$count" . 'm',
        };
        $self->{'ansi_meta'}->{'background'}->{ 'B_GRAY ' . ($count - 232) } = {
            'desc' => "ANSI256 grey level " . ($count - 232),
            'out'  => $csi . "48;5;$count" . 'm',
        };
    } ## end foreach my $count (232 .. 255)

    $self->{'debug'}->DEBUG(['  Populate ansi_sequences']);
    foreach my $code (qw(special clear cursor attributes foreground background)) {
        foreach my $name (keys %{ $self->{'ansi_meta'}->{$code} }) {
            $self->{'ansi_sequences'}->{$name} = $self->{'ansi_meta'}->{$code}->{$name}->{'out'};
        }
    }
    $self->{'debug'}->DEBUG(['End ANSI Initialize']);
    return ($self);
} ## end sub ansi_initialize

 

# package BBS::Universal::ASCII;

sub ascii_initialize {
    my $self = shift;

	$self->{'debug'}->DEBUG(['Start ASCII Initialize']);
	$self->{'ascii_meta'} = {
        'RETURN'    => {
			'out' => chr(13),
			'unicode' => ' ',
			'desc' => 'Carriage Return',
		},
        'LINEFEED'  => {
			'out' => chr(10),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},
        'NEWLINE'   => {
			'out'=> chr(13) . chr(10),
			'unicode' => ' ',
			'desc' => 'Newline',
		},
        'BACKSPACE' => {
			'out' => chr(8),
			'unicode' => ' ',
			'desc' => 'Backspace',
		},
		'TAB'       => {
			'out' => chr(9),
			'unicode' => ' ',
			'desc' => 'Tab',
		},
        'DELETE'    => {
			'out' => chr(127),
			'unicode' => ' ',
			'desc' => 'Delete',
		},
        'CLS'       => {
			'out' => chr(12), # Formfeed
			'unicode' => ' ',
			'desc' => 'Clear Screen (Formfeed)',
		},
        'CLEAR'     => {
			'out' => chr(12),
			'unicode' => ' ',
			'desc' => 'Clear Screen (Formfeed)',
		},
        'RING BELL' => {
			'out' => chr(7),
			'unicode' => ' ',
			'desc' => 'Console Bell',
		},
    };
	foreach my $name (keys %{ $self->{'ascii_meta'} }) {
		$self->{'ascii_sequences'}->{$name} = $self->{'ascii_meta'}->{$name}->{'out'};
	}
	$self->{'debug'}->DEBUG(['End ACSII Initialize']);
    return ($self);
}

sub ascii_output {
    my $self   = shift;
    my $text   = shift;

	$self->{'debug'}->DEBUG(['Start ASCII Output']);
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
		while($text =~ /\[\%\s+HORIZONTAL RULE\s+\%\]/) {
			my $rule = '=' x $self->{'USER'}->{'max_columns'};
			$text =~ s/\[\%\s+HORIZONTAL RULE\s+\%\]/$rule/gs;
		}
    }
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
		}
		$self->send_char($char);
	}
	$self->{'debug'}->DEBUG(['End ASCII Output']);
    return (TRUE);
}

 

# package BBS::Universal::ATASCII;

sub atascii_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start ATASCII Initialize']);
	$self->{'atascii_meta'} = {
        'HEART'                        => {
			'out' => chr(0),   # ♥
			'unicode' => '♥',
			'desc' => 'Heart',
		},
        'VERTICAL BAR MIDDLE LEFT'     => {
			'out' => chr(1),   # ├
			'unicode' => '├',
			'desc' => 'Vertical Bar Middle Left',
		},
        'RIGHT VERTICAL BAR'           => {
			'out' => chr(2),   #
			'unicode' => ' ',
			'desc' => 'Right Vertical Bar',
		},
        'BOTTOM RIGHT CORNER'          => {
			'out' => chr(3),   # ┘
			'unicode' => '┘',
			'desc' => 'Bottom Right Corner',
		},
        'VERTICAL BAR MIDDLE RIGHT'    => {
			'out' => chr(4),   # ┤
			'unicode' => '┤',
			'desc' => 'Vertical Bar Middle Right',
		},
        'TOP RIGHT CORNER'             => {
			'out' => chr(5),   # ┐
			'unicode' => '┐',
			'desc' => 'Top Right Corner',
		},
        'LARGE FORWARD SLASH'          => {
			'out' => chr(6),   # ╱
			'unicode' => '╱',
			'desc' => 'Large Forward Slash',
		},
        'RING BELL'                    => {
			'out' => chr(253),
			'unicode' => ' ',
			'desc' => 'Console Bell',
		},
        'LARGE BACKSLASH'             => {
			'out' => chr(7),   # ╲
			'unicode' => '╲',
			'desc' => 'Large Backslash',
		},
        'TOP LEFT WEDGE'               => {
			'out' => chr(8),   # ◢
			'unicode' => '◢',
			'desc' => 'Top Left Wedge',
		},
        'BOTTOM RIGHT BOX'             => {
			'out' => chr(9),   # ▗
			'unicode' => '▗',
			'desc' => 'Bottom Right Box',
		},
        'TOP RIGHT WEDGE'              => {
			'out' => chr(10),  # ◣
			'unicode' => '◣',
			'desc' => 'Top Right Wedge',
		},
        'LINEFEED'                     => {
			'out' => chr(10),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},
        'TOP RIGHT BOX'                => {
			'out' => chr(11),  # ▝
			'unicode' => '▝',
			'desc' => 'Top Right Box',
		},
        'TOP LEFT BOX'                 => {
			'out' => chr(12),  # ▘
			'unicode' => '▘',
			'desc' => 'Top Left Box',
		},
        'RETURN'                       => {
			'out' => chr(155),
			'unicode' => ' ',
			'desc' => 'Carriage Return',
		},
        'NEWLINE'                      => {
			'out' => chr(155),
			'unicode' => ' ',
			'desc' => 'Newline',
		},
        'TOP HORIZONTAL BAR'           => {
			'out' => chr(13),
			'unicode' => ' ',
			'desc' => 'Top Horizontal Bar',
		},
        'BOTTOM HORIZONTAL BAR'        => {
			'out' => chr(14),  # ▂
			'unicode' => '▂',
			'desc' => 'Bottom Horizontal Bar',
		},
        'BOTTOM LEFT BOX'              => {
			'out' => chr(15),  # ▖
			'unicode' => '▖',
			'desc' => 'Bottom Left Box',
		},
        'CLUB'                         => {
			'out' => chr(16),  # ♣
			'unicode' => '♣',
			'desc' => 'Club',
		},
        'TOP LEFT CORNER'              => {
			'out' => chr(17),  # ┌
			'unicode' => '┌',
			'desc' => 'Top Left Corner',
		},
        'HORIZONTAL BAR'               => {
			'out' => chr(18),  # ─
			'unicode' => '─',
			'desc' => 'Horizontal Bar',
		},
        'CROSS BAR'                    => {
			'out' => chr(19),  # ┼
			'unicode' => '┼',
			'desc' => 'Cross Bar',
		},
        'CENTER DOT'                   => {
			'out' => chr(20),  # •
			'unicode' => '•',
			'desc' => 'Center Dot',
		},
        'BOTTOM BOX'                   => {
			'out' => chr(21),  # ▄
			'unicode' => '▄',
			'desc' => 'Bottom Box',
		},
        'LEFT VERTICAL BAR'            => {
			'out' => chr(22),  # ▎
			'unicode' => '▎',
			'desc' => 'Left Vertical Bar',
		},
        'HORIZONTAL BAR MIDDLE TOP'    => {
			'out' => chr(23),  # ┬
			'unicode' => '┬',
			'desc' => 'Horizontal Bar Middle Top',
		},
        'HORIZONTAL BAR MIDDLE BOTTOM' => {
			'out' => chr(24),  # ┴
			'unicode' => '┴',
			'desc' => 'Horizontal Bar Middle Bottom',
		},
        'LEFT VERTICAL BAR'            => {
			'out' => chr(25),  # ▌
			'unicode' => '▌',
			'desc' => 'Left Vertical Bar',
		},
        'BOTTOM LEFT CORNER'           => {
			'out' => chr(26),  # └
			'unicode' => '└',
			'desc' => 'Botom Left Corner',
		},
        'ESC'                          => {
			'out' => chr(27),  # ␛
			'unicode' => '␛',
			'desc' => 'Escape',
		},
        'UP'                           => {
			'out' => chr(28),
			'unicode' => ' ',
			'desc' => 'Move Cursor Up',
		},
        'UP ARROW'                     => {
			'out' => chr(28),  # ↑
			'unicode' => '↑',
			'desc' => 'Up Arrow',
		},
        'DOWN'                         => {
			'out' => chr(29),
			'unicode' => ' ',
			'desc' => 'Move Cursor Down',
		},
        'DOWN ARROW'                   => {
			'out' => chr(29),  # ↓
			'unicode' => '↓',
			'desc' => 'Down Arrow',
		},
        'LEFT'                         => {
			'out' => chr(30),
			'unicode' => ' ',
			'desc' => 'Move Cursor Left',
		},
        'LEFT ARROW'                   => {
			'out' => chr(30),  # ←
			'unicode' => '←',
			'desc' => 'Left Arrow',
		},
        'RIGHT'                        => {
			'out' => chr(31),
			'unicode' => ' ',
			'desc' => 'Move Cursor Right',
		},
        'RIGHT ARROW'                  => {
			'out' => chr(31),  # →
			'unicode' => '→',
			'desc' => 'Right Arrow',
		},
        'DIAMOND'                      => {
			'out' => chr(96),  # ♦
			'unicode' => '♦',
			'desc' => 'Diamond',
		},
        'SPADE'                        => {
			'out' => chr(123), # ♠
			'unicode' => '♠',
			'desc' => 'Spade',
		},
        'MIDDLE VERTICAL BAR'          => {
			'out' => chr(124), # |
			'unicode' => '|',
			'desc' => 'Middle Vertical Bar',
		},
        'CLEAR'                        => {
			'out' => chr(125),
			'unicode' => ' ',
			'desc' => 'Clear Screen',
		},
        'BACK ARROW'                   => {
			'out' => chr(125), # 🢰
			'unicode' => '🢰',
			'desc' => 'Back Arrow',
		},
        'BACKSPACE'                    => {
			'out' => chr(126),
			'unicode' => ' ',
			'desc' => 'Backspace',
		},
        'LEFT TRIANGLE'                => {
			'out' => chr(126), # ◀
			'unicode' => '◀',
			'desc' => 'Left Triangle',
		},
        'TAB'                          => {
			'out' => chr(127),
			'unicode' => ' ',
			'desc' => 'Tab',
		},
        'RIGHT TRIANGLE'               => {
			'out' => chr(127), # ▶
			'unicode' => '▶',
			'desc' => 'Right Triangle',
		},
        'BOTTOM RIGHT WEDGE'           => {
			'out' => chr(136), # ◤
			'unicode' => '◤',
			'desc' => 'Bottom Right Wedge',
		},
        'TOP LEFT CORNER BOX'          => {
			'out' => chr(137), # ▛
			'unicode' => '▛',
			'desc' => 'Top Left Corner Box',
		},
        'BOTTOM LEFT WEDGE'            => {
			'out' => chr(138), # ◥
			'unicode' => '◥',
			'desc' => 'Bottom Left Wedge',
		},
        'BOTTOM LEFT CORNER BOX'       => {
			'out' => chr(139), # ▙
			'unicode' => '▙',
			'desc' => 'Bottom Left Corner Box',
		},
        'BOTTOM RIGHT CORNER BOX'      => {
			'out' => chr(140), # ▟
			'unicode' => '▟',
			'desc' => 'Bottom Right Corner Box',
		},
        'BOTTOM BOX'                   => {
			'out' => chr(141), # ▆
			'unicode' => '▆',
			'desc' => 'Bottom Box',
		},
        'TOP RIGHT CORNER BOX'         => {
			'out' => chr(143), # ▜
			'unicode' => '▜',
			'desc' => 'Top Right Corner Box',
		},
        'SOLID BLOCK'                  => {
			'out' => chr(160), # █
			'unicode' => '█',
			'desc' => 'Solid Block',
		},
        'DELETE LINE'                  => {
			'out' => chr(156),
			'unicode' => ' ',
			'desc' => 'Delete Line',
		},
        'INSERT LINE'                  => {
			'out' => chr(157),
			'unicode' => ' ',
			'desc' => 'Insert Line',
		},
        'CLEAR TAB STOP'               => {
			'out' => chr(158),
			'unicode' => ' ',
			'desc' => 'Clear Tab Stop',
		},
        'SET TAB STOP'                 => {
			'out' => chr(159),
			'unicode' => ' ',
			'desc' => 'Set Tab Stop',
		},
        # Top bit inverts
        'DELETE LINE'                  => {
			'out' => chr(156),
			'unicode' => ' ',
			'desc' => 'Delete Line',
		},
        'INSERT LINE'                  => {
			'out' => chr(157),
			'unicode' => ' ',
			'desc' => 'Insert Line',
		},
        'DELETE'                       => {
			'out' => chr(254),
			'unicode' => ' ',
			'desc' => 'Delete',
		},
        'INSERT'                       => {
			'out' => chr(255),
			'unicode' => ' ',
			'desc' => 'Insert',
		},
	};
	foreach my $name (keys %{ $self->{'atascii_meta'} }) {
		$self->{'atascii_sequences'}->{$name} = $self->{'atascii_meta'}->{$name}->{'out'};
	}
    $self->{'debug'}->DEBUG(['End ATASCII Initialize']);
    return ($self);
}

sub atascii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start ATASCII Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        while($text =~ /\[\%\s+HORIZONTAL RULE\s+\%\]/) {
            my $rule = '[% TOP HORIZONTAL BAR %]' x $self->{'USER'}->{'max_columns'};
            $text =~ s/\[\%\s+HORIZONTAL RULE\s+\%\]/$rule/gs;
        }
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
    $self->{'debug'}->DEBUG(['End ATASCII Output']);
    return (TRUE);
}

 

# package BBS::Universal::BBS_List;

sub bbs_list_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start BBS List Initialize']);
    $self->{'debug'}->DEBUG(['End BBS List Initialize']);
    return ($self);
}

sub bbs_list_add {
    my $self  = shift;

    $self->{'debug'}->DEBUG(['Start BBS List Add']);

    my $index = 0;
    my $response = TRUE;
    $self->prompt('What is the BBS Name');
    my $bbs_name = $self->get_line(ECHO, 50);
    $self->{'debug'}->DEBUG(["  BBS NAme:  $bbs_name"]);
    $self->output("\n");
    if ($bbs_name ne '' && length($bbs_name) > 3) {
        $self->prompt('What is the URL or Hostname');
        my $bbs_hostname = $self->get_line(ECHO, 50);
        $self->{'debug'}->DEBUG(["  BBS Hostname:  $bbs_hostname"]);
        $self->output("\n");
        if ($bbs_hostname ne '' && length($bbs_hostname) > 5) {
            $self->prompt('What is the Port number');
            my $bbs_port = $self->get_line(ECHO, 5);
            $self->{'debug'}->DEBUG(["  BBS Port:  $bbs_port"]);
            $self->output("\n");
            if ($bbs_port ne '' && $bbs_port =~ /^\d+$/) {
                $self->{'debug'}->DEBUG(["  Adding BBS Entry"]);
                $self->output('Adding BBS Entry...');
                my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
                $sth->execute($bbs_name, $bbs_hostname, $bbs_port);
                $sth->finish();
            } else {
                $response = FALSE;
            }
        } else {
            $response = FALSE;
        }
    } else {
        $response = FALSE;
    }
    $self->{'debug'}->DEBUG(['End BBS List Add']);
    return ($response);
}

sub bbs_list {
    my $self   = shift;
    my $search = shift;

    $self->{'debug'}->DEBUG(['Start BBS List']);
    my $sth;
    my $string;
    my $mode = $self->{'USER'}->{'text_mode'};
    my $ch;
    if ($search) {
        $self->{'debug'}->DEBUG(['  Search BBS List']);
        $self->prompt('Please Enter The BBS To Search For');
        $string = $self->get_line(ECHO,64,'');
        $self->{'debug'}->DEBUG(["  Search String:  $string"]);
        return(FALSE) unless(defined($string) && $string ne '');
        $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_name LIKE ? ORDER BY bbs_name');
        $sth->execute('%' . $string . '%');
        $self->output("\n\n");
        if ($mode eq 'ANSI') {
            $ch = '[% GREEN %]' . $string . '[% RESET %]';
            $self->output("[% B_BRIGHT YELLOW %][% BLACK %] Search BBS listing for [% RESET %] $ch\n\n");
        } elsif ($mode eq 'ATASCII') {
            $ch = $string;
            $self->output("Search BBS listing for $ch\n\n");
        } elsif ($mode eq 'PETSCII') {
            $ch = '[% GREEN %]' . $string . '[% RESET %]';
            $self->output("[% YELLOW %]Search BBS listing for[% RESET %] $ch\n\n");
        } else {
            $ch = $string;
            $self->output("Search BBS listing for '$string'\n\n");
        }
    } else {
        $self->{'debug'}->DEBUG(['  BBS List Full']);
        $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view ORDER BY bbs_name');
        $sth->execute();
        $self->output("\n\nShow full BBS list\n\n");
    }
    $self->{'debug'}->DEBUG(['  BBS Listing - DB query complete']);
    my @listing;
    my ($name_size, $hostname_size, $poster_size) = (4, 14, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    }
    $self->{'debug'}->DEBUGMAX(\@listing);
    if (scalar(@listing)) {
        my $table;
        if ($self->{'USER'}->{'max_columns'} > 40) {
            $table = Text::SimpleTable->new($name_size, $hostname_size, 5, $poster_size);
            $table->row('NAME', 'HOSTNAME/PHONE', 'PORT', 'POSTER');
            $table->hr();
            foreach my $line (@listing) {
                $table->row($line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
            }
        } else {
            $table = Text::SimpleTable->new($name_size, $hostname_size);
            $table->row('NAME', 'HOSTNAME/PHONE');
            $table->hr();
            foreach my $line (@listing) {
                $table->row($line->{'bbs_name'}, $line->{'bbs_hostname'} . ':' . $line->{'bbs_port'});
            }
        }
        my $response;
        if ($mode eq 'ANSI') {
            $response = $table->boxes->draw();
            while ($response =~ / (NAME|HOSTNAME.PHONE|PORT|POSTER) /) {
                my $ch = $1;
                my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                $response =~ s/ $ch / $new /gs;
            }
            $response = $self->color_border($response,'BRIGHT BLUE');
        } elsif ($mode eq 'ATASCII') {
            $response = $table->boxes->draw();
            $response = $self->color_border($response,'BRIGHT BLUE'); # color is ignored for ATASCII
        } elsif ($mode eq 'PETSCII') {
            $response = $table->boxes->draw();
            while ($response =~ / (NAME|HOSTNAME.PHONE|PORT|POSTER) /) {
                my $ch = $1;
                my $new = '[% YELLOW %]' . $ch . '[% WHITE %]';
                $response =~ s/ $ch / $new /gs;
            }
            $response = $self->color_border($response,'BRIGHT BLUE');
        } else {
            $response = $table->draw();
        }
        $response =~ s/$string/$ch/gs if ($search);
        $self->output($response);
    }
    $self->output("\n\nPress any key to continue\n");
    $self->get_key(SILENT, BLOCKING);
    $self->{'debug'}->DEBUG(['End BBS List']);
    return (TRUE);
}

 

# package BBS::Universal::CPU;

sub cpu_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start CPU Initialize']);
    $self->{'debug'}->DEBUG(['END CPU Initialize']);
    return ($self);
}

sub cpu_info {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start CPU Info']);
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
    $self->{'debug'}->DEBUG(['End CPU Info']);
    return ($response);
}

sub cpu_identify {
    my $self = shift;

    return ($self->{'CPUINFO'}) if (exists($self->{'CPUINFO'}));
    $self->{'debug'}->DEBUG(['Start CPU Identity']);
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
    $self->{'debug'}->DEBUGMAX([$response]);
    $self->{'debug'}->DEBUG(['End CPU Identity']);
    return ($response);
}

 

# package BBS::Universal::DB;

sub db_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start DB Initialize']);
    $self->{'debug'}->DEBUG(['End DB Initialize']);
    return ($self);
}

sub db_connect {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start DB Connect']);
    my @dbhosts = split(/\s*,\s*/, $self->{'CONF'}->{'STATIC'}->{'DATABASE HOSTNAME'});
    my $errors  = '';
    foreach my $host (@dbhosts) {
        $errors        = '';
        # This is for the brave that want to try SSL connections.
        #    $self->{'dsn'} = sprintf('dbi:%s:database=%s;' .
        #        'host=%s;' .
        #        'port=%s;' .
        #        'mysql_ssl=%d;' .
        #        'mysql_ssl_client_key=%s;' .
        #        'mysql_ssl_client_cert=%s;' .
        #        'mysql_ssl_ca_file=%s',
        #        $self->{'CONF'}->{'DATABASE TYPE'},
        #        $self->{'CONF'}->{'DATABASE NAME'},
        #        $self->{'CONF'}->{'DATABASE HOSTNAME'},
        #        $self->{'CONF'}->{'DATABASE PORT'},
        #        TRUE,
        #        '/etc/mysql/certs/client-key.pem',
        #        '/etc/mysql/certs/client-cert.pem',
        #        '/etc/mysql/certs/ca-cert.pem'
        #    );
        $self->{'dsn'} = sprintf('dbi:%s:database=%s;' . 'host=%s;' . 'port=%s;', $self->{'CONF'}->{'STATIC'}->{'DATABASE TYPE'}, $self->{'CONF'}->{'STATIC'}->{'DATABASE NAME'}, $host, $self->{'CONF'}->{'STATIC'}->{'DATABASE PORT'},);
        $self->{'dbh'} = DBI->connect(
            $self->{'dsn'},
            $self->{'CONF'}->{'STATIC'}->{'DATABASE USERNAME'},
            $self->{'CONF'}->{'STATIC'}->{'DATABASE PASSWORD'},
            {
                'PrintError' => FALSE,
                'RaiseError' => TRUE,
                'AutoCommit' => TRUE,
            },
        ) or $errors = $DBI::errstr;
        last if ($errors eq '');
    }
    if ($errors ne '') {
        $self->{'debug'}->ERROR(["Database Host not found!\n$errors"]);
        exit(1);
    }
    $self->{'debug'}->DEBUG(['End DB Connect']);
    return (TRUE);
}

sub db_count_users {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start DB Count Users']);
    unless (exists($self->{'dbh'})) {
        $self->db_connect();
    }
    my $response = $self->{'dbh'}->do('SELECT COUNT(id) FROM users');
    $self->{'debug'}->DEBUG(['End DB Count Users']);
    return ($response);
}

sub db_disconnect {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start DB Disconnect']);
    $self->{'dbh'}->disconnect() if (defined($self->{'dbh'}));
    $self->{'debug'}->DEBUG(['End DB Disconnect']);
    return (TRUE);
}

 

# package BBS::Universal::FileTransfer;

sub filetransfer_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start FileTransfer Initialize']);
    $self->{'debug'}->DEBUG(['End FileTransfer Initialize']);
    return ($self);
}

sub files_type {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start File Type']);
    my @tmp = split(/\./,$file);
    my $ext = uc(pop(@tmp));
    my $sth = $self->{'dbh'}->prepare('SELECT type FROM file_types WHERE extension=?');
    $sth->execute($ext);
    my $name;
    if ($sth->rows > 0) {
        $name = $sth->fetchrow_array();
    }
    $sth->finish();
    $self->{'debug'}->DEBUG(['End File Type']);
    return($ext,$name);
}

sub files_load_file {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start Files Load File']);
    my $filename = sprintf('%s.%s', $file, $self->{'USER'}->{'text_mode'});
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    $self->{'debug'}->DEBUG(['End Files Load File']);
    return (join("\n", @text));
}

sub files_list_summary {
    my $self   = shift;
    my $search = shift;

    $self->{'debug'}->DEBUG(['Start Files List Summary']);
    my $sth;
    my $filter;
    if ($search) {
        $self->prompt('Search for');
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
        my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
            my $text = $table->boxes->draw();
            while ($text =~ / (FILENAME|TITLE) /s) {
                my $ch = $1;
                my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $self->output("\n" . $self->color_border($text,'MAGENTA'));
        } elsif ($mode eq 'ATASCII') {
            $self->output("\n" . $self->color_border($table->boxes->draw(),'MAGENTA'));
        } elsif ($mode eq 'PETSCII') {
            my $text = $table->boxes->draw();
            while ($text =~ / (FILENAME|TITLE) /s) {
                my $ch = $1;
                my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $self->output("\n" . $self->color_border($text,'PURPLE'));
        } else {
            $self->output("\n" . $table->draw());
        }
    } elsif ($search) {
        $self->output("\nSorry '$filter' not found");
    } else {
        $self->output("\nSorry, this file category is empty\n");
    }
    $self->output("\nPress a key to continue ...");
    $self->get_key(ECHO, BLOCKING);
    $self->{'debug'}->DEBUG(['End Files List Summary']);
    return (TRUE);
}

sub files_list_detailed {
    my $self   = shift;
    my $search = shift;

    $self->{'debug'}->DEBUG(['Start Files List Detailed']);
    my $sth;
    my $filter;
    my $columns = $self->{'USER'}->{'max_columns'};
    if ($search) {
        $self->prompt('Search for');
        $filter = $self->get_line(ECHO, 20);
        $sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
        $sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
        $sth->execute($self->{'USER'}->{'file_category'});
    }
    my @files;
    my $max_filename = 8;
    my $max_size     = 3;
    my $max_title    = 5;
    my $max_uploader = 8;
    my $max_type     = 4;
    my $max_uploaded = 8;
    my $max_thumbs_up = 9;
    my $max_thumbs_down = 11;
    my $max_fullname = 8;
    my $max_username = 17;
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
            if ($row->{'prefer_nickname'}) {
                $max_uploader = max(length($row->{'nickname'}), $max_uploader);
            } else {
                $max_uploader = max(length($row->{'fullname'}), $max_uploader);
            }
            $max_size         = max(length(format_number($row->{'file_size'})), $max_size, 4);
            $max_filename     = max(length($row->{'filename'}),  $max_filename);
            $max_title        = max(length($row->{'title'}),     $max_title);
            $max_type         = max(length($row->{'type'}),      $max_type);
            $max_uploaded     = max(length($row->{'uploaded'}),  $max_uploaded);
            $max_thumbs_up    = max(length($row->{'thumbs_up'}) + 4, $max_thumbs_up);
            $max_thumbs_down  = max(length($row->{'thumbs_up'}) + 4, $max_thumbs_down);
            $max_fullname     = max(length($row->{'fullname'}),  $max_fullname);
            $max_username     = max(length($row->{'username'}),  $max_username);
        }
        $self->{'debug'}->DEBUGMAX(\@files);
        my $table;
        my $mode = $self->{'USER'}->{'text_mode'};
        if ($columns <= 40) {
            $self->{'debug'}->DEBUG(['  40 Columns']);
            $table = Text::SimpleTable->new($max_filename, $max_uploader);
            $table->row('FILENAME', 'UPLOADER NAME');
            $table->hr();
            foreach my $record (@files) {
                $table->row(
                    $record->{'filename'},
                    ($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
                );
            }
        } elsif ($columns <= 64) {
            $self->{'debug'}->DEBUG(['  64 Columns']);
            $table = Text::SimpleTable->new($max_title, $max_filename, $max_uploader, $max_thumbs_up, $max_thumbs_down);
            $table->row('TITLE', 'FILENAME', 'UPLOADER NAME', 'THUMBS UP','THUMBS DOWN');
            $table->hr();
            foreach my $record (@files) {
                $table->row(
                    $record->{'title'},
                    $record->{'filename'},
                    ($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
                    (0 + $record->{'thumbs_up'}),
                    (0 + $record->{'thumbs_down'}),
                );
            }
        } elsif ($columns <= 80) {
            $self->{'debug'}->DEBUG(['  80 Columns']);
            $table = Text::SimpleTable->new($max_title, $max_filename, $max_uploader, $max_type, $max_thumbs_up, $max_thumbs_down);
            $table->row('TITLE', 'FILENAME', 'UPLOADER NAME','TYPE', 'THUMBS_UP', 'THUMBS_DOWN');
            $table->hr();
            foreach my $record (@files) {
                $table->row(
                    $record->{'title'},
                    $record->{'filename'},
                    ($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
                    $record->{'type'},
                    (0 + $record->{'thumbs_up'}),
                    (0 + $record->{'thumbs_down'}),
                );
            }
        } elsif ($columns <= 132) {
            $self->{'debug'}->DEBUG(['  132 Columns']);
            $table = Text::SimpleTable->new($max_title, $max_filename, $max_size, $max_uploader, $max_username, $max_type, $max_uploaded, $max_thumbs_up, $max_thumbs_down);
            $table->row('TITLE', 'FILENAME', 'SIZE', 'UPLOADER NAME','UPLOADER USERNAME', 'TYPE', 'UPLOAD DATE', 'THUMBS UP', 'THUMBS DOWN');
            $table->hr();
            foreach my $record (@files) {
                $table->row(
                    $record->{'title'},
                    $record->{'filename'},
                    sprintf('%' . $max_size . 's', format_number($record->{'file_size'})),
                    ($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
                    $record->{'username'},
                    $record->{'type'},
                    $record->{'uploaded'},
                    (0 + $record->{'thumbs_up'}),
                    (0 + $record->{'thumbs_down'}),
                );
            }
        } else {
            $self->{'debug'}->DEBUG(['  > 133 Columns']);
            $table = Text::SimpleTable->new($max_title, $max_filename, $max_size, $max_uploader, $max_username, $max_type, $max_uploaded, $max_thumbs_up, $max_thumbs_down);
            $table->row('TITLE', 'FILENAME', 'SIZE', 'UPLOADER NAME','UPLOADER USERNAME', 'TYPE', 'UPLOAD DATE', 'THUMBS UP', 'THUMBS DOWN');
            $table->hr();
            foreach my $record (@files) {
                $table->row(
                    $record->{'title'},
                    $record->{'filename'},
                    sprintf('%' . $max_size . 's', format_number($record->{'file_size'})),
                    ($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
                    $record->{'username'},
                    $record->{'type'},
                    $record->{'uploaded'},
                    (0 + $record->{'thumbs_up'}),
                    (0 + $record->{'thumbs_down'}),
                );
            }
        }
        my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
            my $text = $table->boxes->draw();
            while ($text =~ / (FILENAME|TITLE) /s) {
                my $ch = $1;
                my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $self->output("\n" . $self->color_border($text,'MAGENTA'));
        } elsif ($mode eq 'ATASCII') {
            $self->output("\n" . $self->color_border($table->boxes->draw(),'MAGENTA'));
        } elsif ($mode eq 'PETSCII') {
            my $text = $table->boxes->draw();
            while ($text =~ / (FILENAME|TITLE) /s) {
                my $ch = $1;
                my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $self->output("\n" . $self->color_border($text,'PURPLE'));
        } else {
            $self->output("\n" . $table->draw());
        }
    } elsif ($search) {
        $self->output("\nSorry '$filter' not found");
    } else {
        $self->output("\nSorry, this file category is empty\n");
    }
    $self->output("\nPress a key to continue ...");
    $self->get_key(ECHO, BLOCKING);
    $self->{'debug'}->DEBUG(['End Files List Detailed']);
    return (TRUE);
}

sub save_file {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start Save File']);
    $self->{'debug'}->DEBUG(['End Save File']);
    return (TRUE);
}

sub receive_file {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start Receive File']);
    $self->{'debug'}->DEBUG(['End Receive File']);
    return(TRUE);
}

sub send_file {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start Send File']);
    $self->{'debug'}->DEBUG(['End Send File']);
    return (TRUE);
}

 

# package BBS::Universal::Messages;

sub messages_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start Messages Initialize']);
    $self->{'debug'}->DEBUG(['End Messages Initialize']);
    return ($self);
}

sub messages_forum_categories {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Messages Forum Categories']);
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
    $self->prompt('Choose Forum Category');
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
    $self->{'debug'}->DEBUG(['End Messages Forum Categories']);
    return($command);
}

sub messages_list_messages {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Messages List Messages']);
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
        $self->output("[% CLS %]== FORUM " . '=' x ($self->{'USER'}->{'max_columns'} - 7) . "\n");
        my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
            $self->output('[% B_BRIGHT GREEN %][% BLACK %] CATEGORY [% RESET %] [% FORUM CATEGORY %]' . "\n");
            $self->output('[% BRIGHT WHITE %][% B_BLUE %]   Author [% RESET %] ');
            $self->output(($result->{'prefer_nickname'}) ? $result->{'author_nickname'} : $result->{'author_fullname'});
            $self->output(' (' . $result->{'author_username'} . ')' . "\n");
            $self->output('[% BRIGHT WHITE %][% B_BLUE %]    Title [% RESET %] ' . $result->{'title'} . "\n");
            $self->output('[% BRIGHT WHITE %][% B_BLUE %]  Created [% RESET %] ' . $self->users_get_date($result->{'created'}) . "\n\n");
            $self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
        } elsif ($mode eq 'ATASCII') {
            $self->output('[% GREEN   %] CATEGORY [% RESET %] [% FORUM CATEGORY %]' . "\n");
            $self->output('[% YELLOW %]   Author [% RESET %] ');
            $self->output(($result->{'prefer_nickname'}) ? $result->{'author_nickname'} : $result->{'author_fullname'});
            $self->output(' (' . $result->{'author_username'} . ')' . "\n");
            $self->output('[% YELLOW %]    Title [% RESET %] ' . $result->{'title'} . "\n");
            $self->output('[% YELLOW %]  Created [% RESET %] ' . $self->users_get_date($result->{'created'}) . "\n\n");
            $self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
        } else {
            $self->output(' CATEGORY > [% FORUM CATEGORY %]' . "\n");
            $self->output('  Author:  ');
            $self->output(($result->{'prefer_nickname'}) ? $result->{'nickname'} : $result->{'author_fullname'});
            $self->output(' (' . $result->{'author_username'} . ')' . "\n");
            $self->output('   Title:  ' . $result->{'title'} . "\n");
            $self->output(' Created:  ' . $self->users_get_date($result->{'created'}) . "\n\n");
            $self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
        }
        $self->output("\n" . '=' x $self->{'USER'}->{'max_columns'} . "\n");
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
        $self->prompt('Choose');
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
    $self->{'debug'}->DEBUG(['End Messages List Messages']);
    return(TRUE);
}

sub messages_edit_message {
    my $self        = shift;
    my $mode        = shift;
    my $old_message = (scalar(@_)) ? shift : undef;

    $self->{'debug'}->DEBUG(['Start Messages Edit Message']);
    my $message;
    if ($mode eq 'ADD') {
        $self->{'debug'}->DEBUG(['  Add Message']);
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
            sleep 1;
        }
    } elsif ($mode eq 'REPLY') {
        $self->output("  Edit Message\n");
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
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $self->output('[% GREEN %]Message Saved[% RESET %]');
            } else {
                $self->output('Message Saved');
            }
            $message->{'id'} = $sth->last_insert_id();
            sleep 1;
        }
    } else { # EDIT
        $self->output("  Edit Message\n");
        $self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor($old_message);
        if (defined($message)) {
            my $sth = $self->{'dbh'}->prepare('UPDATE messages SET message=? WHERE id=>');
            $sth->execute(
                $message->{'message'},
                $message->{'id'}
            );
            $sth->finish();
            $message->{'id'} = $old_message->{'id'};
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $self->output('[% GREEN %]Message Saved[% RESET %]');
            } else {
                $self->output('Message Saved');
            }
            sleep 1;
        }
    }
    $self->{'debug'}->DEBUG(['End Messages Edit Message']);
    return($message);
}

sub messages_delete_message {
    my $self    = shift;
    my $message = shift;

    $self->{'debug'}->DEBUG(['Start Messages Delete Message']);
    my $response = FALSE;
    $self->output("\n\nReally Delete This Message?  ");
    if ($self->decision() && defined($message)) {
        my $sth = $self->{'dbh'}->prepare('UPDATE messages SET hidden=TRUE WHERE id=?');
        $sth->execute($message->{'id'});
        $sth->finish();
        $response = TRUE;
    }
    $self->{'debug'}->DEBUG(['End Messages Delete Message']);
    return($response);
}

sub messages_text_editor {
    my $self    = shift;
    my $message = (scalar(@_)) ? shift : undef;

    $self->{'debug'}->DEBUG(['Start Messages Text Editor']);
    my $title = '';
    my $text  = '';
    if ($self->{'local_mode'} || $self->{'sysop'} || $self->is_connected()) {
        if (defined($message)) {
            $title = $message->{'title'};
            $text  = $message->{'message'};
            $self->prompt('Message');
            $text  = $self->messages_text_edit($title,$text);
        } else {
            $self->prompt('Title');
            $title = $self->get_line(ECHO, 255);
            $self->prompt('Message');
            $text  = $self->messages_text_edit($title);
        }
        if (defined($text) && defined($title)) {
            $self->{'debug'}->DEBUG(['End Messages Text Editor']);
            return(
                {
                    'title'   => $title,
                    'message' => $text,
                }
            );
        }
    }
    $self->{'debug'}->DEBUG(['  Abort','End Messages Text Editor']);
    return(undef);
}

sub messages_text_edit {
    my $self  = shift;
    my $title = (scalar(@_)) ? shift : undef;
    my $text  = (scalar(@_)) ? shift : undef;

    $self->{'debug'}->DEBUG(['Start Messages Text Edit']);
    my $columns = $self->{'USER'}->{'max_columns'};
    my $text_mode = $self->{'USER'}->{'text_mode'};
    my @lines;
    if (defined($text) && $text ne '') {
        @lines = split(/\n$/,$text . "\n");
    }
    my $save   = FALSE;
    my $cancel = FALSE;
    do {
        my $counter = 0;
        if ($text_mode eq 'ANSI') {
            $self->output('[% CLEAR %][% BRIGHT GREEN %]' . '=' x $columns . '[% RESET %]' . "\n");
            $self->output('[% CYAN %]Subject[% RESET %]:  ' . $title . "\n");
            $self->output('[% BRIGHT GREEN %]' . '-' x $columns . '[% RESET %]' . "\n");
            $self->output("Type a command on a line by itself\n");
            $self->output('  :[% YELLOW %]S[% RESET %] = Save and exit' . "\n");
            $self->output('  :[% RED %]Q[% RESET %] = Cancel, do not save' . "\n");
            $self->output('  :[% BRIGHT BLUE %]E[% RESET %] = Edit a specific line number (:E5 edits line 5)' . "\n");
            $self->output('[% BRIGHT GREEN %]' . '=' x $columns . '[% RESET %]' . "\n");
        } elsif ($text_mode eq 'PETSCII') {
            $self->output('[% CLEAR %][% LIGHT GREEN %]' . '=' x $columns . "\n");
            $self->output('[% CYAN %]Subject[% WHITE %]:  ' . $title . "\n");
            $self->output('[% LIGHT GREEN %]' . '-' x $columns . "\n");
            $self->output('[% WHITE %]Type a command on a line by itself' . "\n");
            $self->output('  :[% YELLOW %]S[% WHITE %] = Save and exit' . "\n");
            $self->output('  :[% RED %]Q[% WHITE %] = Cancel, do not save' . "\n");
            $self->output('  :[% BLUE %]E[% WHITE %] = Edit a specific line number (:E5 edits line 5)' . "\n");
            $self->output('=' x $columns . "\n");
        } elsif ($text_mode eq 'ATASCII') {
            $self->output('[% CLEAR %]' . '=' x $columns . "\n");
            $self->output("Subject:  $title\n");
            $self->output('-' x $columns . "\n");
            $self->output("Type a command on a line by itself\n");
            $self->output("  :S = Save and exit\n");
            $self->output("  :Q = Cancel, do not save\n");
            $self->output("  :E = Edit a specific line number (:E5 edits line 5)\n");
            $self->output('=' x $columns . "\n");
        } else { # ASCII
            $self->output('[% CLEAR %]' . '=' x $columns . "\n");
            $self->output("Subject:  $title\n");
            $self->output('-' x $columns . "\n");
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
            } elsif ($text_mode eq 'PETSCII') {
                $self->output(sprintf('%s%03d%s ', '[% CYAN %]', ($counter + 1), '[% WHITE %]'));
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
                        } elsif ($text_mode eq 'PETSCII') {
                            $self->output(sprintf('%s%03d%s ', '[% CYAN %]', $line_number, '[% WHITE %]'));
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
    $self->{'debug'}->DEBUG(['End Messages Text Edit']);
    return($text);
}

 

# package BBS::Universal::News;

sub news_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start News Initialize']);
    $self->{'rss'} = XML::RSS::LibXML->new();
    $self->{'debug'}->DEBUG(['End News Initialize']);
    return ($self);
}

sub news_display {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start News Display']);
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
                $news .= "$today - [% B_GREEN %][% BLACK %] Today is the author's birthday! [% RESET %] " . '[% PARTY POPPER %]' . "\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
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
    $self->{'debug'}->DEBUG(['End News Display']);
    return (TRUE);
}

sub news_summary {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start News Summary']);
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
        my $table = Text::SimpleTable->new(10, $self->{'USER'}->{'max_columns'} - 14);
        $table->row('DATE', 'TITLE');
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            $table->row($row->{'newsdate'}, $row->{'news_title'});
        }
        my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
            my $text = $table->boxes->draw();
            my $ch = colored(['bright_yellow'],'DATE');
            $text =~ s/DATE/$ch/;
            $ch = colored(['bright_yellow'],'TITLE');
            $text =~ s/TITLE/$ch/;
            $self->output($self->color_border($text,'BRIGHT BLUE'));
        } elsif ($mode eq 'ATASCII') {
            my $text = $self->color_border($table->boxes->draw(),'BLUE');
            $self->output($text);
        } elsif ($mode eq 'PETSCII') {
            my $text = $table->boxes->draw();
            while ($text =~ / (DATE|TITLE) /s) {
                my $ch = $1;
                my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $text = $self->color_border($text, 'LIGHT BLUE');
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
    $self->{'debug'}->DEBUG(['End News Summary']);
    return (TRUE);
}

sub news_rss_categories {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start News RSS Categories']);
    my $command = '';
    my $id;
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM rss_feed_categories WHERE id<>? ORDER BY title');
    $sth->execute($self->{'USER'}->{'rss_category'});
    my $mapping = {
        'TEXT' => '',
        'Z'    => {
            'command'      => 'BACK',
            'color'        => 'WHITE',
            'access_level' => 'USER',
            'text'         => 'Return to News Menu',
        },
    };
    my @menu_choices = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y));
    while(my $result = $sth->fetchrow_hashref()) {
        if ($self->check_access_level($result->{'access_level'})) {
            $mapping->{shift(@menu_choices)} = {
                'command'      => $result->{'title'},
                'id'           => $result->{'id'},
                'color'        => 'WHITE',
                'access_level' => $result->{'access_level'},
                'text'         => $result->{'description'},
            };
        }
    }
    $sth->finish();
    $self->show_choices($mapping);
    $self->prompt('Choose World News Feed Category');
    my $key;
    do {
        $key = uc($self->get_key(SILENT, BLOCKING));
    } until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
    if ($key eq chr(3)) {
        return('DISCONNECT');
    } else {
        $id      = $mapping->{$key}->{'id'};
        $command = $mapping->{$key}->{'command'};
    }
    if ($self->is_connected() && $command ne 'BACK') {
        $self->output($command);
        $sth = $self->{'dbh'}->prepare('UPDATE users SET rss_category=? WHERE id=?');
        $sth->execute($id, $self->{'USER'}->{'id'});
        if ($sth->err) {
            $self->{'debug'}->ERROR([$sth->errstr]);
        }
        $sth->finish();
        $self->{'USER'}->{'rss_category'} = $id;
        $command = 'BACK';
    }
    $self->{'debug'}->DEBUG(['End News RSS Categories']);
    return($command);
}

sub news_rss_feeds {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start News RSS Feeds']);
    my $mode = $self->{'USER'}->{'text_mode'};
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM rss_view WHERE category=? ORDER BY title');
    $sth->execute($self->{'USER'}->{'rss_category'});
    my $mapping = {
        'TEXT' => '',
        'Z' => {
            'command'      => 'BACK',
            'color'        => 'WHITE',
            'access_level' => 'USER',
            'text'         => 'Return to News Menu',
        },
    };
    my @menu_choices = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y));
    while(my $result = $sth->fetchrow_hashref()) {
        if ($self->check_access_level($result->{'access_level'})) {
            $mapping->{shift(@menu_choices)} = {
                'command'      => $result->{'title'},
                'id'           => $result->{'id'},
                'color'        => 'WHITE',
                'access_level' => $result->{'access_level'},
                'text'         => $self->news_title_colorize($result->{'title'}),
                'url'          => $result->{'url'},
            };
        }
    }
    $sth->finish();
    $self->show_choices($mapping);
    $self->prompt('Choose World News Feed');
    my $id;
    my $key;
    my $command;
    my $url;
    do {
        $key = uc($self->get_key(SILENT, BLOCKING));
    } until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
    if ($key eq chr(3)) {
        $command = 'DISCONNECT';
    } else {
        $id      = $mapping->{$key}->{'id'};
        $command = $mapping->{$key}->{'command'};
        $url     = $mapping->{$key}->{'url'};
    }
    if ($self->is_connected() && $command ne 'DISCONNECT' && $command ne 'BACK') {
        $self->output($command);
        my $rss_string = `curl -s $url`;
        my $rss = XML::RSS::LibXML->new;
        $rss->parse($rss_string);

        my $list        = $rss->items;

        my $text;
        foreach my $item (@{$list}) {
            last unless ($self->is_connected());
            if ($mode eq 'ANSI') {
                $text .= '[% NAVY %]' . '━' x $self->{'USER'}->{'max_columns'} . "[% RESET %]\n";
                $text .= '[% BRIGHT WHITE %][% B_TEAL %]       Title [% RESET %] [% GREEN %]' . $self->html_to_text($item->{'title'}) . "[% RESET %]\n";
                $text .= '[% BRIGHT WHITE %][% B_TEAL %] Description [% RESET %] ' . $self->html_to_text($item->{'description'}) . "\n";
                $text .= '[% BRIGHT WHITE %][% B_TEAL %]        Link [% RESET %] [% YELLOW %]' . $item->{'link'} . "[% RESET %]\n";
            } elsif ($mode eq 'PETSCII') {
                $text .= '[% YELLOW %]       Title [% RESET %] [% GREEN %]' . $self->html_to_text($item->{'title'}) . "\n";
                $text .= '[% YELLOW %] Description [% RESET %] ' . $self->html_to_text($item->{'description'}) . "\n";
                $text .= '[% YELLOW %]        Link [% RESET %] [% YELLOW %]' . $item->{'link'} . "[% RESET %]\n";
            } else {
                $text .= '      Title:  ' . $item->{'title'} . "\n";
                $text .= 'Description:  ' . $self->html_to_text($item->{'description'}) . "\n";
                $text .= '       Link:  ' . $item->{'link'} . "\n\n";
            }
        }
        $self->output("\n\n" . $text);
        $self->output("\n\nPress any key to continue\n");
        $self->get_key(SILENT, BLOCKING);
        $command = 'BACK';
    }
    $self->{'debug'}->DEBUG(['End News RSS Feeds']);
    return($command);
}

sub news_title_colorize {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start News Title Colorize']);
    my $mode = $self->{'USER'}->{'text_mode'};
    if ($mode eq 'ANSI') {
        if ($text =~ /fox news/i) {
            my $fox = '[% B_BLUE %][% BRIGHT WHITE %]FOX NEW[% B_RED %]S[% RESET %]';
            $text =~ s/fox news/$fox/gsi;
        } elsif ($text =~ /cnn news/i) {
            my $cnn = '[% BRIGHT RED %]CNN News[% RESET %]';
            $text =~ s/cnn/$cnn/gsi;
        } elsif ($text =~ /cbs news/i) {
            my $cbs = '[% BRIGHT BLUE %]CBS News[% RESET %]';
            $text =~ s/cbs/$cbs/gsi;
        } elsif ($text =~ /reuters/i) {
            my $reuters = '[% B_BRIGHT WHITE %][% ORANGE %]✺ [% BLACK %] Reuters[% RESET %]';
            $text =~ s/reuters/$reuters/gsi;
        } elsif ($text =~ /npr/i) {
            my $npr = '[% B_BRIGHT RED %][% BRIGHT WHITE %]n[% B_BLACK %]p[% B_BRIGHT BLUE %]r[% RESET %]';
            $text =~ s/npr/$npr/gsi;
        } elsif ($text =~ /bbc news/i) {
            my $bbc = '[% BRIGHT RED %][% B_BRIGHT WHITE %]BBC NEWS[% RESET %]';
            $text =~ s/bbc news/$bbc/gsi;
        } elsif ($text =~ /wired/i) {
            my $wired = '[% B_BLACK %][% BRIGHT WHITE %]W[% B_BRIGHT WHITE %][% BLACK %]I[% B_BLACK %][% BRIGHT WHITE %]R[% B_BRIGHT WHITE %][% BLACK %]E[% B_BLACK %][% BRIGHT WHITE %]D[% RESET %]';
            $text =~ s/wired/$wired/gsi;
        } elsif ($text =~ /daily wire/i) {
            my $dw = '[% BLACK %][% BRIGHT WHITE %]DAILY WIRE[% RED %]🞤[% RESET %]';
            $text =~ s/daily wire/$dw/gsi;
        } elsif ($text =~ /the blaze/i) {
            my $blaze = '[% B_BRIGHT WHITE %][% BLACK %]the[% RED %]Blaze[% RESET %]';
            $text =~ s/the blaze/$blaze/gsi;
        } elsif ($text =~ /national review/i) {
            my $nr = '[% B_BLACK %][% BRIGHT WHITE %]NR[% RESET %] NATIONAL REVIEW';
            $text =~ s/national review/$nr/gsi;
        } elsif ($text =~ /hot air/i) {
            my $hr = '[% BRIGHT WHITE %]HOT A[% RED %]i[% BRIGHT WHITE %]R[% RESET %]';
            $text =~ s/hot air/$hr/gsi;
        } elsif ($text =~ /gateway pundit/i) {
            my $gp = '[% B_WHITE %][% BRIGHT BLUE %]GP[% GOLD %]🭦[% RESET %] The Gateway Pundit';
            $text =~ s/gateway pundit/$gp/gsi;
        } elsif ($text =~ /daily signal/i) {
            my $ds = '[% B_BRIGHT WHITE %][% BLACK %]ⓢ [% RESET %] Daily Signal';
            $text =~ s/daily signal/$ds/gsi;
        } elsif ($text =~ /newsbusters/i) {
            my $nb = '[% ORANGE %]NewsBusters[% RESET %]';
            $text =~ s/newsbusters/$nb/gsi;
        } elsif ($text =~ /newsmax/i) {
            my $nm = '[% B_BLUE %][% RED %]N[% BRIGHT WHITE %]EWSMAX[% RESET %]';
            $text =~ s/newsmax/$nm/gsi;
        } elsif ($text =~ /american thinker/i) {
            my $at = '[% B_OLIVE %][% BLUE %]American Thinker[% RESET %]';
            $text =~ s/american thinker/$at/gsi;
        } elsif ($text =~ /pj media/i) {
            my $pj = '[% B_TEAL %][% BRIGHT WHITE %]PJ[% RESET %] Media';
            $text =~ s/pj media/$pj/gsi;
        } elsif ($text =~ /breitbart/i) {
            my $b = '[% B_DARK ORANGE %][% BRIGHT WHITE %] B [% RESET %] Breitbart';
            $text =~ s/breitbart/$b/gsi;
        }
    }
    $self->{'debug'}->DEBUG(['End News Title Colorize']);
    return($text);
}

 

# package BBS::Universal::PETSCII;

sub petscii_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start PETSCII Initialize']);
	$self->{'petscii_meta'} = {
        'UNDERLINE ON' => {
			'out' => chr(2),
			'unicode' => ' ',
			'desc' => 'Turn on underline mode',
		},
        'WHITE'        => {
			'out' => chr(5),
			'unicode' => ' ',
			'desc' => 'White text',
		},
        'RESET'        => {
			'out' => chr(5),
			'unicode' => ' ',
			'desc' => 'Reset back to white text',
		},
        'RING BELL'    => {
			'out' => chr(7),
			'unicode' => ' ',
			'desc' => 'Sound bell',
		},
        'TAB'          => {
			'out' => chr(9),
			'unicode' => ' ',
			'desc' => 'Tab',
		},
        'RETURN'       => {
			'out' => chr(13),
			'unicode' => ' ',
			'desc' => 'Carriage Return',
		},
        'LINEFEED'     => {
			'out' => chr(10),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},
        'NEWLINE'      => {
			'out' => chr(13) . chr(10),
			'unicode' => ' ',
			'desc' => 'Newline',
		},
        'CLEAR'        => {
			'out' => chr(0x93),
			'unicode' => ' ',
			'desc' => 'Clear Screen',
		},
        'CLS'          => {
			'out' => chr(0x93),
			'unicode' => ' ',
			'desc' => 'Clear Screen',
		},
        'BACKSPACE'    => {
			'out' => chr(20),
			'unicode' => ' ',
			'desc' => 'Backspace',
		},
        'DELETE'       => {
			'out' => chr(20),
			'unicode' => ' ',
			'desc' => 'Delete',
		},
        'BLACK'         => {
			'out' => chr(0x90),
			'unicode' => ' ',
			'desc' => 'Black',
		},
        'RED'           => {
			'out' => chr(0x1C),
			'unicode' => ' ',
			'desc' => 'Red',
		},
        'GREEN'         => {
			'out' => chr(0x1E),
			'unicode' => ' ',
			'desc' => 'Green',
		},
        'BLUE'          => {
			'out' => chr(0x1F),
			'unicode' => ' ',
			'desc' => 'Blue',
		},
        'DARK PURPLE'   => {
			'out' => chr(0x81),
			'unicode' => ' ',
			'desc' => 'Dark Purple',
		},
        'UNDERLINE OFF' => {
			'out' => chr(0x82),
			'unicode' => ' ',
			'desc' => 'Turn Underline Off',
		},
        'BLINK ON'      => {
			'out' => chr(0x0F),
			'unicode' => ' ',
			'desc' => 'Turn Blink On',
		},
        'BLINK OFF'     => {
			'out' => chr(0x8F),
			'unicode' => ' ',
			'desc' => 'Turn Blink On',
		},
        'REVERSE ON'    => {
			'out' => chr(0x12),
			'unicode' => ' ',
			'desc' => 'Turn Reverse On',
		},
        'REVERSE OFF'   => {
			'out' => chr(0x92),
			'unicode' => ' ',
			'desc' => 'Turn Reverse Off',
		},
        'BROWN'         => {
			'out' => chr(0x95),
			'unicode' => ' ',
			'desc' => 'Brown',
		},
        'PINK'          => {
			'out' => chr(0x96),
			'unicode' => ' ',
			'desc' => 'Pink',
		},
        'CYAN'          => {
			'out' => chr(0x97),
			'unicode' => ' ',
			'desc' => 'Cyan',
		},
        'LIGHT GRAY'    => {
			'out' => chr(0x98),
			'unicode' => ' ',
			'desc' => 'Light Gray',
		},
        'LIGHT GREEN'   => {
			'out' => chr(0x99),
			'unicode' => ' ',
			'desc' => 'Light Green',
		},
        'LIGHT BLUE'    => {
			'out' => chr(0x9A),
			'unicode' => ' ',
			'desc' => 'Light Blue',
		},
        'GRAY'          => {
			'out' => chr(0x9B),
			'unicode' => ' ',
			'desc' => 'Gray',
		},
        'PURPLE'        => {
			'out' => chr(0x9C),
			'unicode' => ' ',
			'desc' => 'Purple',
		},
        'YELLOW'        => {
			'out' => chr(0x9E),
			'unicode' => ' ',
			'desc' => 'Yellow',
		},
        'CYAN'          => {
			'out' => chr(0x9F),
			'unicode' => ' ',
			'desc' => 'Cyan',
		},
        'UP'            => {
			'out' => chr(0x91),
			'unicode' => ' ',
			'desc' => 'Move Cursor Up',
		},
        'DOWN'          => {
			'out' => chr(0x11),
			'unicode' => ' ',
			'desc' => 'Move Cursor Down',
		},
        'LEFT'          => {
			'out' => chr(0x9D),
			'unicode' => ' ',
			'desc' => 'Move Cursor Left',
		},
        'RIGHT'         => {
			'out' => chr(0x1D),
			'unicode' => ' ',
			'desc' => 'Move Cursor Right',
		},
        'ESC'           => {
			'out' => chr(0x1B),
			'unicode' => ' ',
			'desc' => 'Escape',
		},
        'LINEFEED'      => {
			'out' => chr(0x0A),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},

        'BRITISH POUND'                => {
			'out' => chr(0x5C),    # £
			'unicode' => '£',
			'desc' => 'British Pound',
		},
        'UP ARROW'                     => {
			'out' => chr(0x5E),    # ↑
			'unicode' => '↑',
			'desc' => 'Up Arrow',
		},
        'LEFT ARROW'                   => {
			'out' => chr(0x5F),    # ←
			'unicode' => '←',
			'desc' => 'Left Arrow',
		},
        'HORIZONTAL BAR'               => {
			'out' => chr(0x60),    # ─
			'unicode' => '─',
			'desc' => 'Horizontal Bar',
		},
        'SPADE'                        => {
			'out' => chr(0x61),    # ♠
			'unicode' => '♠',
			'desc' => 'Spade',
		},
        'TOP RIGHT ROUNDED CORNER'     => {
			'out' => chr(0x69),    # ╮
			'unicode' => '╮',
			'desc' => 'Top Right Rounded Corner',
		},
        'BOTTOM LEFT ROUNDED CORNER'   => {
			'out' => chr(0x6A),    # ╰
			'unicode' => '╰',
			'desc' => 'Bottom Left Rounded Corner',
		},
        'BOTTOM RIGHT ROUNDED CORNER'  => {
			'out' => chr(0x6B),    # ╯
			'unicode' => '╯',
			'desc' => 'Bottom Right Rounded Corner',
		},
        'GIANT BACKSLASH'             => {
			'out' => chr(0x6D),    # ╲
			'unicode' => '╲',
			'desc' => 'Giant Backslash',
		},
        'GIANT FORWARD SLASH'          => {
			'out' => chr(0x6E),    # ╱
			'unicode' => '╱',
		},
        'CENTER DOT'                   => {
			'out' => chr(0x71),    # •
			'unicode' => '•',
			'desc' => 'Center Dot',
		},
        'HEART'                        => {
			'out' => chr(0x73),    # ♥
			'unicode' => '♥',
			'desc' => 'Heart',
		},
        'TOP LEFT ROUNDED CORNER'      => {
			'out' => chr(0x75),    # ╭
			'unicode' => '╭',
			'desc' => 'Top Left Rounded Corner',
		},
        'GIANT X'                      => {
			'out' => chr(0x76),    # ╳
			'unicode' => '╳',
			'desc' => 'Giant X',
		},
        'THIN CIRCLE'                  => {
			'out' => chr(0x77),    # ○
			'unicode' => '○',
			'desc' => 'Thin Circle',
		},
        'CLUB'                         => {
			'out' => chr(0x78),    # ♣
			'unicode' => '♣',
			'desc' => 'Club',
		},
        'DIAMOND'                      => {
			'out' => chr(0x7A),    # ♦
			'unicode' => '♦',
			'desc' => 'Diamond',
		},
        'CROSS BAR'                    => {
			'out' => chr(0x7B),    # ┼
			'unicode' => '┼',
			'desc' => 'Cross Bar',
		},
        'GIANT VERTICAL BAR'           => {
			'out' => chr(0x7D),    # │
			'unicode' => '│',
			'desc' => 'Giant Vertical Bar',
		},
        'PI'                           => {
			'out' => chr(0x7E),    # π
			'unicode' => 'π',
			'desc' => 'Pi',
		},
        'BOTTOM LEFT WEDGE'            => {
			'out' => chr(0x7F),    # ◥
			'unicode' => '◥',
			'desc' => 'Bottom Left Wedge',
		},
        'DITHERED FULL'                => {
			'out' => chr(0x7C),
			'unicode' => ' ',
			'desc' => 'Dithered Box Full',
		},
        'LEFT HALF'                    => {
			'out' => chr(0xA1),    # ▌
			'unicode' => '▌',
			'desc' => 'Left Half',
		},
        'BOTTOM BOX'                   => {
			'out' => chr(0xA2),    # ▄
			'unicode' => '▄',
			'desc' => 'Bottom Box',
		},
        'TOP HORIZONTAL BAR'           => {
			'out' => chr(0xA3),    # ▔
			'unicode' => '▔',
			'desc' => 'Top Horizontal Bar',
		},
        'BOTTOM HORIZONTAL BAR'        => {
			'out' => chr(0xA4),    # ▁
			'unicode' => '▁',
			'desc' => 'Bottom Horizontal Bar',
		},
        'LEFT VERTICAL BAR'            => {
			'out' => chr(0xA5),    #
			'unicode' => ' ',
			'desc' => 'Left Vertical Bar',
		},
        'DITHERED BOX'                 => {
			'out' => chr(0xA6),    # ▒
			'unicode' => '▒',
			'desc' => 'Dithered Box',
		},
        'RIGHT VERTICAL BAR'           => {
			'out' => chr(0xA7),    # ▕
			'unicode' => '▕',
			'desc' => 'Right Vertical Bar',
		},
        'DITHERED LEFT'                => {
			'out' => chr(0xA8),
			'unicode' => ' ',
			'desc' => 'Dithered Left',
		},
        'BOTTOM RIGHT WEDGE'           => {
			'out' => chr(0xA9),    # ◤
			'unicode' => '◤',
			'desc' => 'Bottom Right Wedge',
		},
        'VERTICAL BAR MIDDLE LEFT'     => {
			'out' => chr(0xAB),    # ├
			'unicode' => '├',
			'desc' => 'Vertical Bar Middle Left',
		},
        'BOTTOM RIGHT BOX'             => {
			'out' => chr(0xAC),    # ▗
			'unicode' => '▗',
			'desc' => 'Bottom Right Box',
		},
        'BOTTOM LEFT CORNER'           => {
			'out' => chr(0xAD),    # └
			'unicode' => '└',
			'desc' => 'Bottom Left Corner',
		},
        'TOP RIGHT CORNER'             => {
			'out' => chr(0xAE),    # ┐
			'unicode' => '┐',
			'desc' => 'Top Right Corner',
		},
        'HORIZONTAL BAR BOTTOM'        => {
			'out' => chr(0xAF),    # ▂
			'unicode' => '▂',
			'desc' => 'Horizontal Bar Bottom',
		},
        'TOP LEFT CORNER'              => {
			'out' => chr(0xB0),    # ┌
			'unicode' => '┌',
			'desc' => 'Top Left Corner',
		},
        'HORIZONTAL BAR MIDDLE BOTTOM' => {
			'out' => chr(0xB1),    # ┴
			'unicode' => '┴',
			'desc' => 'Horizontal Bar Middle Bottom',
		},
        'HORIZONTAL BAR MIDDLE TOP'    => {
			'out' => chr(0xB2),    # ┬
			'unicode' => '┬',
			'desc' => 'Horizontal Bar Middle Top',
		},
        'VERTICAL BAR MIDDLE RIGHT'    => {
			'out' => chr(0xB3),    # ┤
			'unicode' => '┤',
			'desc' => 'Vertical Bar Middle Right',
		},
        'VERTICAL BOX LEFT'            => {
			'out' => chr(0xB4),    # ▎
			'unicode' => '▎',
			'desc' => 'Vertical Box Left',
		},
        'LEFT HALF BOX'                => {
			'out' => chr(0xB5),    # ▍
			'unicode' => '▍',
			'desc' => 'Left Half Box',
		},
        'BOTTOM HALF BOX'              => {
			'out' => chr(0xB9),    # ▃
			'unicode' => '▃',
			'desc' => 'Bottom Half Box',
		},
        'BOTTOM LEFT BOX'              => {
			'out' => chr(0xBB),    # ▖
			'unicode' => '▖',
			'desc' => 'Bottom Left Box',
		},
        'TOP RIGHT BOX'                => {
			'out' => chr(0xBC),    # ▝
			'unicode' => '▝', 
			'desc' => 'Top Right Box',
		},
        'BOTTOM RIGHT CORNER'          => {
			'out' => chr(0xBD),    # ┘
			'unicode' => '┘',
			'desc' => 'Bottom Right Corner',
		},
        'TOP LEFT BOX'                 => {
			'out' => chr(0xBE),    # ▘
			'unicode' => '▘',
			'desc' => 'Top Left Box',
		},
        'TOP LEFT BOTTOM RIGHT BOX'    => {
			'out' => chr(0xBF),    # ▚
			'unicode' => '▚',
			'desc' => 'Top Left Bottom Right Box',
		},
        'DITHERED LEFT REVERSE'        => {
			'out' => chr(0xDC),
			'unicode' => ' ',
			'desc' => 'Dithered Left Reverse',
		},
        'DITHERED BOTTOM REVERSE'      => {
			'out' => chr(0xE8),
			'unicode' => ' ',
			'desc' => 'Dithered Bottom Reverse',
		},
        'DITHERED FULL REVERSE'        => {
			'out' => chr(0xFC),
			'unicode' => ' ',
			'desc' => 'Dithered Full Reverse',
		},
	};
	foreach my $name (keys %{ $self->{'petscii_meta'} }) {
		$self->{'petscii_sequences'}->{$name} = $self->{'petscii_meta'}->{$name}->{'out'};
	}
    $self->{'debug'}->DEBUG(['End PETSCII Initialize']);
    return ($self);
} ## end sub petscii_initialize

sub petscii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start PETSCII Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        while($text =~ /\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/) {
            my $rule = "[% $1 %]" . '[% TOP HORIZONTAL BAR %]' x $self->{'USER'}->{'max_columns'} . '[% RESET %]';
            $text =~ s/\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/$rule/gs;
        }
        foreach my $string (keys %{ $self->{'petscii_sequences'} }) {    # Decode macros
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'petscii_sequences'}->{$string}/gi;
            }
        } ## end foreach my $string (keys %{...})
    } ## end if (length($text) > 1)
    my $s_len = length($text);
    my $nl    = $self->{'petscii_sequences'}->{'NEWLINE'};
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
    $self->{'debug'}->DEBUG(['End PETSCII Output']);
    return (TRUE);
} ## end sub petscii_output

 

# package BBS::Universal::SysOp;

sub sysop_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Initialize']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    $self->{'wsize'} = $wsize;
    $self->{'hsize'} = $hsize;
    $self->{'debug'}->DEBUG(["Screen Size is $wsize x $hsize"]);
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

    $self->{'flags_default'} = {
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

    $self->{'sysop_tokens'} = {
        # Static Tokens
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

        # Non-static tokens
        'THREADS COUNT' => sub {
            my $self = shift;
            return ($self->{'CACHE'}->get('THREADS_RUNNING'));
        },
        'USERS COUNT' => sub {
            my $self = shift;
            return ($self->db_count_users());
        },
        'UPTIME' => sub {
            my $self   = shift;
            my $uptime = `uptime -p`;
            chomp($uptime);
            return ($uptime);
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
        'SYSOP VIEW CONFIGURATION' => sub {
            my $self = shift;
            return ($self->sysop_view_configuration('string'));
        },
        'COMMANDS REFERENCE' => sub {
            my $self = shift;
            return ($self->sysop_list_commands());
        },
        'MIDDLE VERTICAL RULE color' => sub {
            my $self = shift;
            my $color = shift;
            return($self->sysop_locate_middle('B_' . $color));
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
            banned
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

    $self->{'SYSOP FIELD TYPES'} = {
        'id' => {
            'type' => NUMERIC,
            'max'  => 2,
            'min'  => 2,
        },
        'username' => {
            'type' => HOST,
            'max'  => 32,
            'min'  => 16,
        },
        'fullname' => {
            'type' => STRING,
            'max'  => 20,
            'min'  => 15,
        },
        'given' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'family' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'nickname' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'email' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'birthday' => {
            'type' => STRING,
            'max'  => 10,
            'min'  => 10,
        },
        'location' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 40,
        },
        'date_format' => {
            'type'    => RADIO,
            'max'     => 14,
            'min'     => 14,
            'choices' => ['MONTH/DAY/YEAR', 'DAY/MONTH/YEAR', 'YEAR/MONTH/DAY',],
            'default' => 'DAY/MONTH/YEAR',
        },
        'access_level' => {
            'type'    => RADIO,
            'max'     => 12,
            'min'     => 12,
            'choices' => ['USER', 'VETERAN', 'JUNIOR SYSOP', 'SYSOP',],
            'default' => 'USER',
        },
        'baud_rate' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['FULL', '19200', '9600', '4800', '2400', '1200', '600', '300',],
            'default' => 'FULL',
        },
        'login_time' => {
            'type' => STRING,
            'max'  => 10,
            'min'  => 10,
        },
        'logout_time' => {
            'type' => STRING,
            'max'  => 10,
            'min'  => 10,
        },
        'text_mode' => {
            'type'    => RADIO,
            'max'     => 7,
            'min'     => 9,
            'choices' => ['ANSI', 'ASCII', 'ATASCII', 'PETSCII',],
            'default' => 'ASCII',
        },
        'max_rows' => {
            'type'    => NUMERIC,
            'max'     => 3,
            'min'     => 3,
            'default' => 25,
        },
        'max_columns' => {
            'type'    => NUMERIC,
            'max'     => 3,
            'min'     => 3,
            'default' => 80,
        },
        'timeout' => {
            'type'    => NUMERIC,
            'max'     => 5,
            'min'     => 5,
            'default' => 10,
        },
        'retro_systems' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 40,
        },
        'accomplishments' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 40,
        },
        'prefer_nickname' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'view_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'YES',
        },
        'banned' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'upload_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'download_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'remove_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'read_message' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'YES',
        },
        'post_message' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'remove_message' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'play_fortunes' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'YES',
        },
        'sysop' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'page_sysop' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'password' => {
            'type' => STRING,
            'max'  => 64,
            'min'  => 32,
        },
    };
    $self->{'debug'}->DEBUG(['End SysOp Initialize']);
    return ($self);
} ## end sub sysop_initialize

sub sysop_list_commands {
    my $self = shift;
    my $mode = shift;

    $self->{'debug'}->DEBUG(['Start SysOp List Commands']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $size   = ($hsize - ($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')));
    my $srow   = $size - 5;
    my @sys    = (sort(keys %{$main::SYSOP_COMMANDS}));
    my @stkn   = (sort(keys %{ $self->{'sysop_tokens'} }));
    my @usr    = (sort(keys %{ $self->{'COMMANDS'} }));
    my @tkn    = (sort(keys %{ $self->{'TOKENS'} }));
    my @anstkn = grep(!/CSI|COLOR|GRAY|RGB|FONT|HORIZONTAL RULE/, (keys %{ $self->{'ansi_sequences'} }));
    @anstkn = sort(@anstkn);
    foreach my $count (16 .. 231) {
        push(@anstkn, 'COLOR ' . $count);
    }
    foreach my $count (0 .. 24) {
        push(@anstkn, 'GRAY ' . $count);
    }
    foreach my $count (16 .. 231) {
        push(@anstkn, 'B_COLOR ' . $count);
    }
    foreach my $count (0 .. 24) {
        push(@anstkn, 'B_GRAY ' . $count);
    }
    my @atatkn = (sort(keys %{ $self->{'atascii_sequences'} },'HORIZONTAL RULE'));
    my @pettkn = (sort(keys %{ $self->{'petscii_sequences'} },'HORIZONTAL RULE color'));
    my @asctkn = (sort(keys %{ $self->{'ascii_sequences'} },'HORIZONTAL RULE'));
    my $x      = 1;
    my $xt     = 1;
    my $y      = 1;
    my $z      = 1;
    my $ans    = 31;
    my $ata    = 1;
    my $pet    = 1;
    my $asc    = 12;
    my $text   = '';
    {
        my $cell;
        foreach $cell (@sys) {
            $x = max(length($cell), $x);
        }
        foreach $cell (@stkn) {
            $xt = max(length($cell), $xt);
        }
        foreach $cell (@usr) {
            $y = max(length($cell), $y);
        }
        foreach $cell (@tkn) {
            $z = max(length($cell), $z);
        }
        foreach $cell (@anstkn) {
            $ans = max(length($cell), $ans);
        }
        foreach $cell (@atatkn) {
            $ata = max(length($cell), $ata);
        }
        foreach $cell (@pettkn) {
            $pet = max(length($cell), $pet);
        }
        foreach $cell (@asctkn) {
            $asc = max(length($cell), $asc);
        }
    }
    if ($mode eq 'ASCII') {
        my $table = Text::SimpleTable->new($asc,25);
        $table->row('ASCII TOKENS','DESCRIPTION');
        $table->hr();
        my $ascii_tokens;
        while (scalar(@asctkn)) {
            $ascii_tokens = shift(@asctkn);
            $table->row($ascii_tokens, $self->{'ascii_meta'}->{$ascii_tokens}->{'desc'});
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'ANSI') {
        my $crgb = (exists($ENV{'COLORTERM'}) && $ENV{'COLORTERM'} eq 'truecolor') ? TRUE : FALSE;
        my $c256 = (exists($ENV{'TERM'}) && $ENV{'TERM'} =~ /256/) ? TRUE : FALSE;
        my $table = Text::SimpleTable->new(25, $ans, 55);
        $table->row('TYPE', 'ANSI TOKENS', 'DESCRIPTION');
        foreach my $code ('special', 'clear', 'cursor', 'attributes', 'foreground ANSI 16', 'foreground ANSI 256', 'foreground ANSI TrueColor', 'background ANSI 16', 'background ANSI 256', 'background ANSI TrueColor') {
            $table->hr();
            if ($code =~ /^foreground/) {
                my $ncode = 'foreground';
                foreach my $name (@anstkn, 'RGB 0,0,0 - RGB 255,255,255') {
                    next unless (exists($self->{'ansi_meta'}->{$ncode}->{$name}));
                    if ($name eq 'RGB 0,0,0 - RGB 255,255,255' && $code =~ /TrueColor/ && $crgb) {
                        $table->row(ucfirst($code), $name, '24 Bit Color in Red,Green,Blue order');
                    } else {
                        if ($self->{'ansi_meta'}->{$ncode}->{$name}->{'out'} =~ /^\e\[\d+;\d;\d+m/ && $code =~ /256/ && $c256) {
                            $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$ncode}->{$name}->{'desc'});
                        } elsif ($self->{'ansi_meta'}->{$ncode}->{$name}->{'out'} =~ /^\e\[\d+:\d:\d+:\d+:\d+m/ && $code =~ /TrueColor/ && $crgb) {
                            $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$ncode}->{$name}->{'desc'});
                        } elsif($self->{'ansi_meta'}->{$ncode}->{$name}->{'out'} =~ /^\e\[\d+m/ && $code =~ /16/) {
                            $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$ncode}->{$name}->{'desc'});
                        }
                    }
                }
            } elsif ($code =~ /^background/) {
                my $ncode = 'background';
                foreach my $name (@anstkn, 'B_RGB 0,0,0 - RGB 255,255,255') {
                    next unless (exists($self->{'ansi_meta'}->{$ncode}->{$name}));
                    if ($name eq 'B_RGB 0,0,0 - B_RGB 255,255,255' && $code =~ /TrueColor/ && $crgb) {
                        $table->row(ucfirst($code), $name, '24 Bit Color in Red,Green,Blue order');
                    } else {
                        if ($self->{'ansi_meta'}->{$ncode}->{$name}->{'out'} =~ /^\e\[\d+;\d;\d+m/ && $code =~ /256/ && $c256) {
                            $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$ncode}->{$name}->{'desc'});
                        } elsif ($self->{'ansi_meta'}->{$ncode}->{$name}->{'out'} =~ /^\e\[\d+:\d:\d+:\d+:\d+m/ && $code =~ /TrueColor/ && $crgb) {
                            $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$ncode}->{$name}->{'desc'});
                        } elsif($self->{'ansi_meta'}->{$ncode}->{$name}->{'out'} =~ /^\e\[\d+m/ && $code =~ /16/) {
                            $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$ncode}->{$name}->{'desc'});
                        }
                    }
                }
            } elsif ($code eq 'cursor') {
                foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}}, 'LOCATE column,row')) {
                    if ($name eq 'LOCATE column,row') {
                        $table->row(ucfirst($code), $name, 'Position the Cursor at Column,Row');
                    } else {
                        $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
                    }
                }
            } elsif ($code eq 'special') {
                foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}}, 'FONT 0 - FONT 9', 'HORIZONTAL RULE color')) {
                    if ($name eq 'FONT 0 - FONT 9') {
                        $table->row(ucfirst($code), $name, 'Set the Specified Console Font');
                    } elsif ($name eq 'HORIZONTAL RULE color') {
                        $table->row(ucfirst($code), $name, 'A Horizontal Rule (Screen Width) in The Specified Color');
                    } else {
                        $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
                    }
                }
            } else {
                foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}})) {
                    $table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
                }
            }
        }
        $text = $self->center($table->boxes->draw(), $wsize);
		foreach my $code (qw(foreground background)) {
			foreach my $name (keys %{ $self->{'ansi_meta'}->{$code} }) {
				if ($name =~ /B_WHITE|B_BRIGHT|B_CYAN|B_GREEN|B_RED|B_YELLOW|B_ORANGE|B_PINK|B_COLOR \d\d+|B_GRAY \d\d|B_[A-B]|B_C(OL|OF|OP|OR|A|E|G|H|I|R)|B_D(A|E)|B_(E|F|G|H|I|J|K|L|M|O|P|R|SA|SE|T|SH|SK|SP|ST|SU|U|V|W)/) {
					$text =~ s/│(\s$name\s+)│/│\[\% BLACK \%\]\[\% $name \%\]$1\[\% RESET \%\]│/;
				} else {
					$text =~ s/│(\s$name\s+)│/│\[\% $name \%\]$1\[\% RESET \%\]│/;
				}
			}
		}
    } elsif ($mode eq 'ATASCII') {
        my $table = Text::SimpleTable->new(1,$ata,25);
        $table->row('C','ATASCII TOKENS','DESCRIPTION');
        $table->hr();
        my $atascii_tokens;
        while (scalar(@atatkn)) {
            $atascii_tokens = shift(@atatkn);
            $table->row($self->{'atascii_meta'}->{$atascii_tokens}->{'unicode'}, $atascii_tokens, $self->{'atascii_meta'}->{$atascii_tokens}->{'desc'});
			$table->hr() if (scalar(@atatkn));
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'PETSCII') {
        my $table = Text::SimpleTable->new(1,$pet,28);
        $table->row('C','PETSCII TOKENS','DESCRIPTION');
        $table->hr();
        my $petscii_tokens;
        while (scalar(@pettkn)) {
            $petscii_tokens = shift(@pettkn);
            $table->row($self->{'petscii_meta'}->{$petscii_tokens}->{'unicode'}, $petscii_tokens, $self->{'petscii_meta'}->{$petscii_tokens}->{'desc'});
			$table->hr() if (scalar(@pettkn));
		}
        $text = $self->center($table->boxes->draw(), $wsize);
		$text =~ s/│ (WHITE)/│ \[\% BRIGHT WHITE \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (YELLOW)/│ \[\% YELLOW \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (CYAN)/│ \[\% CYAN \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (GREEN)/│ \[\% GREEN \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (PINK)/│ \[\% PINK \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (BLUE)/│ \[\% BLUE \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (RED)/│ \[\% RED \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (PURPLE)/│ \[\% COLOR 127 \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (DARK PURPLE)/│ \[\% COLOR 53 \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (GRAY)/│ \[\% GRAY 9 \%\]$1\[\% RESET \%\]/g;
		$text =~ s/│ (BROWN)/│ \[\% COLOR 94 \%\]$1\[\% RESET \%\]/g;
    } elsif ($mode eq 'USER') {
        my $table = Text::SimpleTable->new($y, $z);
        $table->row('USER MENU COMMANDS', 'USER TOKENS');
        $table->hr();
        my ($user_names, $token_names);
        my $count = 0; # Try to follow the scroll logic
        while (scalar(@usr) || scalar(@tkn)) {
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
            $table->row($user_names, $token_names);
            $count++;
            if ($count > $srow) {
                $count = 0;
                $table->hr();
                $table->row('USER MENU COMMANDS', 'USER TOKENS');
                $table->hr();
            }
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'SYSOP') {
        my $table = Text::SimpleTable->new($x, $xt);
        $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS');
        $table->hr();
        my ($sysop_names, $sysop_tokens);
        my $count = 0; # Try to follow the scroll logic
        while (scalar(@sys) || scalar(@stkn)) {
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
            $table->row($sysop_names, $sysop_tokens);
            $count++;
            if ($count > $srow) {
                $count = 0;
                $table->hr();
                $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS');
                $table->hr();
            }
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } else {
        my $table = Text::SimpleTable->new($x, $xt, $y, $z, $ans, $ata, $pet, $asc);
        $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS', 'USER MENU COMMANDS', 'USER TOKENS', 'ANSI TOKENS', 'ATASCII TOKENS', 'PETSCII TOKENS', 'ASCII TOKENS');
        $table->hr();
        my ($sysop_names, $sysop_tokens, $user_names, $token_names, $ansi_tokens, $atascii_tokens, $petscii_tokens, $ascii_tokens);
        my $count = 0; # Try to follow the scroll logic
        while (scalar(@sys) || scalar(@stkn) || scalar(@usr) || scalar(@tkn) || scalar(@anstkn) || scalar(@atatkn) || scalar(@pettkn) || scalar(@asctkn)) {
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
            if (scalar(@anstkn)) {
                $ansi_tokens = shift(@anstkn);
            } else {
                $ansi_tokens = ' ';
            }
            if (scalar(@atatkn)) {
                $atascii_tokens = shift(@atatkn);
            } else {
                $atascii_tokens = ' ';
            }
            if (scalar(@pettkn)) {
                $petscii_tokens = shift(@pettkn);
            } else {
                $petscii_tokens = ' ';
            }
            if (scalar(@asctkn)) {
                $ascii_tokens = shift(@asctkn);
            } else {
                $ascii_tokens = ' ';
            }
            $table->row($sysop_names, $sysop_tokens, $user_names, $token_names, $ansi_tokens, $atascii_tokens, $petscii_tokens, $ascii_tokens);
            $count++;
            if ($count > $srow) {
                $count = 0;
                $table->hr();
                $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS', 'USER MENU COMMANDS', 'USER TOKENS', 'ANSI TOKENS', 'ATASCII TOKENS', 'PETSCII TOKENS', 'ASCII TOKENS');
                $table->hr();
            }
        } ## end while (scalar(@sys) || scalar...)
        $text = $self->center($table->boxes->draw(), $wsize);
		foreach my $code (qw(foreground background)) {
			foreach my $name (keys %{ $self->{'ansi_meta'}->{$code} }) {
				if ($name =~ /B_WHITE|B_BRIGHT|B_CYAN|B_GREEN|B_RED|B_YELLOW|B_ORANGE|B_PINK|B_COLOR \d\d+|B_GRAY \d\d|B_[A-B]|B_C(OL|OF|OP|OR|A|E|G|H|I|R)|B_D(A|E)|B_(E|F|G|H|I|J|K|L|M|O|P|R|SA|SE|T|SH|SK|SP|ST|SU|U|V|W)/) {
					$text =~ s/│(\s$name\s+)│/│\[\% BLACK \%\]\[\% $name \%\]$1\[\% RESET \%\]│/;
				} else {
					$text =~ s/│(\s$name\s+)│/│\[\% $name \%\]$1\[\% RESET \%\]│/;
				}
			}
		}
		$text = $self->sysop_color_border($text, 'ORANGE','DOUBLE');
    }
    # This monstrosity fixes up the pre-rendered table to add all of the colors and special characters for friendly output
    $text =~ s/( C |DESCRIPTION|TYPE|SYSOP MENU COMMANDS|SYSOP TOKENS|USER MENU COMMANDS|USER TOKENS|ANSI TOKENS|ATASCII TOKENS|PETSCII TOKENS|ASCII TOKENS)/\[\% BRIGHT YELLOW \%\]$1\[\% RESET \%\]/g;
    $self->{'debug'}->DEBUG(['End SysOp List Commands']);
    return ($self->ansi_decode($text));
} ## end sub sysop_list_commands

sub sysop_online_count {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Online Count']);
    my $count = $self->{'CACHE'}->get('ONLINE');
    $self->{'debug'}->DEBUG(["  SysOp Online Count $count", 'End SysOp Online Count']);
    return ($count);
} ## end sub sysop_online_count

sub sysop_versions_format {
    my $self     = shift;
    my $sections = shift;
    my $bbs_only = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Versions Format']);
    my $versions = "\n";
    my $heading  = ''; #  = "\t";
    my $counter  = $sections;

    for (my $count = $sections - 1; $count > 0; $count--) {
        $heading .= ' NAME                         VERSION ';
        if ($count) {
            $heading .= "\t";
        } else {
            $heading .= "\n";
        }
    } ## end for (my $count = $sections...)
    $heading = '[% BRIGHT YELLOW %][% B_RED %]' .  $heading . '[% RESET %]';
    foreach my $v (sort(keys %{ $self->{'VERSIONS'} })) {
        next if ($bbs_only && $v !~ /^BBS/);
        $versions .= sprintf(' %-28s  %.03f', $v, $self->{'VERSIONS'}->{$v});
        $counter--;
        if ($counter <= 1) {
            $counter = $sections;
            $versions .= "\n";
        } else {
            $versions .= "\t";
        }
    } ## end foreach my $v (keys %{ $self...})
    chop($versions) if (substr($versions, -1, 1) eq "\t");
    $self->{'debug'}->DEBUG(['End SysOp Versions Format']);
    return ($heading . $versions . "\n");
} ## end sub sysop_versions_format

sub sysop_disk_free {    # Show the Disk Free portion of Statistics
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Disk Free']);
    my $diskfree = '';
    if ((-e '/usr/bin/duf' || -e '/usr/local/bin/duf') && $self->configuration('USE DUF') eq 'TRUE') {
        my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
        $diskfree = "\n" . `duf -theme ansi -width $wsize`;
    } else {
        my @free  = split(/\n/, `nice df -h -T`);    # Get human readable disk free showing type
        my $width = 1;
        foreach my $l (@free) {
            $width = max(length($l), $width);        # find the width of the widest line
        }
        foreach my $line (@free) {
            next if ($line =~ /tmp|boot/);
            if ($line =~ /^Filesystem/) {
                $diskfree .= '[% B_BLUE %][% BRIGHT YELLOW %]' . " $line " . ' ' x ($width - length($line)) . "[% RESET %]\n";    # Make the heading the right width
            } else {
                $diskfree .= " $line\n";
            }
        } ## end foreach my $line (@free)
    } ## end else [ if ((-e '/usr/bin/duf'...))]
    $self->{'debug'}->DEBUG(['End SysOp Disk Free']);
    return ($diskfree);
} ## end sub sysop_disk_free

sub sysop_load_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Load Menu', "  SysOp Load Menu $file"]);
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
            } else {
                $mode = 0;
            }
        } else {
            $mapping->{'TEXT'} .= $self->sysop_detokenize($line) . "\n";
        }
    } ## end while (chomp(my $line = <$FILE>...))
    close($FILE);
    $self->{'debug'}->DEBUG(['End SysOp Load Menu']);
    return ($mapping);
} ## end sub sysop_load_menu

sub sysop_pager {
    my $self   = shift;
    my $text   = shift;
    my $offset = (scalar(@_)) ? shift : 0;

    $self->{'debug'}->DEBUG(['Start SysOp Pager']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my @lines;
    @lines  = split(/\n$/, $text);
    my $size   = ($hsize - ($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')));
    $size  -= $offset;
    my $scroll = TRUE;
    my $count = 1;
    while (scalar(@lines)) {
        my $line = shift(@lines);
        $self->ansi_output("$line\n");
        $count++;
        if ($count >= $size) {
            $count = 1;
            $scroll = $self->sysop_scroll();
            last unless ($scroll);
        }
    } ## end foreach my $line (@lines)
    $self->{'debug'}->DEBUG(['End SysOp Pager']);
    return ($scroll);
} ## end sub sysop_pager

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Parse Menu', "  SysOp Parse Menu $file"]);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown;
    my $scroll = $self->sysop_pager($mapping->{'TEXT'}, 3);
    my $keys   = '';
    print "\r", cldown unless ($scroll);
    $self->sysop_show_choices($mapping);
    $self->sysop_prompt('Choose');
    my $key;
    do {
        $key = uc($self->sysop_keypress());
    } until (exists($mapping->{$key}));
    print $mapping->{$key}->{'command'}, "\n";
    $self->{'debug'}->DEBUG(['End SysOp Parse Menu']);
    return ($mapping->{$key}->{'command'});
} ## end sub sysop_parse_menu

sub sysop_decision {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Decision']);
    my $response;
    do {
        $response = uc($self->sysop_keypress());
    } until ($response =~ /Y|N/i || $response eq chr(13));
    if ($response eq 'Y') {
        print "YES\n";
        $self->{'debug'}->DEBUG(['  SysOp Decision YES']);
        $self->{'debug'}->DEBUG(['End SysOp Decision']);
        return (TRUE);
    }
    $self->{'debug'}->DEBUG(['  SysOp Decision NO']);
    print "NO\n";
    $self->{'debug'}->DEBUG(['End SysOp Decision']);
    return (FALSE);
} ## end sub sysop_decision

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
} ## end sub sysop_keypress

sub sysop_ip_address {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp IP Address']);
    chomp(my $ip = `nice hostname -I`);
    $self->{'debug'}->DEBUG(["  SysOp IP Address:  $ip",'End SysOp IP Address']);
    return ($ip);
} ## end sub sysop_ip_address

sub sysop_hostname {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Hostname']);
    chomp(my $hostname = `nice hostname`);
    $self->{'debug'}->DEBUG(["  SysOp Hostname:  $hostname",'End SysOp Hostname']);
    return ($hostname);
} ## end sub sysop_hostname

sub sysop_locate_middle {
    my $self  = shift;
    my $color = (scalar(@_)) ? shift : 'B_WHITE';

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $middle = int($wsize / 2);
    my $string = "\r" . $self->{'ansi_sequences'}->{'RIGHT'} x $middle . $self->{'ansi_sequences'}->{$color} . ' ' . $self->{'ansi_sequences'}->{'RESET'};
    return ($string);
} ## end sub sysop_locate_middle

sub sysop_memory {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Memory']);
    my $memory = `nice free`;
    my @mem    = split(/\n$/, $memory);
    my $output = '[% BLACK %][% B_GREEN %]  ' . shift(@mem) . ' [% RESET %]' . "\n";
    while (scalar(@mem)) {
        $output .= shift(@mem) . "\n";
    }
    if ($output =~ /(Mem\:       )/) {
        my $ch = '[% BLACK %][% B_GREEN %] ' . $1 . ' [% RESET %]';
        $output =~ s/Mem\:       /$ch/;
    }
    if ($output =~ /(Swap\:      )/) {
        my $ch = '[% BLACK %][% B_GREEN %] ' . $1 . ' [% RESET %]';
        $output =~ s/Swap\:      /$ch/;
    }
    $self->{'debug'}->DEBUG(['End SysOp Memory']);
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

    $self->{'debug'}->DEBUG(['Start SysOp List Users']);
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
        $sql   = q{ SELECT * FROM users_view };
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
            } ## end foreach my $name (@order)
        } ## end while (my $row = $sth->fetchrow_hashref...)
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
            } ## end foreach my $name (@order)
        } ## end while (my $Row = $sth->fetchrow_hashref...)
        $sth->finish();
        my $string = $table->boxes->draw();
        my $ch     = colored(['bright_yellow'], 'NAME');
        $string =~ s/ NAME / $ch /;
        $ch = colored(['bright_yellow'], 'VALUE');
        $string =~ s/ VALUE / $ch /;
        $string = $self->sysop_color_border($string, 'CYAN', 'HEAVY');
        $self->sysop_pager("$string\n");
    } else {    # Horizontal
        my @hw;
        foreach my $name (@order) {
            push(@hw, $self->{'SYSOP FIELD TYPES'}->{$name}->{'min'});
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
        my $string = $table->boxes->draw();
        $string = $self->sysop_color_border($string, 'CYAN', 'HEAVY');
        $self->sysop_pager("$string\n");
    } ## end else [ if ($list_mode =~ /VERTICAL/)]
    print 'Press a key to continue ... ';
    $self->{'debug'}->DEBUG(['End SysOp List Users']);
    return ($self->sysop_keypress(TRUE));
} ## end sub sysop_list_users

sub sysop_delete_files {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Delete Files']);
    $self->{'debug'}->DEBUG(['End SysOp Delete Files']);
    return (TRUE);
} ## end sub sysop_delete_files

sub sysop_list_files {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp List Files']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $sizes = {};
    while (my $row = $sth->fetchrow_hashref()) {
        foreach my $name (keys %{$row}) {
            if ($name eq 'file_size') {
                my $size = format_number($row->{$name});
                $sizes->{$name} = max(length($size), $sizes->{$name});
            } else {
                $sizes->{$name} = max(length("$row->{$name}"), $sizes->{$name});
            }
        } ## end foreach my $name (keys %{$row...})
    } ## end while (my $row = $sth->fetchrow_hashref...)
    $sth->finish();
    my $table;
    if ($wsize > 150) {
        $table = Text::SimpleTable->new(max(5, $sizes->{'title'}), max(8, $sizes->{'filename'}), max(4, $sizes->{'type'}), max(11, $sizes->{'description'}), max(8, $sizes->{'username'}), max(4, $sizes->{'file_size'}), max(6, $sizes->{'uploaded'}), max(9, $sizes->{'thumbs_up'}), max(11, $sizes->{'thumbs_down'}));
        $table->row('TITLE', 'FILENAME', 'TYPE', 'DESCRIPTION', 'UPLOADER', 'SIZE', 'UPLOADED', 'THUMBS UP', 'THUMBS DOWN');
    } else {
        $table = Text::SimpleTable->new(max(5, $sizes->{'filename'}), max(8, $sizes->{'title'}), max(4, $sizes->{'extension'}), max(11, $sizes->{'description'}), max(8, $sizes->{'username'}), max(4, $sizes->{'file_size'}), max(9, $sizes->{'thumbs_up'}), max(11, $sizes->{'thumbs_down'}));
        $table->row('TITLE', 'FILENAME', 'TYPE', 'DESCRIPTION', 'UPLOADER', 'SIZE', 'THUMBS UP', 'THUMBS DOWN');
    }
    $table->hr();
    $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $category;

    while (my $row = $sth->fetchrow_hashref()) {
        if ($wsize > 150) {
            $table->row($row->{'title'}, $row->{'filename'}, $row->{'type'}, $row->{'description'}, $row->{'username'}, format_number($row->{'file_size'}), $row->{'uploaded'}, sprintf('%-06u',$row->{'thumbs_up'}), sprintf('%-06u',$row->{'thumbs_down'}));
        } else {
            $table->row($row->{'title'}, $row->{'filename'}, $row->{'extension'}, $row->{'description'}, $row->{'username'}, format_number($row->{'file_size'}), sprintf('%-06u',$row->{'thumbs_up'}), sprintf('%-06u',$row->{'thumbs_down'}));
        }
        $category = $row->{'category'};
    } ## end while (my $row = $sth->fetchrow_hashref...)
    $sth->finish();
    $self->sysop_output("\n" . '[% B_ORANGE %][% BLACK %] Current Category [% RESET %] [% BRIGHT YELLOW %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% BRIGHT WHITE %][% FILE CATEGORY %][% RESET %]');
    my $tbl = $table->boxes->draw();
    $tbl = $self->sysop_color_border($tbl, 'YELLOW', 'DOUBLE');
    while ($tbl =~ / (TITLE|FILENAME|TYPE|DESCRIPTION|UPLOADER|SIZE|UPLOADED) /) {
        my $ch = $1;
        my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
        $tbl =~ s/ $ch / $new /gs;
    }
    $self->sysop_output("\n$tbl\nPress a Key To Continue ...");
    $self->sysop_keypress();
    print " BACK\n";
    $self->{'debug'}->DEBUG(['End SysOp List Files']);
    return (TRUE);
} ## end sub sysop_list_files

sub sysop_color_border {
    my $self  = shift;
    my $tbl   = shift;
    my $color = shift;
    my $type  = shift; # ROUNDED, DOUBLE, HEAVY, DEFAULT

    $self->{'debug'}->DEBUG(['Start SysOp Color Border']);
    $color = '[% ' . $color . ' %]';
    my $new;
    if ($tbl =~ /(─)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/─/\[\% BOX DRAWINGS DOUBLE HORIZONTAL \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/─/\[\% BOX DRAWINGS HEAVY HORIZONTAL \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(│)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/│/\[\% BOX DRAWINGS DOUBLE VERTICAL \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/│/\[\% BOX DRAWINGS HEAVY VERTICAL \%\]/gs;
        }
        $new = '[% RESET %]' . $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┌)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'ROUNDED') {
            $new =~ s/┌/\[\% BOX DRAWINGS LIGHT ARC DOWN AND RIGHT \%\]/gs;
        } elsif ($type eq 'DOUBLE') {
            $new =~ s/┌/\[\% BOX DRAWINGS DOUBLE DOWN AND RIGHT \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┌/\[\% BOX DRAWINGS HEAVY DOWN AND RIGHT \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(└)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'ROUNDED') {
            $new =~ s/└/\[\% BOX DRAWINGS LIGHT ARC UP AND RIGHT \%\]/gs;
        } elsif ($type eq 'DOUBLE') {
            $new =~ s/└/\[\% BOX DRAWINGS DOUBLE UP AND RIGHT \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/└/\[\% BOX DRAWINGS HEAVY UP AND RIGHT \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┬)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/┬/\[\% BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┬/\[\% BOX DRAWINGS HEAVY DOWN AND HORIZONTAL \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┐)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'ROUNDED') {
            $new =~ s/┐/\[\% BOX DRAWINGS LIGHT ARC DOWN AND LEFT \%\]/gs;
        } elsif ($type eq 'DOUBLE') {
            $new =~ s/┐/\[\% BOX DRAWINGS DOUBLE DOWN AND LEFT \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┐/\[\% BOX DRAWINGS HEAVY DOWN AND LEFT \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(├)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/├/\[\% BOX DRAWINGS DOUBLE VERTICAL AND RIGHT \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/├/\[\% BOX DRAWINGS HEAVY VERTICAL AND RIGHT \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┘)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'ROUNDED') {
            $new =~ s/┘/\[\% BOX DRAWINGS LIGHT ARC UP AND LEFT \%\]/gs;
        } elsif ($type eq 'DOUBLE') {
            $new =~ s/┘/\[\% BOX DRAWINGS DOUBLE UP AND LEFT \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┘/\[\% BOX DRAWINGS HEAVY UP AND LEFT \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┼)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/┼/\[\% BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┼/\[\% BOX DRAWINGS HEAVY VERTICAL AND HORIZONTAL \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┤)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/┤/\[\% BOX DRAWINGS DOUBLE VERTICAL AND LEFT \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┤/\[\% BOX DRAWINGS HEAVY VERTICAL AND LEFT \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┴)/) {
        my $ch = $1;
        $new = $ch;
        if ($type eq 'DOUBLE') {
            $new =~ s/┴/\[\% BOX DRAWINGS DOUBLE UP AND HORIZONTAL \%\]/gs;
        } elsif ($type eq 'HEAVY') {
            $new =~ s/┴/\[\% BOX DRAWINGS HEAVY UP AND HORIZONTAL \%\]/gs;
        }
        $new = $color . $new . '[% RESET %]';
        $tbl =~ s/$ch/$new/gs;
    }
    $self->{'debug'}->DEBUG(['End SysOp Color Border']);
    return($tbl);
}

sub sysop_select_file_category {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Select File Category']);
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
    my $text = $table->boxes->draw();
    while ($text =~ / (ID|TITLE|DESCRIPTION) /) {
        my $ch = $1;
        my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
        $text =~ s/ $ch / $new /gs;
    }
    $self->sysop_output($self->sysop_color_border($text,'MAGENTA', 'DOUBLE') . "\n");
    $self->sysop_prompt('Choose ID (< = Nevermind)');
    my $line;
    do {
        $line = uc($self->sysop_get_line(ECHO, 3, ''));
    } until ($line =~ /^(\d+|\<)/i);
    my $response = FALSE;
    if ($line >= 1 && $line <= $max_id) {
        $sth = $self->{'dbh'}->prepare('UPDATE users SET file_category=? WHERE id=1');
        $sth->execute($line);
        $sth->finish();
        $self->{'USER'}->{'file_category'} = $line + 0;
        $response = TRUE;
    }
    $self->{'debug'}->DEBUG(['End SysOp Select File Category']);
    return ($response);
} ## end sub sysop_select_file_category

sub sysop_edit_file_categories {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Edit File Categories']);
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
    $sth->execute();
    my $table = Text::SimpleTable->new(3, 30, 50);
    $table->row('ID', 'TITLE', 'DESCRIPTION');
    $table->hr();
    while (my $row = $sth->fetchrow_hashref()) {
        $table->row($row->{'id'}, $row->{'title'}, $row->{'description'});
    }
    $sth->finish();
    my $text = $table->boxes->draw();
    while ($text =~ / (ID|TITLE|DESCRIPTION) /) {
        my $ch = $1;
        my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
        $text =~ s/ $ch / $new /gs;
    }
    $self->sysop_output($text . "\n");
    $self->sysop_prompt('Choose ID (A = Add, < = Nevermind)');
    my $line;
    do {
        $line = uc($self->sysop_get_line(ECHO, 3, ''));
    } until ($line =~ /^(\d+|A|\<)/i);
    if ($line eq 'A') {    # Add
        $self->{'debug'}->DEBUG(['  SysOp Edit File Categories Add']);
        print "\nADD NEW FILE CATEGORY\n";
        $table = Text::SimpleTable->new(11, 80);
        $table->row('TITLE',       "\n" . charnames::string_vianame('OVERLINE') x 80);
        $table->row('DESCRIPTION', "\n" . charnames::string_vianame('OVERLINE') x 80);
        my $text = $table->boxes->draw();
        while ($text =~ / (TITLE|DESCRIPTION) /) {
            my $ch = $1;
            my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
            $text =~ s/ $ch / $new /gs;
        }
        $self->sysop_output("\n" . $self->sysop_color_border($text, 'MAGENTA', 'DOUBLE'));
        print $self->{'ansi_sequences'}->{'UP'} x 5, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
        my $title = $self->sysop_get_line(ECHO, 80, '');
        if ($title ne '') {
            print "\r", $self->{'ansi_sequences'}->{'DOWN'}, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
            my $description = $self->sysop_get_line(ECHO, 80, '');
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
        $self->{'debug'}->DEBUG(['  SysOp Edit File Categories Edit']);
    }
    $self->{'debug'}->DEBUG(['Start SysOp Edit File Categories']);
    return (TRUE);
} ## end sub sysop_edit_file_categories

sub sysop_vertical_heading {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Vertical Heading']);
    my $heading = '';
    for (my $count = 0; $count < length($text); $count++) {
        $heading .= substr($text, $count, 1) . "\n";
    }
    $self->{'debug'}->DEBUG(['End SysOp Vertical Heading']);
    return ($heading);
} ## end sub sysop_vertical_heading

sub sysop_view_configuration {
    my $self = shift;
    my $view = shift;

    $self->{'debug'}->DEBUG(['Start SysOp View Configuration']);

    # Get maximum widths
    my $name_width  = 6;
    my $value_width = 60;
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
    } ## end foreach my $conf (sort(keys...))
    if ($view) {
        $table->hr();
        $table->row('CONFIG NAME', 'CONFIG VALUE');
    } else {
        $table->row('CHOICE', 'CONFIG NAME', 'CONFIG VALUE');
    }
    $table->hr();
    my $count = 0;
    foreach my $conf (sort(keys %{ $self->{'CONF'} })) {
        my $choice = ($count >= 10) ? chr(55 + $count) : $count;
        next if ($conf eq 'STATIC');
        my $c = $self->{'CONF'}->{$conf};
        if ($conf eq 'DEFAULT TIMEOUT') {
            $c .= ' Minutes';
        } elsif ($conf eq 'DEFAULT BAUD RATE') {
            $c .= ' bps - 300, 600, 1200, 2400, 4800, 9600, 19200, FULL';
        } elsif ($conf eq 'THREAD MULTIPLIER') {
            $c .= ' x CPU Cores';
        } elsif ($conf eq 'DEFAULT TEXT MODE') {
            $c .= ' - ANSI, ASCII, ATASCII, PETSCII';
        }
        if ($view) {
            $table->row($conf, $c);
        } else {
            if ($conf =~ /AUTHOR/) {
                $table->row(' ', $conf, $c);
            } else {
                $table->row($choice, $conf, $c);
                $count++;
            }
        } ## end else [ if ($view) ]
    } ## end foreach my $conf (sort(keys...))
    my $output = $table->boxes->draw();
    foreach my $change ('AUTHOR EMAIL', 'AUTHOR LOCATION', 'AUTHOR NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME', '300, 600, 1200, 2400, 4800, 9600, 19200, FULL', '%d = day, %m = Month, %Y = Year', 'ANSI, ASCII, ATASCII, PETSCII', 'ANSI, ASCII, ATAASCII,PETSCII') {
        if ($output =~ /$change/) {
            my $ch;
            if (/^(AUTHOR|DATABASE)/) {
                $ch = '[% YELLOW %]' . $change . '[% RESET %]';
            } else {
                $ch = '[% GRAY 11 %]' . $change . '[% RESET %]';
            }
            $output =~ s/$change/$ch/gs;
        }
    } ## end foreach my $change ('AUTHOR EMAIL'...)
    {
        my $ch = colored(['cyan'], 'CHOICE');
        $output =~ s/CHOICE/$ch/gs;
        $ch = colored(['bright_yellow'], 'STATIC NAME');
        $output =~ s/STATIC NAME/$ch/gs;
        $ch = colored(['green'], 'CONFIG NAME');
        $output =~ s/CONFIG NAME/$ch/gs;
        $ch = colored(['cyan'], 'CONFIG VALUE');
        $output =~ s/CONFIG VALUE/$ch/gs;
        $output = $self->sysop_color_border($output, 'RED', 'HEAVY');
    }
    my $response;
    if ("$view" eq 'string') {
        $response = $output;
    } elsif ($view == TRUE) {
        print $self->sysop_detokenize($output);
        print 'Press a key to continue ... ';
        $response = $self->sysop_keypress(TRUE);
    } elsif ($view == FALSE) {
        print $self->sysop_detokenize($output);
        print $self->sysop_menu_choice('TOP',    '',    '');
        print $self->sysop_menu_choice('Z',      'RED', 'Return to Settings Menu');
        print $self->sysop_menu_choice('BOTTOM', '',    '');
        $self->sysop_prompt('Choose');
        $response = TRUE;
    } ## end elsif ($view == FALSE)
    $self->{'debug'}->DEBUG(['End SysOp View Configuration']);
    return($response);
} ## end sub sysop_view_configuration

sub sysop_edit_configuration {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Edit Configuration']);
    $self->sysop_view_configuration(FALSE);
    my $types = {
        'BBS NAME' => {
            'max'  => 50,
            'type' => STRING,
        },
        'BBS ROOT' => {
            'max'  => 60,
            'type' => STRING,
        },
        'HOST' => {
            'max'  => 20,
            'type' => HOST,
        },
        'THREAD MULTIPLIER' => {
            'max'  => 2,
            'type' => NUMERIC,
        },
        'PORT' => {
            'max'  => 5,
            'type' => NUMERIC,
        },
        'DEFAULT BAUD RATE' => {
            'max'     => 5,
            'type'    => RADIO,
            'choices' => ['300', '600', '1200', '2400', '4800', '9600', '19200', 'FULL'],
        },
        'DEFAULT TEXT MODE' => {
            'max'     => 7,
            'type'    => RADIO,
            'choices' => ['ANSI', 'ASCII', 'ATASCII', 'PETSCII'],
        },
        'DEFAULT TIMEOUT' => {
            'max'  => 3,
            'type' => NUMERIC,
        },
        'FILES PATH' => {
            'max'  => 60,
            'type' => STRING,
        },
        'LOGIN TRIES' => {
            'max'  => 1,
            'type' => NUMERIC,
        },
        'MEMCACHED HOST' => {
            'max'  => 20,
            'type' => HOST,
        },
        'MEMCACHED NAMESPACE' => {
            'max'  => 32,
            'type' => STRING,
        },
        'MEMCACHED PORT' => {
            'max'  => 5,
            'type' => NUMERIC,
        },
        'DATE FORMAT' => {
            'max'     => 14,
            'type'    => RADIO,
            'choices' => ['MONTH/DAY/YEAR', 'DAY/MONTH/YEAR', 'YEAR/MONTH/DAY',],
        },
        'USE DUF' => {
            'max'     => 5,
            'type'    => RADIO,
            'choices' => ['TRUE', 'FALSE'],
        },
        'PLAY SYSOP SOUNDS' => {
            'max'     => 5,
            'type'    => RADIO,
            'choices' => ['TRUE', 'FALSE'],
        },
    };
    my $choice;
    do {
        $choice = uc($self->sysop_keypress(TRUE));
    } until ($choice =~ /\d|[A-G]|Z/i);
    if ($choice =~ /Z/i) {
        print "BACK\n";
        return (FALSE);
    }

    $choice = ("$choice" =~ /[A-Y]/i) ? $choice = (ord($choice) - 55) : $choice;
    my @conf = grep(!/STATIC|AUTHOR/, sort(keys %{ $self->{'CONF'} }));
    if ($types->{ $conf[$choice] }->{'type'} == RADIO) {
        print '(Edit) ', $conf[$choice], ' (' . join(' ', @{ $types->{ $conf[$choice] }->{'choices'} }) . ') ', charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE'), '  ';
    } else {
        print '(Edit) ', $conf[$choice], ' ', charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE'), '  ';
    }
    my $string;
    $self->{'debug'}->DEBUGMAX([$self->configuration()]);
    $string = $self->sysop_get_line($types->{ $conf[$choice] }, $self->configuration($conf[$choice]));
    my $response = TRUE;
    if ($string eq '') {
        $response = FALSE;
    } else {
        $self->configuration($conf[$choice], $string);
    }
    $self->{'debug'}->DEBUG(['End SysOp Edit Configuration']);
    return ($response);
} ## end sub sysop_edit_configuration

sub sysop_get_key {
    my $self     = shift;
    my $echo     = shift;
    my $blocking = shift;

    my $key     = undef;
    my $mode    = $self->{'USER'}->{'text_mode'};
    my $timeout = $self->{'USER'}->{'timeout'} * 60;
    local $/ = "\x{00}";
    ReadMode 'ultra-raw';
    $key = ($blocking) ? ReadKey($timeout) : ReadKey(-1);
    ReadMode 'restore';
    threads->yield;
    return ($key) if ($key eq chr(13));

    if ($key eq chr(127)) {
        $key = $self->{'ansi_sequences'}->{'BACKSPACE'};
    }
    if ($echo == NUMERIC && defined($key)) {
        unless ($key =~ /[0-9]/) {
            $key = '';
        }
    }
    threads->yield;
    return ($key);
} ## end sub sysop_get_key

sub sysop_get_line {
    my $self = shift;
    my $echo = shift;
    my $type = $echo;

    my $line;
    my $limit;
    my $choices;
    my $key;

    $self->{'CACHE'}->set('SHOW_STATUS', FALSE);
    $self->{'debug'}->DEBUG(['Start SysOp Get Line']);
    $self->flush_input();

    if (ref($type) eq 'HASH') {
        $limit = $type->{'max'};
        if (exists($type->{'choices'})) {
            $choices = $type->{'choices'};
            if (exists($type->{'default'})) {
                $line = $type->{'default'};
            } else {
                $line = shift;
            }
        } ## end if (exists($type->{'choices'...}))
        $echo = $type->{'type'};
    } else {
        if ($echo == STRING || $echo == ECHO || $echo == NUMERIC || $echo == HOST) {
            $limit = shift;
        }
        $line = shift;
    } ## end else [ if (ref($type) eq 'HASH')]

    $self->{'debug'}->DEBUGMAX([$type, $echo, $line]);
    $self->sysop_output($line) if ($line ne '');
    my $mode = 'ANSI';
    my $bs   = $self->{'ansi_sequences'}->{'BACKSPACE'};
    if ($echo == RADIO) {
        $self->{'debug'}->DEBUG(['  SysOp Get Line RADIO']);
        my $regexp = join('', @{ $type->{'choices'} });
        $self->{'debug'}->DEBUGMAX([$regexp]);
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            print "$key $key";
                            chop($line);
                        }
                    } elsif ($regexp =~ /$key/i) {
                        print uc($key);
                        $line .= uc($key);
                    } else {
                        $self->sysop_output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    print "$key $key";
                    chop($line);
                } else {
                    $self->sysop_output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } elsif ($echo == NUMERIC) {
        $self->{'debug'}->DEBUG(['  SysOp Get Line NUMERIC']);
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(NUMERIC, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            print "$key $key";
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[0-9]/) {
                        print $key;
                        $line .= $key;
                    } else {
                        $self->sysop_output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    print "$key $key";
                    chop($line);
                } else {
                    $self->sysop_output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } elsif ($echo == HOST) {
        $self->{'debug'}->DEBUG(['  SysOp Get Line HOST']);
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->sysop_output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[a-z]|[0-9]|\./) {
                        print lc($key);
                        $line .= lc($key);
                    } else {
                        $self->sysop_output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    print "$key $key";
                    chop($line);
                } else {
                    $self->sysop_output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } else {
        $self->{'debug'}->DEBUG(['  SysOp Get Line NORMAL']);
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs) {
                        my $len = length($line);
                        if ($len > 0) {
                            print "$key $key";
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && ord($key) > 31 && ord($key) < 127) {
                        print $key;
                        $line .= $key;
                    } else {
                        $self->sysop_output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    print "$key $key";
                    chop($line);
                } else {
                    $self->sysop_output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } ## end else [ if ($echo == RADIO) ]
    threads->yield();
    $line = '' if ($key eq chr(3));
    print "\n";
    $self->{'CACHE'}->set('SHOW_STATUS', TRUE);
    $self->{'debug'}->DEBUG(['End SysOp Get Line']);
    return ($line);
} ## end sub sysop_get_line

sub sysop_user_delete {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start SysOp User Delete']);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my $key;
    $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(ECHO, 20, '');
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
        if ($self->sysop_pager($self->sysop_color_border($table->boxes->draw(), 'RED', 'HEAVY'))) {
            print "Are you sure that you want to delete this user (Y|N)?  ";
            my $answer = $self->sysop_decision();
            if ($answer) {
                print "\n\nDeleting ", $user_row->{'username'}, " ... ";
                $sth = $self->users_delete($user_row->{'id'});
            }
        } ## end if ($self->sysop_pager...)
    } ## end if (defined($user_row))
    $self->{'debug'}->DEBUG(['End SysOp User Delete']);
} ## end sub sysop_user_delete

sub sysop_user_edit {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start SysOp User Edit']);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
    my $key;
    $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(ECHO, 20, '');
    return (FALSE) if ($search eq '');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($user_row)) {
        my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
        do {
            my $valsize = 1;
            foreach my $fld (keys %{$user_row}) {
                $valsize = max($valsize, length($user_row->{$fld}));
            }
            $valsize = min($valsize, $wsize - 29);
            my $table = Text::SimpleTable->new(6, 16, $valsize);
            $table->row('CHOICE', 'FIELD', 'VALUE');
            $table->hr();
            my $count = 0;
            my %choice;
            foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
                if ($field =~ /_time|fullname|_category|id/) {
                    $table->row(' ', uc($field), $user_row->{$field} . '');
                } else {
                    if ($user_row->{$field} =~ /^(0|1)$/) {
                        $table->row($choices[$count], uc($field), $self->sysop_true_false($user_row->{$field}, 'YN'));
                    } elsif ($field eq 'access_level') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - USER, VETERAN, JUNIOR SYSOP, SYSOP');
                    } elsif ($field eq 'date_format') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - YEAR/MONTH/DAY, MONTH/DAY/YEAR, DAY/MONTH/YEAR');
                    } elsif ($field eq 'baud_rate') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - 300, 600, 1200, 2400, 4800, 9600, 19200, FULL');
                    } elsif ($field eq 'text_mode') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - ASCII, ANSI, ATASCII, PETSCII');
                    } elsif ($field eq 'timeout') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - Minutes');
                    } else {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . '');
                    }
                    $count++ if ($key_exit eq $choices[$count]);
                    $choice{ $choices[$count] } = $field;
                    $count++;
                } ## end else [ if ($field =~ /_time|fullname|_category|id/)]
            } ## end foreach my $field (@{ $self...})
            my $tbl = $table->boxes->draw();
            while ($tbl =~ / (CHOICE|FIELD|VALUE|No|Yes|USER. VETERAN. JUNIOR SYSOP. SYSOP|YEAR.MONTH.DAY, MONTH.DAY.YEAR, DAY.MONTH.YEAR|300. 600. 1200. 2400. 4800. 9600. 19200. FULL|ASCII. ANSI. ATASCII. PETSCII|Minutes) /) {
                my $ch  = $1;
                my $new;
                if ($ch =~ /Yes/) {
                    $new = '[% GREEN %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /No/) {
                    $new = '[% RED %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /CHOICE|FIELD|VALUE/) {
                    $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                } else {
                    $new = '[% RGB 50,50,150 %]' . $ch . '[% RESET %]';
                }
                $tbl =~ s/$ch/$new/g;
            }
            $tbl = $self->sysop_color_border($tbl, 'BRIGHT CYAN', 'ROUNDED');
            $self->sysop_output('[% CLS %]' . $tbl . "\n");
            $self->sysop_show_choices($mapping);
            $self->sysop_prompt('Choose');
            do {
                $key = uc($self->sysop_keypress());
            } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
            if ($key !~ /$key_exit/i) {
                print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
                if ($choice{$key} =~ /^(prefer_nickname|view_files|upload_files|download_files|remove_files|read_message|post_message|remove_message|sysop|page_sysop)$/) {
                    $user_row->{$choice{$key}} = ($user_row->{$choice{$key}} == 1) ? 0 : 1;
                    my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . $choice{ $key } . '= !' . $choice{$key} . '  WHERE id=?');
                    $sth->execute($user_row->{'id'});
                    $sth->finish();
                } else {
                    my $new = $self->sysop_get_line(ECHO, 1 + $self->{'SYSOP FIELD TYPES'}->{ $choice{$key} }->{'max'}, $user_row->{ $choice{$key} });
                    $user_row->{ $choice{$key} } = $new;
                    my $sth = $self->{'dbh'}->prepare('UPDATE users SET ' . $choice{$key} . '=? WHERE id=?');
                    $sth->execute($new, $user_row->{'id'});
                    $sth->finish();
                }
            } else {
                print "BACK\n";
            }
        } until ($key =~ /$key_exit/i);
    } elsif ($search ne '') {
        print "User not found!\n\n";
    }
    $self->{'debug'}->DEBUG(['End SysOp User Edit']);
    return (TRUE);
} ## end sub sysop_user_edit

sub sysop_new_user_edit {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start SysOp User Edit']);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
    my $key;
    my @responses;
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE access_level=?');
    $sth->execute('USER');
    my $user_row;

    while ($user_row = $sth->fetchrow_hashref()) {
        push(@responses, $user_row);
    }
    $sth->finish();

    $self->{'debug'}->DEBUGMAX(\@responses);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    while ($user_row = pop(@responses)) {
        do {
            my $valsize = 1;
            foreach my $fld (keys %{$user_row}) {
                $valsize = max($valsize, length($user_row->{$fld}));
            }
            $valsize = min($valsize, $wsize - 29);
            my $table = Text::SimpleTable->new(6, 16, $valsize);
            $table->row('CHOICE', 'FIELD', 'VALUE');
            $table->hr();
            my $count = 0;
            my %choice;
            foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
                if ($field =~ /_time|fullname|_category|id/) {
                    $table->row(' ', $field, $user_row->{$field} . '');
                } else {
                    if ($user_row->{$field} =~ /^(0|1)$/) {
                        $table->row($choices[$count], $field, $self->sysop_true_false($user_row->{$field}, 'YN'));
                    } elsif ($field eq 'access_level') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - USER, VETERAN, JUNIOR SYSOP, SYSOP');
                    } elsif ($field eq 'date_format') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - YEAR/MONTH/DAY, MONTH/DAY/YEAR, DAY/MONTH/YEAR');
                    } elsif ($field eq 'baud_rate') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - 300, 600, 1200, 2400, 4800, 9600, 19200, FULL');
                    } elsif ($field eq 'text_mode') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - ASCII, ANSI, ATASCII, PETSCII');
                    } elsif ($field eq 'timeout') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - Minutes');
                    } else {
                        $table->row($choices[$count], $field, $user_row->{$field} . '');
                    }
                    $count++ if ($key_exit eq $choices[$count]);
                    $choice{ $choices[$count] } = $field;
                    $count++;
                } ## end else [ if ($field =~ /_time|fullname|_category|id/)]
            } ## end foreach my $field (@{ $self...})
            my $tbl = $table->boxes->draw();
            while ($tbl =~ / (CHOICE|FIELD|VALUE|No|Yes|USER. VETERAN. JUNIOR SYSOP. SYSOP|YEAR.MONTH.DAY, MONTH.DAY.YEAR, DAY.MONTH.YEAR|300. 600. 1200. 2400. 4800. 9600. 19200. FULL|ASCII. ANSI. ATASCII. PETSCII|Minutes) /) {
                my $ch  = $1;
                my $new;
                if ($ch =~ /Yes/) {
                    $new = '[% GREEN %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /No/) {
                    $new = '[% RED %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /CHOICE|FIELD|VALUE/) {
                    $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                } else {
                    $new = '[% RGB 50,50,150 %]' . $ch . '[% RESET %]';
                }
                $tbl =~ s/$ch/$new/g;
            }
            $tbl = $self->sysop_color_border($tbl, 'BRIGHT CYAN', 'ROUNDED');
            $self->sysop_output('[% CLS %]' . $tbl . "\n");
            $self->sysop_show_choices($mapping);
            $self->sysop_prompt('Choose');
            do {
                $key = uc($self->sysop_keypress());
            } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
            if ($key !~ /$key_exit/i) {
                print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
                my $new = $self->sysop_get_line(ECHO, 1 + $self->{'SYSOP FIELD TYPES'}->{ $choice{$key} }->{'max'}, $user_row->{ $choice{$key} });
                unless ($new eq '') {
                    $new =~ s/^(Yes|On)$/1/i;
                    $new =~ s/^(No|Off)$/0/i;
                }
                $user_row->{ $choice{$key} } = $new;
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
        } until ($key =~ /$key_exit/i);
    } ## end while ($user_row = pop(@responses...))
    $self->{'debug'}->DEBUG(['End SysOp User Edit']);
    return (TRUE);
} ## end sub sysop_new_user_edit

sub sysop_user_add {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start SysOp User Add']);
    my $flags_default = $self->{'flags_default'};
    my $mapping       = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $table = Text::SimpleTable->new(15, 150);
    my $user_template;
    my @tmp = grep(!/id|banned|fullname|_time|max_|_category/, @{ $self->{'SYSOP ORDER DETAILED'} });
    push(@tmp, 'password');

    foreach my $name (@tmp) {
        my $size = max(3, $self->{'SYSOP FIELD TYPES'}->{$name}->{'max'});
        if ($name eq 'timeout') {
            $table->row($name, '_' x $size . ' - Minutes');
        } elsif ($name eq 'baud_rate') {
            $table->row($name, '_' x $size . ' - 300 or 600 or 1200 or 2400 or 4800 or 9600 or 19200 or FULL');
        } elsif ($name =~ /username|given|family|password/) {
            if ($name eq 'given') {
                $table->row("$name (first)", '_' x $size . ' - Cannot be empty');
            } elsif ($name eq 'family') {
                $table->row("$name (last)", '_' x $size . ' - Cannot be empty');
            } else {
                $table->row($name, '_' x $size . ' - Cannot be empty');
            }
        } elsif ($name eq 'date_format') {
            $table->row($name, '_' x $size . ' - YEAR/MONTH/DAY or MONTH/DAY/YEAR or DAY/MONTH/YEAR');
        } elsif ($name eq 'access_level') {
            $table->row($name, '_' x $size . ' - USER or VETERAN or JUNIOR SYSOP or SYSOP');
        } elsif ($name eq 'text_mode') {
            $table->row($name, '_' x $size . ' - ANSI or ASCII or ATASCII or PETSCII');
        } elsif ($name eq 'birthday') {
            $table->row($name, '_' x $size . ' - YEAR-MM-DD');
        } elsif ($name =~ /(prefer_nickname|_files|_message|sysop|fortunes)/) {
            $table->row($name, '_' x $size . ' - Yes/No or True/False or On/Off or 1/0');
        } elsif ($name =~ /location|retro_systems|accomplishments/) {
            $table->row($name, '_' x ($self->{'SYSOP FIELD TYPES'}->{$name}->{'max'}));
        } else {
            $table->row($name, '_' x $size);
        }
        $user_template->{$name} = undef;
    } ## end foreach my $name (@tmp)
    my $string = $table->boxes->draw();
    while ($string =~ / (Cannot be empty|YEAR.MM.DD|USER or VETERAN or JUNIOR SYSOP or SYSOP|YEAR.MONTH.DAY or MONTH.DAY.YEAR or DAY.MONTH.YEAR|300 or 600 or 1200 or 2400 or 4800 or 9600 or 19200 or FULL|ANSI or ASCII or ATASCII or PETSCII|Minutes|Yes.No or True.False or On.Off or 1.0) /) {
        my $ch  = $1;
        my $new = '[% RGB 50,50,150 %]' . $ch . '[% RESET %]';
        $string =~ s/$ch/$new/gs;
    }
    $self->sysop_output($self->sysop_color_border($string, 'PINK', 'DEFAULT'));
    $self->sysop_show_choices($mapping);
    my $column     = 21;
    my $adjustment = $self->{'CACHE'}->get('START_ROW') - 1;
    foreach my $entry (@tmp) {
        do {
            print locate($row + $adjustment, $column), '_' x max(3, $self->{'SYSOP FIELD TYPES'}->{$entry}->{'max'}), locate($row + $adjustment, $column);
            chomp($user_template->{$entry} = $self->sysop_get_line($self->{'SYSOP FIELD TYPES'}->{$entry}));
            return ('BACK') if ($user_template->{$entry} eq '<' || $user_template->{$entry} eq chr(3));
            if ($entry =~ /text_mode|baud_rate|timeout|given|family/) {
                if ($user_template->{$entry} eq '') {
                    if ($entry eq 'text_mode') {
                        $user_template->{$entry} = 'ASCII';
                    } elsif ($entry eq 'baud_rate') {
                        $user_template->{$entry} = 'FULL';
                    } elsif ($entry eq 'timeout') {
                        $user_template->{$entry} = $self->{'CONF'}->{'DEFAULT TIMEOUT'};
                    } elsif ($entry =~ /prefer|_files|_message|sysop|_fortunes/) {
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
            } elsif ($entry =~ /prefer_|_files|_message|sysop|_fortunes/) {
                $user_template->{$entry} = uc($user_template->{$entry});
                print locate($row + $adjustment, $column), $user_template->{$entry};
            }
        } until ($self->sysop_validate_fields($entry, $user_template->{$entry}, $row + $adjustment, $column));
        if ($user_template->{$entry} =~ /^(yes|on|true|1)$/i) {
            $user_template->{$entry} = TRUE;
        } elsif ($user_template->{$entry} =~ /^(no|off|false|0)$/i) {
            $user_template->{$entry} = FALSE;
        }
        $adjustment++;
    } ## end foreach my $entry (@tmp)
    $self->{'debug'}->DEBUGMAX([$user_template]);
    if ($self->users_add($user_template)) {
        print "\n\n", colored(['green'], 'SUCCESS'), "\n";
        $self->{'debug'}->DEBUG(['sysop_user_add end']);
        return (TRUE);
    }
    $self->{'debug'}->DEBUG(['End SysOp User Add']);
    return (FALSE);
} ## end sub sysop_user_add

sub sysop_show_choices {
    my $self    = shift;
    my $mapping = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Show Choices']);

    print $self->sysop_menu_choice('TOP', '', '');
    my $keys = '';
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        print $self->sysop_menu_choice($kmenu, $mapping->{$kmenu}->{'color'}, $mapping->{$kmenu}->{'text'});
        $keys .= $kmenu;
    }
    print $self->sysop_menu_choice('BOTTOM', '', '');
    $self->{'debug'}->DEBUG(['End SysOp Show Choices']);
    return (TRUE);
} ## end sub sysop_show_choices

sub sysop_validate_fields {
    my $self   = shift;
    my $name   = shift;
    my $val    = shift;
    my $row    = shift;
    my $column = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Validate Fields']);
    my $size = max(3, $self->{'SYSOP FIELD TYPES'}->{$name}->{'max'});
    my $response = TRUE;
    if ($name =~ /(username|given|family|baud_rate|timeout|_files|_message|sysop|prefer|password)/ && $val eq '') {    # cannot be empty
        print locate($row, ($column + $size)), colored(['red'], ' Cannot Be Empty'), locate($row, $column);
        $response = FALSE;
    } elsif ($name eq 'baud_rate' && $val !~ /^(300|600|1200|2400|4800|9600|FULL)$/i) {
        print locate($row, ($column + $size)), colored(['red'], ' Only 300,600,1200,2400,4800,9600,FULL'), locate($row, $column);
        $response = FALSE;
    } elsif ($name =~ /max_/ && $val =~ /\D/i) {
        print locate($row, ($column + $size)), colored(['red'], ' Only Numeric Values'), locate($row, $column);
        $response = FALSE;
    } elsif ($name eq 'timeout' && $val =~ /\D/) {
        print locate($row, ($column + $size)), colored(['red'], ' Must be numeric'), locate($row, $column);
        $response = FALSE;
    } elsif ($name eq 'text_mode' && $val !~ /^(ASCII|ATASCII|PETSCII|ANSI)$/) {
        print locate($row, ($column + $size)), colored(['red'], ' Only ASCII,ATASCII,PETSCII,ANSI'), locate($row, $column);
        $response = FALSE;
    } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/ && $val !~ /^(yes|no|true|false|on|off|0|1)$/i) {
        print locate($row, ($column + $size)), colored(['red'], ' Only Yes/No or On/Off or 1/0'), locate($row, $column);
        $response = FALSE;
    } elsif ($name eq 'birthday' && $val ne '' && $val !~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
        print locate($row, ($column + $size)), colored(['red'], ' YEAR-MM-DD'), locate($row, $column);
        $self->{'debug'}->DEBUG(['sysop_validate_fields end']);
        $response = FALSE;
    }
    $self->{'debug'}->DEBUG(['Start SysOp Validate Fields']);
    return ($response);
} ## end sub sysop_validate_fields

sub sysop_prompt {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Prompt']);
    my $response = "\n" . '[% B_BRIGHT MAGENTA %][% BLACK %] SYSOP TOOL [% RESET %] ' . $text . ' [% PINK %][% BLACK RIGHTWARDS ARROWHEAD %][% RESET %] ';
    print $self->sysop_detokenize($response);
    $self->{'debug'}->DEBUG(['End SysOp Prompt']);
    return(TRUE);
} ## end sub sysop_prompt

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    # OPERATION TOKENS
    foreach my $key (keys %{ $self->{'sysop_tokens'} }) {
        my $ch = '';
        if ($key eq 'MIDDLE VERTICAL RULE color' && $text =~ /\[\%\s+MIDDLE VERTICAL RULE (.*?)\s+\%\]/) {
            my $color = $1;
            if (ref($self->{'sysop_tokens'}->{$key}) eq 'CODE') {
                $ch = $self->{'sysop_tokens'}->{$key}->($self,$color);
            }
            $text =~ s/\[\%\s+MIDDLE VERTICAL RULE (.*?)\s+\%\]/$ch/gi;
        } elsif ($text =~ /\[\%\s+$key\s+\%\]/) {
            if (ref($self->{'sysop_tokens'}->{$key}) eq 'CODE') {
                $ch = $self->{'sysop_tokens'}->{$key}->($self);
            } else {
                $ch = $self->{'sysop_tokens'}->{$key};
            }
            $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
        }
    } ## end foreach my $key (keys %{ $self...})

    $text = $self->ansi_decode($text);

    return ($text);
} ## end sub sysop_detokenize

sub sysop_menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Menu Choice']);
    my $response;
    if ($choice eq 'TOP') {
        $response = charnames::string_vianame('BOX DRAWINGS LIGHT ARC DOWN AND RIGHT') . charnames::string_vianame('BOX DRAWINGS LIGHT HORIZONTAL') . charnames::string_vianame('BOX DRAWINGS LIGHT ARC DOWN AND LEFT') . "\n";
    } elsif ($choice eq 'BOTTOM') {
        $response = charnames::string_vianame('BOX DRAWINGS LIGHT ARC UP AND RIGHT') . charnames::string_vianame('BOX DRAWINGS LIGHT HORIZONTAL') . charnames::string_vianame('BOX DRAWINGS LIGHT ARC UP AND LEFT') . "\n";
    } else {
        $response = $self->ansi_decode(charnames::string_vianame('BOX DRAWINGS LIGHT VERTICAL') . '[% BOLD %][% ' . $color . ' %]' . $choice . '[% RESET %]' . charnames::string_vianame('BOX DRAWINGS LIGHT VERTICAL') . ' [% ' . $color . ' %]' . charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE') . '[% RESET %] ' . $desc . "\n");
    }
    $self->{'debug'}->DEBUG(['End SysOp Menu Choice']);
    return ($response);
} ## end sub sysop_menu_choice

sub sysop_showenv {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp ShowENV']);
    my $MAX  = 0;
    my $text = '';
    foreach my $e (keys %ENV) {
        $MAX = max(length($e), $MAX);
    }

    foreach my $env (sort(keys %ENV)) {
        if ($ENV{$env} =~ /\n/g || $env eq 'WHATISMYIP_INFO') {
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
                    $l = colored(['bold red'], 'United') . ' ' . colored(['bold bright_white'], 'States') . ' of ' . colored(['bold bright_blue'], 'America') if ($l =~ /^us/i);
                    $l = colored(['bold red'], 'Unit') . colored(['bold bright_white'], 'ed Kin') . colored(['bold bright_blue'], 'gdom') if ($l =~ /^uk/i);
                    $l = colored(['bold bright_red'], 'Ca') . colored(['bold bright_white'], 'na') . colored(['bold bright_red'], 'da') if ($l =~ /^can/i);
                    $l = colored(['bold bright_red'], 'Me') . colored(['bold bright_white'], 'xi') . colored(['bold green'], 'co') if ($l =~ /^mex/i);
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
        } elsif ($env =~ /GNOME_SHELL_SESSION_MODE|GDMSESSION|DESKTOP_SESSION|XDG_SESSION_DESKTOP/) {
            if ($ENV{$env} eq 'ubuntu') {
                $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = [% ORANGE %]' . $ENV{$env} . "[% RESET %]\n";
            } elsif ($ENV{$env} eq 'redhat') {
                $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = [% RED %]' . $ENV{$env} . "[% RESET %]\n";
            }
        } elsif ($env eq 'COLORTERM') {
            my $colorized = colored(['red'], 't') . colored(['green'], 'r') . colored(['yellow'], 'u') . colored(['cyan'], 'e') . colored(['bright_blue'], 'c') . colored(['magenta'], 'o') . colored(['bright_green'], 'l') . colored(['bright_blue'], 'o') . colored(['red'],'r');
            my $line      = $ENV{$env};
            $line =~ s/truecolor/$colorized/;
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . $line . "\n";
        } elsif ($env eq 'WHATISMYIP') {
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ENV{$env}) . "\n";
        } else {
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . $ENV{$env} . "\n";
        }
    } ## end foreach my $env (sort(keys ...))
    $self->{'debug'}->DEBUG(['End SysOp ShowENV']);
    return ($text);
} ## end sub sysop_showenv

sub sysop_scroll {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Scroll']);
    my $response = TRUE;
    print $self->{'ansi_sequences'}->{'RESET'},"\rScroll?  ";
    if ($self->sysop_keypress(ECHO, BLOCKING) =~ /N/i) {
        $response = FALSE;
    } else {
        print "\r" . clline;
    }
    $self->{'debug'}->DEBUG(['End SysOp Scroll']);
    return (TRUE);
} ## end sub sysop_scroll

sub sysop_list_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp List BBS']);
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view ORDER BY bbs_name');
    $sth->execute();
    my @listing;
    my ($id_size, $name_size, $hostname_size, $poster_size) = (2, 4, 14, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $id_size       = max(length('' . $row->{'bbs_id'}),  $id_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    } ## end while (my $row = $sth->fetchrow_hashref...)
    my $table = Text::SimpleTable->new($id_size, $name_size, $hostname_size, 5, $poster_size);
    $table->row('ID', 'NAME', 'HOSTNAME/PHONE', 'PORT', 'POSTER');
    $table->hr();
    foreach my $line (@listing) {
        $table->row($line->{'bbs_id'}, $line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
    }
    $self->sysop_output($self->sysop_color_border($table->boxes->draw(), 'BRIGHT BLUE', 'ROUNDED'));
    print 'Press a key to continue... ';
    $self->sysop_keypress();
    $self->{'debug'}->DEBUG(['End SysOp List BBS']);
    return(TRUE);
} ## end sub sysop_list_bbs

sub sysop_edit_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Edit BBS']);
    my @choices = (qw( bbs_id bbs_name bbs_hostname bbs_port ));
    $self->sysop_prompt('Please enter the ID, the hostname/phone, or the BBS name to edit');
    my $search;
    $search = $self->sysop_get_line(ECHO, 50, '');
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
        } ## end foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port))
        $self->sysop_output($self->sysop_color_border($table->boxes->draw(), 'BRIGHT BLUE', 'ROUNDED'));
        $self->sysop_prompt('Edit which field (Z=Nevermind)');
        my $choice;
        do {
            $choice = $self->sysop_keypress();
        } until ($choice =~ /[1-3]|Z/i);
        if ($choice =~ /\D/) {
            print "BACK\n";
            return (FALSE);
        }
        $self->sysop_prompt($choices[$choice] . ' (' . $bbs->{ $choices[$choice] } . ') ');
        my $width = ($choices[$choice] eq 'bbs_port') ? 5 : 50;
        my $new   = $self->sysop_get_line(ECHO, $width, '');
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
    $self->{'debug'}->DEBUG(['End SysOp Edit BBS']);
    return(TRUE);
} ## end sub sysop_edit_bbs

sub sysop_add_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Add BBS']);
    my $table = Text::SimpleTable->new(14, 50);
    foreach my $name ('BBS NAME', 'HOSTNAME/PHONE', 'PORT') {
        my $count = ($name eq 'PORT') ? 5 : 50;
        $table->row($name, "\n" . charnames::string_vianame('OVERLINE') x $count);
        $table->hr() unless ($name eq 'PORT');
    }
    my @order = (qw(bbs_name bbs_hostname bbs_port));
    my $bbs   = {
        'bbs_name'     => '',
        'bbs_hostname' => '',
        'bbs_port'     => '',
    };
    my $index = 0;
    my $response = TRUE;
    $self->sysop_output($self->sysop_color_border($table->boxes->draw(), 'BRIGHT BLUE', 'ROUNDED'));
    print $self->{'ansi_sequences'}->{'UP'} x 9, $self->{'ansi_sequences'}->{'RIGHT'} x 19;
    $bbs->{'bbs_name'} = $self->sysop_get_line(ECHO, 50, '');
    $self->{'debug'}->DEBUG(['  BBS Name:  ' . $bbs->{'bbs_name'}]);
    if ($bbs->{'bbs_name'} ne '' && length($bbs->{'bbs_name'}) > 3) {
        print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 19;
        $bbs->{'bbs_hostname'} = $self->sysop_get_line(ECHO, 50, '');
        $self->{'debug'}->DEBUG(['  BBS Hostname:  ' . $bbs->{'bbs_hostname'}]);
        if ($bbs->{'bbs_hostname'} ne '' && length($bbs->{'bbs_hostname'}) > 5) {
            print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 19;
            $bbs->{'bbs_port'} = $self->sysop_get_line(ECHO, 5, '');
            $self->{'debug'}->DEBUG(['  BBS Port:  ' . $bbs->{'bbs_port'}]);
            if ($bbs->{'bbs_port'} ne '' && $bbs->{'bbs_port'} =~ /^\d+$/) {
                $self->{'debug'}->DEBUG(['  Add to BBS List']);
                my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
                $sth->execute($bbs->{'bbs_name'}, $bbs->{'bbs_hostname'}, $bbs->{'bbs_port'});
                $sth->finish();
            } else {
                $response = FALSE;
            }
        } else {
            $response = FALSE;
        }
    } else {
        $response = FALSE;
    }
    $self->{'debug'}->DEBUG(['End SysOp Add BBS']);
    return ($response);
} ## end sub sysop_add_bbs

sub sysop_delete_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Delete BBS']);
    $self->sysop_prompt('Please enter the ID, the hostname, or the BBS name to delete');
    my $search;
    $search = $self->sysop_get_line(ECHO, 50, '');
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
        $self->sysop_output($self->sysop_color_border($table->boxes->draw(), 'RED', 'ROUNDED'));
        print 'Are you sure that you want to delete this BBS from the list (Y|N)?  ';
        my $choice = $self->sysop_decision();
        unless ($choice) {
            $self->{'debug'}->DEBUG(['End SysOp Delete BBS']);
            return (FALSE);
        }
        $sth = $self->{'dbh'}->prepare('DELETE FROM bbs_listing WHERE bbs_id=?');
        $sth->execute($bbs->{'bbs_id'});
    } ## end if ($sth->rows() > 0)
    $sth->finish();
    $self->{'debug'}->DEBUG(['End SysOp Delete BBS']);
    return (TRUE);
} ## end sub sysop_delete_bbs

sub sysop_add_file {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp Add File']);
    opendir(my $DIR, 'files/files/');
    my @dir = grep(!/^\.+/, readdir($DIR));
    closedir($DIR);
    my $list;
    my $nw  = 0;
    my $sw  = 4;
    my $tw  = 0;
    my $sth = $self->{'dbh'}->prepare('SELECT id FROM files WHERE filename=?');
    my $search;
    my $root          = $self->configuration('BBS ROOT');
    my $files_path    = $self->configuration('FILES PATH');
    my $file_category = $self->{'USER'}->{'file_category'};

    foreach my $file (@dir) {
        $sth->execute($file);
        my $rows = $sth->rows();
        if ($rows <= 0) {
            $nw = max(length($file), $nw);
            my $raw_size = (-s "$root/$files_path/$file");
            my $size     = format_number($raw_size);
            $sw = max(length("$size"), $sw, 4);
            my ($ext, $type) = $self->files_type($file);
            $tw                          = max(length($type), $tw);
            $list->{$file}->{'raw_size'} = $raw_size;
            $list->{$file}->{'size'}     = $size;
            $list->{$file}->{'type'}     = $type;
            $list->{$file}->{'ext'}      = uc($ext);
        } ## end if ($rows <= 0)
    } ## end foreach my $file (@dir)
    $sth->finish();
    if (defined($list)) {
        my @names = grep(!/^README.md$/, (sort(keys %{$list})));
        if (scalar(@names)) {
            $self->{'debug'}->DEBUGMAX($list);
            my $table = Text::SimpleTable->new($nw, $sw, $tw);
            $table->row('FILE', 'SIZE', 'TYPE');
            $table->hr();
            foreach my $file (sort(keys %{$list})) {
                $table->row($file, $list->{$file}->{'size'}, $list->{$file}->{'type'});
            }
            my $text = $self->sysop_color_border($table->boxes->draw(),'GREEN', 'DOUBLE');
            $self->sysop_pager($text);
            while (scalar(@names)) {
                ($search) = shift(@names);
                $self->sysop_output('[% B_WHITE %][% BLACK %] Current Category [% RESET %] [% BRIGHT YELLOW %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% BRIGHT WHITE %][% FILE CATEGORY %][% RESET %]' . "\n\n");
                $self->sysop_prompt('Which file would you like to add?  ');
                $search = $self->sysop_get_line(ECHO, $nw, $search);
                my $filename = "$root/$files_path/$search";
                if (-e $filename) {
                    $self->sysop_prompt('               What is the Title?');
                    my $title = $self->sysop_get_line(ECHO, 255, '');
                    if (defined($title) && $title ne '') {
                        $self->sysop_prompt('                Add a description');
                        my $description = $self->sysop_get_line(ECHO, 65535, '');
                        if (defined(description) && $description ne '') {
                            my $head = "\n" . '[% REVERSE %]    Category [% RESET %] [% FILE CATEGORY %]' . "\n" . '[% REVERSE %]   File Name [% RESET %] ' . $search . "\n" . '[% REVERSE %]       Title [% RESET %] ' . $title . "\n" . '[% REVERSE %] Description [% RESET %] ' . $description . "\n\n";
                            print $self->sysop_detokenize($head);
                            $self->sysop_prompt('Is this correct?');
                            if ($self->sysop_decision()) {
                                $sth = $self->{'dbh'}->prepare('INSERT INTO files (filename, title, user_id, category, file_type, description, file_size) VALUES (?,?,1,?,(SELECT id FROM file_types WHERE extension=?),?,?)');
                                $sth->execute($search, $title, $self->{'USER'}->{'file_category'}, $list->{$search}->{'ext'}, $description, $list->{$search}->{'raw_size'});
                                if ($self->{'dbh'}->err) {
                                    $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
                                }
                                $sth->finish();
                            } ## end if ($self->sysop_decision...)
                        } ## end if (defined(description...))
                    } ## end if (defined($title) &&...)
                } ## end if (-e $filename)
            } ## end while (scalar(@names))
        } else {
            $self->sysop_output("\n\n" . '[% BRIGHT RED %]NO FILES TO ADD![% RESET %]  ');
            sleep 2;
        }
    } else {
        print colored(['yellow'], 'No unmapped files found'), "\n";
        sleep 2;
    }
    $self->{'debug'}->DEBUG(['End SysOp Add File']);
} ## end sub sysop_add_file

sub sysop_bbs_list_bulk_import {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start SysOp BBS List Bulk Import']);
    my $filename = $self->configuration('BBS ROOT') . "/bbs_list.txt";
    if (-e $filename) {
        $self->sysop_output("\n\nImporting/merging BBS list from bbs_list.txt\n\n");
        $self->sysop_output('[% GREEN %]╭───────────────────────────────────────────────────────────────────┬──────────────────────────────────┬───────╮[% RESET %]' . "\n");
        $self->sysop_output('[% GREEN %]│[% RESET %] NAME                                                              [% GREEN %]│[% RESET %] HOSTNAME/PHONE                   [% GREEN %]│[% RESET %] PORT  [% GREEN %]│[% RESET %]' . "\n");
        $self->sysop_output('[% GREEN %]├───────────────────────────────────────────────────────────────────┼──────────────────────────────────┼───────┤[% RESET %]' . "\n");
        open(my $FILE, '<', $filename);
        chomp(my @bbs = <$FILE>);
        close($FILE);

        my $sth = $self->{'dbh'}->prepare('REPLACE INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,?)');
        foreach my $row (@bbs) {
            if ($row =~ /^. \S/ && $row !~ /^\* = NEW/) {
                $row =~ s/^\* /  /;
                my ($name, $url) = (substr($row,2,41), substr($row,43));
                $name =~ s/(.*?)\s+$/$1/;
                my ($address, $port) = split(/:/,$url);
                $port = 23 unless(defined($port));
                $sth->execute($name, $address, $port, $self->{'USER'}->{'id'});
                $self->sysop_output('[% GREEN %]│[% RESET %] ' . sprintf('%-65s', $name) . '[% GREEN %] │[% RESET %] ' . sprintf('%-32s', $address) . ' [% GREEN %]│[% RESET %] ' . sprintf('%5d', $port) . ' [% GREEN %]│[% RESET %]' . "\n");
            }
        }
        $sth->finish();
        $self->sysop_output('[% GREEN %]╰───────────────────────────────────────────────────────────────────┴──────────────────────────────────┴───────╯[% RESET %]' . "\n\nImport Complete\n");
    } else {
        $self->sysop_output("\n[% RING BELL %][% RED %]Cannot find [% RESET %]$filename\n");
        $self->{'debug'}->WARNING(["Cannot find $filename"]);
    }
    $self->sysop_output("\nPress any key to continue\n");
    $self->sysop_get_key(SILENT, BLOCKING);
    $self->{'debug'}->DEBUG(['End SysOp BBS List Bulk Import']);
    return(TRUE);
}

sub sysop_ansi_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start SysOp ANSI Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $text = $self->ansi_decode($text);
    my $s_len = length($text);
    my $nl    = $self->{'ansi_sequences'}->{'NEWLINE'};

    my @lines = split(/\n/,$text);
    my $size = $self->{'USER'}->{'max_rows'};
    while (scalar(@lines)) {
        my $line = shift(@lines);
        print $line;
        $size--;
        if ($size <= 0) {
            $size = $self->{'USER'}->{'max_rows'};
            last unless ($self->scroll(("\n")));
        } else {
            print "\n";
        }
    }
    $self->{'debug'}->DEBUG(['End SysOp ANSI Output']);
    return (TRUE);
}

sub sysop_output {
    my $self = shift;
    $|=1;
    $self->{'debug'}->DEBUG(['Start SysOp Output']);
    my $text = $self->detokenize_text(shift);

    my $response = TRUE;
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
        } ## end if ($text =~ /\[\%\s+WRAP\s+\%\]/)
        $self->sysop_ansi_output($text);
    } else {
        $response = FALSE;
    }
    $self->{'debug'}->DEBUG(['End SysOp Output']);
    return ($response);
}

 

# package BBS::Universal::Text_Editor;

sub text_editor_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Text Editor Initialize']);
    $self->{'debug'}->DEBUG(['End Text Editor Initialize']);
    return ($self);
}

sub text_editor_edit {
	my $self = shift;

    $self->{'debug'}->DEBUG(['Start Text Editor Edit']);
    $self->{'debug'}->DEBUG(['End Text Editor Edit']);
}

 

# package BBS::Universal::Users;

sub users_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Initialize']);
    $self->{'USER'}->{'mode'} = ASCII;
    $self->{'debug'}->DEBUG(['End Users Initialize']);
    return ($self);
}

sub users_change_access_level {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Change Access Level']);
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
        $self->prompt('([% BRIGHT YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } elsif ($mode eq 'ATASCII') {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
    } elsif ($mode eq 'PETSCII') {
        $self->prompt('([% YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } else {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
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
    $self->{'debug'}->DEBUG(['End Users Change Access Level']);
    return (TRUE);
}

sub users_change_date_format {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Change Date Format']);
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
        $self->prompt('([% BRIGHT YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } elsif ($mode eq 'ATASCII') {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
    } elsif ($mode eq 'PETSCII') {
        $self->prompt('([% YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } else {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
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
    $self->{'debug'}->DEBUG(['End Users Change Date Format']);
    return (TRUE);
}

sub users_change_baud_rate {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Change Baud Rate']);
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
        $self->prompt('([% BRIGHT YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } elsif ($mode eq 'ATASCII') {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
    } elsif ($mode eq 'PETSCII') {
        $self->prompt('([% YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } else {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
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
        $self->{'debug'}->DEBUG(["  Baud Rate:  $command"]);
    }
    $self->{'debug'}->DEBUG(['End Users Change Baud Rate']);
    return (TRUE);
}

sub users_change_screen_size {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Change Screen Size']);
    $self->prompt("\nColumns");
    my $columns = 0 + $self->get_line(NUMERIC,3,$self->{'USER'}->{'max_columns'});
    if ($columns >= 32 && $columns ne $self->{'USER'}->{'max_columns'} && $self->is_connected()) {
        $self->{'USER'}->{'max_columns'} = $columns;
        my $sth = $self->{'dbh'}->prepare('UPDATE users SET max_columns=? WHERE id=?');
        $sth->execute($columns,$self->{'USER'}->{'id'});
        $sth->finish;
        $self->{'debug'}->DEBUG(["  Columns:  $columns"]);
    }
    $self->prompt("\nRows");
    my $rows = 0 + $self->get_line(NUMERIC,3,$self->{'USER'}->{'max_rows'});
    if ($rows >= 25 && $rows ne $self->{'USER'}->{'max_rows'} && $self->is_connected()) {
        $self->{'USER'}->{'max_rows'} = $rows;
        my $sth = $self->{'dbh'}->prepare('UPDATE users SET max_rows=? WHERE id=?');
        $sth->execute($rows,$self->{'USER'}->{'id'});
        $sth->finish;
        $self->{'debug'}->DEBUG(["  Rows:  $rows"]);
    }
    $self->{'debug'}->DEBUG(['Start Users Change Screen Size']);
    return (TRUE);
}

sub users_update_retro_systems {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Update Retro Systems']);
    $self->prompt("\nName your retro computers");
    my $retro = $self->get_line(ECHO,65535,$self->{'USER'}->{'retro_systems'});
    if (length($retro) >= 5 && $retro ne $self->{'USER'}->{'retro_systems'} && $self->is_connected()) {
        $self->{'USER'}->{'retro_systems'} = $retro;
        my $sth = $self->{'dbh'}->prepare('UPDATE users SET retro_systems=? WHERE id=?');
        $sth->execute($retro,$self->{'USER'}->{'id'});
        $sth->finish;
        $self->{'debug'}->DEBUG(["  Retro Systems:  $retro"]);
    }
    $self->{'debug'}->DEBUG(['End Users Update Retro Systems']);
    return (TRUE);
}

sub users_update_email {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Update Email']);
    $self->prompt("\nEnter email address");
    my $email = $self->get_line(ECHO,255,$self->{'USER'}->{'email'});
    if (length($email) > 5 && $email ne $self->{'USER'}->{'email'} && $self->is_connected()) {
        $self->{'USER'}->{'email'} = $email;
        my $sth = $self->{'dbh'}->prepare('UPDATE users SET email=? WHERE id=?');
        $sth->execute($email,$self->{'USER'}->{'id'});
        $sth->finish;
        $self->{'debug'}->DEBUG(["  Email:  $email"]);
    }
    $self->{'debug'}->DEBUG(['End Users Update Email']);
    return (TRUE);
}

sub users_toggle_permission {
    my $self  = shift;
    my $field = shift;

    $self->{'debug'}->DEBUG(['Start Users Toggle Permission']);
    if (0 + $self->{'USER'}->{$field}) {
        $self->{'USER'}->{$field} = FALSE;
    } else {
        $self->{'USER'}->{$field} = TRUE;
    }
    my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . $field . '=? WHERE id=?');
    $sth->execute($self->{'USER'}->{$field}, $self->{'USER'}->{'id'});
    $self->{'dbh'}->commit;
    $sth->finish();
    $self->{'debug'}->DEBUG(['End Users Toggle Permission']);
    return (TRUE);
}

sub users_update_location {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Update Location']);
    $self->prompt("\nEnter your location");
    my $location = $self->get_line(ECHO,255,$self->{'USER'}->{'location'});
    if (length($location) >= 4 && $location ne $self->{'USER'}->{'location'} && $self->is_connected()) {
        $self->{'USER'}->{'location'} = $location;
        my $sth = $self->{'dbh'}->prepare('UPDATE users SET location=? WHERE id=?');
        $sth->execute($location,$self->{'USER'}->{'id'});
        $sth->finish;
        $self->{'debug'}->DEBUG(["  Location:  $location"]);
    }
    $self->{'debug'}->DEBUG(['End Users Update Location']);
    return (TRUE);
}

sub users_update_accomplishments {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Update Accomplishments']);
    $self->prompt("\nEnter your accomplishments");
    my $accomplishments = $self->get_line(ECHO,255,$self->{'USER'}->{'accomplishments'});
    if (length($accomplishments) >= 4 && $accomplishments ne $self->{'USER'}->{'accomplishments'} && $self->is_connected()) {
        $self->{'USER'}->{'accomplishments'} = $accomplishments;
        my $sth = $self->{'dbh'}->prepare('UPDATE users SET accomplishments=? WHERE id=?');
        $sth->execute($accomplishments,$self->{'USER'}->{'id'});
        $sth->finish;
        $self->{'debug'}->DEBUG(["  Accomplishments:  $accomplishments"]);
    }
    $self->{'debug'}->DEBUG(['End Users Update Accomplishments']);
    return (TRUE);
}

sub users_update_text_mode {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Update Text Mode']);
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
        $self->prompt('([% BRIGHT YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } elsif ($mode eq 'ATASCII') {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
    } elsif ($mode eq 'PETSCII') {
        $self->prompt('([% YELLOW %]' . $self->{'USER'}->{'username'} . '[% RESET %]) ' . 'Choose');
    } else {
        $self->prompt('(' . $self->{'USER'}->{'username'} . ') ' . 'Choose');
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
        $self->{'debug'}->DEBUG(["  Text Mode:  $command"]);
    }
    $self->{'debug'}->DEBUG(['Start Users Update Text Mode']);
    return (TRUE);
}

sub users_load {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    $self->{'debug'}->DEBUG(['Start Users Load']);
    my $sth;
    if ($self->{'sysop'}) {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE username=?');
        $sth->execute($username);
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE username=? AND password=SHA2(?,512)');
        $sth->execute($username, $password);
    }
    my $results = $sth->fetchrow_hashref();
    my $response = FALSE;
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
            play_fortunes
            banned
            sysop
            )
        ) {
            $self->{'USER'}->{$field} = 0 + $self->{'USER'}->{$field};
        }
        $response = TRUE;
    }
    $self->{'debug'}->DEBUG(['End Users Load']);
    return ($response);
}

sub users_get_date {
    my $self     = shift;
    my $old_date = shift;

    $self->{'debug'}->DEBUG(['Start User Get Date']);
    my $response;
    if ($old_date =~ / /) {
        my $time;
        ($old_date,$time) = split(/ /,$old_date);
        my ($year,$month,$day) = split(/-/,$old_date);
        my $date = $self->{'USER'}->{'date_format'};
        $date =~ s/YEAR/$year/;
        $date =~ s/MONTH/$month/;
        $date =~ s/DAY/$day/;
        $response = "$date $time";
    } else {
        my ($year,$month,$day) = split(/-/,$old_date);
        my $date = $self->{'USER'}->{'date_format'};
        $date =~ s/YEAR/$year/;
        $date =~ s/MONTH/$month/;
        $date =~ s/DAY/$day/;
        $response = $date;
    }
    $self->{'debug'}->DEBUG(['End User Get Date']);
    return($response);
}

sub users_list {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users List']);
    my $sth = $self->{'dbh'}->prepare(
        q{
            SELECT
              username,
              fullname,
              nickname,
              accomplishments,
              retro_systems,
              birthday,
              prefer_nickname,
              location
            FROM users_view
            WHERE banned=FALSE
            ORDER BY username;
        }
    );
    $sth->execute();
    my $columns = $self->{'USER'}->{'max_columns'};
    my $table;
    if ($columns <= 40) {       # Username and Fullname
        $table = Text::SimpleTable->new(10, 36);
        $table->row('USERNAME', 'FULLNAME');
    } elsif ($columns <= 64) {  # Username, Nickname and Fullname
        $table = Text::SimpleTable->new(10, 20, 32);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME');
    } elsif ($columns <= 80) {  # Username, Nickname, Fullname and Location
        $table = Text::SimpleTable->new(10, 20, 32, 32);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION');
    } elsif ($columns <= 132) { # Username, Nickname, Fullname, Location, Retro Systems
        $table = Text::SimpleTable->new(10, 20, 30, 30, 40);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS');
    } else {                    # Username, Nickname, Fullname, Location, Retro Systems, Birthday and Accomplishments
        $table = Text::SimpleTable->new(10, 20, 32, 32, 40, 5, 100);
        $table->row('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS', 'BDAY', 'ACCOMPLISHMENTS');
    }
    while (my $results = $sth->fetchrow_hashref()) {
        $table->hr;
        my $preferred = ($results->{'prefer_nickname'}) ? $results->{'nickname'} : $results->{'fullname'};
        if ($columns <= 40) {      # Username and Fullname
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-36s', $preferred));
        } elsif ($columns <= 64) {    # Username, Nickname and Fullname
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-32s', $preferred));
        } elsif ($columns <= 80) {    # Username, Nickname, Fullname and Location
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-32s', $preferred), sprintf('%-32s', $results->{'location'}));
        } elsif ($columns <= 132) {    # Username, Nickname, Fullname, Location, Retro Systems
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-30s', $preferred), sprintf('%-30s', $results->{'location'}), sprintf('%-40s', $results->{'retro_systems'}));
        } else {                       # Username, Nickname, Fullname, Location, Retro Systems, Birthday and Accomplishments
            my ($year, $month, $day) = split('-', $results->{'birthday'});
            $table->row(sprintf('%-10s', $results->{'username'}), sprintf('%-20s', $results->{'nickname'}), sprintf('%-32s', $preferred), sprintf('%-32s', $results->{'location'}), sprintf('%-40s', $results->{'retro_systems'}), sprintf('%02d/%02d', $month, $day), sprintf('%-100s', $results->{'accomplishments'}));
        }
    }
    $sth->finish;
    my $text;
    my $mode = $self->{'USER'}->{'text_mode'};
    if ($mode eq 'ANSI') {
        $text = $table->boxes->draw();
        foreach my $orig ('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS', 'BDAY', 'ACCOMPLISHMENTS') {
            my $ch = '[% BRIGHT YELLOW %]' . $orig . '[% RESET %]';
            $text =~ s/$orig/$ch/gs;
        }
        $text = $self->color_border($text,'GREEN');
    } elsif ($mode eq 'ATASCII') {
        $text = $self->color_border($table->boxes->draw(),'GREEN');
    } elsif ($mode eq 'PETSCII') {
        $text = $table->boxes->draw();
        foreach my $orig ('USERNAME', 'NICKNAME', 'FULLNAME', 'LOCATION', 'RETRO SYSTEMS', 'BDAY', 'ACCOMPLISHMENTS') {
            my $ch = '[% YELLOW %]' . $orig . '[% RESET %]';
            $text =~ s/$orig/$ch/gs;
        }
        $text = $self->color_border($text,'GREEN');
    } else {
        $text = $table->draw();
    }
    $self->{'debug'}->DEBUG(['End Users List']);
    return ($text);
}

sub users_add {
    my $self          = shift;
    my $user_template = shift;

    $self->{'debug'}->DEBUG(['Start Users Add']);
    $self->{'debug'}->DEBUGMAX([$user_template]);
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
              VALUES (?,?,?,?,?,?,?,DATE(?),?,?,(SELECT text_modes.id FROM text_modes WHERE text_modes.text_mode=?),SHA2(?,512))
        }
    );
    $sth->execute(
        $user_template->{'username'},
        $user_template->{'given'},
        $user_template->{'family'},
        $user_template->{'nickname'},
        $user_template->{'email'},
        $user_template->{'accomplishments'},
        $user_template->{'retro_systems'},
        $user_template->{'birthday'},
        $user_template->{'location'},
        $user_template->{'baud_rate'},
        $user_template->{'text_mode'},
        $user_template->{'password'},
    );
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
                play_fortunes,
                timeout)
              VALUES (LAST_INSERT_ID(),?,?,?,?,?,?,?,?,?,?,?,?,?);
        }
    );
    $sth->execute(
        $user_template->{'prefer_nickname'},
        $user_template->{'view_files'},
        $user_template->{'upload_files'},
        $user_template->{'download_files'},
        $user_template->{'remove_files'},
        $user_template->{'read_message'},
        $user_template->{'show_email'},
        $user_template->{'post_message'},
        $user_template->{'remove_message'},
        $user_template->{'sysop'},
        $user_template->{'page_sysop'},
        $user_template->{'play_fortunes'},
        $user_template->{'timeout'},
    );
    my $response;
    if ($self->{'dbh'}->err) {
        $self->{'dbh'}->rollback;
        $sth->finish();
        $response = FALSE;
    } else {
        $self->{'dbh'}->commit;
        $sth->finish();
        $response = TRUE;
    }
    $self->{'debug'}->DEBUG(['End Users Add']);
    return($response);
}

sub users_delete {
    my $self = shift;
    my $id   = shift;

    $self->{'debug'}->DEBUG(['Start Users Delete']);
    if ($id == 1) {
        $self->{'debug'}->ERROR(['  Attempt to delete SysOp user']);
        return(FALSE);
    }
    $self->{'debug'}->WARNING(["  Delete user $id"]);
    $self->{'dbh'}->begin_work();
    my $sth = $self->{'dbh'}->prepare('DELETE FROM permissions WHERE id=?');
    $sth->execute($id);
    if ($self->{'dbh'}->err) {
        $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
        $self->{'dbh'}->rollback();
        $sth->finish();
        $self->{'debug'}->DEBUG(['   End Users Delete']);
        return (FALSE);
    } else {
        $sth->finish();
        $sth = $self->{'dbh'}->prepare('DELETE FROM users WHERE id=?');
        $sth->execute($id);
        if ($self->{'dbh'}->err) {
            $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
            $self->{'dbh'}->rollback();
            $sth->finish();
            $self->{'debug'}->DEBUG(['   End Users Delete']);
            return (FALSE);
        } else {
            $self->{'dbh'}->commit();
            $sth->finish();
            $self->{'debug'}->DEBUG(['   End Users Delete']);
            return (TRUE);
        }
    }
    $self->{'debug'}->DEBUG(['End Users Delete']);
}

sub users_file_category {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users File Category']);
    my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'file_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    $self->{'debug'}->DEBUG(['End Users File Category']);
    return ($category);
}

sub users_forum_category {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Forum Category']);
    my $sth = $self->{'dbh'}->prepare('SELECT name FROM message_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'forum_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    $self->{'debug'}->DEBUG(['End Users Forum Category']);
    return ($category);
}

sub users_rss_category {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users RSS Category']);
    my $sth = $self->{'dbh'}->prepare('SELECT title FROM rss_feed_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'rss_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    $self->{'debug'}->DEBUG(['End Users RSS Category']);
    return ($category);
}

sub users_find {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start Users Find']);
    $self->{'debug'}->DEBUG(['End Users Find']);
    return(TRUE);
}

sub users_count {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Count']);
    my $sth = $self->{'dbh'}->prepare('SELECT COUNT(*) FROM users');
    $sth->execute();
    my ($count) = ($sth->fetchrow_array());
    $sth->finish();
    $self->{'debug'}->DEBUG(['End Users Count']);
    return ($count);
}

sub users_info {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Users Info']);
    my $table;
    my $text  = '';
    my $width = 1;

    foreach my $field (keys %{ $self->{'USER'} }) {
        $width = max($width, length($self->{'USER'}->{$field}));
    }

    my $columns = $self->{'USER'}->{'max_columns'};
    $self->{'debug'}->DEBUG(["  $columns Columns"]);
    if ($columns <= 40) {
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
    } elsif ((($width + 22) * 2) <= $columns) {
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

    my $mode = $self->{'USER'}->{'text_mode'};
    if ($mode eq 'ATASCII') {
        $text = $self->color_border($table->boxes->draw(),'WHITE');
    } elsif ($mode eq 'ANSI') {
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
            my $ch = colored(['yellow'], $field);
            $text =~ s/$field/$ch/gs;
        }
        $text = $self->color_border($text, 'RGB 0,90,190');
    } elsif ($mode eq 'PETSCII') {
        $text = $table->boxes->draw();
        my $no    = '[% RED %]NO[% RESET %]';
        my $yes   = '[% GREEN %]YES[% RESET %]';
        my $field = '[% YELLOW %]FIELD[% RESET %]';
        my $va    = '[% YELLOW %]VALUE[% RESET %]';
        $text =~ s/ FIELD / $field /gs;
        $text =~ s/ VALUE / $va /gs;
        $text =~ s/ NO / $no /gs;
        $text =~ s/ YES / $yes /gs;

        foreach $field ('PLAY FORTUNES','ACCESS LEVEL','SUFFIX','ACCOUNT NUMBER', 'USERNAME', 'FULLNAME', 'SCREEN', 'BIRTHDAY', 'LOCATION', 'BAUD RATE', 'LAST LOGIN', 'LAST LOGOUT', 'TEXT MODE', 'IDLE TIMEOUT', 'RETRO SYSTEMS', 'ACCOMPLISHMENTS', 'SHOW EMAIL', 'PREFER NICKNAME', 'VIEW FILES', 'UPLOAD FILES', 'DOWNLOAD FILES', 'REMOVE FILES', 'READ MESSAGES', 'POST MESSAGES', 'REMOVE MESSAGES', 'PAGE SYSOP', 'EMAIL', 'NICKNAME','DATE FORMAT') {
            my $ch = '[% BROWN %]' . $field . '[% RESET %]';
            $text =~ s/$field/$ch/gs;
        }
        $text = $self->color_border($text, 'BLUE');
    } else {
        $text = $table->draw();
    }
    $self->{'debug'}->DEBUG(['End Users Info']);
    return ($text);
}

 

# MANUAL IMPORT HERE #

1;
