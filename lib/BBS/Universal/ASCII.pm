package BBS::Universal::ASCII;

use strict;
use constant {
	TRUE  => 1,
	FALSE => 0
};

use DateTime;
use Time::HiRes qw(time sleep);

BEGIN {
	require Exporter;

	our $VERSION   = '0.01';
	our @ISA       = qw(Exporter);
	our @EXPORT    = qw(
        ascii_output
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

sub ascii_output {
    my $self = shift;
    my $string = shift;

    
}

1;
