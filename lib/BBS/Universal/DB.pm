package BBS::Universal::DB;

use strict;
use constant {
	TRUE  => 1,
	FALSE => 0
};

use threads;
use threads::shared;
use DateTime;
use Time::HiRes qw(time sleep);
use File::Basename;
use Config;
use DBI;
use DBD::mysql;

BEGIN {
	require Exporter;

	our $VERSION   = '0.001';
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
