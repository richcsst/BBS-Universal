package BBS::Universal;

# Pragmas
use strict;
use constant {
    TRUE  => 1,
    FALSE => 0,

    ASCII   => 0,
    ATASCII => 1,
    PETSCII => 2,
    VT102   => 3,

    MAX_THREADS => 16,
};
use English qw( -no_match_vars );
use Config;

# Modules
use threads (
    'yield',
    'exit' => 'threads_only',
    'stringify',
);
use threads::shared;
use DateTime;
use File::Basename;
use Time::HiRes qw(time sleep);
use Term::ANSIScreen;
use Text::Format;
use Text::SimpleTable::AutoWidth;
use Sys::CPU;
use IO::Socket;
use IO::Socket::INET;
use Debug::Easy;
our $debug = Debug::Easy->new('LogLevel' => 'ERROR', 'Color' => 1);

use BBS::Universal::ASCII;    # Subs will have mode names as a prefix, so they can all be imported
use BBS::Universal::ATASCII;
use BBS::Universal::PETSCII;
use BBS::Universal::VT102;

use BBS::Universal::Messages;
use BBS::Universal::SysOp;
use BBS::Universal::FileTransfer;
use BBS::Universal::Users;
use BBS::Universal::DB;

BEGIN {
    require Exporter;

    our $VERSION   = '0.001';
    our @ISA       = qw(Exporter);
    our @EXPORT    = qw();
    our @EXPORT_OK = qw(
      $suffixes
      $speeds
    );
    $ENV{'PATH'} = '/usr/bin;/usr/local/bin';    # Taint mode requires this (for test scripts)
} ## end BEGIN

my $suffixes = {                                 # File types by suffix, kind of "MIME"ish
    'ASCII'   => 'ASC',
    'ATASCII' => 'ATA',
    'PETSCII' => 'PET',
    'VT102'   => 'VT',
};
my $speeds = {                                   # delays for simulating baud rates (not 100% accurate, but close enough)
    'FULL'  => 0,
    '300'   => 0.02,
    '1200'  => 0.005,
    '2400'  => 0.0025,
    '9600'  => 0.000625,
    '19200' => 0.0003125,                        # Is Time::HiRes even this granular?
};
my $RUNNING : shared = TRUE;                     # Thread keep running flag

sub DESTROY {
    my $self = shift;
    $self->{'dbh'}->disconnect();
}

sub new {    # Always call with the socket as a parameter
    my $class     = shift;
    my $socket    = shift;
    my $cl_socket = shift;
    my $dbg       = shift;

    my $self = {};

    my $os = `/usr/bin/uname -a`;
    $self = {
        'debug'     => $dbg,
        'socket'    => $socket,
        'cl_socket' => $cl_socket,
        'peerhost'  => $cl_socket->peerhost(),
        'peerport'  => $cl_socket->peerport(),
        'cpu'       => Sys::CPU::cpu_count(),
        'cpu_clock' => Sys::CPU::cpu_clock(),
        'cpu_type'  => Sys::CPU::cpu_type(),
        'os'        => $os,
        'versions'  => {
            'perl'         => "Perl - Version $OLD_PERL_VERSION",
            'bbs'          => "BBS::Universal - Version $BBS::Universal::VERSION",
            'ascii'        => "BBS::Universal::ASCII - Version $BBS::Universal::ASCII::VERSION",
            'atascii'      => "BBS::Universal::ATASCII - Version $BBS::Universal::ATASCII::VERSION",
            'petscii'      => "BBS::Universal::PETSCII - Version $BBS::Universal::PETSCII::VERSION",
            'vt102'        => "BBS::Universal::VT102 - Version $BBS::Universal::VT102::VERSION",
            'messages'     => "BBS::Universal::Messages - Version $BBS::Universal::Messages::VERSION",
            'sysop'        => "BBS::Universal::SysOp - Version $BBS::Universal::SysOp::VERSION",
            'filetransfer' => "BBS::Universal::FileTransfer - Version $BBS::Universal::FileTransfer::VERSION",
            'users'        => "BBS::Universal::Users - Version $BBS::Universal::Users::VERSION",
            'db'           => "BBS::Universal::DB - Version $BBS::Universal::DB::VERSION",
        },
        'suffixes'        => $suffixes,
        'speeds'          => $speeds,
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
        'mode'            => 'ASCII',     # Default mode
        'bbs_name'        => undef,       # These are pulled in from the configuration or connection
        'baud_rate'       => undef,
        'user'            => undef,
    };
    bless($self, $class);
    $self->{'bbs_name'}  = $self->configuration('bbs_name');
    $self->{'baud_rate'} = $self->configuration('baud_rate');

    $debug->DEBUG("Socket connected from $self->{peerport} on port $self->{peerport}");
    my ($user, $error) = $self->run();    # BBS proper runs here.  New doesn't actually return an object
    shutdown($cl_socket, 1);
    $socket->close();
    return ($user, $error);
} ## end sub new

sub run {
    my $self = shift;

    my $error;

    if ($self->greeting()) {              # Greeting also logs in
        $self->main_menu();
    }
    $self->disconnect();
    return ($self->{'user'}, $error);
} ## end sub run

sub greeting {
    my $self = shift;

    # Load and print greetings message here
    my $text = $self->file_load('greetings');
    $self->output($text);
    return ($self->login());    # Login will also create new users
} ## end sub greeting

sub login {
    my $self = shift;

    my $valid = FALSE;

    # Login stuff here
    return ($valid);
} ## end sub login

sub main_menu {
    my $self = shift;

    my $disconnect = FALSE;
    do {
        my $text = $self->file_load('main_menu');
        $self->output($text);
        my $cmd = $self->get_key(TRUE);              # Wait for character
        if (defined($cmd) && length($cmd) == 1) {    # Sanity
        }
    } until ($disconnect);
} ## end sub main_menu

sub disconnect {
    my $self = shift;

    # Load and print disconnect message here
    my $text = $self->file_load('disconnect');
    $self->output($text);
} ## end sub disconnect

sub configuration {
    my $self  = shift;
    my $count = scalar(@_);
    if ($count == 1) {    # Get single value
        my $name = shift;
        $debug->DEBUG("Configuration query for $name");
        my $result;
        return ($result);
    } elsif ($count == 2) {    # Set a single value
        my $name  = shift;
        my $value = shift;
        $debug->DEBUG("Configuration set $name = $value");
        return (TRUE);
    } else {                   # Get entire configuration
        my $results;
        $debug->DEBUG('Configuration query for all');
        $debug->DEBUGMAX($results);
        return ($results);
    } ## end else [ if ($count == 1) ]
} ## end sub configuration

sub categories_menu {    # Handle categories menu
    my $self = shift;
}

sub get_key {
    my $self     = shift;
    my $echo     = shift || FALSE;
    my $blocking = shift || FALSE;

    my $key;
    if ($blocking) {
        $self->{'cl_socket'}->recv($key, 1, MSG_WAITALL);
    } else {
        $self->{'cl_socket'}->recv($key, 1, MSG_DONTWAIT);
    }

    $self->output($key) if ($echo && defined($key));
    return ($key);
} ## end sub get_key

sub get_line {
    my $self = shift;
    my $line;

    return ($line);
} ## end sub get_line

sub detokenize_text {

    # Detokenize text markup
    my $self = shift;
    my $text = shift;

    my $tokens = {
        'AUTHOR'             => 'Richard Kelsch',
        'SYSOP'              => $self->{'sysop'},
        'CPU'                => $self->{'cpu'},
        'CPU CORES'          => $self->{'cpu_count'},
        'CPU SPEED'          => $self->{'cpu_clock'},
        'CPU TYPE'           => $self->{'cpu_type'},
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

    foreach my $key (keys %$tokens) {
        if ($key eq 'VERSIONS' && $text =~ /$key/i) {
            my $versions = '';
            foreach my $names (sort(keys %{ $self->{'versions'} })) {
                $versions .= $self->{'versions'}->{$names} . "\n";
            }
            $text =~ s/\[\% $key \%\]/$versions/gi;
        } else {
            $text =~ s/\[\% $key \%\]/$tokens->{$key}/gi;
        }
    } ## end foreach my $key (keys %$tokens)
    return ($text);
} ## end sub detokenize_text

sub output {
    my $self = shift;
    my $text = $self->detokenize_text(shift);

    my $mode = $self->{'MODE'};
    if ($mode eq 'ATASCII') {
        $self->atascii_output($text);
    } elsif ($mode eq 'PETSCII') {
        $self->petscii_output($text);
    } elsif ($mode eq 'VT102') {
        $self->vt102_output($text);
    } else {    # ASCII
        $self->ascii_output($text);
    }
    return ($text);
} ## end sub output

sub send_char {
    my $self = shift;
    my $char = shift;

    # This sends one character at a time to the socket to simulate a retro BBS
    $self->{'socket'}->send($char);

    # Send at the chosen baud rate by delaying the output by a fraction of a second
    # Only delay if the baud_rate is not FULL
    sleep $self->{'speeds'}->{ $self->{'baud_rate'} } if ($self->{'baud_rate'} ne 'FULL');
} ## end sub send_char

sub _server {    # Main connection loop
    my $host   = shift;
    my $port   = shift;
    my $socket = IO::Socket::INET->new(
        'LocalHost' => $host,
        'LocalPort' => $port,
        'Proto'     => 'tcp',
        'Listen'    => MAX_THREADS,
        'ReuseAddr' => FALSE,
        'Timeout'   => 30,
        'Blocking'  => TRUE,
    );

    my $error;
    $error = "Cannot create socket $!n" unless ($socket);
    $socket->autoflush();
    $debug->DEBUG("Server started");
    while ($RUNNING && !defined($error)) {
        my $client_socket = $socket->accept();    # Blocking until connection received
                                                  # we ALWAYS limit connections to avoid an attack
        {
            my @THREADS = threads->list(threads::running);
            if (scalar(@THREADS) < MAX_THREADS) {
                my $thr = threads->create(\&BBS::Universal::new, $socket, $client_socket, $debug);
            } else {
                $client_socket->send("\n\nSorry, too many users.  Please try later\n\n");
                shutdown($client_socket, 1);
                $socket->close();
            }
            $socket = IO::Socket::INET->new(
                'LocalHost' => $host,
                'LocalPort' => $port,
                'Proto'     => 'tcp',
                'Listen'    => MAX_THREADS,
                'ReuseAddr' => FALSE,
                'Timeout'   => 30,
                'Blocking'  => TRUE,
            );
            $error = "Cannot create socket $!n" unless ($socket);
        }
        _clean_joinable();
    } ## end while ($RUNNING && !defined...)
    $RUNNING = FALSE;    # Just in case this was a socket error
    $debug->DEBUG('Shutdown...');
    while (threads->list(threads::running)) {    # Make sure everyone got the shutdown message first
        threads->yield();
    }
    _clean_joinable();
} ## end sub _server

sub _clean_joinable {
    my @joinable = threads->list(threads::joinable);
    foreach my $thread (@joinable) {
        my ($user, $error) = $thread->join() if ($thread->is_joinable);    # A bit of a sanity check before actually joining

        $debug->ERROR($error) if (defined($error));
        $debug->DEBUGMAX($user);
    } ## end foreach my $thread (@joinable)
} ## end sub _clean_joinable

1;
