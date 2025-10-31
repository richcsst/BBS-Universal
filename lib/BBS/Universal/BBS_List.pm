package BBS::Universal::BBS_List;
BEGIN { our $VERSION = '0.001'; }

sub bbs_list_initialize {
    my $self = shift;
    return ($self);
}

sub bbs_list_bulk_import {
	my $self = shift;

	my $filename = $self->configuration('BBS ROOT') . "/bbs_list.txt";
	if (-e $filename) {
		$self->output("\n\nImporting/merging BBS list from bbs_list.txt\n\n");
		open(my $FILE, '<', $filename);
		chomp(my @bbs = <$FILE>);
		close($FILE);

		my $sth = $self->{'dbh'}->prepare('REPLACE INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,?)');
		foreach my $line (@bbs) {
			my ($name,$url,$port) = split(/\s\s+|:/,$line);
			$port = 23 if ($port eq '' || ! defined($port));
			$sth->execute($name,$url,$port,$self->{'USER'}->{'id'});
			$self->send_char('.');
		}
		$sth->finish();
		$self->output("\n");
		sleep 1;
	} else {
		$self->output("\n[% RING BELL %][% RED %]Cannot find [% RESET %]$filename\n");
		$self->{'debug'}->WARNING(["Cannot find $filename"]);
		sleep 3;
	}
	return(TRUE);
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

sub bbs_list {
    my $self   = shift;
	my $search = shift;

	my $sth;
	my $string;
	my $mode = $self->{'USER'}->{'text_mode'};
	my $ch;
	if ($search) {
		$self->{'debug'}->DEBUG(['Search BBS List']);
		$self->output("\n" . $self->prompt('Please Enter The BBS To Search For'));
		$string = $self->get_line(ECHO,64,'');
		return(FALSE) unless(defined($string) && $string ne '');
		$sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_name LIKE ? ORDER BY bbs_name');
		$sth->execute('%' . $string . '%');
		$self->output("\n\n");
		if ($mode eq 'ANSI') {
			$ch = '[% GREEN %]' . $string . '[% RESET %]';
			$self->output("[% B_BRIGHT YELLOW %][% BLACK %] Search BBS listing for [% RESET %] $ch\n\n");
		} elsif ($mode eq 'ATASCII') {
			$ch = $string;
			$self->output("Search BBS listing for $ch\n\n");
		} elsif ($mode eq 'PETSCII') {
			$ch = '[% GREEN %]' . $string . '[% RESET %]';
			$self->output("[% YELLOW %]Search BBS listing for[% RESET %] $ch\n\n");
		} else {
			$ch = $string;
			$self->output("Search BBS listing for '$string'\n\n");
		}
	} else {
		$self->{'debug'}->DEBUG(['BBS List Full']);
		$sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view ORDER BY bbs_name');
		$sth->execute();
		$self->output("\n\nShow full BBS list\n\n");
	}
	$self->{'debug'}->DEBUG(['BBS Listing - DB query complete']);
    my @listing;
    my ($name_size, $hostname_size, $poster_size) = (4, 14, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    }
	$self->{'debug'}->DEBUGMAX(\@listing);
	if (scalar(@listing)) {
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
		$response =~ s/$string/$ch/gs if ($search);
		$self->output($response);
	}
	$self->output("\nPress any key to continue\n");
	$self->get_key(SILENT, BLOCKING);
    return (TRUE);
}
1;
