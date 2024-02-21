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
    my $self = shift;
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
		return(FALSE);
	} else {
		$self->{'dbh'}->commit;
		$self->{'debug'}->DEBUG(['Success']);
		$sth->finish();
		return(TRUE);
	}
}

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
		return(FALSE);
	} else {
		$sth->finish();
		$self->{'debug'}->DEBUG(['Permissions deleted, now the user']);
		$sth = $self->{'dbh'}->prepare('DELETE FROM users WHERE id=?');
		$sth->execute($id);
		if ($self->{'dbh'}->errstr) {
			$self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
			$self->{'dbh'}->rollback();
			$sth->finish();
			return(FALSE);
		} else {
			$self->{'dbh'}->commit();
			$self->{'debug'}->DEBUG(['Success']);
			$sth->finish();
			return(TRUE);
		}
	}
}

sub users_file_category {
	my $self = shift;

	my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
	$sth->execute($self->{'USER'}->{'file_category'});
	my ($category) = ($sth->fetchrow_array());
	$sth->finish();
	return($category);
}

sub users_forum_category {
	my $self = shift;

	my $sth = $self->{'dbh'}->prepare('SELECT name FROM message_categories WHERE id=?');
	$sth->execute($self->{'USER'}->{'forum_category'});
	my ($category) = ($sth->fetchrow_array());
	$sth->finish();
	return($category);
}

sub users_find {
    my $self = shift;
}

sub users_count {
    my $self = shift;
    return (0);
}

sub user_info {
    my $self = shift;

    my $text = '';
    if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
        $text .= '[% BOLD %][% CYAN %]ACCOUNT NUMBER  [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'id'} . "\n";
        $text .= '[% BOLD %][% CYAN %]USERNAME        [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'username'} . "\n";
        $text .= '[% BOLD %][% CYAN %]FULL NAME       [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'fullname'} . "\n";
        $text .= '[% BOLD %][% CYAN %]NICKNAME        [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'nickname'} . "\n";
        $text .= '[% BOLD %][% CYAN %]EMAIL           [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'email'} . "\n";
        $text .= '[% BOLD %][% CYAN %]SCREEN          [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'} . "\n";
        $text .= '[% BOLD %][% CYAN %]BIRTHDAY        [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'birthday'} . "\n";
        $text .= '[% BOLD %][% CYAN %]LOCATION        [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'location'} . "\n";
        $text .= '[% BOLD %][% CYAN %]BAUD RATE       [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'baud_rate'} . "\n";
        $text .= '[% BOLD %][% CYAN %]LAST LOGIN      [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'login_time'} . "\n";
        $text .= '[% BOLD %][% CYAN %]LAST LOGOUT     [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'logout_time'} . "\n";
        $text .= '[% BOLD %][% CYAN %]TEXT MODE       [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'text_mode'} . "\n";
        $text .= '[% BOLD %][% CYAN %]IDLE TIMEOUT    [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'timeout'} . "\n";
        $text .= '[% BOLD %][% CYAN %]RETRO SYSTEMS   [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'retro_systems'} . "\n";
        $text .= '[% BOLD %][% CYAN %]ACCOMPLISHMENTS [% MAGENTA %]=[% RESET %] ' . $self->{'USER'}->{'accomplishments'} . "\n";
        $text .= '[% BOLD %][% CYAN %]SHOW EMAIL      [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'show_email'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]PREFER NICKNAME [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'prefer_nickname'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]VIEW FILES      [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'view_files'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]UPLOAD FILES    [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'upload_files'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]DOWNLOAD FILES  [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'download_files'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]REMOVE FILES    [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'remove_files'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]READ_MESSAGES   [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'read_message'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]POST MESSAGES   [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'post_message'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]REMOVE MESSAGES [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'remove_message'}) . "\n";
        $text .= '[% BOLD %][% CYAN %]PAGE SYSOP      [% MAGENTA %]=[% RESET %] ' . $self->yes_no($self->{'USER'}->{'page_sysop'}) . "\n";
    } else {
        $text .= 'ACCOUNT NUMBER  = ' . $self->{'USER'}->{'id'} . "\n";
        $text .= 'USERNAME        = ' . $self->{'USER'}->{'username'} . "\n";
        $text .= 'FULL NAME       = ' . $self->{'USER'}->{'fullname'} . "\n";
        $text .= 'NICKNAME        = ' . $self->{'USER'}->{'nickname'} . "\n";
        $text .= 'EMAIL           = ' . $self->{'USER'}->{'email'} . "\n";
        $text .= 'SCREEN          = ' . $self->{'USER'}->{'max_columns'} . 'x' . $self->{'USER'}->{'max_rows'} . "\n";
        $text .= 'BIRTHDAY        = ' . $self->{'USER'}->{'birthday'} . "\n";
        $text .= 'LOCATION        = ' . $self->{'USER'}->{'location'} . "\n";
        $text .= 'BAUD RATE       = ' . $self->{'USER'}->{'baud_rate'} . "\n";
        $text .= 'LAST LOGIN      = ' . $self->{'USER'}->{'login_time'} . "\n";
        $text .= 'LAST LOGOUT     = ' . $self->{'USER'}->{'logout_time'} . "\n";
        $text .= 'TEXT MODE       = ' . $self->{'USER'}->{'text_mode'} . "\n";
        $text .= 'IDLE TIMEOUT    = ' . $self->{'USER'}->{'timeout'} . "\n";
        $text .= 'RETRO SYSTEMS   = ' . $self->{'USER'}->{'retro_systems'} . "\n";
        $text .= 'ACCOMPLISHMENTS = ' . $self->{'USER'}->{'accomplishments'} . "\n";
        $text .= 'SHOW EMAIL      = ' . $self->yes_no($self->{'USER'}->{'show_email'}) . "\n";
        $text .= 'PREFER NICKNAME = ' . $self->yes_no($self->{'USER'}->{'prefer_nickname'}) . "\n";
        $text .= 'VIEW FILES      = ' . $self->yes_no($self->{'USER'}->{'view_files'}) . "\n";
        $text .= 'UPLOAD FILES    = ' . $self->yes_no($self->{'USER'}->{'upload_files'}) . "\n";
        $text .= 'DOWNLOAD FILES  = ' . $self->yes_no($self->{'USER'}->{'download_files'}) . "\n";
        $text .= 'REMOVE FILES    = ' . $self->yes_no($self->{'USER'}->{'remove_files'}) . "\n";
        $text .= 'READ_MESSAGES   = ' . $self->yes_no($self->{'USER'}->{'read_message'}) . "\n";
        $text .= 'POST MESSAGES   = ' . $self->yes_no($self->{'USER'}->{'post_message'}) . "\n";
        $text .= 'REMOVE MESSAGES = ' . $self->yes_no($self->{'USER'}->{'remove_message'}) . "\n";
        $text .= 'PAGE SYSOP      = ' . $self->yes_no($self->{'USER'}->{'page_sysop'}) . "\n";
    }

    return ($text);
}
1;
