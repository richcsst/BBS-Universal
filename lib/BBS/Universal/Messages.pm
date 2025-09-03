package BBS::Universal::Messages;
BEGIN { our $VERSION = '0.001'; }

sub messages_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized Messages']);
    return ($self);
} ## end sub messages_initialize

sub messages_forum_categories {
    my $self = shift;
    return(TRUE);
}

sub messages_list_messages {
    my $self = shift;
    return(TRUE);
}

sub messages_read_message {
    my $self = shift;
    return(TRUE);
}

sub messages_edit_message {
    my $self = shift;
    my $mode = shift;
    if ($mode eq 'ADD') {
        $self->output("Add New Message\n");
        my $message = $self->text_editor();
		if (defined($message) && $message ne '') {
		}
    } else { # EDIT
        $self->output("Edit Message\n");
        my $message = $self->text_editor();
		if (defined($message) && $message ne '') {
		}
    }
    return(TRUE);
}

sub messages_delete_message {
    my $self = shift;
    return(TRUE);
}
1;
