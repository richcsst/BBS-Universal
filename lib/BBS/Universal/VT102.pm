package BBS::Universal::VT-102;

use strict;
use constant {
	TRUE  => 1,
	FALSE => 0
};

use DateTime;
use Time::HiRes qw(time sleep);
use File::Basename;
use Config;
use Text::SimpleTable::AutoWidth;
use threads;
use threads::shared;

BEGIN {
	require Exporter;

	our $VERSION   = '0.01';
	our @ISA       = qw(Exporter);
	our @EXPORT    = qw();
	our @EXPORT_OK = qw();
}

sub DESTROY {
	my $self = shift;
}

sub new {
    my $class = shift;

    my $self = {};
    bless($self, $class);
    return($self);
}

1;
