package BBS::Universal::Messages;
BEGIN { our $VERSION = '0.001'; }

sub messages_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized Messages']);
    return ($self);
} ## end sub messages_initialize

sub messages_forum_categories {
    my $self = shift;

	my $command = '';
	my $id;
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM message_categories WHERE id<>? ORDER BY name');
    $sth->execute($self->{'USER'}->{'forum_category'});
    my $mapping = {
        'TEXT' => '',
        'Z'    => {
            'command'      => 'BACK',
            'color'        => 'WHITE',
            'access_level' => 'USER',
            'text'         => 'Return to Forum Menu',
        },
    };
    my @menu_choices = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y));
    while(my $result = $sth->fetchrow_hashref()) {
        if ($self->check_access_level($result->{'access_level'})) {
             $mapping->{shift(@menu_choices)} = {
                'command'      => $result->{'name'},
				'id'           => $result->{'id'},
                'color'        => 'WHITE',
                'access_level' => $result->{'access_level'},
                'text'         => $result->{'description'},
            };
		}
	}
	$sth->finish();
	$self->{'debug'}->DEBUGMAX($mapping);
    $self->show_choices($mapping);
	$self->output("\n" . $self->prompt('Choose Forum Category'));
	my $key;
	do {
		$key = uc($self->get_key(SILENT, FALSE));
	} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	if ($key eq chr(3)) {
		$command = 'DISCONNECT';
	} else {
		$id      = $mapping->{$key}->{'id'};
		$command = $mapping->{$key}->{'command'};
	}
	$self->{'debug'}->DEBUGMAX([$key, $mapping->{$key}]);
	if ($self->is_connected() && $command ne 'DISCONNECT') {
		$self->output($command);
		$sth = $self->{'dbh'}->prepare('UPDATE users SET forum_category=? WHERE id=?');
		$sth->execute($id,$self->{'USER'}->{'id'});
		$sth->finish();
		$self->{'USER'}->{'forum_category'} = $id;
		$command = 'BACK';
	}
    return($command);
}

sub messages_list_messages {
    my $self = shift;

	my $forum_category = $self->{'USER'}->{'forum_category'};
    $self->output('[% CLEAR %][% BRIGHT B_GREEN %][% BLACK %] FORUM CATEGORY [% RESET %] [% MAGENTA %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% FORUM CATEGORY %]' . "\n\n");
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM messages_view WHERE category=? AND hidden<>TRUE');
    $sth->execute($forum_category);
    while(my $result = $sth->fetchrow_hashref()) {
		last unless ($self->is_connected || $self->{'sysop'} || $self->{'local_mode'});
		$self->{'debug'}->DEBUGMAX($result);
		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output('[% INVERT %]  Author [% RESET %]  ' . $result->{'author_fullname'} . ' (' . $result->{'author_username'} . ')' . "\n");
			$self->output('[% INVERT %]   Title [% RESET %]  ' . $result->{'title'} . "\n");
			$self->output('[% INVERT %] Created [% RESET %]  ' . $self->users_get_date($result->{'created'}) . "\n\n");
			$self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'remove_message'});
		} else {
			$self->output(' Author:  ' . $result->{'author_fullname'} . ' (' . $result->{'author_username'} . ')' . "\n");
			$self->output('  Title:  ' . $result->{'title'} . "\n");
			$self->output('Created:  ' . $self->users_get_date($result->{'created'}) . "\n\n");
			$self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'remove_message'});
		}
		$self->output("\n");
        my $mapping = {
            'Z' => {
                'command'      => 'BACK',
                'color'        => 'WHITE',
                'access_level' => 'USER',
                'text'         => 'Return to the Forum Menu',
            },
			'N' => {
                'command'      => 'NEXT',
                'color'        => 'BRIGHT BLUE',
                'access_level' => 'USER',
                'text'         => 'Next Message',
            },
        };
        if ($self->{'USER'}->{'post_message'}) {
            $mapping->{'R'} = {
                'command'      => 'REPLY',
                'color'        => 'BRIGHT GREEN',
                'access_level' => 'USER',
				'text'         => 'Reply',
            };
        }
        if ($self->{'USER'}->{'remove_message'}) {
            $mapping->{'D'} = {
                'command'      => 'DELETE',
                'color'        => 'RED',
                'access_level' => 'VETERAN',
				'text'         => 'Delete Message',
            };
        }
		$self->{'debug'}->DEBUGMAX($mapping);
        $self->show_choices($mapping);
        $self->output("\n" . $self->prompt('Choose'));
        my $key;
        do {
            $key = uc($self->get_key(SILENT, FALSE));
        } until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
        my $id;
        my $command;
        if ($key eq chr(3)) {
            $command = 'DISCONNECT';
        } else {
            $id      = $mapping->{$key}->{'id'};
            $command = $mapping->{$key}->{'command'};
        }
		$self->output($command);
		if ($command eq 'READ') {
			$self->messages_read_message($result);
		} elsif ($command eq 'REPLY') {
			$self->messages_add_message($result);
		} elsif ($command eq 'DELETE') {
			$self->messages_delete_message($result);
		}
        last if ($command =~ /DISCONNECT|BACK/);
    }
    $sth->finish();
    return(TRUE);
}

sub messages_add_message {
    my $self          = shift;
	my $reply_message = shift || undef;
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
	$self->output("\n\nReally Delete This Message?  ");
	if ($self->decision()) {
	}
    return(TRUE);
}
1;
