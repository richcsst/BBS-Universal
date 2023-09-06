package BBS::Universal;

use strict;
use constant {
	TRUE    => 1,
	FALSE   => 0,

	ASCII   => 0,
	ATASCII => 1,
	PETSCII => 2,
	VT102   => 3,

	THREADS => 16,
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

my @translations : shared = qw( ASCII ATASCII PETSCII VT-102 );
my $translation  : shared = 'ASCII';

sub DESTROY {
	my $self = shift;
}

sub new {
}

1;
