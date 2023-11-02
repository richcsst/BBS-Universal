package BBS::Universal::FileTransfer;

use strict;
use constant {
	TRUE  => 1,
	FALSE => 0
};

use DateTime;
use Time::HiRes qw(time sleep);
use File::Basename;
use Config;
use threads;
use threads::shared;

BEGIN {
	require Exporter;

	our $VERSION   = '0.001';
	our @ISA       = qw(Exporter);
	our @EXPORT    = qw(
        load_file
        save_file
        send_file
        receive_file
    );
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

sub load_file {
    my $self = shift;
}

sub save_file {
    my $self = shift;
}

sub receive_file {
    my $self = shift;
}

sub send_file {
    my $self = shift;
}

1;
