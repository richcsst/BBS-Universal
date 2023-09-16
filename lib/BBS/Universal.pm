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

use BBS::Universal::ASCII;
use BBS::Universal::ATASCII;
use BBS::Universal::PETSCII;
use BBS::Universal::VT102;
use BBS::universal::Messages;
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
my @translations = keys %{$suffixes};

my $CORES     = Sys::CPU::cpu_count();
my $CPU_SPEED = Sys::CPU::cpu_clock();
my $CPU_TYPE  = SYS::CPU::cpu_type();

my $DSN = "DBI:mysql:database=BBSUniversal;host=$DBHOST";

sub DESTROY {
	my $self = shift;
    $self->{'dbh'}->disconnect();
}

## Tables
# config - These are file names
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    bbs_name VARCHAR(255) DEFAULT 'BBS Universal'
#    greeting VARCHAR(255)
#    logout VARCHAR(255)
#    sys_info VARCHAR(255)
#    policy VARCHAR(255)
#    threads SMALLINT UNSIGNED DEFAULT 2
#    connect_mode VARCHAR(8) DEFAULT 'ASCII'
# users -
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    username VARCHAR(255)
#    password PASSWORD
#    given VARCHAR(255)
#    family VARCHAR(255)
#    permissions UNSIGNED INTEGER
# messages -
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    from_id INTEGRER UNSIGNED INTEGER NOT NULL
#    title VARCHAR(255)
#    message TEXT
#    created TIMESTAMP
# message categories -
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    name VARCHAR(255) NOT NULL
#    description VARCHAR(255) # file
# file_categories -
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    name VARCHAR(255)
#    description VARCHAR(255)
# permissions -
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    view_files BOOLEAN DEFAULT 0
#    post_files BOOLEAN DEFAULT 0
#    download_files BOOLEAN DEFAULT 0
#    remove_files BOOLEAN DEFAULT 0
#    read_message BOOLEAN DEFAULT 0
#    post_message BOOLEAN DEFAULT 0
#    remove_message BOOLEAN DEFAULT 0
#    sysop BOOLEAN DEFAULT 0
#    timeout INT UNSIGNED DEFAULT 10
# files -
#    id INTEGER UNSIGNED AUTOINCREMENT NOT NULL
#    filename VARCHAR(255)
#    title VARCHAR(255)
#    category INTEGER UNSIGNED NOT NULL
#    description TEXT
#    size BIGINTEGER UNSIGNED NOT NULL
#    uploaded TIMESTAMP
#    endorsement INTEGER UNSIGNED NOT NULL

sub new {
    my $class = shift;

    my $self = {
        'dbh' => DBI->connect($DSN,$DBUSER,$DBPASS),
    };
    bless($self, $class);
    return($self);
}

sub configuration {
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
}

1;
