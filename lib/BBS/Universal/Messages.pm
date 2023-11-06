package BBS::Universal::Messages;

use strict;
use constant {
    TRUE  => 1,
    FALSE => 0
};

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      list_sections
      list_messages
      read_message
      edit_message
      delete_message
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

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
