package BBS::Universal::News;
BEGIN { our $VERSION = '0.003'; }

sub news_initialize {
    my $self = shift;

    return ($self);
}

sub news_display {
    my $self = shift;

    my $news   = "\n";
    my $format = Text::Format->new(
        'columns'     => $self->{'USER'}->{'max_columns'} - 1,
        'tabstop'     => 4,
        'extraSpace'  => TRUE,
        'firstIndent' => 2,
    );
    {
        my $dt = DateTime->now;
        if ($dt->month == 7 && $dt->day == 10) {
            my $today;
            if ($self->{'USER'}->{'DATE FORMAT'} eq 'DAY/MONTH/YEAR') {
                $today = $dt->dmy;
            } elsif ($self->{'USER'}->{'DATE FORMAT'} eq 'YEAR/MONTH/DAY') {
                $today = $dt->ymd;
            } else {
                $today = $dt->mdy;
            }
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $news .= "$today - [% B_GREEN %][% BLACK %] Today is the author's birthday! [% RESET %] " . '[% PARTY POPPER %]' . "\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
            } else {
                $news .= "* $today - Today is the author's birthday!\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
            }
            $news .= "\n";
        }
    }
	my $df = $self->{'USER'}->{'date_format'};
	$df =~ s/YEAR/\%Y/;
	$df =~ s/MONTH/\%m/;
	$df =~ s/DAY/\%d/;
    my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,?) AS newsdate
		FROM news
		ORDER BY news_date DESC
	};
    my $sth = $self->{'dbh'}->prepare($sql);
    $sth->execute($df);
    if ($sth->rows > 0) {
        while (my $fields = $sth->fetchrow_hashref()) {
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $news .= $fields->{'newsdate'} . ' - [% B_GREEN %][% BLACK %] ' . $fields->{'news_title'} . " [% RESET %]\n\n" . $format->format($fields->{'news_content'});
            } else {
                $news .= '* ' . $fields->{'newsdate'} . ' - ' . $fields->{'news_title'} . "\n\n" . $format->format($fields->{'news_content'});
            }
            $news .= "\n";
        }
    } else {
        $news = "No News\n\n";
    }
    $sth->finish();
    $self->output($news);
    $self->output("Press a key to continue ... ");
    $self->get_key(SILENT, BLOCKING);
    return (TRUE);
}

sub news_summary {
    my $self = shift;

	my $format = $self->{'USER'}->{'date_format'};
	$format =~ s/YEAR/\%Y/;
	$format =~ s/MONTH/\%m/;
	$format =~ s/DAY/\%d/;
    my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,?) AS newsdate
		FROM news
		ORDER BY news_date DESC};
    my $sth = $self->{'dbh'}->prepare($sql);
    $sth->execute($format);
    if ($sth->rows > 0) {
        my $table = Text::SimpleTable->new(10, $self->{'USER'}->{'max_columns'} - 14);
        $table->row('DATE', 'TITLE');
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            $table->row($row->{'newsdate'}, $row->{'news_title'});
        }
        if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
            my $text = $table->boxes->draw();
			my $ch = colored(['bright_yellow'],'DATE');
			$text =~ s/DATE/$ch/;
			$ch = colored(['bright_yellow'],'TITLE');
			$text =~ s/TITLE/$ch/;
			$self->output($text);
        } else {
            $self->output($table->draw());
        }
    } else {
        $self->output('No News');
    }
    $sth->finish();
    $self->output("\nPress a key to continue ... ");
    $self->get_key(SILENT, BLOCKING);
    return (TRUE);
}
1;
