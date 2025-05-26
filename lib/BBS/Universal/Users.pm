package BBS::Universal::Users;
BEGIN { our $VERSION = '0.002'; }

sub users_initialize {
    my $self = shift;

    $self->{'USER'}->{'mode'} = ASCII;
    $self->{'debug'}->DEBUG(['Users initialized']);
    return ($self);
} ## end sub users_initialize

sub users_load {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    my $sth;
    if ($self->{'sysop'}) {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE username=?');
        $sth->execute($username);
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE username=? AND password=SHA2(?,512)');
        $sth->execute($username, $password);
    }
    my $results = $sth->fetchrow_hashref();
    if (defined($results)) {
        $self->{'debug'}->DEBUG(["$username found"]);
        $self->{'USER'} = $results;
        delete($self->{'USER'}->{'password'});
        return (TRUE);
    } ## end if (defined($results))
    return (FALSE);
} ## end sub users_load

sub users_list {
    my $self = shift;
}

sub users_add {
    my $self          = shift;
    my $user_template = shift;

    $self->{'dbh'}->begin_work;
    my $sth = $self->{'dbh'}->prepare(
        q{
			INSERT INTO users (
				username,
				given,
				family,
				nickname,
                email,
				accomplishments,
				retro_systems,
				birthday,
				location,
				baud_rate,
				text_mode,
				password)
			  VALUES (?,?,?,?,?,?,DATE(?),?,?,(SELECT text_modes.id FROM text_modes WHERE text_modes.text_mode=?),SHA2(?,512))
		}
    );
    $self->{'debug'}->DEBUGMAX($user_template);
    $sth->execute($user_template->{'username'}, $user_template->{'given'}, $user_template->{'family'}, $user_template->{'nickname'}, $user_template->{'email'}, $user_template->{'accomplishments'}, $user_template->{'retro_systems'}, $user_template->{'birthday'}, $user_template->{'location'}, $user_template->{'baud_rate'}, $user_template->{'text_mode'}, $user_template->{'password'},) or $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
    $sth = $self->{'dbh'}->prepare(
        q{
			INSERT INTO permissions (
				id,
				prefer_nickname,
				view_files,
				upload_files,
				download_files,
				remove_files,
				read_message,
                show_email,
				post_message,
				remove_message,
				sysop,
				page_sysop,
				timeout)
			  VALUES (LAST_INSERT_ID(),?,?,?,?,?,?,?,?,?,?,?);
		}
    );
    $sth->execute($user_template->{'prefer_nickname'}, $user_template->{'view_files'}, $user_template->{'upload_files'}, $user_template->{'download_files'}, $user_template->{'remove_files'}, $user_template->{'read_message'}, $user_template->{'show_email'}, $user_template->{'post_message'}, $user_template->{'remove_message'}, $user_template->{'sysop'}, $user_template->{'page_sysop'}, $user_template->{'timeout'});

    if ($self->{'dbh'}->errstr) {
        $self->{'dbh'}->rollback;
        $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
        $sth->finish();
        return (FALSE);
    } else {
        $self->{'dbh'}->commit;
        $self->{'debug'}->DEBUG(['Success']);
        $sth->finish();
        return (TRUE);
    } ## end else [ if ($self->{'dbh'}->errstr)]
} ## end sub users_add

sub users_edit {
    my $self = shift;
}

sub users_delete {
    my $self = shift;
    my $id   = shift;

    $self->{'debug'}->WARNING(["Delete user $id"]);
    $self->{'debug'}->DEBUG(['Delete Permissions first']);
    $self->{'dbh'}->begin_work();
    my $sth = $self->{'dbh'}->prepare('DELETE FROM permissions WHERE id=?');
    $sth->execute($id);
    if ($self->{'dbh'}->errstr) {
        $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
        $self->{'dbh'}->rollback();
        $sth->finish();
        return (FALSE);
    } else {
        $sth->finish();
        $self->{'debug'}->DEBUG(['Permissions deleted, now the user']);
        $sth = $self->{'dbh'}->prepare('DELETE FROM users WHERE id=?');
        $sth->execute($id);
        if ($self->{'dbh'}->errstr) {
            $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
            $self->{'dbh'}->rollback();
            $sth->finish();
            return (FALSE);
        } else {
            $self->{'dbh'}->commit();
            $self->{'debug'}->DEBUG(['Success']);
            $sth->finish();
            return (TRUE);
        } ## end else [ if ($self->{'dbh'}->errstr)]
    } ## end else [ if ($self->{'dbh'}->errstr)]
} ## end sub users_delete

sub users_file_category {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'file_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    return ($category);
} ## end sub users_file_category

sub users_forum_category {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT name FROM message_categories WHERE id=?');
    $sth->execute($self->{'USER'}->{'forum_category'});
    my ($category) = ($sth->fetchrow_array());
    $sth->finish();
    return ($category);
} ## end sub users_forum_category

sub users_find {
    my $self = shift;
}

sub users_count {
    my $self = shift;
    return (0);
}

sub user_info {
    my $self = shift;

    my $table;
    my $text = '';

    if (($self->{'USER'}->{'max_colums'} + 0) <= 40) {
        $table = Text::SimpleTable->new(15, $self->{'USER'}->{'max_columns'} - 10);
        $table->row('FIELD', 'VALUE');
        $table->hr();
        $table->row('ACCOUNT NUMBER',  $self->{'USER'}->{'id'});
        $table->row('USERNAME',        $self->{'USER'}->{'username'});
        $table->row('FULL NAME',       $self->{'USER'}->{'fullname'});
        $table->row('NICKNAME',        $self->{'USER'}->{'nickname'});
        $table->row('EMAIL',           $self->{'USER'}->{'email'});
        $table->row('SCREEN',          $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'});
        $table->row('BIRTHDAY',        $self->{'USER'}->{'birthday'});
        $table->row('LOCATION',        $self->{'USER'}->{'location'});
        $table->row('BAUD RATE',       $self->{'USER'}->{'baud_rate'});
        $table->row('LAST LOGIN',      $self->{'USER'}->{'login_time'});
        $table->row('LAST LOGOUT',     $self->{'USER'}->{'logout_time'});
        $table->row('TEXT MODE',       $self->{'USER'}->{'text_mode'});
        $table->row('IDLE TIMEOUT',    $self->{'USER'}->{'timeout'});
        $table->row('RETRO SYSTEMS',   $self->{'USER'}->{'retro_systems'});
        $table->row('ACCOMPLISHMENTS', $self->{'USER'}->{'accomplishments'});
        $table->row('SHOW EMAIL',      $self->yes_no($self->{'USER'}->{'show_email'},      FALSE));
        $table->row('PREFER NICKNAME', $self->yes_no($self->{'USER'}->{'prefer_nickname'}, FALSE));
        $table->row('VIEW FILES',      $self->yes_no($self->{'USER'}->{'view_files'},      FALSE));
        $table->row('UPLOAD FILES',    $self->yes_no($self->{'USER'}->{'upload_files'},    FALSE));
        $table->row('DOWNLOAD FILES',  $self->yes_no($self->{'USER'}->{'download_files'},  FALSE));
        $table->row('REMOVE FILES',    $self->yes_no($self->{'USER'}->{'remove_files'},    FALSE));
        $table->row('READ_MESSAGES',   $self->yes_no($self->{'USER'}->{'read_message'},    FALSE));
        $table->row('POST MESSAGES',   $self->yes_no($self->{'USER'}->{'post_message'},    FALSE));
        $table->row('REMOVE MESSAGES', $self->yes_no($self->{'USER'}->{'remove_message'},  FALSE));
        $table->row('PAGE SYSOP',      $self->yes_no($self->{'USER'}->{'page_sysop'},      FALSE));
    } else {
        $table = Text::SimpleTable->new(15, ($self->{'USER'}->{'max_columns'} / 2) - 10, 15, ($self->{'USER'}->{'max_columns'} / 2) - 10);
        $table->row('FIELD', 'VALUE', 'FIELD', 'VALUE');
        $table->hr();
        $table->row('ACCOUNT NUMBER',  $self->{'USER'}->{'id'},                                                'SHOW EMAIL',      $self->yes_no($self->{'USER'}->{'show_email'},      FALSE));
        $table->row('USERNAME',        $self->{'USER'}->{'username'},                                          'PREFER NICKNAME', $self->yes_no($self->{'USER'}->{'prefer_nickname'}, FALSE));
        $table->row('FULL NAME',       $self->{'USER'}->{'fullname'},                                          'VIEW FILES',      $self->yes_no($self->{'USER'}->{'view_files'},      FALSE));
        $table->row('NICKNAME',        $self->{'USER'}->{'nickname'},                                          'UPLOAD FILES',    $self->yes_no($self->{'USER'}->{'upload_files'},    FALSE));
        $table->row('EMAIL',           $self->{'USER'}->{'email'},                                             'DOWNLOAD FILES',  $self->yes_no($self->{'USER'}->{'download_files'},  FALSE));
        $table->row('SCREEN',          $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'}, 'REMOVE FILES',    $self->yes_no($self->{'USER'}->{'remove_files'},    FALSE));
        $table->row('BIRTHDAY',        $self->{'USER'}->{'birthday'},                                          'READ_MESSAGES',   $self->yes_no($self->{'USER'}->{'read_message'},    FALSE));
        $table->row('LOCATION',        $self->{'USER'}->{'location'},                                          'POST MESSAGES',   $self->yes_no($self->{'USER'}->{'post_message'},    FALSE));
        $table->row('BAUD RATE',       $self->{'USER'}->{'baud_rate'},                                         'REMOVE MESSAGES', $self->yes_no($self->{'USER'}->{'remove_message'},  FALSE));
        $table->row('LAST LOGIN',      $self->{'USER'}->{'login_time'},                                        'PAGE SYSOP',      $self->yes_no($self->{'USER'}->{'page_sysop'},      FALSE));
        $table->row('LAST LOGOUT',     $self->{'USER'}->{'logout_time'},                                       'TEXT MODE',       $self->{'USER'}->{'text_mode'});
        $table->row('IDLE TIMEOUT',    $self->{'USER'}->{'timeout'},                                           'RETRO SYSTEMS',   $self->{'USER'}->{'retro_systems'});
        $table->row('ACCOMPLISHMENTS', $self->{'USER'}->{'accomplishments'},                                   '',                '');
    } ## end else [ if (($self->{'USER'}->...))]

    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $text = $table->boxes->draw();
    } else {
        $text = $table->draw();
    }

    return ($text);
} ## end sub user_info
1;
