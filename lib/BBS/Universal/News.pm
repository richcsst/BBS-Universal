package BBS::Universal::News;
BEGIN { our $VERSION = '0.003'; }

sub news_initialize {
    my $self = shift;
    $self->{'rss'} = XML::RSS::LibXML->new();
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
        my $mode = $self->{'USER'}->{'text_mode'};
        if ($mode eq 'ANSI') {
            my $text = $table->boxes->draw();
            my $ch = colored(['bright_yellow'],'DATE');
            $text =~ s/DATE/$ch/;
            $ch = colored(['bright_yellow'],'TITLE');
            $text =~ s/TITLE/$ch/;
            $self->output($self->color_border($text,'BRIGHT BLUE'));
        } elsif ($mode eq 'ATASCII') {
            my $text = $self->color_border($table->boxes->draw(),'BLUE');
            $self->output($text);
        } elsif ($mode eq 'PETSCII') {
            my $text = $table->boxes->draw();
            while ($text =~ / (DATE|TITLE) /s) {
                my $ch = $1;
                my $new = '[% YELLOW %]' . $ch . '[% RESET %]';
                $text =~ s/ $ch / $new /gs;
            }
            $text = $self->color_border($text, 'LIGHT BLUE');
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

sub news_rss_categories {
	my $self = shift;

    my $command = '';
	my $id;
	my $sth = $self->{'dbh'}->prepare('SELECT * FROM rss_feed_categories WHERE id<>? ORDER BY title');
	$sth->execute($self->{'USER'}->{'rss_category'});
	my $mapping = {
		'TEXT' => '',
		'Z'    => {
			'command'      => 'BACK',
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => 'Return to News Menu',
		},
	};
	my @menu_choices = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y));
	while(my $result = $sth->fetchrow_hashref()) {
		if ($self->check_access_level($result->{'access_level'})) {
			$mapping->{shift(@menu_choices)} = {
				'command'      => $result->{'title'},
				'id'           => $result->{'id'},
				'color'        => 'WHITE',
				'access_level' => $result->{'access_level'},
				'text'         => $result->{'description'},
			};
		}
	}
	$sth->finish();
	$self->show_choices($mapping);
	$self->output("\n" . $self->prompt('Choose World News Feed Category'));
	my $key;
	do {
		$key = uc($self->get_key(SILENT, BLOCKING));
	} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	if ($key eq chr(3)) {
		return('DISCONNECT');
	} else {
		$id      = $mapping->{$key}->{'id'};
		$command = $mapping->{$key}->{'command'};
	}
	if ($self->is_connected() && $command ne 'BACK') {
		$self->output($command);
		$sth = $self->{'dbh'}->prepare('UPDATE users SET rss_category=? WHERE id=?');
		$sth->execute($id, $self->{'USER'}->{'id'});
		if ($sth->err) {
			$self->{'debug'}->ERROR([$sth->errstr]);
		}
		$sth->finish();
		$self->{'USER'}->{'rss_category'} = $id;
		$command = 'BACK';
	}
	return($command);
}

sub news_rss_feeds {
	my $self = shift;

	my $mode = $self->{'USER'}->{'text_mode'};
	my $sth = $self->{'dbh'}->prepare('SELECT * FROM rss_view WHERE category=? ORDER BY title');
	$sth->execute($self->{'USER'}->{'rss_category'});
	my $mapping = {
		'TEXT' => '',
		'Z' => {
			'command'      => 'BACK',
			'color'        => 'WHITE',
			'access_level' => 'USER',
			'text'         => 'Return to News Menu',
		},
	};
	my @menu_choices = (qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y));
	while(my $result = $sth->fetchrow_hashref()) {
		if ($self->check_access_level($result->{'access_level'})) {
			$mapping->{shift(@menu_choices)} = {
				'command'      => $result->{'title'},
				'id'           => $result->{'id'},
				'color'        => 'WHITE',
				'access_level' => $result->{'access_level'},
				'text'         => $self->news_title_colorize($result->{'title'}),
				'url'          => $result->{'url'},
			};
		}
	}
	$sth->finish();
	$self->show_choices($mapping);
	$self->output("\n" . $self->prompt('Choose World News Feed'));
	my $id;
	my $key;
	my $command;
	my $url;
	do {
		$key = uc($self->get_key(SILENT, BLOCKING));
	} until(exists($mapping->{$key}) || $key eq chr(3) || !$self->is_connected());
	if ($key eq chr(3)) {
		$command = 'DISCONNECT';
	} else {
		$id      = $mapping->{$key}->{'id'};
		$command = $mapping->{$key}->{'command'};
		$url     = $mapping->{$key}->{'url'};
	}
	if ($self->is_connected() && $command ne 'DISCONNECT' && $command ne 'BACK') {
		$self->output($command);
		my $rss_string = `curl -s $url`;
		my $rss = XML::RSS::LibXML->new;
		$rss->parse($rss_string);

		my $list        = $rss->items;

		my $text;
		foreach my $item (@{$list}) {
			last unless ($self->is_connected());
			if ($mode eq 'ANSI') {
				$text .= '[% NAVY %]' . '━' x $self->{'USER'}->{'max_columns'} . "[% RESET %]\n";
				$text .= '[% BRIGHT WHITE %][% B_TEAL %]       Title [% RESET %] [% GREEN %]' . $self->html_to_text($item->{'title'}) . "[% RESET %]\n";
				$text .= '[% BRIGHT WHITE %][% B_TEAL %] Description [% RESET %] ' . $self->html_to_text($item->{'description'}) . "\n";
				$text .= '[% BRIGHT WHITE %][% B_TEAL %]        Link [% RESET %] [% YELLOW %]' . $item->{'link'} . "[% RESET %]\n";
			} elsif ($mode eq 'PETSCII') {
				$text .= '[% YELLOW %]       Title [% RESET %] [% GREEN %]' . $self->html_to_text($item->{'title'}) . "\n";
				$text .= '[% YELLOW %] Description [% RESET %] ' . $self->html_to_text($item->{'description'}) . "\n";
				$text .= '[% YELLOW %]        Link [% RESET %] [% YELLOW %]' . $item->{'link'} . "[% RESET %]\n";
			} else {
				$text .= '      Title:  ' . $item->{'title'} . "\n";
				$text .= 'Description:  ' . $self->html_to_text($item->{'description'}) . "\n";
				$text .= '       Link:  ' . $item->{'link'} . "\n\n";
			}
		}
		$self->output("\n\n" . $text);
		$self->output("\n\nPress any key to continue\n");
		$self->get_key(SILENT, BLOCKING);
		$command = 'BACK';
	}
	return($command);
}

sub news_title_colorize {
	my $self = shift;
	my $text = shift;

	my $mode = $self->{'USER'}->{'text_mode'};
	if ($mode eq 'ANSI') {
		if ($text =~ /fox news/i) {
			my $fox = '[% B_BLUE %][% BRIGHT WHITE %]FOX NEW[% B_RED %]S[% RESET %]';
			$text =~ s/fox news/$fox/gsi;
		} elsif ($text =~ /cnn news/i) {
			my $cnn = '[% BRIGHT RED %]CNN News[% RESET %]';
			$text =~ s/cnn/$cnn/gsi;
		} elsif ($text =~ /cbs news/i) {
			my $cbs = '[% BRIGHT BLUE %]CBS News[% RESET %]';
			$text =~ s/cbs/$cbs/gsi;
		} elsif ($text =~ /reuters/i) {
			my $reuters = '[% B_BRIGHT WHITE %][% ORANGE %]✺ [% BLACK %] Reuters[% RESET %]';
			$text =~ s/reuters/$reuters/gsi;
		} elsif ($text =~ /npr/i) {
			my $npr = '[% B_BRIGHT RED %][% BRIGHT WHITE %]n[% B_BLACK %]p[% B_BRIGHT BLUE %]r[% RESET %]';
			$text =~ s/npr/$npr/gsi;
		} elsif ($text =~ /bbc news/i) {
			my $bbc = '[% BRIGHT RED %][% B_BRIGHT WHITE %]BBC NEWS[% RESET %]';
			$text =~ s/bbc news/$bbc/gsi;
		} elsif ($text =~ /wired/i) {
			my $wired = '[% B_BLACK %][% BRIGHT WHITE %]W[% B_BRIGHT WHITE %][% BLACK %]I[% B_BLACK %][% BRIGHT WHITE %]R[% B_BRIGHT WHITE %][% BLACK %]E[% B_BLACK %][% BRIGHT WHITE %]D[% RESET %]';
			$text =~ s/wired/$wired/gsi;
		} elsif ($text =~ /daily wire/i) {
			my $dw = '[% BLACK %][% BRIGHT WHITE %]DAILY WIRE[% RED %]🞤[% RESET %]';
			$text =~ s/daily wire/$dw/gsi;
		} elsif ($text =~ /the blaze/i) {
			my $blaze = '[% B_BRIGHT WHITE %][% BLACK %]the[% RED %]Blaze[% RESET %]';
			$text =~ s/the blaze/$blaze/gsi;
		} elsif ($text =~ /national review/i) {
			my $nr = '[% B_BLACK %][% BRIGHT WHITE %]NR[% RESET %] National Review';
			$text =~ s/national review/$nr/gsi;
		} elsif ($text =~ /hot air/i) {
			my $hr = '[% BRIGHT WHITE %]HOT A[% RED %]i[% BRIGHT WHITE %]R[% RESET %]';
			$text =~ s/hot air/$hr/gsi;
		} elsif ($text =~ /gateway pundit/i) {
			my $gp = '[% B_WHITE %][% BRIGHT BLUE %]GP[% GOLD %]🭦[% RESET %] The Gateway Pundit';
			$text =~ s/gateway pundit/$gp/gsi;
		} elsif ($text =~ /daily signal/i) {
			my $ds = '[% B_BRIGHT WHITE %][% BLACK %]ⓢ [% RESET %] Daily Signal';
			$text =~ s/daily signal/$ds/gsi;
		} elsif ($text =~ /newsbusters/i) {
			my $nb = '[% ORANGE %]NewsBusters[% RESET %]';
			$text =~ s/newsbusters/$nb/gsi;
		} elsif ($text =~ /newsmax/i) {
			my $nm = '[% B_BLUE %][% RED %]N[% BRIGHT WHITE %]EWSMAX[% RESET %]';
			$text =~ s/newsmax/$nm/gsi;
		} elsif ($text =~ /american thinker/i) {
			my $at = '[% B_OLIVE %][% BLUE %]American Thinker[% RESET %]';
			$text =~ s/american thinker/$at/gsi;
		} elsif ($text =~ /pj media/i) {
			my $pj = '[% B_TEAL %][% BRIGHT WHITE %]PJ[% RESET %] Media';
			$text =~ s/pj media/$pj/gsi;
		} elsif ($text =~ /breitbart/i) {
			my $b = '[% B_DARK ORANGE %][% BRIGHT WHITE %] B [% RESET %] Breitbart';
			$text =~ s/breitbart/$b/gsi;
		}
	}
	return($text);
}
1;
