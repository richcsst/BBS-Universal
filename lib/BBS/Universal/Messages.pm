package BBS::Universal::Messages;

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
        list_sections
        list_messages
        read_message
        edit_message
        delete_message
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

1;
