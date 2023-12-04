package BBS::Universal::Users;
BEGIN { our $VERSION = '0.001'; }

sub users_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Users initialized']);
    return ($self);
} ## end sub users_initialize

sub users_list {
    my $self = shift;
}

sub users_add {
    my $self = shift;
}

sub users_edit {
    my $self = shift;
}

sub users_delete {
    my $self = shift;
}

sub users_find {
    my $self = shift;
}

sub users_count {
    my $self = shift;
    return (0);
}
1;
