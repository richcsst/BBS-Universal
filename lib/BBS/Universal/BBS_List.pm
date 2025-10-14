package BBS::Universal::BBS_List;
BEGIN { our $VERSION = '0.001'; }

sub bbs_list_initialize {
    my $self = shift;
    return ($self);
}

sub bbs_list_add {
    my $self  = shift;

    my $index = 0;
    $self->output($self->prompt('What is the BBS Name'));
    my $bbs_name = $self->get_line(ECHO, 50);
    $self->output("\n");
    if ($bbs_name ne '' && length($bbs_name) > 3) {
        $self->output($self->prompt('What is the URL or Hostname'));
        my $bbs_hostname = $self->get_line(ECHO, 50);
        $self->output("\n");
        if ($bbs_hostname ne '' && length($bbs_hostname) > 5) {
            $self->output($self->prompt('What is the Port number'));
            my $bbs_port = $self->get_line(ECHO, 5);
            $self->output("\n");
            if ($bbs_port ne '' && $bbs_port =~ /^\d+$/) {
                $self->output('Adding BBS Entry...');
                my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
                $sth->execute($bbs_name, $bbs_hostname, $bbs_port);
                $sth->finish();
                $self->output("\n");
            } else {
                return (FALSE);
            }
        } else {
            return (FALSE);
        }
    } else {
        return (FALSE);
    }
    return (TRUE);
}

sub bbs_list_all {
    my $self = shift;

    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view ORDER BY bbs_name');
    $sth->execute();
    my @listing;
    my ($name_size, $hostname_size, $poster_size) = (4, 14, 6);
	my $mode = $self->{'USER'}->{'text_mode'};
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    }
	my $table;
	if ($self->{'USER'}->{'max_columns'} > 40) {
		$table = Text::SimpleTable->new($name_size, $hostname_size, 5, $poster_size);
		$table->row('NAME', 'HOSTNAME/PHONE', 'PORT', 'POSTER');
		$table->hr();
		foreach my $line (@listing) {
			$table->row($line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
		}
	} else {
		$table = Text::SimpleTable->new($name_size, $hostname_size);
		$table->row('NAME', 'HOSTNAME/PHONE');
		$table->hr();
		foreach my $line (@listing) {
			$table->row($line->{'bbs_name'}, $line->{'bbs_hostname'} . ':' . $line->{'bbs_port'});
		}
	}
	my $response;
    if ($mode eq 'ANSI') {
        $response = $table->boxes->draw();
		while ($response =~ / (NAME|HOSTNAME.PHONE|PORT|POSTER) /) {
			my $ch = $1;
			my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
			$response =~ s/ $ch / $new /gs;
		}
		$response = $self->color_border($response,'BRIGHT BLUE');
	} elsif ($mode eq 'ATASCII') {
        $response = $table->boxes->draw();
		$response = $self->color_border($response,'BRIGHT BLUE'); # color is ignored for ATASCII
	} elsif ($mode eq 'PETSCII') {
        $response = $table->boxes->draw();
		while ($response =~ / (NAME|HOSTNAME.PHONE|PORT|POSTER) /) {
			my $ch = $1;
			my $new = '[% YELLOW %]' . $ch . '[% WHITE %]';
			$response =~ s/ $ch / $new /gs;
		}
		$response = $self->color_border($response,'BRIGHT BLUE');
    } else {
        $response = $table->draw();
    }
    return ($response);
}
1;
