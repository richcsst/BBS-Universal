package BBS::Universal::FileTransfer;
BEGIN { our $VERSION = '0.002'; }

sub filetransfer_initialize {
    my $self = shift;

    return ($self);
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
        if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
            $self->output("\n" . $table->boxes->draw());
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
    my $max_uploader = 8;
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            push(@files, $row);
            $max_filename = max(length($row->{'filename'}), $max_filename);
            $max_title    = max(length($row->{'title'}),    $max_title);
            if ($row->{'prefer_nickname'}) {
                $max_uploader = max(length($row->{'nickname'}), $max_uploader);
            } else {
                $max_uploader = max(length($row->{'username'}), $max_uploader);
            }
        }
        my $table = Text::SimpleTable->new($max_filename, $max_title, $max_uploader);
        $table->row('FILENAME', 'TITLE', 'UPLOADER');
        $table->hr();
        foreach my $record (@files) {
            if ($record->{'prefer_nickname'}) {
                $table->row($record->{'filename'}, $record->{'title'}, $record->{'nickname'});
            } else {
                $table->row($record->{'filename'}, $record->{'title'}, $record->{'username'});
            }
        }
        if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
            $self->output("\n" . $table->boxes->draw());
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
}

sub send_file {
    my $self = shift;
    return (TRUE);
}
1;
