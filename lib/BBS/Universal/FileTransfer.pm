package BBS::Universal::FileTransfer;

use strict;
use constant {
    TRUE  => 1,
    FALSE => 0
};

use File::Basename;

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      load_file
      save_file
      send_file
      receive_file
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

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
