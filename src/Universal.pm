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

    # VERSIONS #
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

L<https://perlfoundation.org/artistic-license-20.html>

Any use, modification, and distribution of the Standard or Modified Versions is governed by this Artistic License. By using, modifying or distributing the Package, you accept this license. Do not use, modify, or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made by someone other than you, you are nevertheless required to ensure that your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge patent license to make, have made, use, offer to sell, sell, import and otherwise transfer the Package with respect to any patent claims licensable by the Copyright Holder that are necessarily infringed by the Package. If you institute patent litigation (including a cross-claim or counterclaim) against any party alleging that the Package constitutes direct or contributory patent infringement, then this Artistic License to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES. THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

# MANUAL IMPORT HERE #

1;
