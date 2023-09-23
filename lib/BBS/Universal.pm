package BBS::Universal;

use strict;
use constant {
	TRUE    => 1,
	FALSE   => 0,

	ASCII   => 0,
	ATASCII => 1,
	PETSCII => 2,
	VT102   => 3,

	MAX_THREADS => 16,
};
use English;
use utf8;
use Config;

use DateTime;
use File::Basename;
use Time::HiRes qw(time sleep);
use Term::ANSIScreen;
use Text::Format;
use Text::SimpleTable::AutoWidth;
use Sys::CPU;
use DBI;
use DBD::mysql;
use Debug::Easy;

use BBS::Universal::ASCII;   # Subs will have mode names as a prefix, so they can all be imported
use BBS::Universal::ATASCII;
use BBS::Universal::PETSCII;
use BBS::Universal::VT102;
use BBS::Universal::Messages;
use BBS::Universal::SysOp;
use BBS::Universal::File-Transfer;
use BBS::Universal::Users;

use threads (
	'yield',
	'exit' => 'threads_only',
	'stringify',
);
use threads::shared;

BEGIN {
	require Exporter;

	our $VERSION   = '0.01';
	our @ISA       = qw(Exporter);
	our @EXPORT    = qw();
	our @EXPORT_OK = qw();
};

my $translation  : shared = 'ASCII';
my $suffixes     : shared = { # File types by suffix, kind of "MIME"ish
    'ASCII'   => 'ASC',
    'ATASCII' => 'ATA',
    'PETSCII' => 'PET',
    'VT102'   => 'VT',
};
my $speeds : shared = { # delays for simulating baud rates
    'FULL'  => 0,
    '300'   => 0.02,
    '1200'  => 0.005,
    '2400'  => 0.0025,
    '9600'  => 0.000625,
    '19200' => 0.0003125,
};
my @translations = keys %{$suffixes};

my $DSN = "DBI:mysql:database=BBSUniversal;host=$DBHOST";

sub DESTROY {
	my $self = shift;
    $self->{'dbh'}->disconnect();
}

sub new {
    my $class = shift;

    my $self ={};
    bless($self,$class);

    $self = {
        'dbh'          => DBI->connect($DSN,$DBUSER,$DBPASS),
        'cpu'          => Sys::CPU::cpu_count(),
        'cpu_clock'    => Sys::CPU::cpu_clock(),
        'cpu_type'     => Sys::CPU::cpu_type(),
        'os'           => chomp(`/usr/bin/uname -a`),
        'perl_version' => $OLD_PERL_VERSION,
        'bbs_name'     => $self->configuration('bbs_name'),
        'bbs_version'  => "BBS Universal - Version $VERSION",
    };

    return($self);
}

sub configuration {
    my $self  = shift;
    my $count = scalar(@_);
    if ($count == 1) { # Get single value
        my $name = shift;
        my $result;
        return($result);
    } elsif ($count == 2) { # Set a single value
        my $name  = shift;
        my $value = shift;
        return(TRUE);
    } else { # Get entire configuration
        my $results;
        return($results);
    }
}

sub server { # Main connection loop
    my $self = shift;
}

sub main_menu { # Handle main menu
    my $self = shift;
}

sub categories_menu { # Handle categories menu
    my $self = shift;
}

sub get_key {
    my $self = shift;
    my $key;

    return($key);
}

sub get_line {
    my $self = shift;
    my $line;

    return($line);
}

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
        'UPTIME'             => split(chomp(`/usr/bin/uptime`),' ',1),
        'PERL VERSION'       => $self->{'perl_version'},
        'BBS NAME'           => $self->{'bbs_name'},
        'BBS VERSION'        => $self->{'bbs_version'},
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
        $text =~ s/\[\% $key \%\]/$tokens->{$key}/g;
    }
    return($text);
}


1;
