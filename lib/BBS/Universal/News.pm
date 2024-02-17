package BBS::Universal::News;
BEGIN { our $VERSION = '0.002'; }

sub news_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['News Initialized']);
    return ($self);
}

sub news_display {
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
		$self->output("\n");
		while(my $row = $sth->fetchrow_hashref()) {
			if ($self->{'USER'}->{'text_mode'} eq 'ANSI') {
				$self->output(
					'[% B_GREEN %] ' .
					$row->{'news_title'} .
					' [% RESET %] - ' .
					$row->{'newsdate'} . 
					"\n\n" .
					'[% WRAP %]' .
					$row->{'news_content'} .
					"\n\n"
				);
			} else {
				$self->output(
					'* ' .
					$row->{'news_title'} .
					' - ' .
					$row->{'newsdate'} .
					"\n\n" .
					'[% WRAP %]' .
					$row->{'news_content'} .
					"\n\n"
				);
			}
		}
	} else {
		$self->output('No News');
	}
	$sth->finish();
	$self->output("\nPress a key to continue ... ");
	$self->get_key(SILENT,BLOCKING);
	return(TRUE);
}

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
		my $table = Text::SimpleTable->new(10,$self->{'USER'}->{'max_columns'} - 13);
		$table->row('DATE','TITLE');
		$table->hr();
		while(my $row = $sth->fetchrow_hashref()) {
			$table->row($row->{'newsdate'},$row->{'news_title'});
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
	$self->get_key(SILENT,BLOCKING);
	return(TRUE);
}
1;
