package BBS::Universal::FileTransfer;
BEGIN { our $VERSION = '0.004'; }

sub filetransfer_initialize {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start FileTransfer Initialize']);
    $self->{'debug'}->DEBUG(['End FileTransfer Initialize']);
    return ($self);
}

sub files_type {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start File Type']);
    my @tmp = split(/\./,$file);
    my $ext = uc(pop(@tmp));
    my $sth = $self->{'dbh'}->prepare('SELECT type FROM file_types WHERE extension=?');
    $sth->execute($ext);
    my $name;
    if ($sth->rows > 0) {
        $name = $sth->fetchrow_array();
    }
    $sth->finish();
    $self->{'debug'}->DEBUG(['End File Type']);
    return($ext,$name);
}

sub files_load_file {
    my $self = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['Start Files Load File']);
    my $filename = sprintf('%s.%s', $file, $self->{'USER'}->{'text_mode'});
    $self->{'CACHE'}->set(sprintf('SERVER %02d %s', $self->{'thread_number'},'CURRENT MENU FILE'), $filename);
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    $self->{'debug'}->DEBUG(['End Files Load File']);
    return (join("\n", @text));
}

sub files_list_summary {
    my $self   = shift;
    my $search = shift;

    $self->prompt('File Name? ');
    my $file = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});
    $self->{'debug'}->DEBUG(['Start Files List Summary']);
    my $sth;
    my $filter;
    if ($search) {
        $self->prompt('Search for');
        $filter = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});
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
            my $text = $table->boxes2('MAGENTA')->draw();
            while ($text =~ / (FILENAME|TITLE) /s) {
                my $ch = $1;
                my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $self->output("\n$text");
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
    $self->{'debug'}->DEBUG(['End Files List Summary']);
    return (TRUE);
}

sub files_choices {
    my $self   = shift;
    my $record = shift;
	my $view   = FALSE;
    my $mapping = {
        'TEXT' => '',
        'Z'    => {
            'command'      => 'BACK',
            'color'        => 'WHITE',
            'access_level' => 'USER',
            'text'         => 'Return to File Menu',
        },
        'N' => {
            'command'      => 'NEXT',
            'color'        => 'BLUE',
            'access_level' => 'USER',
            'text'         => 'Next file',
        },
        'D' => {
            'command'      => 'DOWNLOAD',
            'color'        => 'CYAN',
            'access_level' => 'VETERAN',
            'text'         => 'Download file',
        },
        'R' => {
            'command'      => 'REMOVE FILE',
            'color'        => 'RED',
            'access_level' => 'JUNIOR SYSOP',
            'text'         => 'Remove file',
        },
    };
    if ($record->{'extension'} =~ /^(TXT|ASC|ATA|PET|VT|ANS|MD|INF|CDF|PL|PM|PY|C|CPP|H|SH|CSS|HTM|HTML|SHTML|JS|JAVA|XML|BAT)$/ && $self->check_access_level('VETERAN')) {
		$view = TRUE;
        $mapping->{'V'} = {
            'command'      => 'VIEW FILE',
            'color'        => 'CYAN',
            'access_level' => 'VETERAN',
            'text'         => 'View file',
        };
    };
    $self->show_choices($mapping);
    $self->prompt('Choose');
    my $key;
    do {
        $key = uc($self->get_key());
    } until($key =~ /D|N|Z/ || ($key eq 'V' && $view) || ($key eq 'R' && $self->check_access_level('JUNION SYSOP')));
    $self->output($mapping->{$key}->{'command'} . "\n");
    if ($mapping->{$key}->{'command'} eq 'DOWNLOAD') {
        my $file = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $record->{'filename'};
        $mapping = {
            'B'    => {
                'command'      => 'BACK',
                'color'        => 'WHITE',
                'access_level' => 'USER',
                'text'         => 'Return to File Menu',
            },
            'Y' => {
                'command'      => 'YMODEM',
                'color'        => 'YELLOW',
                'access_level' => 'VETERAN',
                'text'         => 'Download with the Ymodem protocol',
            },
            'X' => {
                'command'      => 'XMODEM',
                'color'        => 'BRIGHT BLUE',
                'access_level' => 'VETERAN',
                'text'         => 'Download with the Xmodem protocol',
            },
            'Z' => {
                'command'      => 'ZMODEM',
                'color'        => 'GREEN',
                'access_level' => 'VETERAN',
                'text'         => 'Download with the Zmodem protocol',
            },
        };
        $self->show_choices($mapping);
        $self->prompt('Choose');
        do {
            $key = uc($self->get_key());
        } until($key =~ /B|X|Y|Z/);
        $self->output($mapping->{$key}->{'command'});
        if ($mapping->{$key}->{'command'} eq 'XMODEM') {
            system('sz', '--xmodem', '--quiet', '--binary', $file);
        } elsif ($mapping->{$key}->{'command'} eq 'YMODEM') {
            system('sz', '--ymodem', '--quiet', '--binary', $file);
        } elsif ($mapping->{$key}->{'command'} eq 'ZMODEM') {
            system('sz', '--zmodem', '--quiet', '--binary', '--resume', $file);
        } else {
            return(FALSE);
        }
        return(TRUE);
    } elsif ($mapping->{$key}->{'command'} eq 'VIEW FILE' && $self->check_access_level($mapping->{$key}->{'access_level'})) {
        my $file = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $record->{'filename'};
        open(my $VIEW,'<',$file);
        binmode($VIEW, ":encoding(UTF-8)");
        my $data;
        read($VIEW, $data, $record->{'file_size'}, 0);
        close($VIEW);
        $self->output('[% CLS %]' . $data . '[% RESET %]');
        return(TRUE);
    } elsif ($mapping->{$key}->{'command'} eq 'REMOVE FILE' && $self->check_access_level($mapping->{$key}->{'access_level'})) {
        return(TRUE);
    } elsif ($mapping->{$key}->{'command'} eq 'NEXT') {
        return(TRUE);
    }
    return(FALSE);
}

sub files_upload_choices {
    my $self   = shift;
    my $ckey;

    $self->prompt('File Name? ');
    my $file = $self->get_line({ 'type' => FILENAME, 'max' => 255, 'default' => ''});
    my $ext  = uc($file =~ /\.(.*?)$/);

    $self->prompt('Title (Fiendly name)? ');
    my $title = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});

    $self->prompt('Description? ');
    my $description = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});

    my $file_category = $self->{'USER'}->{'file_category'};

    my $mapping = {
        'B'    => {
            'command'      => 'BACK',
            'color'        => 'WHITE',
            'access_level' => 'USER',
            'text'         => 'Return to File Menu',
        },
        'Y' => {
            'command'      => 'YMODEM',
            'color'        => 'YELLOW',
            'access_level' => 'VETERAN',
            'text'         => 'Upload with the Ymodem protocol',
        },
        'X' => {
            'command'      => 'XMODEM',
            'color'        => 'BRIGHT BLUE',
            'access_level' => 'VETERAN',
            'text'         => 'Upload with the Xmodem protocol',
        },
        'Z' => {
            'command'      => 'ZMODEM',
            'color'        => 'GREEN',
            'access_level' => 'VETERAN',
            'text'         => 'Upload with the Zmodem protocol',
        },
    };
    $self->show_choices($mapping);
    $self->prompt('Choose');
    do {
        $ckey = uc($self->get_key());
    } until($ckey =~ /B|X|Y|Z/);
    $self->output($mapping->{$ckey}->{'command'});
    if ($mapping->{$ckey}->{'command'} eq 'XMODEM') {
        if ($self->files_receive_file($file,XMODEM)) {
            my $filename = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
            my $size     = (-s $filename);
            my $sth      = $self->{'dbh'}->prepare('INSERT INTO files (category,filename,title,file_type,description,file_size) VALUES (?,?,?,(SELECT id FROM file_types WHERE extension=?),?,?');
            $sth->execute($file_category,$file,$title,$ext,$description,$size);
            $sth->finish();
        }
    } elsif ($mapping->{$ckey}->{'command'} eq 'YMODEM') {
        if ($self->files_receive_file($file,YMODEM)) {
            my $filename = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
            my $size     = (-s $filename);
            my $sth      = $self->{'dbh'}->prepare('INSERT INTO files (category,filename,title,file_type,description,file_size) VALUES (?,?,?,(SELECT id FROM file_types WHERE extension=?),?,?');
            $sth->execute($file_category,$file,$title,$ext,$description,$size);
            $sth->finish();
        }
    } elsif ($mapping->{$ckey}->{'command'} eq 'ZMODEM') {
        if ($self->files_receive_file($file,ZMODEM)) {
            my $filename = $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'} . $file;
            my $size     = (-s $filename);
            my $sth      = $self->{'dbh'}->prepare('INSERT INTO files (category,filename,title,file_type,description,file_size) VALUES (?,?,?,(SELECT id FROM file_types WHERE extension=?),?,?');
            $sth->execute($file_category,$file,$title,$ext,$description,$size);
            $sth->finish();
        }
    } else {
        return(FALSE);
    }
    if ($? == -1) {
        $self->{'debug'}->ERROR(["Could not execute rz:  $!"]);
    } elsif ($? & 127) {
        $self->{'debug'}->ERROR(["File Transfer Aborted:  $!"]);
    } else {
        $self->{'debug'}->DEBUG(['File Transfer Successful']);
    }
    return(TRUE);
}

sub files_list_detailed {
    my $self   = shift;
    my $search = shift;

    $self->{'debug'}->DEBUG(['Start Files List Detailed']);
    my $sth;
    my $filter;
    my $columns = $self->{'USER'}->{'max_columns'};
    if ($search) {
        $self->prompt('Search for');
        $filter = $self->get_line({ 'type' => STRING, 'max' => 255, 'default' => ''});
        $sth    = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE (filename LIKE ? OR title LIKE ?) AND category_id=? ORDER BY uploaded DESC');
        $sth->execute('%' . $filter . '%', '%' . $filter . '%', $self->{'USER'}->{'file_category'});
    } else {
        $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view WHERE category_id=? ORDER BY uploaded DESC');
        $sth->execute($self->{'USER'}->{'file_category'});
    }
    my @files;
    if ($sth->rows > 0) {
        $self->{'debug'}->DEBUGMAX(\@files);
        my $table;
        my $mode = $self->{'USER'}->{'text_mode'};
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
        }
        $sth->finish();
        foreach my $record (@files) {
            if ($mode eq 'ANSI') {
                $self->output("\n" . '[% HORIZONTAL RULE GREEN %]' . "\n");
                $self->output('[% B_BLUE %][% BRIGHT WHITE %]       TITLE [% RESET %] ' . $record->{'title'} . "\n");
                $self->output('[% B_BLUE %][% BRIGHT WHITE %]    FILENAME [% RESET %] ' . $record->{'filename'} . "\n");
                $self->output('[% B_BLUE %][% BRIGHT WHITE %]   FILE SIZE [% RESET %] ' . format_number($record->{'file_size'}) . "\n");
                if ($record->{'prefer_nickname'}) {
                    $self->output('[% B_BLUE %][% BRIGHT WHITE %]    UPLOADER [% RESET %] ' . $record->{'nickname'} . "\n");
                } else {
                    $self->output('[% B_BLUE %][% BRIGHT WHITE %]    UPLOADER [% RESET %] ' . $record->{'fullname'} . "\n");
                }
                $self->output('[% B_BLUE %][% BRIGHT WHITE %]   FILE TYPE [% RESET %] ' . $record->{'type'} . "\n");
                $self->output('[% B_BLUE %][% BRIGHT WHITE %]    UPLOADED [% RESET %] ' . $record->{'uploaded'} . "\n");
                $self->output('[% B_BLUE %][% BRIGHT WHITE %]      THUMBS [% RESET %] [% THUMBS UP SIGN %] ' . (0 + $record->{'thumbs_up'}) . '   [% THUMBS DOWN SIGN %] ' . (0 + $record->{'tumbs_down'}) . "\n");
                $self->output('[% HORIZONTAL RULE GREEN %]' . "\n");
            } else {
                $self->output("\n      TITLE: " . $record->{'title'} . "\n");
                $self->output('   FILENAME: ' . $record->{'filename'} . "\n");
                $self->output('  FILE SIZE: ' . format_number($record->{'file_size'}) . "\n");
                if ($record->{'prefer_nickname'}) {
                    $self->output('   UPLOADER: ' . $record->{'nickname'} . "\n");
                } else {
                    $self->output('   UPLOADER: ' . $record->{'fullname'} . "\n");
                }
                $self->output('  FILE TYPE: ' . $record->{'type'} . "\n");
                $self->output('   UPLOADED: ' . $record->{'uploaded'} . "\n");
                $self->output('  THUMBS UP: ' . (0 + $record->{'thumbs_up'}) . "\n");
                $self->output('THUMBS DOWN: ' . (0 + $record->{'thumbs_down'}) . "\n");
            }
            last unless($self->files_choices($record));
        }
    } elsif ($search) {
        $self->output("\nSorry '$filter' not found");
    } else {
        $self->output("\nSorry, this file category is empty\n");
    }
    $self->output("\nPress a key to continue ...");
    $self->get_key(ECHO, BLOCKING);
    $self->{'debug'}->DEBUG(['End Files List Detailed']);
    return (TRUE);
}

sub files_save_file {
    my $self = shift;
    $self->{'debug'}->DEBUG(['Start Save File']);
    $self->{'debug'}->DEBUG(['End Save File']);
    return (TRUE);
}

sub files_receive_file {
    my $self     = shift;
    my $file     = shift;
    my $protocol = shift;

    my $success = TRUE;
    $self->{'debug'}->DEBUG(['Start Receive File']);
    unless ($self->{'local_mode'}) {
        chdir $self->{'CONF'}->{'BBS ROOT'} . '/' . $self->{'CONF'}->{'FILES PATH'};
        select $self->{'cl_socket'};
        if ($protocol == YMODEM) {
            $self->{'debug'}->DEBUG(["Send file $file with Ymodem"]);
            system('rz', '--binary', '--quiet', '--ymodem', '--rename', '--restricted', '--restricted');
        } elsif ($protocol == ZMODEM) {
            $self->{'debug'}->DEBUG(["Send file $file with Zmodem"]);
            system('rz', '--binary', '--quiet', '--zmodem', '--rename', '--restricted', '--restricted');
        } else { # Xmodem
            $self->{'debug'}->DEBUG(["Send file $file with Xmodem"]);
            system('rx', '--binary', '--quiet', '--xmodem', $file);
        }
        select STDOUT;
        if ($? == -1) {
            $self->{'debug'}->ERROR(["Could not execute rz:  $!"]);
        } elsif ($? & 127) {
            $self->{'debug'}->ERROR(["File Transfer Aborted:  $!"]);
        } else {
            $self->{'debug'}->DEBUG(['File Transfer Successful']);
        }
    } else {
        $self->output("Upload not allowed in local mode\n");
    }
    chdir $self->{'CONF'}->{'BBS ROOT'};
    $self->{'debug'}->DEBUG(['End Receive File']);
    return($success);
}

sub files_send_file {
    my $self     = shift;
    my $file     = shift;
    my $protocol = shift;

    my $success = TRUE;
    $self->{'debug'}->DEBUG(['Start Send File']);
    unless ($self->{'local_mode'}) { # No file transfer in local mode
        chdir $self->{'CONF'}->{'FILE PATH'};
        select $self->{'cl_socket'};
        if ($protocol == YMODEM) {
            $self->{'debug'}->DEBUG(["Send file $file with Ymodem"]);
            system('sz', '--binary', '--quiet', '--$protocol ymodem', $file);
        } elsif ($protocol == ZMODEM) {
            $self->{'debug'}->DEBUG(["Send file $file with Zmodem"]);
            system('sz', '--binary', '--quiet', '--$protocol zmodem', '--resume', $file);
        } else { # Xmodem
            $self->{'debug'}->DEBUG(["Send file $file with Xmodem"]);
            system('sz', '--binary', '--quiet', '--$protocol xmodem', $file);
        }
        select STDOUT;
        chdir $self->{'CONF'}->{'BBS ROOT'};
    }
    $self->{'debug'}->DEBUG(['End Send File']);
    return ($success);
}
1;
