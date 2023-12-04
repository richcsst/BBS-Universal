package BBS::Universal;

# Pragmas
use strict;
no strict 'subs';
use utf8;
use constant {
    TRUE  => 1,
    FALSE => 0,

    ASCII   => 0,
    ATASCII => 1,
    PETSCII => 2,
    VT102   => 3,
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
use Text::SimpleTable::AutoWidth;
use IO::Socket::INET;
use Sys::Info;
use Sys::Info::Constants qw( :device_cpu );

# use Data::Dumper::Simple;

BEGIN {
    require Exporter;

    # Due to Perl being a royal pain in the ass to coerce into inheriting methods, this is a sledge hammer approach

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      TRUE
      FALSE
      ASCII
      ATASCII
      PETSCII
      VT102
    );
    our @EXPORT_OK = qw();
    binmode(STDOUT, ":encoding(UTF-8)");
    our $ASCII_VERSION = '0.001';
    our $ATASCII_VERSION = '0.001';
    our $DB_VERSION = '0.001';
    our $FILETRANSFER_VERSION = '0.001';
    our $MESSAGES_VERSION = '0.001';
    our $PETSCII_VERSION = '0.001';
    our $SYSOP_VERSION = '0.001';
    our $USERS_VERSION = '0.001';
    our $VT102_VERSION = '0.001';
} ## end BEGIN

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
    $self->ascii_initialize()->atascii_initialize()->petscii_initialize()->vt102_initialize()->filetransfer_initialize()->messages_initialize()->sysop_initialize()->users_initialize()->db_initialize();
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
        'suffixes'        => qw( ASC ATA PET VT ),
        'speeds'          => {                       # This depends on the granularity of Time::HiRes
            'FULL'  => 0,
            '300'   => 0.02,
            '1200'  => 0.005,
            '2400'  => 0.0025,
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
    $self->ascii_initialize()->atascii_initialize()->petscii_initialize()->vt102_initialize()->filetransfer_initialize()->messages_initialize()->sysop_initialize()->users_initialize()->db_initialize();
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
            foreach my $names (qw( perl bbs db filetransfer messages sysop users ascii atascii petscii vt102)) {
                $versions .= $self->{'versions'}->{$names} . "\n";
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
    } elsif ($mode == VT102) {
        $self->{'debug'}->DEBUG(['Send VT-102']);
        $self->vt102_output($text);
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

sub configuration {
    my $self = shift;

    # Placeholder code for testing before DB code is ready
    ######################################################
    my $temp = {
        'HOST'              => '0.0.0.0',
        'PORT'              => 9999,
        'BBS ROOT'          => '/home/rich/source/github/BBS-Universal',
        'THREAD MULTIPLIER' => 8,
        'BBS NAME'          => 'The Looney Bin!',
        'BAUD RATE'         => 2400,
        'VERSIONS'          => $self->parse_versions(),
    };
    #######################################################
    my $count = scalar(@_);
    if ($count == 1) {    # Get single value
        my $name = shift;

        # Placeholder code for testing before DB code is ready
        ######################################################
        my $result = $temp->{$name};
        ######################################################
        return ($result);
    } elsif ($count == 2) {    # Set a single value
        my $name  = shift;
        my $value = shift;
        return (TRUE);
    } else {                   # Get entire configuration
                               # Placeholder code for testing before DB code is ready
        ######################################################
        my $results = $temp;
        ######################################################
        return ($results);
    } ## end else [ if ($count == 1) ]
} ## end sub configuration

sub parse_versions {
    my $self = shift;

    my $versions = {
        'perl'         => "Perl                          $OLD_PERL_VERSION",
        'bbs'          => "BBS::Universal                $BBS::Universal::VERSION",
        'ascii'        => "BBS::Universal::ASCII         $BBS::Universal::ASCII_VERSION",
        'atascii'      => "BBS::Universal::ATASCII       $BBS::Universal::ATASCII_VERSION",
        'petscii'      => "BBS::Universal::PETSCII       $BBS::Universal::PETSCII_VERSION",
        'vt102'        => "BBS::Universal::VT102         $BBS::Universal::VT102_VERSION",
        'messages'     => "BBS::Universal::Messages      $BBS::Universal::MESSAGES_VERSION",
        'sysop'        => "BBS::Universal::SysOp         $BBS::Universal::SYSOP_VERSION",
        'filetransfer' => "BBS::Universal::FileTransfer  $BBS::Universal::FILETRANSFER_VERSION",
        'users'        => "BBS::Universal::Users         $BBS::Universal::USERS_VERSION",
        'db'           => "BBS::Universal::DB            $BBS::Universal::DB_VERSION",
    };
    return ($versions);
} ## end sub parse_versions

sub cpu_info {
    my $self = shift;

    my $info     = Sys::Info->new();
    my $cpu      = $info->device('CPU');
    my $identity = $cpu->identify();
    $identity =~ s/^\d+ x //;    # Strip off the multiplier.  We already get that elsewhere
    my $speed = $cpu->speed();
    if ($speed > 999.999) {      # GHz
        $speed = sprintf('%.02f GHz', ($speed / 1000));
    } else {                     # MHz
        $speed = sprintf('%.02f MHz', $speed);
    }
    my $response = {
        'CPU IDENTITY' => $identity,
        'CPU SPEED'    => $speed,
        'CPU CORES'    => $cpu->count(),
        'CPU THREADS'  => $cpu->ht(),
        'CPU BITS'     => $cpu->bitness(),
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

    return (TRUE);
}

sub db_disconnect {
    my $self = shift;

    return (TRUE);
}

sub db_query {
    my $self  = shift;
    my $table = shift;
    my @names = @_;

    return (TRUE);
} ## end sub db_query

sub db_insert {
    my $self  = shift;
    my $table = shift;
    my $hash  = shift;

    return (TRUE);
} ## end sub db_insert

 

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

    my $versions = "\t" . colored(['bold yellow on_red'], ' NAME                          VERSION') . colored(['on_red'], clline) . "\n";
    foreach my $v (qw( perl bbs db filetransfer messages sysop users ascii atascii petscii vt102 )) {
        $versions .= "\t\t\t " . $self->{'CONF'}->{'VERSIONS'}->{$v} . "\n";
    }

    $self->{'sysop_special_characters'} = {
        'EURO'               => chr(128),
        'ELIPSIS'            => chr(133),
        'BULLET DOT'         => chr(149),
        'BIG HYPHEN'         => chr(150),
        'BIGGEST HYPHEN'     => chr(151),
        'TRADEMARK'          => chr(153),
        'CENTS'              => chr(162),
        'POUND'              => chr(163),
        'YEN'                => chr(165),
        'COPYRIGHT'          => chr(169),
        'DOUBLE LT'          => chr(171),
        'REGISTERED'         => chr(174),
        'OVERLINE'           => chr(175),
        'DEGREE'             => chr(176),
        'SQUARED'            => chr(178),
        'CUBED'              => chr(179),
        'MICRO'              => chr(181),
        'MIDDLE DOT'         => chr(183),
        'DOUBLE GT'          => chr(187),
        'QUARTER'            => chr(188),
        'HALF'               => chr(189),
        'THREE QUARTERS'     => chr(190),
        'INVERTED QUESTION'  => chr(191),
        'DIVISION'           => chr(247),
        'BULLET RIGHT'       => '▶',
        'BULLET LEFT'        => '◀',
        'SMALL BULLET RIGHT' => '▸',
        'SMALL BULLET LEFT'  => '◂',
        'BIG BULLET RIGHT'   => '►',
        'BIG BULLET LEFT'    => '◄',
        'BULLET DOWN'        => '▼',
        'BULLET UP'          => '▲',
        'WEDGE TOP LEFT'     => '◢',
        'WEDGE TOP RIGHT'    => '◣',
        'WEDGE BOTTOM LEFT'  => '◥',
        'WEDGE BOTTOM RIGHT' => '◤',

        # Tokens
        'CPU CORES'       => $self->{'CPU'}->{'CPU CORES'},
        'UPTIME'          => $self->get_uptime(),
        'VERSIONS'        => $versions,
        'BBS NAME'        => colored(['green'], $self->{'CONF'}->{'BBS NAME'}),
        'USERS COUNT'     => $self->users_count($self),
        'THREADS COUNT'   => int($self->{'CPU'}->{'CPU CORES'} * $self->{'CONF'}->{'THREAD MULTIPLIER'}),
        'DISK FREE SPACE' => sub {
            my @free     = split(/\n/, `df -h`);
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
        },
    };

    #$self->{'debug'}->ERROR($self);exit;
    $self->{'debug'}->DEBUG(['Initialized SysOp object']);
    return ($self);
} ## end sub sysop_initialize

sub sysop_load_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = { 'TEXT' => '' };
    my $mode    = 1;
    my $text    = locate($row, 1) . cldown;
    open(my $FILE, '<', $file);

    while (chomp(my $line = <$FILE>)) {
        $self->{'debug'}->DEBUGMAX([$line]);
        if ($mode) {
            if ($line !~ /^---/) {
                my ($k, $c, $t) = split(/\|/, $line);
                $k = uc($k);
                $c = uc($c);
                $self->{'debug'}->DEBUGMAX([$k, $c, $t]);
                $mapping->{$k} = {
                    'command' => $c,
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
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        print sprintf('%s%s%s %s %s', $self->{'sysop_special_characters'}->{'WEDGE TOP LEFT'}, colored(['reverse'], ' ' . uc($kmenu) . ' '), $self->{'sysop_special_characters'}->{'WEDGE BOTTOM RIGHT'}, $self->{'sysop_special_characters'}->{'BIG BULLET RIGHT'}, $mapping->{$kmenu}->{'text'}), "\n";
        $keys .= $kmenu;
    }
    print "\nChoose> ";
    my $key;
    do {
        $key = uc($self->sysop_keypress());
    } until (exists($mapping->{$key}));
    print $mapping->{$key}->{'command'}, "\n";
    return ($mapping->{$key}->{'command'});
} ## end sub sysop_parse_menu

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

sub sysop_user_edit {
    my $self = shift;

    return (TRUE);
}

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUGMAX([$text]);    # Before
    foreach my $key (keys %{ $self->{'sysop_special_characters'} }) {
        my $ch = '';
        if ($key =~ /DISK FREE SPACE/) {
            $ch = $self->{'sysop_special_characters'}->{$key}->($self);
        } else {
            $ch = $self->{'sysop_special_characters'}->{$key};
        }
        $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
    } ## end foreach my $key (keys %{ $self...})
    foreach my $name (keys %{ $self->{'vt102_sequences'} }) {
        my $ch = $self->{'vt102_sequences'}->{$name};
        $text =~ s/\[\%\s+$name\s+\%\]/$ch/gi;
    }
    $self->{'debug'}->DEBUGMAX([$text]);    # After

    return ($text);
} ## end sub sysop_detokenize

 

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

 

# package BBS::Universal::VT102;

sub vt102_initialize {
    my $self = shift;

    my $esc = chr(27) . '[';

    $self->{'vt_prefix'}       = $esc;
    $self->{'vt102_sequences'} = {
        'CLEAR' => $esc . '2J',

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
    };

    $self->{'debug'}->DEBUG(['Initialized VT102']);
    return ($self);
} ## end sub vt102_initialize

sub vt102_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Send VT102 text']);
    foreach my $string (keys %{ $self->{'vt102_sequences'} }) {
        $text =~ s/\[\% $string \%\]/$self->{'vt102_sequences'}->{$string}/gi;
    }
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub vt102_output

 

1;
