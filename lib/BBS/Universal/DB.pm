package BBS::Universal::DB;
BEGIN { our $VERSION = '0.002'; }

sub db_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Initialized DB']);

    return ($self);
} ## end sub db_initialize

sub db_connect {
    my $self = shift;

    my @dbhosts = split(/\s*,\s*/, $self->{'CONF'}->{'STATIC'}->{'DATABASE HOSTNAME'});
    my $errors  = '';
    foreach my $host (@dbhosts) {
        $errors        = '';
    # This is for the brave that want to try SSL connections.
    #	$self->{'dsn'} = sprintf('dbi:%s:database=%s;' .
    #		'host=%s;' .
    #		'port=%s;' .
    #		'mysql_ssl=%d;' .
    #		'mysql_ssl_client_key=%s;' .
    #		'mysql_ssl_client_cert=%s;' .
    #		'mysql_ssl_ca_file=%s',
    #		$self->{'CONF'}->{'DATABASE TYPE'},
    #		$self->{'CONF'}->{'DATABASE NAME'},
    #		$self->{'CONF'}->{'DATABASE HOSTNAME'},
    #		$self->{'CONF'}->{'DATABASE PORT'},
    #		TRUE,
    #		'/etc/mysql/certs/client-key.pem',
    #		'/etc/mysql/certs/client-cert.pem',
    #		'/etc/mysql/certs/ca-cert.pem'
    #	);
        $self->{'dsn'} = sprintf('dbi:%s:database=%s;' . 'host=%s;' . 'port=%s;', $self->{'CONF'}->{'STATIC'}->{'DATABASE TYPE'}, $self->{'CONF'}->{'STATIC'}->{'DATABASE NAME'}, $host, $self->{'CONF'}->{'STATIC'}->{'DATABASE PORT'},);
        $self->{'dbh'} = DBI->connect(
            $self->{'dsn'},
            $self->{'CONF'}->{'STATIC'}->{'DATABASE USERNAME'},
            $self->{'CONF'}->{'STATIC'}->{'DATABASE PASSWORD'},
            {
                'PrintError' => FALSE,
                'AutoCommit' => TRUE
            },
        ) or $errors = $DBI::errstr;
        last if ($errors eq '');
    } ## end foreach my $host (@dbhosts)
    if ($errors ne '') {
        $self->{'debug'}->ERROR(["Database Host not found!\n$errors"]);
        exit(1);
    }
    $self->{'debug'}->DEBUG(["Connected to DB $self->{dsn}"]);
    return (TRUE);
} ## end sub db_connect

sub db_count_users {
    my $self = shift;

    unless (exists($self->{'dbh'})) {
        $self->db_connect();
    }
    my $response = $self->{'dbh'}->do('SELECT COUNT(id) FROM users');
    return ($response);
} ## end sub db_count_users

sub db_disconnect {
    my $self = shift;

    $self->{'dbh'}->disconnect() if (defined($self->{'dbh'}));
    return (TRUE);
} ## end sub db_disconnect

sub db_insert {
    my $self  = shift;
    my $table = shift;
    my $hash  = shift;

    return (TRUE);
} ## end sub db_insert

sub db_sql_execute {
    my $self = shift;
    my $file = shift;

    print "Executing $file\n";
    system('mysql --user=' . $self->{'CONF'}->{'DATABASE USERNAME'} . ' --password=' . $self->{'CONF'}->{'DATABASE PASSWORD'} . " < $file");
    print "Done!\n";
    return (TRUE);
} ## end sub db_sql_execute
1;
