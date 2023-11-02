package BBS::Universal::Users;

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
        users_list
        user_add
        user_edit
        user_delete
        user_find
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

sub users_list {
    my $self = shift;
}

sub user_add {
    my $self = shift;
}

sub user_edit {
    my $self = shift;
}

sub user_delete {
    my $self = shift;
}

sub user_find {
    my $self = shift;
}


1;
