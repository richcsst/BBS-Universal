package BBS::Universal::Users;

use parent qw( BBS::Universal );

use strict;
no strict 'subs';

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      users_list
      user_add
      user_edit
      user_delete
      user_find
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

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
