package BBS::Universal::Messages;
BEGIN { our $VERSION = '0.001'; }

sub messages_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized Messages']);
    return ($self);
} ## end sub messages_initialize

sub messages_forum_categories {
    my $self = shift;
}

sub messages_list_messages {
    my $self = shift;
}

sub messages_read_message {
    my $self = shift;
}

sub messages_edit_message {
    my $self = shift;
}

sub messages_delete_message {
    my $self = shift;
}
1;
