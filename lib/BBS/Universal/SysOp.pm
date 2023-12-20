package BBS::Universal::SysOp;
BEGIN { our $VERSION = '0.001'; }

sub sysop_initialize {
    my $self = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    #### Format Versions for display
	my $sections;
	if ($wsize <= 80) {
		$sections = 1;
	} elsif ($wsize <= 120) {
		$sections = 2;
	} elsif ($wsize <= 160) {
		$sections = 3;
	} elsif ($wsize <= 200) {
		$sections = 4;
	} elsif ($wsize <= 240) {
		$sections = 5;
	} elsif ($wsize >= 280) {
		$sections = 6;
	}
    my $versions = $self->sysop_versions_format($sections,FALSE);
    my $bbs_versions = $self->sysop_versions_format($sections,TRUE);

    $self->{'sysop_tokens'} = {
        'EURO'                             => chr(128),
        'ELIPSIS'                          => chr(133),
        'BULLET DOT'                       => chr(149),
		'HOLLOW BULLET DOT'                => '○',
        'BIG HYPHEN'                       => chr(150),
        'BIGGEST HYPHEN'                   => chr(151),
        'TRADEMARK'                        => chr(153),
        'CENTS'                            => chr(162),
        'POUND'                            => chr(163),
        'YEN'                              => chr(165),
        'COPYRIGHT'                        => chr(169),
        'DOUBLE LT'                        => chr(171),
        'REGISTERED'                       => chr(174),
        'OVERLINE'                         => chr(175),
        'DEGREE'                           => chr(176),
        'SQUARED'                          => chr(178),
        'CUBED'                            => chr(179),
        'MICRO'                            => chr(181),
        'MIDDLE DOT'                       => chr(183),
        'DOUBLE GT'                        => chr(187),
        'QUARTER'                          => chr(188),
        'HALF'                             => chr(189),
        'THREE QUARTERS'                   => chr(190),
        'INVERTED QUESTION'                => chr(191),
        'DIVISION'                         => chr(247),
		'HEART'                            => '♥',
		'CLUB'                             => '♣',
		'DIAMOND'                          => '♦',
		'LARGE PLUS'                       => '┼',
		'LARGE VERTICAL BAR'               => '│',
		'LARGE OVERLINE'                   => '▔',
		'LARGE UNDERLINE'                  => '▁',
        'BULLET RIGHT'                     => '▶',
        'BULLET LEFT'                      => '◀',
        'SMALL BULLET RIGHT'               => '▸',
        'SMALL BULLET LEFT'                => '◂',
        'BIG BULLET RIGHT'                 => '►',
        'BIG BULLET LEFT'                  => '◄',
        'BULLET DOWN'                      => '▼',
        'BULLET UP'                        => '▲',
        'WEDGE TOP LEFT'                   => '◢',
        'WEDGE TOP RIGHT'                  => '◣',
        'WEDGE BOTTOM LEFT'                => '◥',
        'WEDGE BOTTOM RIGHT'               => '◤',
        'LOWER ONE EIGHT BLOCK'            => '▁',
        'LOWER ONE QUARTER BLOCK'          => '▂',
        'LOWER THREE EIGHTHS BLOCK'        => '▃',
        'LOWER FIVE EIGTHS BLOCK'          => '▅',
        'LOWER THREE QUARTERS BLOCK'       => '▆',
        'LOWER SEVEN EIGHTHS BLOCK'        => '▇',
        'LEFT SEVEN EIGHTHS BLOCK'         => '▉',
        'LEFT THREE QUARTERS BLOCK'        => '▊',
        'LEFT FIVE EIGHTHS BLOCK'          => '▋',
        'LEFT THREE EIGHTHS BLOCK'         => '▍',
        'LEFT ONE QUARTER BLOCK'           => '▎',
        'LEFT ONE EIGHTH BLOCK'            => '▏',
        'MEDIUM SHADE'                     => '▒',
        'DARK SHADE'                       => ' ',
        'UPPER ONE EIGHTH BLOCK'           => '▔',
        'RIGHT ONE EIGHTH BLOCK'           => '▕',
        'LOWER LEFT QUADRANT'              => '▖',
        'LOWER RIGHT QUADRANT'             => '▗',
        'UPPER LEFT QUADRANT'              => '▘',
        'LEFT LOWER RIGHT QUADRANTS'       => '▙',
        'UPPER LEFT LOWER RIGHT QUADRANTS' => '▚',
        'LEFT UPPER RIGHT QUADRANTS'       => '▛',
        'UPPER LEFT RIGHT QUADRANTS'       => '▜',
        'UPPER RIGHT QUADRANT'             => '▝',
        'UPPER RIGHT LOWER LEFT QUADRANTS' => '▞',
        'RIGHT LOWER LEFT QUADRANTS'       => '▟',
        'THICK VERTICAL BAR'               => chr(0xA6),
        'THIN HORIZONTAL BAR'              => '─',
        'THICK HORIZONTAL BAR'             => '━',
        'THIN VERTICAL BAR'                => '│',
        'MEDIUM VERTICAL BAR'              => '┃',
        'THIN DASHED HORIZONTAL BAR'       => '┄',
        'THICK DASHED HORIZONTAL BAR'      => '┅',
        'THIN DASHED VERTICAL BAR'         => '┆',
        'THICK DASHED VERTICAL BAR'        => '┇',
        'THIN DOTTED HORIZONTAL BAR'       => '┈',
        'THICK DOTTED HORIZONTAL BAR'      => '┉',
        'MEDIUM DASHED VERTICAL BAR'       => '┊',
        'THICK DASHED VERTICAL BAR'        => '┋',
        'U250C'                            => '┌',
        'U250D'                            => '┍',
        'U250E'                            => '┎',
        'U250F'                            => '┏',
        'U2510'                            => '┐',
        'U2511'                            => '┑',
        'U2512'                            => '┒',
        'U2513'                            => '┓',
        'U2514'                            => '└',
        'U2515'                            => '┕',
        'U2516'                            => '┖',
        'U2517'                            => '┗',
        'U2518'                            => '┘',
        'U2519'                            => '┙',
        'U251A'                            => '┚',
        'U251B'                            => '┛',
        'U251C'                            => '├',
        'U251D'                            => '┝',
        'U251E'                            => '┞',
        'U251F'                            => '┟',
        'U2520'                            => '┠',
        'U2521'                            => '┡',
        'U2522'                            => '┢',
        'U2523'                            => '┣',
        'U2524'                            => '┤',
        'U2525'                            => '┥',
        'U2526'                            => '┦',
        'U2527'                            => '┧',
        'U2528'                            => '┨',
        'U2529'                            => '┩',
        'U252A'                            => '┪',
        'U252B'                            => '┫',
        'U252C'                            => '┬',
        'U252D'                            => '┭',
        'U252E'                            => '┮',
        'U252F'                            => '┯',
        'U2530'                            => '┰',
        'U2531'                            => '┱',
        'U2532'                            => '┲',
        'U2533'                            => '┳',
        'U2534'                            => '┴',
        'U2535'                            => '┵',
        'U2536'                            => '┶',
        'U2537'                            => '┷',
        'U2538'                            => '┸',
        'U2539'                            => '┹',
        'U253A'                            => '┺',
        'U253B'                            => '┻',
        'U235C'                            => '┼',
        'U253D'                            => '┽',
        'U253E'                            => '┾',
        'U253F'                            => '┿',
        'U2540'                            => '╀',
        'U2541'                            => '╁',
        'U2542'                            => '╂',
        'U2543'                            => '╃',
        'U2544'                            => '╄',
        'U2545'                            => '╅',
        'U2546'                            => '╆',
        'U2547'                            => '╇',
        'U2548'                            => '╈',
        'U2549'                            => '╉',
        'U254A'                            => '╊',
        'U254B'                            => '╋',
        'U254C'                            => '╌',
        'U254D'                            => '╍',
        'U254E'                            => '╎',
        'U254F'                            => '╏',
		'CHECK'                            => '✓',
		'PIE'                              => 'π',
        'TOP LEFT ROUNDED'                 => '╭',
        'TOP RIGHT ROUNDED'                => '╮',
        'BOTTOM RIGHT ROUNDED'             => '╯',
        'BOTTOM LEFT ROUNDED'              => '╰',
        'FULL FORWARD SLASH'               => '╱',
        'FULL BACKWZARD SLASH'             => '╲',
        'FULL X'                           => '╳',
        'THIN LEFT HALF HYPHEN'            => '╴',
        'THIN TOP HALF BAR'                => '╵',
        'THIN RIGHT HALF HYPHEN'           => '╶',
        'THIN BOTTOM HALF BAR'             => '╷',
        'THICK LEFT HALF HYPHEN'           => '╸',
        'THICK TOP HALF BAR'               => '╹',
        'THICK RIGHT HALF HYPHEN'          => '╺',
        'THICK BOTTOM HALF BAR'            => '╻',
        'RIGHT TELESCOPE'                  => '╼',
        'DOWN TELESCOPE'                   => '╽',
        'LEFT TELESCOPE'                   => '╾',
        'UP TELESCOPE'                     => '╿',
        'MIDDLE VERTICAL RULE BLACK'       => $self->sysop_locate_middle('B_BLACK'),
        'MIDDLE VERTICAL RULE RED'         => $self->sysop_locate_middle('B_RED'),
        'MIDDLE VERTICAL RULE GREEN'       => $self->sysop_locate_middle('B_GREEN'),
        'MIDDLE VERTICAL RULE YELLOW'      => $self->sysop_locate_middle('B_YELLOW'),
        'MIDDLE VERTICAL RULE BLUE'        => $self->sysop_locate_middle('B_BLUE'),
        'MIDDLE VERTICAL RULE MAGENTA'     => $self->sysop_locate_middle('B_MAGENTA'),
        'MIDDLE VERTICAL RULE CYAN'        => $self->sysop_locate_middle('B_CYAN'),
        'MIDDLE VERTICAL RULE WHITE'       => $self->sysop_locate_middle('B_WHITE'),
        'HORIZONTAL RULE RED'              => "\r" . $self->{'ansi_sequences'}->{'B_RED'} . clline . $self->{'ansi_sequences'}->{'RESET'},        # Needs color defined before actual use
        'HORIZONTAL RULE GREEN'            => "\r" . $self->{'ansi_sequences'}->{'B_GREEN'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use
        'HORIZONTAL RULE YELLOW'           => "\r" . $self->{'ansi_sequences'}->{'B_YELLOW'} . clline . $self->{'ansi_sequences'}->{'RESET'},     # Needs color defined before actual use
        'HORIZONTAL RULE BLUE'             => "\r" . $self->{'ansi_sequences'}->{'B_BLUE'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE MAGENTA'          => "\r" . $self->{'ansi_sequences'}->{'B_MAGENTA'} . clline . $self->{'ansi_sequences'}->{'RESET'},    # Needs color defined before actual use
        'HORIZONTAL RULE CYAN'             => "\r" . $self->{'ansi_sequences'}->{'B_CYAN'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE WHITE'            => "\r" . $self->{'ansi_sequences'}->{'B_WHITE'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use

        # Tokens
        'HOSTNAME'        => $self->sysop_hostname,
        'IP ADDRESS'      => $self->sysop_ip_address(),
        'CPU CORES'       => $self->{'CPU'}->{'CPU CORES'},
        'CPU SPEED'       => $self->{'CPU'}->{'CPU SPEED'},
        'CPU IDENTITY'    => $self->{'CPU'}->{'CPU IDENTITY'},
        'CPU THREADS'     => $self->{'CPU'}->{'CPU THREADS'},
        'HARDWARE'        => $self->{'CPU'}->{'HARDWARE'},
        'VERSIONS'        => $versions,
		'BBS VERSIONS'    => $bbs_versions,
        'BBS NAME'        => colored(['green'], $self->{'CONF'}->{'BBS NAME'}),
		# Non-static
        'THREADS COUNT'   => sub {
			my $self = shift;
			return($main::THREADS_RUNNING);
		},
        'USERS COUNT'     => sub {
			my $self = shift;
			return($self->db_count_users());
		},
        'UPTIME'          => sub {
			my $self = shift;
			return($self->get_uptime());
		},
        'DISK FREE SPACE' => sub {
			my $self = shift;
			return($self->sysop_disk_free());
		},
        'MEMORY'          => sub {
			my $self = shift;
			return($self->sysop_memory());
		},
		'ONLINE'          => sub {
			my $self = shift;
			return($self->sysop_online_count());
		},
        'CPU LOAD'        => sub {
			my $self = shift;
			return($self->cpu_info->{'CPU LOAD'});
		},
		'ENVIRONMENT'     => sub {
			my $self = shift;
			return($self->sysop_showenv());
		},
    };
	$self->{'SYSOP ORDER DETAILED'} = [qw(
		id
		fullname
		username
		given
		family
		nickname
		birthday
		location
		baud_rate
		text_mode
		max_columns
		max_rows
		suffix
		timeout
		retro_systems
		accomplishments
		prefer_nickname
		view_files
		upload_files
		download_files
		remove_files
		read_message
		post_message
		remove_message
		sysop
		page_sysop
		login_time
		logout_time
	)];
	$self->{'SYSOP ORDER ABBREVIATED'} = [qw(
		id
		fullname
		username
		given
		family
		nickname
		text_mode
	)];
	$self->{'SYSOP HEADING WIDTHS'} = {
		'id' => 2,
		'username' => 16,
		'fullname' => 20,
		'given' => 12,
		'family' => 12,
		'nickname' => 8,
		'birthday' => 10,
		'location' => 20,
		'baud_rate' => 4,
		'login_time' => 10,
		'logout_time' => 10,
		'text_mode' => 9,
		'max_rows' => 5,
		'max_columns' => 5,
		'suffix' => 3,
		'timeout' => 5,
		'retro_systems' => 20,
		'accomplishments' => 20,
		'prefer_nickname' => 2,
		'view_files' => 2,
		'upload_files' => 2,
		'download_files' => 2,
		'remove_files' => 2,
		'read_message' => 2,
		'post_message' => 2,
		'remove_message' => 2,
		'sysop' => 2,
		'page_sysop' => 2,
		'password' => 64,
	};
    #$self->{'debug'}->ERROR($self);exit;
    $self->{'debug'}->DEBUG(['Initialized SysOp object']);
    return ($self);
} ## end sub sysop_initialize

sub sysop_online_count {
	my $self = shift;

	return($main::ONLINE);
}

sub sysop_versions_format {
	my $self     = shift;
	my $sections = shift;
	my $bbs_only = shift;

	my $versions = "\n\t";
	my $heading  = "\t";
	my $counter  = $sections;

	for(my $count = $sections - 1 ;$count > 0;$count--) {
		$heading .= ' NAME                          VERSION ';
		if ($count) {
			$heading .= "\t\t";
		} else {
			$heading .= "\n";
		}
	}
	$heading = colored(['yellow on_red'], $heading);
	foreach my $v (@{ $self->{'VERSIONS'} }) {
		next if ($bbs_only && $v !~ /^BBS/);
		$versions .= "\t\t $v";
		$counter--;
		if ($counter <= 1) {
			$counter = $sections;
			$versions .= "\n\t";
		}
	}
	chop($versions) if (substr($versions,-1,1) eq "\t");
	return($heading . $versions . "\n");
}

sub sysop_disk_free { # Show the Disk Free portion of Statistics
    my $self = shift;

    my @free     = split(/\n/, `nice df -h -T`); # Get human readable disk free showing type
    my $diskfree = '';
	my $width = 1;
	foreach my $l (@free) {
		$width = max(length($l),$width); # find the width of the widest line
	}
    foreach my $line (@free) {
        next if ($line =~ /tmp|boot/);
        if ($line =~ /^Filesystem/) {
            $diskfree .= "\t" . colored(['bold yellow on_blue'], " $line " . ' ' x ($width - length($line))) . "\n"; # Make the heading the right width
        } else {
            $diskfree .= "\t\t\t $line\n";
        }
    } ## end foreach my $line (@free)
    return ($diskfree);
} ## end sub sysop_disk_free

sub sysop_first_time_setup {
    my $self = shift;
    my $row  = shift;

    print locate($row, 1), cldown;
	my $found = FALSE;
	my @sql_files = ('./sql/database_setup.sql','~/.bbs_universal/database_setup.sql');
	foreach my $file (@sql_files) {
		if (-e $file) {
			$self->{'debug'}->DEBUG(["SQL file $file found"]);
			$found = TRUE;
			$self->db_sql_execute($file);
			last;
		}
		$self->{'debug'}->WARNING(["SQL file $file not found"]);
	}
	unless($found) {
		$self->{'debug'}->ERROR(['Database setup file not found',join("\n",@sql_files)]);
		exit(1);
	}
} ## end sub sysop_first_time_setup

sub sysop_load_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = { 'TEXT' => '' };
    my $mode    = 1;
    my $text    = locate($row, 1) . cldown;
    open(my $FILE, '<', $file);

    while (chomp(my $line = <$FILE>)) {
		next if ($line =~ /^\#/);
        $self->{'debug'}->DEBUGMAX([$line]);
        if ($mode) {
            if ($line !~ /^---/) {
                my ($k, $cmd, $color, $t) = split(/\|/, $line);
                $k   = uc($k);
                $cmd = uc($cmd);
                $self->{'debug'}->DEBUGMAX([$k, $cmd, $color, $t]);
                $mapping->{$k} = {
                    'command' => $cmd,
                    'color'   => $color,
                    'text'    => $t,
                };
				$mapping->{$k}->{'color'} =~ s/(BRIGHT) /${1}_/; # Make it Term::ANSIColor friendly
            } else {
                $mode = 0;
            }
        } else {
            $mapping->{'TEXT'} .= $self->sysop_detokenize($line) . "\n";
        }
    } ## end while (chomp(my $line = <$FILE>...))
    close($FILE);
    return ($mapping);
} ## end sub sysop_load_menu

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUG(['Loaded SysOp Menu']);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $keys = '';
	$self->sysop_show_choices($mapping);
    print "\n",$self->sysop_prompt('Choose');
    my $key;
    do {
        $key = uc($self->sysop_keypress());
    } until (exists($mapping->{$key}));
    print $mapping->{$key}->{'command'}, "\n";
    return ($mapping->{$key}->{'command'});
} ## end sub sysop_parse_menu

sub sysop_decision {
    my $self = shift;

    my $response;
    do {
        $response = uc($self->sysop_keypress());
    } until ($response =~ /Y|N/i);
    if ($response eq 'Y') {
        print "YES\n";
        return (TRUE);
    }
    print "NO\n";
    return (FALSE);
} ## end sub sysop_decision

sub sysop_keypress {
    my $self = shift;
    my $key;
    ReadMode 4;
    do {
        $key = ReadKey(0);
        threads->yield();
    } until (defined($key));
    ReadMode 0;
    return ($key);
} ## end sub sysop_keypress

sub sysop_ip_address {
    my $self = shift;

    chomp(my $ip = `nice hostname -I`);
    return ($ip);
} ## end sub sysop_ip_address

sub sysop_hostname {
    my $self = shift;

    chomp(my $hostname = `nice hostname`);
    return ($hostname);
} ## end sub sysop_hostname

sub sysop_locate_middle {
    my $self  = shift;
    my $color = shift || 'B_WHITE';

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $middle = int($wsize / 2);
    my $string = "\r" . $self->{'ansi_sequences'}->{'RIGHT'} x $middle . $self->{'ansi_sequences'}->{$color} . ' ' . $self->{'ansi_sequences'}->{'RESET'};
    return ($string);
} ## end sub sysop_locate_middle

sub sysop_memory {
    my $self = shift;

    my $memory = `nice free`;
    my @mem    = split(/\n/, $memory);
    my $output = "\t" . colored(['bold black on_green'], '  ' . shift(@mem) . ' ') . "\n";
    while (scalar(@mem)) {
        $output .= "\t\t\t" . shift(@mem) . "\n";
    }
    if ($output =~ /(Mem\:       )/) {
        my $ch = colored(['bold black on_green'], ' ' . $1 . ' ');
        $output =~ s/Mem\:       /$ch/;
    }
    if ($output =~ /(Swap\:      )/) {
        my $ch = colored(['bold black on_green'], ' ' . $1 . ' ');
        $output =~ s/Swap\:      /$ch/;
    }
    return ($output);
} ## end sub sysop_memory

sub sysop_true_false {
	my $self = shift;
	my $boolean = shift;
	my $mode = shift;
	$boolean = $boolean + 0;
	if ($mode eq 'TF') {
		return(($boolean) ? 'TRUE' : 'FALSE');
	} elsif($mode eq 'YN') {
		return(($boolean) ? 'Yes' : 'No');
	}
	return($boolean);
}

sub sysop_list_users {
	my $self = shift;
	my $list_mode = shift;;

	my $table;
	$self->{'debug'}->DEBUG($list_mode);
	my $date_format = $self->configuration('SHORT DATE FORMAT');
	my $name_width = 15;
	my $value_width = 60;
	my $sth;
	my @order;
	my $sql;
	if ($list_mode =~ /DETAILED/) {
		$sql = q{
            SELECT
			  id,
			  username,
			  fullname,
			  given,
			  family,
			  nickname,
			  DATE_FORMAT(birthday,'} . $date_format . q{') AS birthday,
			  location,
			  baud_rate,
			  DATE_FORMAT(login_time,'} . $date_format . q{') AS login_time,
			  DATE_FORMAT(logout_time,'} . $date_format . q{') AS logout_time,
			  text_mode,
			  max_columns,
			  max_rows,
			  suffix,
			  timeout,
			  retro_systems,
			  accomplishments,
			  prefer_nickname,
			  view_files,
			  upload_files,
			  download_files,
			  remove_files,
			  read_message,
			  post_message,
			  remove_message,
			  sysop,
			  page_sysop
			  FROM
			  users_view };
		$sth = $self->{'dbh'}->prepare($sql);
		@order = @{$self->{'SYSOP ORDER DETAILED'}};
	} else {
		@order = @{$self->{'SYSOP ORDER ABBREVIATED'}};
		$sql = 'SELECT id,username,fullname,given,family,nickname,text_mode FROM users_view';
		$sth = $self->{'dbh'}->prepare($sql);
	}
	$sth->execute();
	if ($list_mode =~ /VERTICAL/) {
		while(my $row = $sth->fetchrow_hashref()) {
			foreach my $name (@order) {
				next if ($name =~ /retro_systems|accomplishments/);
				if ($name ne 'id' && $row->{$name} =~ /^(0|1)$/) {
					$row->{$name} = $self->sysop_true_false($row->{$name},'YN');
				}
				$value_width = max(length($row->{$name}),$value_width);
				$self->{'debug'}->DEBUGMAX([$row,$name_width,$value_width]);
			}
		}
		$sth->finish();
		$self->{'debug'}->DEBUG(['Populate the table']);
		$sth = $self->{'dbh'}->prepare($sql);
		$sth->execute();
		$table = Text::SimpleTable->new($name_width,$value_width);
		$table->row('NAME','VALUE');
		$table->hr();
		while(my $Row = $sth->fetchrow_hashref()) {
			foreach my $name (@order) {
				if ($name ne 'id' && $Row->{$name} =~ /^(0|1)$/) {
					$Row->{$name} = $self->sysop_true_false($Row->{$name},'YN');
				} elsif ($name eq 'timeout') {
					$Row->{$name} = $Row->{$name} . ' Minutes'
				}
				$self->{'debug'}->DEBUGMAX([$name,$Row->{$name}]);
				$table->row($name . '',$Row->{$name} . '');
			}
		}
		$sth->finish();
		$self->{'debug'}->DEBUG(['Show table']);
		my $string = $table->boxes->draw();
		$self->{'debug'}->DEBUGMAX(\$string);
		print "$string\n";
	} else { # Horizontal
		my @hw;
		foreach my $name (@order) {
			push(@hw,$self->{'SYSOP HEADING WIDTHS'}->{$name});
		}
		$self->{'debug'}->DEBUGMAX(\@hw);
		$table = Text::SimpleTable->new(@hw);
		if ($list_mode =~ /ABBREVIATED/) {
			$table->row(@order);
		} else {
			my @title = ();
			foreach my $heading (@order) {
				push(@title,$self->sysop_vertical_heading($heading));
			}
			$table->row(@title);
		}
		$table->hr();
		while(my $row = $sth->fetchrow_hashref()) {
			my @vals = ();
			foreach my $name (@order) {
				push(@vals,$row->{$name} . '');
				$self->{'debug'}->DEBUGMAX([$name,$row->{$name}]);
			}
			$table->row(@vals);
		}
		$sth->finish();
		$self->{'debug'}->DEBUG(['Show table']);
		my $string = $table->boxes->draw();
		$self->{'debug'}->DEBUGMAX(\$string);
		print "$string\n";
	}
	print 'Press a key to continue ... ';
	return ($self->sysop_keypress(TRUE));
	return(TRUE);
}

sub sysop_vertical_heading {
	my $self = shift;
	my $text = shift;

	my $heading = '';
	for (my $count = 0;$count < length($text);$count++) {
		$heading .= substr($text,$count,1) . "\n";
	}
	return($heading);
}

sub sysop_view_configuration {
    my $self = shift;
    my $view = shift;

    # Get maximum widths
    my $name_width  = 6;
    my $value_width = 50;
    foreach my $cnf (keys %{ $self->configuration() }) {
        if ($cnf eq 'STATIC') {
            foreach my $static (keys %{ $self->{'CONF'}->{$cnf} }) {
                $name_width  = max(length($static),                            $name_width);
                $value_width = max(length($self->{'CONF'}->{$cnf}->{$static}), $value_width);
            }
        } else {
            $name_width  = max(length($cnf),                    $name_width);
            $value_width = max(length($self->{'CONF'}->{$cnf}), $value_width);
        }
    } ## end foreach my $cnf (keys %{ $self...})
    $self->{'debug'}->DEBUGMAX([$name_width, $value_width]);

    # Assemble table
    my $table = ($view) ? Text::SimpleTable->new($name_width, $value_width) : Text::SimpleTable->new(6, $name_width, $value_width);
    if ($view) {
        $table->row('STATIC NAME', 'STATIC VALUE');
    } else {
        $table->row(' ', 'STATIC NAME', 'STATIC VALUE');
    }
    $table->hr();
    foreach my $conf (sort(keys %{ $self->{'CONF'}->{'STATIC'} })) {
        next if ($conf eq 'DATABASE PASSWORD');
        if ($view) {
            $table->row($conf, $self->{'CONF'}->{'STATIC'}->{$conf});
        } else {
            $table->row(' ', $conf, $self->{'CONF'}->{'STATIC'}->{$conf});
        }
    } ## end foreach my $conf (keys %{ $self...})
    $table->hr();
    if ($view) {
        $table->row('NAME IN DB', 'VALUE IN DB');
    } else {
        $table->row('CHOICE', 'NAME IN DB', 'VALUE IN DB');
    }
    $table->hr();
    my $count = 0;
    foreach my $conf (sort(keys %{ $self->{'CONF'} })) {
        next if ($conf eq 'STATIC');
        if ($view) {
            $table->row($conf, $self->{'CONF'}->{$conf});
        } else {
            if ($conf =~ /AUTHOR/) {
                $table->row(' ', $conf, $self->{'CONF'}->{$conf});
            } else {
                $table->row($count, $conf, $self->{'CONF'}->{$conf});
                $count++;
            }
        } ## end else [ if ($view) ]
    } ## end foreach my $conf (sort(keys...))
    my $output = $table->boxes->draw();
    foreach my $change ('AUTHOR EMAIL','AUTHOR LOCATION','AUTHOR NAME','STATIC NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME') {
        if ($output =~ /($change)/) {
            my $ch = colored(['yellow'], $1);
            $output =~ s/$1/$ch/gs;
        }
    } ## end foreach my $change ('STATIC NAME'...)
    print $output;
    if ($view) {
        print 'Press a key to continue ... ';
        return ($self->sysop_keypress(TRUE));
    } else {
		print $self->sysop_menu_choice('TOP','','');
		print $self->sysop_menu_choice('Z','RED','Return to Settings Menu');
		print $self->sysop_menu_choice('BOTTOM','','');
		print $self->sysop_prompt('Choose');
        return (TRUE);
    }
} ## end sub sysop_view_configuration

sub sysop_edit_configuration {
    my $self = shift;

	$self->sysop_view_configuration(FALSE);
	my $choice;
    do {
		$choice = $self->sysop_keypress(TRUE);
    } until ($choice =~ /\d|Z/i);
	if ($choice !~ /\d/i) {
		print "BACK\n";
		return (FALSE);
	}
    my @conf = grep(!/STATIC|AUTHOR/, sort(keys %{ $self->{'CONF'} }));
    $self->{'debug'}->DEBUGMAX(["Choice $choice $conf[$choice]"]);
    print '(Edit) ', $conf[$choice], ' ', $self->{'sysop_tokens'}->{'BIG BULLET RIGHT'}, '  ';
    my $sizes = {
        'BAUD RATE'         => 4,
        'BBS NAME'          => 50,
        'BBS ROOT'          => 60,
        'HOST'              => 20,
        'THREAD MULTIPLIER' => 2,
        'PORT'              => 5,
    };
    my $string = $self->sysop_get_line($sizes->{ $conf[$choice] });
    return (FALSE) if ($string eq '');
    $self->{'debug'}->DEBUGMAX(["New value $conf[$choice] = $string"]);
    $self->configuration($conf[$choice], $string);
    return (TRUE);
} ## end sub sysop_edit_configuration

sub sysop_get_line {
    my $self  = shift;
    my $width = shift || 50;

    print savepos,
	  "\n",
	  loadpos,
	  $self->{'ansi_sequences'}->{'DOWN'},
	  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x $width,
	  loadpos;
	chomp(my $response = <STDIN>);
    # TEMP
    return ($response);
} ## end sub sysop_get_line

sub sysop_user_edit {
    my $self = shift;
	my $row  = shift;
	my $file = shift;

	$self->{'debug'}->DEBUG(['Begin user Edit']);
    my $mapping = $self->sysop_load_menu($row,$file);
	$self->{'debug'}->DEBUGMAX([$mapping]);
	print locate($row,1),cldown,$mapping->{'TEXT'};
	delete($mapping->{'TEXT'});
	my ($key_exit) = (keys %{$mapping});
	my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
	my $key;
	print $self->sysop_prompt('Please enter the username or account number');
	my $search = $self->sysop_get_line(20);
	return(FALSE) if ($search eq '');
	my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
	$sth->execute($search,$search);
	my $user_row = $sth->fetchrow_hashref();
	$sth->finish();
	if (defined($user_row)) {
		$self->{'debug'}->DEBUGMAX($user_row);
		my $table = Text::SimpleTable->new(6,16,60);
		$table->row('CHOICE','FIELD','VALUE');
		$table->hr();
		my $count = 0;
		$self->{'debug'}->DEBUGMAX(['HERE',$self->{'SYSOP ORDER DETAILED'}]);
		my %choice;
		foreach my $field (@{$self->{'SYSOP ORDER DETAILED'}}) {
			if ($field =~ /_time|fullname|id/) {
				$table->row(' ',$field,$user_row->{$field} . '');
			} else {
				if ($field ne 'id' && $user_row->{$field} =~ /^(0|1)$/) {
					$user_row->{$field} = $self->sysop_true_false($user_row->{$field},'YN');
				} elsif ($field eq 'timeout') {
					$user_row->{$field} = $user_row->{$field} . ' Minutes'
				}
				$count++ if ($key_exit eq $choices[$count]);
				$table->row($choices[$count],$field,$user_row->{$field} . '');
				$choice{$choices[$count]} = $field;
				$count++;
			}
		}
		print $table->boxes->draw(),"\n";
		$self->{'debug'}->DEBUGMAX([$mapping]);
		$self->sysop_show_choices($mapping);
		print "\n",$self->sysop_prompt('Choose');
		do {
			$key = uc($self->sysop_keypress());
		} until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
		if ($key !~ /$key_exit/i) {
			print 'Edit > (', $choice{$key}, ' = ', $user_row->{$choice{$key}},') > ';
			my $new = $self->sysop_get_line(1+$self->{'SYSOP HEADING WIDTHS'}->{$choice{$key}});
			unless($new eq '') {
				$new =~ s/^(Yes|On)$/1/i;
				$new =~ s/^(No|Off)$/0/i;
			}
			if ($key =~ /prefer_nickname|view_files|upload_files|download_files|remove_files|read_message|post_message|remove_message|sysop|page_sysop/) {
				my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . choice{$key} . '=? WHERE id=?');
				$sth->execute($new,$user_row->{'id'});
				$sth->finish();
			} else {
				my $sth = $self->{'dbh'}->prepare('UPDATE users SET ' . $choice{$key} . '=? WHERE id=?');
				$sth->execute($new,$user_row->{'id'});
				$sth->finish();
			}
		}
	} elsif ($search ne '') {
		print "User not found!\n\n";
	}
    return (TRUE);
}

sub sysop_user_add {
	my $self = shift;
	my $row  = shift;
	my $file = shift;

	my $flags_default = {
		'prefer_nickname' => 'Yes',
		'view_files' => 'Yes',
		'upload_files' => 'No',
		'download_files' => 'Yes',
		'remove_files' => 'No',
		'read_message' => 'Yes',
		'post_message' => 'Yes',
		'remove_message' => 'No',
		'sysop' => 'No',
		'page_sysop' => 'Yes',
	};
    my $mapping = $self->sysop_load_menu($row,$file);
	$self->{'debug'}->DEBUGMAX([$mapping]);
	print locate($row,1),cldown,$mapping->{'TEXT'};
	my $table = Text::SimpleTable->new(15,80);
	my $user_template;
	push(@{$self->{'SYSOP ORDER DETAILED'}},'password');
	foreach my $name (@{$self->{'SYSOP ORDER DETAILED'}}) {
		next if ($name =~ /id|fullname|_time|suffix|max_/);
		if ($name eq 'timeout') {
			$table->row($name,' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Minutes\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
		} elsif ($name eq 'baud_rate') {
			$table->row($name,' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (300,1200,2400,4800,9600,FULL)\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
		} elsif ($name =~ /username|given|family|password/) {
			if ($name eq 'given') {
				$table->row("$name (first)",' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
			} elsif ($name eq 'family') {
				$table->row("$name (last)",' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
			} else {
				$table->row($name,' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
			}
		} elsif ($name eq 'text_mode') {
			$table->row($name,' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (ASCII,ATASCII,PETSCII,ANSI)\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
		} elsif ($name eq 'birthday') {
			$table->row($name,' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " YEAR-MM-DD\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
		} elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/) {
			$table->row($name,' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (Yes/No or On/Off or 1/0)\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
		} elsif ($name =~ /location|retro_systems|accomplishments/) {
			$table->row($name,"\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x ($self->{'SYSOP HEADING WIDTHS'}->{$name} * 4));
		} else {
			$table->row($name,"\n" .  $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}));
		}
		$user_template->{$name} = undef;
	}
	print $table->boxes->draw();
	$self->sysop_show_choices($mapping);
	my $column = 21;
	my $adjustment = 7;
    foreach my $entry (@{$self->{'SYSOP ORDER DETAILED'}}) {
		next if ($entry =~ /id|fullname|_time|suffix/);
		do {
			print locate($row + $adjustment,$column), ' ' x max(3,$self->{'SYSOP HEADING WIDTHS'}->{$entry}), locate($row + $adjustment,$column);
			chomp($user_template->{$entry} = <STDIN>);
			return('BACK') if ($user_template->{$entry} eq '<');
			if ($entry =~ /text_mode|baud_rate|timeout|prefer|_files|_message|sysop|given|family/) {
				if ($user_template->{$entry} eq '') {
					if ($entry eq 'text_mode') {
						$user_template->{$entry} = 'ASCII';
					} elsif ($entry eq 'baud_rate') {
						$user_template->{$entry} = 'FULL';
					} elsif ($entry eq 'timeout') {
						$user_template->{$entry} = $self->{'CONF'}->{'DEFAULT TIMEOUT'};
					} elsif ($entry =~ /prefer|_files|_message|sysop/) {
						$user_template->{$entry} = $flags_default->{$entry};
					} else {
						$user_template->{$entry} = uc($user_template->{$entry});
					}
				} elsif ($entry =~ /given|family/) {
					my $ucuser = uc($user_template->{$entry});
					if ($ucuser eq $user_template->{$entry}) {
						$user_template->{$entry} = ucfirst(lc($user_template->{$entry}));
					} else {
						substr($user_template->{$entry},0,1) = uc(substr($user_template->{$entry},0,1));
					}
				}
				print locate($row + $adjustment,$column), $user_template->{$entry};
			} elsif ($entry =~ /prefer_|_files|_message|sysop/) {
				$user_template->{$entry} = ucfirst($user_template->{$entry});
				print locate($row + $adjustment,$column), $user_template->{$entry};
			}
		} until($self->sysop_validate_fields($entry,$user_template->{$entry},$row + $adjustment,$column));
		$self->{'debug'}->DEBUGMAX([$entry,$user_template]);
		if ($user_template->{$entry} =~ /^(yes|on|true)$/i) {
			$user_template->{$entry} = TRUE;
		} elsif ($user_template->{$entry} =~ /^(no|off|false)$/i) {
			$user_template->{$entry} = FALSE;
		}
		$adjustment += 2;
	}
	pop(@{$self->{'SYSOP ORDER DETAILED'}});
	$self->{'dbh'}->begin_work;
	my $sth = $self->{'dbh'}->prepare(
		q{
			INSERT INTO users (
				username,
				given,
				family,
				nickname,
				accomplishments,
				retro_systems,
				birthday,
				location,
				baud_rate,
				text_mode,
				password)
			  VALUES (?,?,?,?,?,?,DATE(?),?,?,(SELECT text_modes.id FROM text_modes WHERE text_modes.text_mode=?),SHA2(?,512))
		}
	);
	$self->{'debug'}->DEBUGMAX($user_template);
	$sth->execute(
		$user_template->{'username'},
		$user_template->{'given'},
		$user_template->{'family'},
		$user_template->{'nickname'},
		$user_template->{'accomplishments'},
		$user_template->{'retro_systems'},
		$user_template->{'birthday'},
		$user_template->{'location'},
		$user_template->{'baud_rate'},
		$user_template->{'text_mode'},
		$user_template->{'password'},
	) or $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
	$sth = $self->{'dbh'}->prepare(
		q{
			INSERT INTO permissions (
				id,
				prefer_nickname,
				view_files,
				upload_files,
				download_files,
				remove_files,
				read_message,
				post_message,
				remove_message,
				sysop,
				page_sysop,
				timeout)
			  VALUES (LAST_INSERT_ID(),?,?,?,?,?,?,?,?,?,?,?);
		}
	);
	$sth->execute(
		$user_template->{'prefer_nickname'},
		$user_template->{'view_files'},
		$user_template->{'upload_files'},
		$user_template->{'download_files'},
		$user_template->{'remove_files'},
		$user_template->{'read_message'},
		$user_template->{'post_message'},
		$user_template->{'remove_message'},
		$user_template->{'sysop'},
		$user_template->{'page_sysop'},
		$user_template->{'timeout'}
	);
	if ($self->{'dbh'}->errstr) {
		$self->{'dbh'}->rollback;
		$self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
	} else {
		$self->{'dbh'}->commit;
		print colored(['gtreen'],"\n\nSUCCESS!");
		sleep(0.5);
	}
	$sth->finish();
	exit;
	return(TRUE);
}

sub sysop_show_choices {
	my $self = shift;
	my $mapping = shift;

	print $self->sysop_menu_choice('TOP','','');
	my $keys = '';
	foreach my $kmenu (sort(keys %{$mapping})) {
		next if ($kmenu eq 'TEXT');
		print $self->sysop_menu_choice($kmenu,$mapping->{$kmenu}->{'color'},$mapping->{$kmenu}->{'text'});
		$keys .= $kmenu;
	}
	print $self->sysop_menu_choice('BOTTOM','','');
	return(TRUE);
}

sub sysop_validate_fields {
	my $self   = shift;
	my $name   = shift;
	my $val    = shift;
	my $row    = shift;
	my $column = shift;

	$self->{'debug'}->DEBUGMAX([$name,$val,$row,$column]);
	if ($name =~ /(username|given|family|baud_rate|timeout|_files|_message|sysop|prefer|password)/ && $val eq '') { # cannot be empty
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' Cannot Be Empty'),locate($row,$column);
		return(FALSE);
	} elsif ($name eq 'baud_rate' && $val !~ /^(300|1200|2400|4800|9600|FULL)$/i) {
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' Only 300,1200,2400,4800,9600,FULL'),locate($row,$column);
		return(FALSE);
	} elsif ($name =~ /max_/ && $val =~ /\D/i) {
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' Only Numeric Values'),locate($row,$column);
		return(FALSE);
	} elsif ($name eq 'timeout' && $val =~ /\D/) {
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' Must be numeric'),locate($row,$column);
		return(FALSE);
	} elsif ($name eq 'text_mode' && $val !~ /^(ASCII|ATASCII|PETSCII|ANSI)$/) {
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' Only ASCII,ATASCII,PETSCII,ANSI'),locate($row,$column);
		return(FALSE);
	} elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/ && $val !~ /^(yes|no|true|false|on|off|0|1)$/i) {
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' Only Yes/No or On/Off or 1/0'),locate($row,$column);
		return(FALSE);
	} elsif ($name eq 'birthday' && $val ne '' && $val !~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
		print locate($row,($column + max(3,$self->{'SYSOP HEADING WIDTHS'}->{$name}))),colored(['red'],' YEAR-MM-DD'),locate($row,$column);
		return(FALSE);
	}
	return(TRUE);
}

sub sysop_prompt {
	my $self = shift;
	my $text = shift;
	my $response =
	  $text .
	  ' ' .
	  $self->{'sysop_tokens'}->{'BIG BULLET RIGHT'} .
	  ' ';
	return($response);
}

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUGMAX([$text]);    # Before
    foreach my $key (keys %{ $self->{'sysop_tokens'} }) {
        my $ch = '';
		if (ref($self->{'sysop_tokens'}->{$key}) eq 'CODE') {
			$ch = $self->{'sysop_tokens'}->{$key}->($self);
		} else {
			$ch = $self->{'sysop_tokens'}->{$key};
		}
        $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
    }
    foreach my $name (keys %{ $self->{'ansi_sequences'} }) {
        my $ch = $self->{'ansi_sequences'}->{$name};
		if ($name eq 'CLEAR') {
			$ch = locate(($main::START_ROW + $main::ROW_ADJUST),1) . cldown;
		}
		$text =~ s/\[\%\s+$name\s+\%\]/$ch/sgi;
    }
    $self->{'debug'}->DEBUGMAX([$text]);    # After

    return ($text);
} ## end sub sysop_detokenize

sub sysop_menu_choice {
	my $self   = shift;
	my $choice = shift;
	my $color  = shift;
	my $desc   = shift;

	my $response;
	if ($choice eq 'TOP') {
		$response =
		  $self->{'sysop_tokens'}->{'TOP LEFT ROUNDED'} .
		  $self->{'sysop_tokens'}->{'THIN HORIZONTAL BAR'} .
		  $self->{'sysop_tokens'}->{'TOP RIGHT ROUNDED'} .
		  "\n";
	} elsif ($choice eq 'BOTTOM') {
		$response =
		  $self->{'sysop_tokens'}->{'BOTTOM LEFT ROUNDED'} .
		  $self->{'sysop_tokens'}->{'THIN HORIZONTAL BAR'} .
		  $self->{'sysop_tokens'}->{'BOTTOM RIGHT ROUNDED'} .
		  "\n";
	} else {
		$response =
		  $self->{'sysop_tokens'}->{'THIN VERTICAL BAR'} .
		  colored(["BOLD $color"],$choice) .
		  $self->{'sysop_tokens'}->{'THIN VERTICAL BAR'} .
		  ' ' .
		  colored([$color],$self->{'sysop_tokens'}->{'BIG BULLET RIGHT'}) .
		  ' ' .
		  $desc .
		  "\n";
	}
	return($response);
}

sub sysop_showenv {
	my $self = shift;
	my $MAX = 0;

	my $text = '';
	foreach my $e (keys %ENV) {
		$MAX = max(length($e),$MAX);
	}

	foreach my $env (sort(keys %ENV)) {
		if ($ENV{$env} =~ /\n/g) {
			my @in = split(/\n/,$ENV{$env});
			my $indent = $MAX + 4;
			$text .= sprintf("%${MAX}s = ---" . $env) . "\n";
			foreach my $line (@in) {
				if ($line =~ /\:/) {
					my ($f,$l) = $line =~ /^(.*?):(.*)/;
					chomp($l);
					chomp($f);
					$f = uc($f);
					if ($f eq 'IP') {
						$l = colored(['bright_green'], $l);
						$f = 'IP ADDRESS';
					}
					my $le = 11 - length($f);
					$f .= ' ' x $le;
					$l = colored(['green'],uc($l)) if ($l =~ /^ok/i);
					$l = colored(['bold red'],'U') . colored(['bold white'],'S') . colored(['bold blue'],'A') if ($l =~ /^us/i);
					$text .= colored(['bold white'], sprintf("%${indent}s",$f)) . " = $l\n";
				} else {
				    $text .= "$line\n";
				}
			}
		} elsif ($env eq 'SSH_CLIENT') {
			my ($ip,$p1,$p2) = split(/ /,$ENV{$env});
			$text .= colored(['bold white'], sprintf("%${MAX}s",$env)),
			  ' = ',
			  colored(['bright_green'],$ip),
			  ' ',
			  colored(['cyan'],$p1),
			  ' ',
			  colored(['yellow'],$p2),
			  "\n";
		} elsif ($env eq 'SSH_CONNECTION') {
			my ($ip1,$p1,$ip2,$p2) = split(/ /,$ENV{$env});
			$text .=
			  colored(['bold white'], sprintf("%${MAX}s",$env)) . ' = ' .
			  colored(['bright_green'],$ip1) . ' ' .
			  colored(['cyan'],$p1) . ' ' .
			  colored(['bright_green'],$ip2) . ' ' .
			  colored(['yellow'],$p2) . "\n";
		} elsif ($env eq 'TERM') {
			my $colorized =
			  colored(['red'],'2') .
			  colored(['green'],'5') .
			  colored(['yellow'],'6') .
			  colored(['cyan'],'c') .
			  colored(['bright_blue'],'o') .
			  colored(['magenta'],'l') .
			  colored(['bright_green'],'o') .
			  colored(['bright_blue'],'r');
			my $line = $ENV{$env};
			$line =~ s/256color/$colorized/;
			$text .= colored(['bold white'], sprintf("%${MAX}s",$env)) . ' = ' . $line . "\n";
		} elsif ($env eq 'WHATISMYIP') {
			$text .= colored(['bold white'], sprintf("%${MAX}s",$env)) . ' = ' . colored(['bright_green'], $ENV{$env}) . "\n";
		} else {
			$text .= colored(['bold white'],sprintf("%${MAX}s",$env)) . ' = ' . $ENV{$env} . "\n";
		}
	}
	return($text);
}
sub sysop_scroll {
	my $self = shift;
	print "Scroll?  ";
	if ($self->sysop_keypress(ECHO,BLOCKING) =~ /N/i) {
		return(FALSE);
	}
	print "\r" . clline;
	return(TRUE);
}

sub sysop_list_bbs {
	my $self = shift;

	my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view');
	$sth->execute();
	my @listing;
	my ($id_size,$name_size,$hostname_size,$poster_size) = (1,1,1,6);
	while (my $row = $sth->fetchrow_hashref()) {
		push(@listing,$row);
		$name_size = max(length($row->{'bbs_name'}),$name_size);
		$hostname_size = max(length($row->{'bbs_hostname'}),$hostname_size);
		$id_size = max(length('' . $row->{'bbs_id'}),$id_size);
        $poster_size = max(length($row->{'bbs_poster'}),$poster_size);
	}
	my $table = Text::SimpleTable->new($id_size,$name_size,$hostname_size,5,$poster_size);
	$table->row('ID','NAME','HOSTNAME','PORT','POSTER');
	$table->hr();
	foreach my $line (@listing) {
		$table->row($line->{'bbs_id'},$line->{'bbs_name'},$line->{'bbs_hostname'},$line->{'bbs_port'},$line->{'bbs_poster'});
	}
    print $table->boxes->draw();
	print 'Press a key to continue... ';
	$self->sysop_keypress();
}

sub sysop_edit_bbs {
	my $self = shift;

	my @choices = (qw( bbs_id bbs_name bbs_hostname bbs_port ));
	print $self->prompt('Please enter the ID, the hostname, or the BBS name to edit');
	my $search;
	$search = $self->sysop_get_line(50);
	return(FALSE) if ($search eq '');
	my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
	$sth->execute($search,$search,$search);
	if ($sth->rows()) {
		my $bbs = $sth->fetchrow_hashref();
		$sth->finish();
		my $table = Text::SimpleTable->new(6,12,50);
		my $index = 1;
		$table->row('CHOICE','FIELD NAME','VALUE');
		$table->hr();
		foreach my $name (qw(bbs_id bbs_name bbs_hostname bbs_port)) {
			if ($name =~ /bbs_id|bbs_poster/) {
				$table->row(' ',$name,$bbs->{$name});
			} else {
				$table->row($index,$name,$bbs->{$name});
				$index++;
			}
		}
		print $table->boxes->draw();
		print $self->prompt('Edit which field (choice)');
		my $choice;
		do {
			$choice = $self->sysop_keypress();
		} until($choice =~ /1|2|3|Z/i);
		if ($choice =~ /\D/) {
			return(FALSE);
		}
		print "\n",$self->sysop_prompt($choices[$choice] . ' (' . $bbs->{$choices[$choice]} . ') ');
		my $new = $self->sysop_get_line(50);
		return(FALSE) if ($new eq '');
		$sth = $self->{'dbh'}->prepare('UPDATE bbs_listing SET ' . $choices[$choice] . '=? WHERE bbs_id=?');
		$sth->execute($new,$bbs->{'bbs_id'});
		$sth->finish();
	} else {
		$sth->finish();
	}
}

sub sysop_add_bbs {
	my $self = shift;

	my $table = Text::SimpleTable->new(12,50);
	foreach my $name (qw(bbs_name bbs_hostname bbs_port)) {
		my $count = ($name eq 'bbs_port') ? 5 : 50;
		$table->row($name,"\n" . $self->{'sysop_tokens'}->{'LARGE OVERLINE'} x $count);
		$table->hr() unless($name eq 'bbs_port');
	}
	my @order = (qw(bbs_name bbs_hostname bbs_port));
	my $bbs = {};
	my $index = 0;
	print $table->boxes->draw();
	print $self->{'ansi_sequences'}->{'UP'} x 9,$self->{'ansi_sequences'}->{'RIGHT'} x 17;
	$bbs->{'bbs_name'} = $self->sysop_get_line(50);
	if ($self->{'bbs_name'} ne '' && length($self->{'bbs_name'}) > 4) {
		print $self->{'ansi_sequences'}->{'DOWN'} x 2,"\r",$self->{'ansi_sequences'}->{'RIGHT'} x 17;
		$bbs->{'bbs_hostname'} = $self->sysop_get_line(50);
		if ($self->{'bbs_hostname'} ne '' && length($self->{'bbs_hostname'}) > 5) {
			print $self->{'ansi_sequences'}->{'DOWN'} x 2,"\r",$self->{'ansi_sequences'}->{'RIGHT'} x 17;
			$bbs->{'bbs_port'} = $self->sysop_get_line(5);
			if ($self->{'bbs_port'} ne '' && $self->{'bbs_port'} =~ /^\d+$/) {
				my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
				$sth->execute($bbs->{'bbs_name'},$self->{'bbs_hostname'},$self->{'bbs_port'});
				$sth->finish();
			} else {
				return(FALSE);
			}
		} else {
			return(FALSE);
		}
	} else {
		return(FALSE);
	}
	return(TRUE);
}
1;
