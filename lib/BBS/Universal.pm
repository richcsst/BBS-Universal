package BBS::Universal;

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
use utf8;
use Config;

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
use Debug::Easy; our $debug = Debug::Easy->new( 'LogLevel' => 'ERROR', 'Color' => 1 );

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
    our @EXPORT_OK = qw();
	$ENV{'PATH'}   = '/usr/bin;/usr/local/bin'; # Taint mode requires this
} ## end BEGIN

my $translation = 'ASCII';
my $suffixes    = {          # File types by suffix, kind of "MIME"ish
    'ASCII'   => 'ASC',
    'ATASCII' => 'ATA',
    'PETSCII' => 'PET',
    'VT102'   => 'VT',
};
my $speeds = {               # delays for simulating baud rates
    'FULL'  => 0,
    '300'   => 0.02,
    '1200'  => 0.005,
    '2400'  => 0.0025,
    '9600'  => 0.000625,
    '19200' => 0.0003125,
};
my @translations = keys %{$suffixes};
my $RUNNING : shared = TRUE; # Thread keep running flag

sub DESTROY {
    my $self = shift;
    $self->{'dbh'}->disconnect();
}

sub new {
    my $class = shift;

    my $self = {};

	my $os = `/usr/bin/uname -a`;
    $self = {
        'cpu'          => Sys::CPU::cpu_count(),
        'cpu_clock'    => Sys::CPU::cpu_clock(),
        'cpu_type'     => Sys::CPU::cpu_type(),
        'os'           => $os,
        'versions'     => {
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
        'default_width'   => 40,
        'default_height'  => 24,
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
        'baud_rate'       => 'FULL',
    };
    bless($self, $class);
	$self->{'bbs_name'} = $self->configuration('bbs_name');

    return ($self);
} ## end sub new

sub configuration {
    my $self  = shift;
    my $count = scalar(@_);
    if ($count == 1) {    # Get single value
        my $name = shift;
        my $result;
        return ($result);
    } elsif ($count == 2) {    # Set a single value
        my $name  = shift;
        my $value = shift;
        return (TRUE);
    } else {                   # Get entire configuration
        my $results;
        return ($results);
    }
} ## end sub configuration

sub server {    # Main connection loop
    my $self = shift;
}

sub main_menu {    # Handle main menu
    my $self = shift;
}

sub categories_menu {    # Handle categories menu
    my $self = shift;
}

sub get_key {
    my $self = shift;
    my $key;

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
		if ($key eq 'VERSIONS' && $text =~ /$key/) {
			my $versions = '';
			foreach my $names (sort(keys %{$self->{'versions'}})) {
				$versions .= ucfirst($names) . ' - ' . $self->{'versions'}->{$names} . "\n";
			}
		} else {
			$text =~ s/\[\% $key \%\]/$tokens->{$key}/g;
		}
    }
    return ($text);
} ## end sub detokenize_text

1;
