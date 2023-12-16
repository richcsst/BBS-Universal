package BBS::Universal::Users;
BEGIN { our $VERSION = '0.001'; }

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
		$sth->execute($username,$password);
	}
    my $results = $sth->fetchrow_hashref();
    if (defined($results)) {
        $self->{'debug'}->DEBUG(["$username found"]);
		$self->{'USER'} = $results;
		delete($self->{'USER'}->{'password'});
        return(TRUE);
    }
    return(FALSE);
}

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

sub user_info {
	my $self = shift;
	return('');
}
1;
