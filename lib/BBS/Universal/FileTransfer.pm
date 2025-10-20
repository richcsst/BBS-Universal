package BBS::Universal::FileTransfer;
BEGIN { our $VERSION = '0.003'; }

sub filetransfer_initialize {
    my $self = shift;

    return ($self);
}

sub files_type {
	my $self = shift;
	my $file = shift;

	my @tmp = split(/\./,$file);
	my $ext = uc(pop(@tmp));
	my $sth = $self->{'dbh'}->prepare('SELECT type FROM file_types WHERE extension=?');
	$sth->execute($ext);
	my $name;
	if ($sth->rows > 0) {
		$name = $sth->fetchrow_array();
	}
	$sth->finish();
	return($ext,$name);
}

sub files_load_file {
    my $self = shift;
    my $file = shift;

    my $filename = sprintf('%s.%s', $file, substr($self->{'USER'}->{'text_mode'},0,3));
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    return (join("\n", @text));
}

sub files_list_summary {
    my $self   = shift;
    my $search = shift;

    my $sth;
    my $filter;
    if ($search) {
        $self->output("\n" . $self->prompt('Search for'));
        $filter = $self->get_line(ECHO, 20);
        $sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
        $sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
        $sth->execute($self->{'USER'}->{'file_category'});
    }
    my @files;
    my $max_filename = 10;
    my $max_title    = 20;
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
            $max_filename = max(length($row->{'filename'}), $max_filename);
            $max_title    = max(length($row->{'title'}),    $max_title);
        }
        my $table = Text::SimpleTable->new($max_filename, $max_title);
        $table->row('FILENAME', 'TITLE');
        $table->hr();
        foreach my $record (@files) {
            $table->row($record->{'filename'}, $record->{'title'});
        }
		my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
			my $text = $table->boxes->draw();
			while ($text =~ / (FILENAME|TITLE) /s) {
				my $ch = $1;
				my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
				$text =~ s/ $ch / $new /gs;
			}
            $self->output("\n" . $self->color_border($text,'MAGENTA'));
		} elsif ($mode eq 'ATASCII') {
            $self->output("\n" . $self->color_border($table->boxes->draw(),'MAGENTA'));
		} elsif ($mode eq 'PETSCII') {
			my $text = $table->boxes->draw();
			while ($text =~ / (FILENAME|TITLE) /s) {
				my $ch = $1;
				my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
				$text =~ s/ $ch / $new /gs;
			}
            $self->output("\n" . $self->color_border($text,'PURPLE'));
        } else {
            $self->output("\n" . $table->draw());
        }
    } elsif ($search) {
        $self->output("\nSorry '$filter' not found");
    } else {
        $self->output("\nSorry, this file category is empty\n");
    }
    $self->output("\nPress a key to continue ...");
    $self->get_key(ECHO, BLOCKING);
    return (TRUE);
}

sub files_list_detailed {
    my $self   = shift;
    my $search = shift;

    my $sth;
    my $filter;
	my $columns = $self->{'USER'}->{'max_columns'};
    if ($search) {
        $self->output("\n" . $self->prompt('Search for'));
        $filter = $self->get_line(ECHO, 20);
        $sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
        $sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
        $sth->execute($self->{'USER'}->{'file_category'});
    }
    my @files;
    my $max_filename = 8;
	my $max_size     = 3;
    my $max_title    = 5;
    my $max_uploader = 8;
	my $max_type     = 4;
	my $max_uploaded = 8;
	my $max_thumbs_up = 9;
	my $max_thumbs_down = 11;
	my $max_fullname = 8;
	my $max_username = 17;
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
            if ($row->{'prefer_nickname'}) {
                $max_uploader = max(length($row->{'nickname'}), $max_uploader);
            } else {
                $max_uploader = max(length($row->{'fullname'}), $max_uploader);
            }
			$max_size         = max(length(format_number($row->{'file_size'})), $max_size, 4);
            $max_filename     = max(length($row->{'filename'}),  $max_filename);
            $max_title        = max(length($row->{'title'}),     $max_title);
			$max_type         = max(length($row->{'type'}),      $max_type);
			$max_uploaded     = max(length($row->{'uploaded'}),  $max_uploaded);
			$max_thumbs_up    = max(length($row->{'thumbs_up'}), $max_thumbs_up);
			$max_thumbs_down  = max(length($row->{'thumbs_up'}), $max_thumbs_down);
			$max_fullname     = max(length($row->{'fullname'}),  $max_fullname);
			$max_username     = max(length($row->{'username'}),  $max_username);
        }
		$self->{'debug'}->DEBUGMAX(\@files);
		my $table;
		if ($columns <= 40) {
			$table = Text::SimpleTable->new($max_filename, $max_uploader);
			$table->row('FILENAME', 'UPLOADER NAME');
			$table->hr();
			foreach my $record (@files) {
				$table->row(
					$record->{'filename'},
					($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
				);
			}
		} elsif ($columns <= 64) {
			$table = Text::SimpleTable->new($max_title, $max_filename, $max_uploader, $max_thumbs_up, $max_thumbs_down);
			$table->row('TITLE', 'FILENAME', 'UPLOADER NAME', 'THUMBS UP','THUMBS DOWN');
			$table->hr();
			foreach my $record (@files) {
				$table->row(
					$record->{'title'},
					$record->{'filename'},
					($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
					sprintf('%06u', $record->{'thumbs_up'}),
					sprintf('%06u', $record->{'thumbs_down'}),
				);
			}
		} elsif ($columns <= 80) {
			$table = Text::SimpleTable->new($max_title, $max_filename, $max_uploader, $max_type, $max_thumbs_up, $max_thumbs_down);
			$table->row('TITLE', 'FILENAME', 'UPLOADER NAME','TYPE', 'THUMBS_UP', 'THUMBS_DOWN');
			$table->hr();
			foreach my $record (@files) {
				$table->row(
					$record->{'title'},
					$record->{'filename'},
					($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
					$record->{'type'},
					sprintf('%06u', $record->{'thumbs_up'}),
					sprintf('%06u', $record->{'thumbs_down'}),
				);
			}
		} elsif ($columns <= 132) {
			$table = Text::SimpleTable->new($max_title, $max_filename, $max_size, $max_uploader, $max_username, $max_type, $max_uploaded, $max_thumbs_up, $max_thumbs_down);
			$table->row('TITLE', 'FILENAME', 'SIZE', 'UPLOADER NAME','UPLOADER USERNAME', 'TYPE', 'UPLOAD DATE', 'THUMBS UP', 'THUMBS DOWN');
			$table->hr();
			foreach my $record (@files) {
				$table->row(
					$record->{'title'},
					$record->{'filename'},
					sprintf('%' . $max_size . 's', format_number($record->{'file_size'})),
					($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
					$record->{'username'},
					$record->{'type'},
					$record->{'uploaded'},
					sprintf('%06u', $record->{'thumbs_up'}),
					sprintf('%06u', $record->{'thumbs_down'}),
				);
			}
		} else {
			$table = Text::SimpleTable->new($max_title, $max_filename, $max_size, $max_uploader, $max_username, $max_type, $max_uploaded, $max_thumbs_up, $max_thumbs_down);
			$table->row('TITLE', 'FILENAME', 'SIZE', 'UPLOADER NAME','UPLOADER USERNAME', 'TYPE', 'UPLOAD DATE', 'THUMBS UP', 'THUMBS DOWN');
			$table->hr();
			foreach my $record (@files) {
				$table->row(
					$record->{'title'},
					$record->{'filename'},
					sprintf('%' . $max_size . 's', format_number($record->{'file_size'})),
					($record->{'prefer_nickname'}) ? $record->{'nickname'} : $record->{'fullname'},
					$record->{'username'},
					$record->{'type'},
					$record->{'uploaded'},
					sprintf('%06u', $record->{'thumbs_up'}),
					sprintf('%06u', $record->{'thumbs_down'}),
				);
			}
		}
		my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
			my $text = $table->boxes->draw();
			while ($text =~ / (FILENAME|TITLE) /s) {
				my $ch = $1;
				my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
				$text =~ s/ $ch / $new /gs;
			}
            $self->output("\n" . $self->color_border($text,'MAGENTA'));
		} elsif ($mode eq 'ATASCII') {
            $self->output("\n" . $self->color_border($table->boxes->draw(),'MAGENTA'));
		} elsif ($mode eq 'PETSCII') {
			my $text = $table->boxes->draw();
			while ($text =~ / (FILENAME|TITLE) /s) {
				my $ch = $1;
				my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
				$text =~ s/ $ch / $new /gs;
			}
            $self->output("\n" . $self->color_border($text,'PURPLE'));
        } else {
            $self->output("\n" . $table->draw());
        }
    } elsif ($search) {
        $self->output("\nSorry '$filter' not found");
    } else {
        $self->output("\nSorry, this file category is empty\n");
    }
    $self->output("\nPress a key to continue ...");
    $self->get_key(ECHO, BLOCKING);
    return (TRUE);
}

sub save_file {
    my $self = shift;
    return (TRUE);
}

sub receive_file {
    my $self = shift;
	return(TRUE);
}

sub send_file {
    my $self = shift;
    return (TRUE);
}
1;
