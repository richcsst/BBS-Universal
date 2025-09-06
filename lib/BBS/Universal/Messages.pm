package BBS::Universal::Messages;
BEGIN { our $VERSION = '0.001'; }

sub messages_initialize {
    my $self = shift;

    return ($self);
}

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
    $self->show_choices($mapping);
	$self->output("\n" . $self->prompt('Choose Forum Category'));
	my $key;
	do {
		$key = uc($self->get_key(SILENT, BLOCKING));
	} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	if ($key eq chr(3)) {
		$command = 'DISCONNECT';
	} else {
		$id      = $mapping->{$key}->{'id'};
		$command = $mapping->{$key}->{'command'};
	}
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

	my $id;
	my $command;
	my $forum_category = $self->{'USER'}->{'forum_category'};
    my $sth = $self->{'dbh'}->prepare('SELECT id,from_id,category,author_fullname,author_nickname,author_username,title,created FROM messages_view WHERE category=? ORDER BY created DESC');
	my @index;
    $sth->execute($forum_category);
	while(my $record = $sth->fetchrow_hashref) {
		push(@index,$record);
	}
	$sth->finish();
	my $result;
	my $count = 0;
    do {
		$result = $index[$count];
		$sth = $self->{'dbh'}->prepare('SELECT message FROM messages_view WHERE id=? ORDER BY created DESC');
		$sth->execute($result->{'id'});
		$result->{'message'} = $sth->fetchrow_array();
		$sth->finish();

		if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
			$self->output('[% CLEAR %][% BRIGHT B_GREEN %][% BLACK %] FORUM CATEGORY [% RESET %] [% MAGENTA %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% FORUM CATEGORY %]' . "\n\n");
			$self->output('[% INVERT %]  Author [% RESET %]  ' . $result->{'author_fullname'} . ' (' . $result->{'author_username'} . ')' . "\n");
			$self->output('[% INVERT %]   Title [% RESET %]  ' . $result->{'title'} . "\n");
			$self->output('[% INVERT %] Created [% RESET %]  ' . $self->users_get_date($result->{'created'}) . "\n\n");
			$self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
		} else {
			$self->output('[% CLEAR %] FORUM CATEGORY > [% FORUM CATEGORY %]' . "\n\n");
			$self->output(' Author:  ' . $result->{'author_fullname'} . ' (' . $result->{'author_username'} . ')' . "\n");
			$self->output('  Title:  ' . $result->{'title'} . "\n");
			$self->output('Created:  ' . $self->users_get_date($result->{'created'}) . "\n\n");
			$self->output('[% WRAP %]' . $result->{'message'}) if ($self->{'USER'}->{'read_message'});
		}
		$self->output("\n");
		my $mapping = {
			'Z' => {
				'id'           => $result->{'id'},
				'command'      => 'BACK',
				'color'        => 'WHITE',
				'access_level' => 'USER',
				'text'         => 'Return to the Forum Menu',
			},
			'N' => {
				'id'           => $result->{'id'},
				'command'      => 'NEXT',
				'color'        => 'BRIGHT BLUE',
				'access_level' => 'USER',
				'text'         => 'Next Message',
			},
		};
		if ($self->{'USER'}->{'post_message'}) {
			$mapping->{'R'} = {
				'id'           => $result->{'id'},
				'command'      => 'REPLY',
				'color'        => 'BRIGHT GREEN',
				'access_level' => 'USER',
				'text'         => 'Reply',
			};
		}
		if ($self->{'USER'}->{'remove_message'}) {
			$mapping->{'D'} = {
				'id'           => $result->{'id'},
				'command'      => 'DELETE',
				'color'        => 'RED',
				'access_level' => 'VETERAN',
				'text'         => 'Delete Message',
			};
		}
		$self->show_choices($mapping);
		$self->output("\n" . $self->prompt('Choose'));
		my $key;
		do {
			$key = uc($self->get_key(SILENT, FALSE));
		} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
		if ($key eq chr(3)) {
			$id      = undef;
			$command = 'DISCONNECT';
		} else {
			$id      = $mapping->{$key}->{'id'};
			$command = $mapping->{$key}->{'command'};
		}
		$self->output($command);
		if ($command eq 'REPLY') {
			my $message = $self->messages_edit_message('REPLY',$result);
			push(@index,$message);
			$count = 0;
		} elsif ($command eq 'DELETE') {
			$self->messages_delete_message($result);
			delete($index[$count]);
		} else {
			$count++;
		}
		unless ($self->{'local_mode'} || $self->{'sysop'} || $self->is_connected()) {
			$command = 'DISCONNECT';
		}
    } until ($count >= scalar(@index) || $command =~ /^(DISCONNECT|BACK)$/);
    return(TRUE);
}

sub messages_edit_message {
    my $self        = shift;
    my $mode        = shift;
	my $old_message = (scalar(@_)) ? shift : undef;

	my $message;
    if ($mode eq 'ADD') {
        $self->output("Add New Message\n");
		$self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor();
		if (defined($message)) {
			$message->{'from_id'} = $self->{'USER'}->{'id'};
			$message->{'category'} = $self->{'USER'}->{'forum_category'};
			my $sth = $self->{'dbh'}->prepare('INSERT INTO messages (category, from_id, title, message) VALUES (?, ?, ?, ?)');
			$sth->execute(
				$message->{'category'},
				$message->{'from_id'},
				$message->{'title'},
				$message->{'message'}
			);
			$sth->finish();
			if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
				$self->output('[% GREEN %]Message Saved[% RESET %]');
			} else {
				$self->output('Message Saved');
			}
			$message->{'id'} = $sth->last_insert_id();
			sleep 2;
		}
	} elsif ($mode eq 'REPLY') {
        $self->output("Edit Message\n");
		unless ($old_message->{'title'} =~ /^Re: /) {
			$old_message->{'title'} = 'Re: ' . $old_message->{'title'};
			$old_message->{'message'} =~ s/^(.*)/\> $1/g;
		}
		$self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor($old_message);
		if (defined($message)) {
			$message->{'from_id'}  = $self->{'USER'}->{'id'};
			$message->{'title'}    = $old_message->{'title'};
			$message->{'category'} = $self->{'USER'}->{'forum_category'};
			my $sth = $self->{'dbh'}->prepare('INSERT INTO messages (category, from_id, title, message) VALUES (?, ?, ?, ?)');
			$sth->execute(
				$message->{'category'},
				$message->{'from_id'},
				$message->{'title'},
				$message->{'message'}
			);
			$sth->finish();
			$message->{'id'} = $sth->last_insert_id();
		}
    } else { # EDIT
        $self->output("Edit Message\n");
		$self->output('-' x $self->{'USER'}->{'max_columns'} . "\n");
        $message = $self->messages_text_editor($old_message);
		if (defined($message)) {
			my $sth = $self->{'dbh'}->prepare('UPDATE messages SET category=?, from_id=?, title=?, message=? WHERE id=>');
			$sth->execute(
				$message->{'category'},
				$message->{'from_id'},
				$message->{'title'},
				$message->{'message'},
				$message->{'id'}
			);
			$sth->finish();
			$message->{'id'} = $old_message->{'id'};
		}
    }
    return($message);
}

sub messages_delete_message {
    my $self    = shift;
	my $message = shift;

	$self->output("\n\nReally Delete This Message?  ");
	if ($self->decision() && defined($message)) {
		my $sth = $self->{'dbh'}->prepare('UPDATE messages SET hidden=TRUE WHERE id=?');
		$sth->execute($message->{'id'});
		$sth->finish();
		return(TRUE);
	}
    return(FALSE);
}

sub messages_text_editor {
	my $self    = shift;
	my $message = (scalar(@_)) ? shift : undef;

	my $title = '';
	my $text  = '';
	if ($self->{'local_mode'} || $self->{'sysop'} || $self->is_connected()) {
		if (defined($message)) {
			$title = $message->{'title'};
			$text  = $message->{'message'};
			$self->output($self->prompt('Message'));
			$text  = $self->messages_text_edit($text);
		} else {
			$self->output($self->prompt('Title'));
			$title = $self->get_line(ECHO, 255);
			$self->output($self->prompt('Message'));
			$text  = $self->messages_text_edit();
		}
		if (defined($text) && defined($title)) {
			return(
				{
					'title'   => $title,
					'message' => $text,
				}
			);
		}
	}
	return(undef);
}

sub messages_text_edit {
	my $self = shift;
	my $text = (scalar(@_)) ? shift : undef;

	my $columns = $self->{'USER'}->{'max_columns'};
	my $text_mode = $self->{'USER'}->{'text_mode'};
	my @lines;
	if (defined($text) && $text ne '') {
		@lines = split(/\n/,$text . "\n");
	}
	my $save   = FALSE;
	my $cancel = FALSE;
	do {
		my $counter = 0;
		if ($text_mode eq 'ANSI') {
			$self->output('[% CLEAR %][% BRIGHT GREEN %]' . '=' x $columns . '[% RESET %]' . "\n");
			$self->output("Type a command on a line by itself\n");
			$self->output('  :[% YELLOW %]S[% RESET %] = Save and exit' . "\n");
			$self->output("  :[% RED %]Q[% RESET %] = Cancel, do not save\n");
			$self->output("  :[% BRIGHT BLUE %]E[% RESET %] = Edit a specific line number (:E5 edits line 5)\n");
			$self->output('[% BRIGHT GREEN %]' . '=' x $columns . '[% RESET %]' . "\n");
		} elsif ($text_mode eq 'PETSCII') {
			$self->output('[% CLEAR %]' . '=' x $columns . "\n");
			$self->output("Type a command on a line by itself\n");
			$self->output("  :S = Save and exit\n");
			$self->output("  :Q = Cancel, do not save\n");
			$self->output("  :E = Edit a specific line number (:E5 edits line 5)\n");
			$self->output('=' x $columns . "\n");
		} else {
			$self->output('[% CLEAR %]' . '=' x $columns . "\n");
			$self->output("Type a command on a line by itself\n");
			$self->output("  :S = Save and exit\n");
			$self->output("  :Q = Cancel, do not save\n");
			$self->output("  :E = Edit a specific line number (:E5 edits line 5)\n");
			$self->output('=' x $columns . "\n");
		}

		foreach my $line (@lines) {
			if ($text_mode eq 'ANSI') {
				$self->output(sprintf('%s%03d%s %s', '[% CYAN %]', ($counter + 1), '[% RESET %]', $line) . "\n");
			} else {
				$self->output(sprintf('%03d %s', ($counter + 1), $line) . "\n");
			}
			$counter++;
		}
		my $menu = FALSE;
		do {
			if ($text_mode eq 'ANSI') {
				$self->output(sprintf('%s%03d%s ', '[% CYAN %]', ($counter + 1), '[% RESET %]'));
			} else {
				$self->output(sprintf('%03d ', ($counter + 1)));
			}
			$text = $self->get_line(ECHO,$self->{'USER'}->{'max_columns'});
			$self->output("\n");
			if ($text =~ /^\:(.)(.*)/i) { # Process command
				my $command = uc($1);
				if ($command eq 'E') {
					my $line_number = $2;
					if ($line_number > 0) {
						if ($text_mode eq 'ANSI') {
							$self->output("\n" . sprintf('%s%03d%s ','[% CYAN %]',$line_number, '[% RESET %]'));
						} else {
							$self->output("\n" . sprintf('%03d ',$line_number));
						}
						my $line = $self->get_line(ECHO,$self->{'USER'}->{'max_columns'},$lines[$line_number - 1]);
						$lines[$line_number - 1] = $line;
					}
					$menu = TRUE;
				} elsif ($command eq 'S') {
					$save = TRUE;
				} elsif ($command eq 'Q') {
					$cancel = TRUE;
				}
			} else {
				chomp($text);
				push(@lines, $text);
				$counter++;
			}
		} until ($menu || $save || $cancel || ! $self->is_connected());
	} until($save || $cancel || ! $self->is_connected());
	if ($save) {
		$text = join("\n",@lines);
	} else {
		undef($text);
	}
	return($text);
}
1;
