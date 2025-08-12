package BBS::Universal::News;
BEGIN { our $VERSION = '0.002'; }

sub news_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['News Initialized']);
    return ($self);
} ## end sub news_initialize

sub news_display {
    my $self = shift;

	my $news = "\n";
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
			if ($self->{'CONF'}->{'SHORT DATE FORMAT'} eq '%d/%m/%Y') {
				$today = $dt->dmy;
			} elsif ($self->{'CONF'}->{'SHORT DATE FORMAT'} eq '%Y/%m/%d') {
				$today = $dt->ymd;
			} else {
				$today = $dt->mdy;
			}
			if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
				$news .= "$today - [% B_GREEN %][% BLACK %] Today is the author's birthday! [% RESET %] " . $self->{'ansi_characters'}->{'PARTY POPPER'} . "\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
			} else {
				$news .= "* $today - Today is the author's birthday!\n\n" . $format->format("Great news!  Happy Birthday to Richard Kelsch (the author of BBS::Universal)!");
			}
			$news .= "\n";
		}
	}
    my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,'} . $self->{'CONF'}->{'SHORT DATE FORMAT'} . q{') AS newsdate
		FROM news
		ORDER BY news_date DESC
	};
    my $sth = $self->{'dbh'}->prepare($sql);
    $sth->execute();
    if ($sth->rows > 0) {
        while (my $row = $sth->fetchrow_hashref()) {
            if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
                $news .= $row->{'newsdate'} . ' - [% B_GREEN %][% BLACK %] ' . $row->{'news_title'} . " [% RESET %]\n\n" . $format->format($row->{'news_content'});
            } else {
                $news .= '* ' . $row->{'newsdate'} . ' - ' . $row->{'news_title'} . "\n\n" . $format->format($row->{'news_content'});
            }
			$news .= "\n";
        } ## end while (my $row = $sth->fetchrow_hashref...)
    } else {
        $news = "No News\n\n";
    }
    $sth->finish();
	$self->output($news);
    $self->output("Press a key to continue ... ");
    $self->get_key(SILENT, BLOCKING);
    return (TRUE);
} ## end sub news_display

sub news_summary {
    my $self = shift;

    my $sql = q{
		SELECT
		  news_id,
		  news_title,
		  news_content,
		  DATE_FORMAT(news_date,'} . $self->{'CONF'}->{'SHORT DATE FORMAT'} . q{') AS newsdate
		FROM news
		ORDER BY news_date DESC};
    my $sth = $self->{'dbh'}->prepare($sql);
    $sth->execute();
    if ($sth->rows > 0) {
        my $table = Text::SimpleTable->new(10, $self->{'USER'}->{'max_columns'} - 13);
        $table->row('DATE', 'TITLE');
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            $table->row($row->{'newsdate'}, $row->{'news_title'});
        }
        if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
            $self->output($table->boxes->draw());
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
} ## end sub news_summary
1;
