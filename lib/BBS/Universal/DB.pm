package BBS::Universal::DB;
BEGIN { our $VERSION = '0.001'; }

sub db_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized DB']);
    return ($self);
} ## end sub db_initialize

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
