package BBS::Universal::Messages;
BEGIN { our $VERSION = '0.001'; }

sub messages_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized Messages']);
    return ($self);
} ## end sub messages_initialize

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
