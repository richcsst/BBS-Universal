package BBS::Universal::DB;

use strict;
no strict 'subs';

use Debug::Easy;
use DBI;
use DBD::mysql;

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      db_connect
      db_disconnect
      db_query
      db_insert
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

sub db_connect {
    my $self = shift;

    return (TRUE);
}

sub db_disconnect {
    my $self = shift;

    return (TRUE);
}

sub db_query {
    my $self  = shift;
    my $table = shift;
    my @names = @_;

    return (TRUE);
} ## end sub db_query

sub db_insert {
    my $self  = shift;
    my $table = shift;
    my $hash  = shift;

    return (TRUE);
} ## end sub db_insert

1;
