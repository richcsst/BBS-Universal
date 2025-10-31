package BBS::Universal::SysOp;
BEGIN { our $VERSION = '0.006'; }

sub sysop_initialize {
    my $self = shift;

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    $self->{'wsize'} = $wsize;
    $self->{'hsize'} = $hsize;
    $self->{'debug'}->DEBUG(["Screen Size is $wsize x $hsize"]);
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
    } else {
        $sections = 6;
    }
    my $versions     = $self->sysop_versions_format($sections, FALSE);
    my $bbs_versions = $self->sysop_versions_format($sections, TRUE);
    my $esc          = chr(27) . '[';

    $self->{'flags_default'} = {
        'prefer_nickname' => 'Yes',
        'view_files'      => 'Yes',
        'upload_files'    => 'No',
        'download_files'  => 'Yes',
        'remove_files'    => 'No',
        'read_message'    => 'Yes',
        'post_message'    => 'Yes',
        'remove_message'  => 'No',
        'sysop'           => 'No',
        'page_sysop'      => 'Yes',
        'show_email'      => 'No',
    };

    $self->{'sysop_tokens'} = {
        # Static Tokens
        'HOSTNAME'     => $self->sysop_hostname,
        'IP ADDRESS'   => $self->sysop_ip_address(),
        'CPU BITS'     => $self->{'CPU'}->{'CPU BITS'},
        'CPU CORES'    => $self->{'CPU'}->{'CPU CORES'},
        'CPU SPEED'    => $self->{'CPU'}->{'CPU SPEED'},
        'CPU IDENTITY' => $self->{'CPU'}->{'CPU IDENTITY'},
        'CPU THREADS'  => $self->{'CPU'}->{'CPU THREADS'},
        'HARDWARE'     => $self->{'CPU'}->{'HARDWARE'},
        'VERSIONS'     => $versions,
        'BBS VERSIONS' => $bbs_versions,
        'BBS NAME'     => colored(['green'], $self->{'CONF'}->{'BBS NAME'}),

        # Non-static tokens
        'THREADS COUNT' => sub {
            my $self = shift;
            return ($self->{'CACHE'}->get('THREADS_RUNNING'));
        },
        'USERS COUNT' => sub {
            my $self = shift;
            return ($self->db_count_users());
        },
        'UPTIME' => sub {
            my $self   = shift;
            my $uptime = `uptime -p`;
            chomp($uptime);
            return ($uptime);
        },
        'DISK FREE SPACE' => sub {
            my $self = shift;
            return ($self->sysop_disk_free());
        },
        'MEMORY' => sub {
            my $self = shift;
            return ($self->sysop_memory());
        },
        'ONLINE' => sub {
            my $self = shift;
            return ($self->sysop_online_count());
        },
        'CPU LOAD' => sub {
            my $self = shift;
            return ($self->cpu_info->{'CPU LOAD'});
        },
        'ENVIRONMENT' => sub {
            my $self = shift;
            return ($self->sysop_showenv());
        },
        'FILE CATEGORY' => sub {
            my $self = shift;

            my $sth = $self->{'dbh'}->prepare('SELECT title FROM file_categories WHERE id=?');
            $sth->execute($self->{'USER'}->{'file_category'});
            my ($result) = $sth->fetchrow_array();
            return ($result);
        },
        'SYSOP VIEW CONFIGURATION' => sub {
            my $self = shift;
            return ($self->sysop_view_configuration('string'));
        },
        'COMMANDS REFERENCE' => sub {
            my $self = shift;
            return ($self->sysop_list_commands());
        },
    };
	foreach my $name (keys %{ $self->{'ansi_meta'}->{'foreground'} }) {
		$self->{'sysop_tokens'}->{'MIDDLE VERTICAL RULE ' . $name} = $self->sysop_locate_middle('B_' . $name);
	}

    $self->{'SYSOP ORDER DETAILED'} = [
        qw(
            id
            fullname
            username
            given
            family
            nickname
            email
            birthday
            location
            access_level
            date_format
            baud_rate
            text_mode
            max_columns
            max_rows
            timeout
            retro_systems
            accomplishments
            prefer_nickname
            view_files
            upload_files
            download_files
            remove_files
            play_fortunes
            read_message
            post_message
            remove_message
            sysop
            page_sysop
            banned
            login_time
            logout_time
        )
    ];
    $self->{'SYSOP ORDER ABBREVIATED'} = [
        qw(
            id
            fullname
            username
            given
            family
            nickname
            text_mode
        )
    ];

    $self->{'SYSOP FIELD TYPES'} = {
        'id' => {
            'type' => NUMERIC,
            'max'  => 2,
            'min'  => 2,
        },
        'username' => {
            'type' => HOST,
            'max'  => 32,
            'min'  => 16,
        },
        'fullname' => {
            'type' => STRING,
            'max'  => 20,
            'min'  => 15,
        },
        'given' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'family' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'nickname' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'email' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 32,
        },
        'birthday' => {
            'type' => STRING,
            'max'  => 10,
            'min'  => 10,
        },
        'location' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 40,
        },
        'date_format' => {
            'type'    => RADIO,
            'max'     => 14,
            'min'     => 14,
            'choices' => ['MONTH/DAY/YEAR', 'DAY/MONTH/YEAR', 'YEAR/MONTH/DAY',],
            'default' => 'DAY/MONTH/YEAR',
        },
        'access_level' => {
            'type'    => RADIO,
            'max'     => 12,
            'min'     => 12,
            'choices' => ['USER', 'VETERAN', 'JUNIOR SYSOP', 'SYSOP',],
            'default' => 'USER',
        },
        'baud_rate' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['FULL', '19200', '9600', '4800', '2400', '1200', '600', '300',],
            'default' => 'FULL',
        },
        'login_time' => {
            'type' => STRING,
            'max'  => 10,
            'min'  => 10,
        },
        'logout_time' => {
            'type' => STRING,
            'max'  => 10,
            'min'  => 10,
        },
        'text_mode' => {
            'type'    => RADIO,
            'max'     => 7,
            'min'     => 9,
            'choices' => ['ANSI', 'ASCII', 'ATASCII', 'PETSCII',],
            'default' => 'ASCII',
        },
        'max_rows' => {
            'type'    => NUMERIC,
            'max'     => 3,
            'min'     => 3,
            'default' => 25,
        },
        'max_columns' => {
            'type'    => NUMERIC,
            'max'     => 3,
            'min'     => 3,
            'default' => 80,
        },
        'timeout' => {
            'type'    => NUMERIC,
            'max'     => 5,
            'min'     => 5,
            'default' => 10,
        },
        'retro_systems' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 40,
        },
        'accomplishments' => {
            'type' => STRING,
            'max'  => 120,
            'min'  => 40,
        },
        'prefer_nickname' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'view_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'YES',
        },
        'banned' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'upload_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'download_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'remove_files' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'read_message' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'YES',
        },
        'post_message' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'remove_message' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'play_fortunes' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'YES',
        },
        'sysop' => {
            'type'    => RADIO,
            'max'     => 5,
            'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'page_sysop' => {
            'type'    => RADIO,
            'max'     => 5,
           'min'     => 5,
            'choices' => ['TRUE', 'FALSE', 'YES', 'NO', 'ON', 'OFF', '1', '0',],
            'default' => 'NO',
        },
        'password' => {
            'type' => STRING,
            'max'  => 64,
            'min'  => 32,
        },
    };

    return ($self);
} ## end sub sysop_initialize

sub sysop_list_commands {
    my $self = shift;
    my $mode = shift;
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $size   = ($hsize - ($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')));
    my $srow   = $size - 5;
    my @sys    = (sort(keys %{$main::SYSOP_COMMANDS}));
    my @stkn   = (sort(keys %{ $self->{'sysop_tokens'} }));
    my @usr    = (sort(keys %{ $self->{'COMMANDS'} }));
    my @tkn    = (sort(keys %{ $self->{'TOKENS'} }));
    my @anstkn = grep(!/CSI|RGB|COLOR|GREY|FONT|HORIZONTAL RULE/, (keys %{ $self->{'ansi_sequences'} }));
    @anstkn = sort(@anstkn);
    my @atatkn = map { "  $_" } (sort(keys %{ $self->{'atascii_sequences'} },'HORIZONTAL RULE'));
    my @pettkn = map { "  $_" } (sort(keys %{ $self->{'petscii_sequences'} },'HORIZONTAL RULE color'));
    my @asctkn = (sort(keys %{ $self->{'ascii_sequences'} },'HORIZONTAL RULE'));
    my $x      = 1;
    my $xt     = 1;
    my $y      = 1;
    my $z      = 1;
    my $ans    = 31;
    my $ata    = 1;
    my $pet    = 1;
    my $asc    = 12;
    my $text   = '';
    {
        my $cell;
        foreach $cell (@sys) {
            $x = max(length($cell), $x);
        }
        foreach $cell (@stkn) {
            $xt = max(length($cell), $xt);
        }
        foreach $cell (@usr) {
            $y = max(length($cell), $y);
        }
        foreach $cell (@tkn) {
            $z = max(length($cell), $z);
        }
        foreach $cell (@anstkn) {
            $ans = max(length($cell), $ans);
        }
        foreach $cell (@atatkn) {
            $ata = max(length($cell), $ata);
        }
        foreach $cell (@pettkn) {
            $pet = max(length($cell), $pet);
        }
        foreach $cell (@asctkn) {
            $asc = max(length($cell), $asc);
        }
    }
    if ($mode eq 'ASCII') {
        my $table = Text::SimpleTable->new($asc);
        $table->row('ASCII TOKENS');
        $table->hr();
        my $ascii_tokens;
        while (scalar(@asctkn)) {
			$ascii_tokens = shift(@asctkn);
            $table->row($ascii_tokens);
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'ANSI') {
		$self->output("\nANSI has standard 16 colors that works with all color terminals.  You can use\nmore colors with compatible expanded color terminals.  Would you like to see\nthe extra colors (y/N)?  ");
		my $expanded = $self->sysop_decision();
		$self->output("\n");
        my $table = Text::SimpleTable->new(10, $ans, 55);
        $table->row('TYPE', 'ANSI TOKENS', 'ANSI TOKENS DESCRIPTION');
        foreach my $code (qw(special clear cursor attributes foreground background)) {
			$table->hr();
			if ($code eq 'foreground') {
				foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}}, 'RGB 0,0,0 - RGB 255,255,255', 'COLOR 0 - COLOR 231', 'GREY 0 - GREY 23')) {
					if ($name eq 'RGB 0,0,0 - RGB 255,255,255' && $expanded) {
						$table->row(ucfirst($code), $name, '24 Bit Color in Red,Green,Blue order');
					} elsif ($name eq 'COLOR 0 - COLOR 231' && $expanded) {
						$table->row(ucfirst($code), $name, 'Extra ANSI Colors');
					} elsif ($name eq 'GREY 0 - GREY 23' && $expanded) {
						$table->row(ucfirst($code), $name, 'Shades of Grey');
					} else {
						if ($expanded) {
							$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
						} elsif($self->{'ansi_meta'}->{$code}->{$name}->{'orig'}) {
							$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
						}
					}
				}
			} elsif ($code eq 'background') {
				foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}}, 'B_RGB 0,0,0 - B_RGB 255,255,255', 'B_COLOR 0 - B_COLOR 231', 'B_GREY 0 - B_GREY 23')) {
					if ($name eq 'B_RGB 0,0,0 - B_RGB 255,255,255' && $expanded) {
						$table->row(ucfirst($code), $name, '24 Bit Color in Red,Green,Blue order');
					} elsif ($name eq 'B_COLOR 0 - B_COLOR 231' && $expanded) {
						$table->row(ucfirst($code), $name, 'Extra ANSI Colors');
					} elsif ($name eq 'B_GREY 0 - B_GREY 23' && $expanded) {
						$table->row(ucfirst($code), $name, 'Shades of Grey');
					} else {
						if ($expanded) {
							$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
						} elsif($self->{'ansi_meta'}->{$code}->{$name}->{'orig'}) {
							$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
						}
					}
				}
			} elsif ($code eq 'cursor') {
				foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}}, 'LOCATE column,row')) {
					if ($name eq 'LOCATE column,row') {
						$table->row(ucfirst($code), $name, 'Position the Cursor at Column,Row');
					} else {
						$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
					}
				}
			} elsif ($code eq 'special') {
				foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}}, 'FONT 0 - FONT 9', 'HORIZONTAL RULE color')) {
					if ($name eq 'FONT 0 - FONT 9') {
						$table->row(ucfirst($code), $name, 'Set the Specified Console Font');
					} elsif ($name eq 'HORIZONTAL RULE color') {
						$table->row(ucfirst($code), $name, 'A Horizontal Rule (Screen Width) in The Specified Color');
					} else {
						$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
					}
				}
			} else {
				foreach my $name (sort(keys %{$self->{'ansi_meta'}->{$code}})) {
					$table->row(ucfirst($code), $name, $self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
				}
			}
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'ATASCII') {
        my $table = Text::SimpleTable->new($ata);
        $table->row('ATASCII TOKENS');
        $table->hr();
        my $atascii_tokens;
        while (scalar(@atatkn)) {
			$atascii_tokens = shift(@atatkn);
            $table->row($atascii_tokens);
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'PETSCII') {
        my $table = Text::SimpleTable->new($pet);
        $table->row('PETSCII TOKENS');
        $table->hr();
        my $petscii_tokens;
        while (scalar(@pettkn)) {
			$petscii_tokens = shift(@pettkn);
            $table->row($petscii_tokens);
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'USER') {
        my $table = Text::SimpleTable->new($y, $z);
        $table->row('USER MENU COMMANDS', 'USER TOKENS');
        $table->hr();
        my ($user_names, $token_names);
        my $count = 0; # Try to follow the scroll logic
        while (scalar(@usr) || scalar(@tkn)) {
            if (scalar(@usr)) {
                $user_names = shift(@usr);
            } else {
                $user_names = ' ';
            }
            if (scalar(@tkn)) {
                $token_names = shift(@tkn);
            } else {
                $token_names = ' ';
            }
            $table->row($user_names, $token_names);
            $count++;
            if ($count > $srow) {
                $count = 0;
                $table->hr();
                $table->row('USER MENU COMMANDS', 'USER TOKENS');
                $table->hr();
            }
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } elsif ($mode eq 'SYSOP') {
        my $table = Text::SimpleTable->new($x, $xt);
        $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS');
        $table->hr();
        my ($sysop_names, $sysop_tokens);
        my $count = 0; # Try to follow the scroll logic
        while (scalar(@sys) || scalar(@stkn)) {
            if (scalar(@sys)) {
                $sysop_names = shift(@sys);
            } else {
                $sysop_names = ' ';
            }
            if (scalar(@stkn)) {
                $sysop_tokens = shift(@stkn);
            } else {
                $sysop_tokens = ' ';
            }
            $table->row($sysop_names, $sysop_tokens);
            $count++;
            if ($count > $srow) {
                $count = 0;
                $table->hr();
                $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS');
                $table->hr();
            }
        }
        $text = $self->center($table->boxes->draw(), $wsize);
    } else {
        my $table = Text::SimpleTable->new($x, $xt, $y, $z, $ans, $ata, $pet, $asc);
        $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS', 'USER MENU COMMANDS', 'USER TOKENS', 'ANSI TOKENS', 'ATASCII TOKENS', 'PETSCII TOKENS', 'ASCII TOKENS');
        $table->hr();
        my ($sysop_names, $sysop_tokens, $user_names, $token_names, $ansi_tokens, $atascii_tokens, $petscii_tokens, $ascii_tokens);
        my $count = 0; # Try to follow the scroll logic
        while (scalar(@sys) || scalar(@stkn) || scalar(@usr) || scalar(@tkn) || scalar(@anstkn) || scalar(@atatkn) || scalar(@pettkn) || scalar(@asctkn)) {
            if (scalar(@sys)) {
                $sysop_names = shift(@sys);
            } else {
                $sysop_names = ' ';
            }
            if (scalar(@stkn)) {
                $sysop_tokens = shift(@stkn);
            } else {
                $sysop_tokens = ' ';
            }
            if (scalar(@usr)) {
                $user_names = shift(@usr);
            } else {
                $user_names = ' ';
            }
            if (scalar(@tkn)) {
                $token_names = shift(@tkn);
            } else {
                $token_names = ' ';
            }
            if (scalar(@anstkn)) {
                $ansi_tokens = shift(@anstkn);
            } else {
                $ansi_tokens = ' ';
            }
            if (scalar(@atatkn)) {
                $atascii_tokens = shift(@atatkn);
            } else {
                $atascii_tokens = ' ';
            }
            if (scalar(@pettkn)) {
                $petscii_tokens = shift(@pettkn);
            } else {
                $petscii_tokens = ' ';
            }
            if (scalar(@asctkn)) {
                $ascii_tokens = shift(@asctkn);
            } else {
                $ascii_tokens = ' ';
            }
            $table->row($sysop_names, $sysop_tokens, $user_names, $token_names, $ansi_tokens, $atascii_tokens, $petscii_tokens, $ascii_tokens);
            $count++;
            if ($count > $srow) {
                $count = 0;
                $table->hr();
                $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS', 'USER MENU COMMANDS', 'USER TOKENS', 'ANSI TOKENS', 'ATASCII TOKENS', 'PETSCII TOKENS', 'ASCII TOKENS');
                $table->hr();
            }
        } ## end while (scalar(@sys) || scalar...)
        $text = $self->center($table->boxes->draw(), $wsize);
    }
    # This monstrosity fixes up the pre-rendered table to add all of the colors and special characters for friendly output
    my $replace = join('|', grep(!/^(TAB|SS3|SS2|OSC|SOS|ST|DCS|PM|APC|FONT D|GAINSBORO|RAPID|SLOW|B_INDIGO|B_MEDIUM BLUE|B_MIDNIGHT BLUE|SUBSCRIPT|SUPERSCRIPT|UNDERLINE|RETURN|REVERSE|B_BLUE|B_DARK BLUE|B_NAVY|RAPID|PROPORTIONAL ON|PROPORTIONAL OFF|NORMAL|INVERT|ITALIC|OVERLINE|FRAMED|FAINT|ENCIRCLE|CURSOR|CROSSED OUT|BOLD|CSI|B_BLACK|BLACK|CL|CSI|RING BELL|BACKSPACE|LINEFEED|NEWLINE|HOME|UP|DOWN|RIGHT|LEFT|NEXT LINE|PREVIOUS LINE|SAVE|RESTORE|RESET|CURSOR|SCREEN|WHITE|HIDE|REVEAL|DEFAULT|B_DEFAULT)/,(sort(keys %{$self->{'ansi_sequences'}}))));
    my $new = 'GAINSBORO|UNDERLINE|OVERLINE ON|ENCIRCLE|FAINT|CROSSED OUT|B_BLUE VIOLET|SLOW BLINK|RAPID BLINK|B_INDIGO|B_MEDIUM BLUE|B_MIDNIGHT BLUE|B_NAVY|B_BLUE|B_DARK BLUE';
    $text =~ s/(TYPE|SYSOP MENU COMMANDS|SYSOP TOKENS|USER MENU COMMANDS|USER TOKENS|ANSI TOKENS DESCRIPTION|ANSI TOKENS|ATASCII TOKENS|PETSCII TOKENS|ASCII TOKENS)/\[\% BRIGHT YELLOW \%\]$1\[\% RESET \%\]/g;
    $text =~ s/│   (BOTTOM HORIZONTAL BAR)/│ \[\% LOWER ONE QUARTER BLOCK \%\] $1/g;
    $text =~ s/│   (TOP HORIZONTAL BAR)/│ \[\% UPPER ONE QUARTER BLOCK \%\] $1/g;
    $text =~ s/│(\s+)($replace)  /│$1\[% BLACK %][\% $2 \%\]$2\[\% RESET \%\]  /g;
        $text =~ s/│(\s+)($new)  /│$1\[\% $2 \%\]$2\[\% RESET \%\]  /g;
        $text =~ s/│   (B_WHITE)/│   \[\% BLACK \%\]\[\% $1 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (LIGHT BLUE)/│   \[\% BRIGHT BLUE \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (LIGHT GREEN)/│   \[\% BRIGHT GREEN \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (LIGHT GRAY)/│   \[\% GREY 13 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (BLACK)/│   \[\% B_WHITE \%\]\[\% $1 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (PURPLE)/│   \[\% COLOR 127 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (DARK PURPLE)/│   \[\% COLOR 53 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (GRAY)/│   \[\% GREY 9 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (BROWN)/│   \[\% COLOR 94 \%\]$1\[\% RESET \%\]/g;
        $text =~ s/│   (HEART)/│ \[\% BLACK HEART SUIT \%\] $1/g;
        $text =~ s/│   (BOTTOM BOX)/│ \[\% LOWER HALF BLOCK \%\] $1/g;
        $text =~ s/│   (BOTTOM LEFT BOX)/│ \[\% QUADRANT LOWER LEFT \%\] $1/g;
        $text =~ s/│   (TOP LEFT BOX)/│ \[\% QUADRANT UPPER LEFT \%\] $1/g;
        $text =~ s/│   (BOTTOM RIGHT BOX)/│ \[\% QUADRANT LOWER RIGHT \%\] $1/g;
        $text =~ s/│   (TOP RIGHT BOX)/│ \[\% QUADRANT UPPER RIGHT \%\] $1/g;
        $text =~ s/│   (BOTTOM LEFT)/│ \[\% BOX DRAWINGS HEAVY UP AND RIGHT \%\] $1/g;
        $text =~ s/│   (BOTTOM RIGHT)/│ \[\% BOX DRAWINGS HEAVY UP AND LEFT \%\] $1/g;
        $text =~ s/│   (LEFT TRIANGLE)/│ \[\% BLACK LEFT-POINTING TRIANGLE \%\] $1/g;
        $text =~ s/│   (RIGHT TRIANGLE)/│ \[\% BLACK RIGHT-POINTING TRIANGLE \%\] $1/g;
        $text =~ s/│   (LEFT VERTICAL BAR)/│ \[\% LEFT ONE QUARTER BLOCK \%\] $1/g;
        $text =~ s/│   (LEFT VERTICAL BAR)/│ \[\% LEFT ONE QUARTER BLOCK \%\] $1/g;                                                                                                                                                                                                                                                                                                                                                                                              # Why twice?  Ask Perl as one doesn't replace all
        $text =~ s/│   (RIGHT VERTICAL BAR)/│ \[\% RIGHT ONE QUARTER BLOCK \%\] $1/g;
        $text =~ s/│   (CENTER DOT)/│ \[\% BLACK CIRCLE \%\] $1/g;
        $text =~ s/│   (CROSS BAR)/│ \[\% BOX DRAWINGS HEAVY VERTICAL AND HORIZONTAL \%\] $1/g;
        $text =~ s/│   (CLUB)/│ \[\% BLACK CLUB SUIT \%\] $1/g;
        $text =~ s/│   (SPADE)/│ \[\% BLACK SPADE SUIT \%\] $1/g;
        $text =~ s/│   (HORIZONTAL BAR MIDDLE TOP)/│ \[\% BOX DRAWINGS HEAVY DOWN AND HORIZONTAL \%\] $1/g;
        $text =~ s/│   (HORIZONTAL BAR MIDDLE BOTTOM)/│ \[\% BOX DRAWINGS HEAVY UP AND HORIZONTAL \%\] $1/g;
        $text =~ s/│   (HORIZONTAL BAR)/│ \[\% BLACK RECTANGLE \%\] $1/g;
        $text =~ s/│   (FORWARD SLASH)/│ \[\% MATHEMATICAL RISING DIAGONAL \%\] $1/g;
        $text =~ s/│   (BACK SLASH)/│ \[\% MATHEMATICAL FALLING DIAGONAL \%\] $1/g;
        $text =~ s/│   (TOP LEFT WEDGE)/│ \[\% BLACK LOWER RIGHT TRIANGLE \%\] $1/g;
        $text =~ s/│   (TOP RIGHT WEDGE)/│ \[\% BLACK LOWER LEFT TRIANGLE \%\] $1/g;
        $text =~ s/│   (TOP RIGHT)/│ \[\% BOX DRAWINGS HEAVY DOWN AND LEFT \%\] $1/g;
        $text =~ s/│   (LEFT ARROW)/│ \[\% WIDE-HEADED LEFTWARDS HEAVY BARB ARROW \%\] $1/g;
        $text =~ s/│   (RIGHT ARROW)/│ \[\% WIDE-HEADED RIGHTWARDS HEAVY BARB ARROW \%\] $1/g;
        $text =~ s/│   (BACK ARROW)/│ \[\% ARROW POINTING UPWARDS THEN NORTH WEST \%\] $1/g;
        $text =~ s/│   (TOP LEFT)/│ \[\% BOX DRAWINGS HEAVY DOWN AND RIGHT \%\] $1/g;
        $text =~ s/│   (MIDDLE VERTICAL BAR)/│ \[\% BOX DRAWINGS HEAVY VERTICAL \%\] $1/g;
        $text =~ s/│   (VERTICAL BAR MIDDLE LEFT)/│ \[\% BOX DRAWINGS HEAVY VERTICAL AND LEFT \%\] $1/g;
        $text =~ s/│   (VERTICAL BAR MIDDLE RIGHT)/│ \[\% BOX DRAWINGS HEAVY VERTICAL AND RIGHT \%\] $1/g;
        $text =~ s/│   (UP ARROW)/│ \[\% UPWARDS ARROW WITH MEDIUM TRIANGLE ARROWHEAD \%\] $1/g;
        $text =~ s/│   (DOWN ARROW)/│ \[\% DOWNWARDS ARROW WITH MEDIUM TRIANGLE ARROWHEAD \%\] $1/g;
        $text =~ s/│   (LEFT HALF)/│ \[\% LEFT HALF BLOCK \%\] $1/g;
        $text =~ s/│   (RIGHT HALF)/│ \[\% RIGHT HALF BLOCK \%\] $1/g;
        $text =~ s/│   (DITHERED FULL REVERSE)/│ \[\% INVERT \%\]\[\% MEDIUM SHADE \%\]\[\% RESET \%\] $1/g;
        $text =~ s/│   (DITHERED FULL)/│ \[\% MEDIUM SHADE \%\] $1/g;
        $text =~ s/│   (DITHERED BOTTOM)/│ \[\% LOWER HALF MEDIUM SHADE \%\] $1/g;
        $text =~ s/│   (DITHERED LEFT REVERSE)/│ \[\% INVERT \%\]\[\% LEFT HALF MEDIUM SHADE \%\]\[\% RESET \%\] $1/g;
        $text =~ s/│   (DITHERED LEFT)/│ \[\% LEFT HALF MEDIUM SHADE \%\] $1/g;
        $text =~ s/│   (DIAMOND)/│ \[\% BLACK DIAMOND CENTRED \%\] $1/g;
        $text =~ s/│   (BRITISH POUND)/│ \[\% POUND SIGN \%\] $1/g;
        $text =~ s/│(\s+)(OVERLINE ON)  /│$1\[\% OVERLINE ON \%\]$2\[\% RESET \%\]  /g;
        $text =~ s/│(\s+)(SUPERSCRIPT ON)  /│$1\[\% SUPERSCRIPT ON \%\]$2\[\% RESET \%\]  /g;
        $text =~ s/│(\s+)(SUBSCRIPT ON)  /│$1\[\% SUBSCRIPT ON \%\]$2\[\% RESET \%\]  /g;
        $text =~ s/│(\s+)(UNDERLINE)  /│$1\[\% UNDERLINE \%\]$2\[\% RESET \%\]  /g;
        $text = $self->sysop_color_border($text, 'PINK','DOUBLE');
        return ($self->ansi_decode($text));
        } ## end sub sysop_list_commands

sub sysop_online_count {
    my $self = shift;

    my $count = $self->{'CACHE'}->get('ONLINE');
    $self->{'debug'}->DEBUG(["SysOp Online Count $count"]);
    return ($count);
} ## end sub sysop_online_count

sub sysop_versions_format {
    my $self     = shift;
    my $sections = shift;
    my $bbs_only = shift;

    $self->{'debug'}->DEBUG(['SysOp Versions Format']);
    my $versions = "\n";
    my $heading  = ''; #  = "\t";
    my $counter  = $sections;

    for (my $count = $sections - 1; $count > 0; $count--) {
        $heading .= ' NAME                         VERSION ';
        if ($count) {
            $heading .= "\t";
        } else {
            $heading .= "\n";
        }
    } ## end for (my $count = $sections...)
    $heading = '[% BRIGHT YELLOW %][% B_RED %]' .  $heading . '[% RESET %]';
    foreach my $v (sort(keys %{ $self->{'VERSIONS'} })) {
        next if ($bbs_only && $v !~ /^BBS/);
        $versions .= sprintf(' %-28s  %.03f', $v, $self->{'VERSIONS'}->{$v});
        $counter--;
        if ($counter <= 1) {
            $counter = $sections;
            $versions .= "\n";
        } else {
            $versions .= "\t";
        }
    } ## end foreach my $v (keys %{ $self...})
    chop($versions) if (substr($versions, -1, 1) eq "\t");
    return ($heading . $versions . "\n");
} ## end sub sysop_versions_format

sub sysop_disk_free {    # Show the Disk Free portion of Statistics
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Disk Free']);
    my $diskfree = '';
    if ((-e '/usr/bin/duf' || -e '/usr/local/bin/duf') && $self->configuration('USE DUF') eq 'TRUE') {
        my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
        $diskfree = "\n" . `duf -theme ansi -width $wsize`;
    } else {
        my @free  = split(/\n/, `nice df -h -T`);    # Get human readable disk free showing type
        my $width = 1;
        foreach my $l (@free) {
            $width = max(length($l), $width);        # find the width of the widest line
        }
        foreach my $line (@free) {
            next if ($line =~ /tmp|boot/);
            if ($line =~ /^Filesystem/) {
                $diskfree .= '[% B_BLUE %][% BRIGHT YELLOW %]' . " $line " . ' ' x ($width - length($line)) . "[% RESET %]\n";    # Make the heading the right width
            } else {
                $diskfree .= " $line\n";
            }
        } ## end foreach my $line (@free)
    } ## end else [ if ((-e '/usr/bin/duf'...))]
    return ($diskfree);
} ## end sub sysop_disk_free

sub sysop_load_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(["SysOp Load Menu $file"]);
    my $mapping = { 'TEXT' => '' };
    my $mode    = 1;
    my $text    = locate($row, 1) . cldown;
    open(my $FILE, '<', $file);

    while (chomp(my $line = <$FILE>)) {
        next if ($line =~ /^\#/);
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

sub sysop_pager {
    my $self   = shift;
    my $text   = shift;
    my $offset = (scalar(@_)) ? shift : 0;

    $self->{'debug'}->DEBUG(['SysOp Pager']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my @lines;
    @lines  = split(/\n$/, $text);
    my $size   = ($hsize - ($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')));
    $size  -= $offset;
    my $scroll = TRUE;
    my $count = 1;
    while (scalar(@lines)) {
        my $line = shift(@lines);
        $self->ansi_output("$line\n");
        $count++;
        if ($count >= $size) {
            $count = 1;
            $scroll = $self->sysop_scroll();
            last unless ($scroll);
        }
    } ## end foreach my $line (@lines)
    return ($scroll);
} ## end sub sysop_pager

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(["SysOp Parse Menu $file"]);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown;
    my $scroll = $self->sysop_pager($mapping->{'TEXT'}, 3);
    my $keys   = '';
    print "\r", cldown unless ($scroll);
    $self->sysop_show_choices($mapping);
    print "\n", $self->sysop_prompt('Choose');
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
    } until ($response =~ /Y|N/i || $response eq chr(13));
    if ($response eq 'Y') {
        print "YES\n";
        $self->{'debug'}->DEBUG(['SysOp Decision YES']);
        return (TRUE);
    }
    $self->{'debug'}->DEBUG(['SysOp Decision NO']);
    print "NO\n";
    return (FALSE);
} ## end sub sysop_decision

sub sysop_keypress {
    my $self = shift;

    $self->{'CACHE'}->set('SHOW_STATUS', FALSE);
    my $key;
    ReadMode 'ultra-raw';
    do {
        $key = ReadKey(-1);
        threads->yield();
    } until (defined($key));
    ReadMode 'restore';
    $self->{'CACHE'}->set('SHOW_STATUS', TRUE);
    return ($key);
} ## end sub sysop_keypress

sub sysop_ip_address {
    my $self = shift;

    chomp(my $ip = `nice hostname -I`);
    $self->{'debug'}->DEBUG(["SysOp IP Address:  $ip"]);
    return ($ip);
} ## end sub sysop_ip_address

sub sysop_hostname {
    my $self = shift;

    chomp(my $hostname = `nice hostname`);
    $self->{'debug'}->DEBUG(["SysOp Hostname:  $hostname"]);
    return ($hostname);
} ## end sub sysop_hostname

sub sysop_locate_middle {
    my $self  = shift;
    my $color = (scalar(@_)) ? shift : 'B_WHITE';

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $middle = int($wsize / 2);
    my $string = "\r" . $self->{'ansi_sequences'}->{'RIGHT'} x $middle . $self->{'ansi_sequences'}->{$color} . ' ' . $self->{'ansi_sequences'}->{'RESET'};
    return ($string);
} ## end sub sysop_locate_middle

sub sysop_memory {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Memory']);
    my $memory = `nice free`;
    my @mem    = split(/\n$/, $memory);
    my $output = '[% BLACK %][% B_GREEN %]  ' . shift(@mem) . ' [% RESET %]' . "\n";
    while (scalar(@mem)) {
        $output .= shift(@mem) . "\n";
    }
    if ($output =~ /(Mem\:       )/) {
        my $ch = '[% BLACK %][% B_GREEN %] ' . $1 . ' [% RESET %]';
        $output =~ s/Mem\:       /$ch/;
    }
    if ($output =~ /(Swap\:      )/) {
        my $ch = '[% BLACK %][% B_GREEN %] ' . $1 . ' [% RESET %]';
        $output =~ s/Swap\:      /$ch/;
    }
    return ($output);
} ## end sub sysop_memory

sub sysop_true_false {
    my $self    = shift;
    my $boolean = shift;
    my $mode    = shift;

    $boolean = $boolean + 0;
    if ($mode eq 'TF') {
        return (($boolean) ? 'TRUE' : 'FALSE');
    } elsif ($mode eq 'YN') {
        return (($boolean) ? 'Yes' : 'No');
    }
    return ($boolean);
} ## end sub sysop_true_false

sub sysop_list_users {
    my $self      = shift;
    my $list_mode = shift;

    $self->{'debug'}->DEBUG(['SysOp List Users']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $table;
    my $date_format = $self->configuration('DATE FORMAT');
    $date_format =~ s/YEAR/\%Y/;
    $date_format =~ s/MONTH/\%m/;
    $date_format =~ s/DAY/\%d/;
    my $name_width  = 15;
    my $value_width = $wsize - 22;
    my $sth;
    my @order;
    my $sql;

    if ($list_mode =~ /DETAILED/) {
        $sql   = q{ SELECT * FROM users_view };
        $sth   = $self->{'dbh'}->prepare($sql);
        @order = @{ $self->{'SYSOP ORDER DETAILED'} };
    } else {
        @order = @{ $self->{'SYSOP ORDER ABBREVIATED'} };
        $sql   = 'SELECT id,username,fullname,given,family,nickname,text_mode FROM users_view';
        $sth   = $self->{'dbh'}->prepare($sql);
    }
    $sth->execute();
    if ($list_mode =~ /VERTICAL/) {
        while (my $row = $sth->fetchrow_hashref()) {
            foreach my $name (@order) {
                next if ($name =~ /retro_systems|accomplishments/);
                if ($name ne 'id' && $row->{$name} =~ /^(0|1)$/) {
                    $row->{$name} = $self->sysop_true_false($row->{$name}, 'YN');
                }
                $value_width = max(length($row->{$name}), $value_width);
            } ## end foreach my $name (@order)
        } ## end while (my $row = $sth->fetchrow_hashref...)
        $sth->finish();
        $sth = $self->{'dbh'}->prepare($sql);
        $sth->execute();
        $table = Text::SimpleTable->new($name_width, $value_width);
        $table->row('NAME', 'VALUE');

        while (my $Row = $sth->fetchrow_hashref()) {
            $table->hr();
            foreach my $name (@order) {
                if ($name !~ /id|time/ && $Row->{$name} =~ /^(0|1)$/) {
                    $Row->{$name} = $self->sysop_true_false($Row->{$name}, 'YN');
                } elsif ($name eq 'timeout') {
                    $Row->{$name} = $Row->{$name} . ' Minutes';
                }
                $self->{'debug'}->DEBUGMAX([$name, $Row->{$name}]);
                $table->row($name . '', $Row->{$name} . '');
            } ## end foreach my $name (@order)
        } ## end while (my $Row = $sth->fetchrow_hashref...)
        $sth->finish();
        my $string = $table->boxes->draw();
        my $ch     = colored(['bright_yellow'], 'NAME');
        $string =~ s/ NAME / $ch /;
        $ch = colored(['bright_yellow'], 'VALUE');
        $string =~ s/ VALUE / $ch /;
        $string = $self->sysop_color_border($string, 'CYAN', 'HEAVY');
        $self->sysop_pager("$string\n");
    } else {    # Horizontal
        my @hw;
        foreach my $name (@order) {
            push(@hw, $self->{'SYSOP FIELD TYPES'}->{$name}->{'min'});
        }
        $table = Text::SimpleTable->new(@hw);
        if ($list_mode =~ /ABBREVIATED/) {
            $table->row(@order);
        } else {
            my @title = ();
            foreach my $heading (@order) {
                push(@title, $self->sysop_vertical_heading($heading));
            }
            $table->row(@title);
        } ## end else [ if ($list_mode =~ /ABBREVIATED/)]
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            my @vals = ();
            foreach my $name (@order) {
                push(@vals, $row->{$name} . '');
                $self->{'debug'}->DEBUGMAX([$name, $row->{$name}]);
            }
            $table->row(@vals);
        } ## end while (my $row = $sth->fetchrow_hashref...)
        $sth->finish();
        my $string = $table->boxes->draw();
        $string = $self->sysop_color_border($string, 'CYAN', 'HEAVY');
        $self->sysop_pager("$string\n");
    } ## end else [ if ($list_mode =~ /VERTICAL/)]
    print 'Press a key to continue ... ';
    return ($self->sysop_keypress(TRUE));
} ## end sub sysop_list_users

sub sysop_delete_files {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Delete Files']);
    return (TRUE);
} ## end sub sysop_delete_files

sub sysop_list_files {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp List Files']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $sizes = {};
    while (my $row = $sth->fetchrow_hashref()) {
        foreach my $name (keys %{$row}) {
            if ($name eq 'file_size') {
                my $size = format_number($row->{$name});
                $sizes->{$name} = max(length($size), $sizes->{$name});
            } else {
                $sizes->{$name} = max(length("$row->{$name}"), $sizes->{$name});
            }
        } ## end foreach my $name (keys %{$row...})
    } ## end while (my $row = $sth->fetchrow_hashref...)
    $sth->finish();
    my $table;
    if ($wsize > 150) {
        $table = Text::SimpleTable->new(max(5, $sizes->{'title'}), max(8, $sizes->{'filename'}), max(4, $sizes->{'type'}), max(11, $sizes->{'description'}), max(8, $sizes->{'username'}), max(4, $sizes->{'file_size'}), max(6, $sizes->{'uploaded'}), max(9, $sizes->{'thumbs_up'}), max(11, $sizes->{'thumbs_down'}));
        $table->row('TITLE', 'FILENAME', 'TYPE', 'DESCRIPTION', 'UPLOADER', 'SIZE', 'UPLOADED', 'THUMBS UP', 'THUMBS DOWN');
    } else {
        $table = Text::SimpleTable->new(max(5, $sizes->{'filename'}), max(8, $sizes->{'title'}), max(4, $sizes->{'extension'}), max(11, $sizes->{'description'}), max(8, $sizes->{'username'}), max(4, $sizes->{'file_size'}), max(9, $sizes->{'thumbs_up'}), max(11, $sizes->{'thumbs_down'}));
        $table->row('TITLE', 'FILENAME', 'TYPE', 'DESCRIPTION', 'UPLOADER', 'SIZE', 'THUMBS UP', 'THUMBS DOWN');
    }
    $table->hr();
    $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $category;

    while (my $row = $sth->fetchrow_hashref()) {
        if ($wsize > 150) {
            $table->row($row->{'title'}, $row->{'filename'}, $row->{'type'}, $row->{'description'}, $row->{'username'}, format_number($row->{'file_size'}), $row->{'uploaded'}, sprintf('%-06u',$row->{'thumbs_up'}), sprintf('%-06u',$row->{'thumbs_down'}));
        } else {
            $table->row($row->{'title'}, $row->{'filename'}, $row->{'extension'}, $row->{'description'}, $row->{'username'}, format_number($row->{'file_size'}), sprintf('%-06u',$row->{'thumbs_up'}), sprintf('%-06u',$row->{'thumbs_down'}));
        }
        $category = $row->{'category'};
    } ## end while (my $row = $sth->fetchrow_hashref...)
    $sth->finish();
    $self->output("\n" . '[% B_ORANGE %][% BLACK %] Current Category [% RESET %] [% BRIGHT YELLOW %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% BRIGHT WHITE %][% FILE CATEGORY %][% RESET %]');
    my $tbl = $table->boxes->draw();
    $tbl = $self->sysop_color_border($tbl, 'YELLOW', 'DOUBLE');
    while ($tbl =~ / (TITLE|FILENAME|TYPE|DESCRIPTION|UPLOADER|SIZE|UPLOADED) /) {
        my $ch = $1;
        my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
        $tbl =~ s/ $ch / $new /gs;
    }
    $self->output("\n$tbl\nPress a Key To Continue ...");
    $self->sysop_keypress();
    print " BACK\n";
    return (TRUE);
} ## end sub sysop_list_files

sub sysop_color_border {
    my $self  = shift;
    my $tbl   = shift;
    my $color = shift;
    my $type  = shift; # ROUNDED, DOUBLE, HEAVY, DEFAULT

    my $new;
    if ($tbl =~ /(─+?)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE HORIZONTAL %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY HORIZONTAL %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(│)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE VERTICAL %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY VERTICAL %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┌)/) {
        my $ch = $1;
        if ($type eq 'ROUNDED') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC DOWN AND RIGHT %][% RESET %]';
        } elsif ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE DOWN AND RIGHT %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY DOWN AND RIGHT %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(└)/) {
        my $ch = $1;
        if ($type eq 'ROUNDED') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC UP AND RIGHT %][% RESET %]';
        } elsif ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE UP AND RIGHT %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY UP AND RIGHT %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┬)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY DOWN AND HORIZONTAL %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┐)/) {
        my $ch = $1;
        if ($type eq 'ROUNDED') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC DOWN AND LEFT %][% RESET %]';
        } elsif ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE DOWN AND LEFT %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY DOWN AND LEFT %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(├)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE VERTICAL AND RIGHT %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY VERTICAL AND RIGHT %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┘)/) {
        my $ch = $1;
        if ($type eq 'ROUNDED') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS LIGHT ARC UP AND LEFT %][% RESET %]';
        } elsif ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE UP AND LEFT %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY UP AND LEFT %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┼)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY VERTICAL AND HORIZONTAL %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┤)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE VERTICAL AND LEFT %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY VERTICAL AND LEFT %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    if ($tbl =~ /(┴)/) {
        my $ch = $1;
        if ($type eq 'DOUBLE') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS DOUBLE UP AND HORIZONTAL %][% RESET %]';
        } elsif ($type eq 'HEAVY') {
            $new = '[% ' . $color . ' %][% BOX DRAWINGS HEAVY UP AND HORIZONTAL %][% RESET %]';
        } else {
            $new = '[% ' . $color . ' %]' . $ch . '[% RESET %]';
        }
        $tbl =~ s/$ch/$new/gs;
    }
    return($tbl);
}

sub sysop_select_file_category {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Select File Category']);
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
    $sth->execute();
    my $table = Text::SimpleTable->new(3, 30, 50);
    $table->row('ID', 'TITLE', 'DESCRIPTION');
    $table->hr();
    my $max_id = 1;
    while (my $row = $sth->fetchrow_hashref()) {
        $table->row($row->{'id'}, $row->{'title'}, $row->{'description'});
        $max_id = $row->{'id'};
    }
    $sth->finish();
    my $text = $table->boxes->draw();
    while ($text =~ / (ID|TITLE|DESCRIPTION) /) {
        my $ch = $1;
        my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
        $text =~ s/ $ch / $new /gs;
    }
    $self->output($self->sysop_color_border($text,'MAGENTA', 'DOUBLE') . "\n" . $self->sysop_prompt('Choose ID (< = Nevermind)'));
    my $line;
    do {
        $line = uc($self->sysop_get_line(ECHO, 3, ''));
    } until ($line =~ /^(\d+|\<)/i);
    if ($line eq '<') {
        return (FALSE);
    } elsif ($line >= 1 && $line <= $max_id) {
        $sth = $self->{'dbh'}->prepare('UPDATE users SET file_category=? WHERE id=1');
        $sth->execute($line);
        $sth->finish();
        $self->{'USER'}->{'file_category'} = $line + 0;
        return (TRUE);
    } else {
        return (FALSE);
    }
} ## end sub sysop_select_file_category

sub sysop_edit_file_categories {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Edit File Categories']);
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM file_categories');
    $sth->execute();
    my $table = Text::SimpleTable->new(3, 30, 50);
    $table->row('ID', 'TITLE', 'DESCRIPTION');
    $table->hr();
    while (my $row = $sth->fetchrow_hashref()) {
        $table->row($row->{'id'}, $row->{'title'}, $row->{'description'});
    }
    $sth->finish();
    my $text = $table->boxes->draw();
    while ($text =~ / (ID|TITLE|DESCRIPTION) /) {
        my $ch = $1;
        my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
        $text =~ s/ $ch / $new /gs;
    }
    $self->output($text . "\n" . $self->sysop_prompt('Choose ID (A = Add, < = Nevermind)'));
    my $line;
    do {
        $line = uc($self->sysop_get_line(ECHO, 3, ''));
    } until ($line =~ /^(\d+|A|\<)/i);
    if ($line eq 'A') {    # Add
        print "\nADD NEW FILE CATEGORY\n";
        $table = Text::SimpleTable->new(11, 80);
        $table->row('TITLE',       "\n" . charnames::string_vianame('OVERLINE') x 80);
        $table->row('DESCRIPTION', "\n" . charnames::string_vianame('OVERLINE') x 80);
        my $text = $table->boxes->draw();
        while ($text =~ / (TITLE|DESCRIPTION) /) {
            my $ch = $1;
            my $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
            $text =~ s/ $ch / $new /gs;
        }
        $self->output("\n" . $self->sysop_color_border($text, 'MAGENTA', 'DOUBLE'));
        print $self->{'ansi_sequences'}->{'UP'} x 5, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
        my $title = $self->sysop_get_line(ECHO, 80, '');
        if ($title ne '') {
            print "\r", $self->{'ansi_sequences'}->{'DOWN'}, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
            my $description = $self->sysop_get_line(ECHO, 80, '');
            if ($description ne '') {
                $sth = $self->{'dbh'}->prepare('INSERT INTO file_categories (title,description) VALUES (?,?)');
                $sth->execute($title, $description);
                $sth->finish();
                print "\n\nNew Entry Added\n";
            } else {
                print "\n\nNevermind\n";
            }
        } else {
            print "\n\n\nNevermind\n";
        }
    } elsif ($line =~ /\d+/) {    # Edit
    }
    return (TRUE);
} ## end sub sysop_edit_file_categories

sub sysop_vertical_heading {
    my $self = shift;
    my $text = shift;

    my $heading = '';
    for (my $count = 0; $count < length($text); $count++) {
        $heading .= substr($text, $count, 1) . "\n";
    }
    return ($heading);
} ## end sub sysop_vertical_heading

sub sysop_view_configuration {
    my $self = shift;
    my $view = shift;

    $self->{'debug'}->DEBUG(['SysOp View Configuration']);

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

    # Assemble table
    my $table = ($view) ? Text::SimpleTable->new($name_width, $value_width) : Text::SimpleTable->new(6, $name_width, $value_width);
    if ($view) {
        $table->row('STATIC NAME', 'STATIC VALUE');
        $table->hr();
    }
    foreach my $conf (sort(keys %{ $self->{'CONF'}->{'STATIC'} })) {
        next if ($conf eq 'DATABASE PASSWORD');
        if ($view) {
            $table->row($conf, $self->{'CONF'}->{'STATIC'}->{$conf});
        }
    } ## end foreach my $conf (sort(keys...))
    if ($view) {
        $table->hr();
        $table->row('CONFIG NAME', 'CONFIG VALUE');
    } else {
        $table->row('CHOICE', 'CONFIG NAME', 'CONFIG VALUE');
    }
    $table->hr();
    my $count = 0;
    foreach my $conf (sort(keys %{ $self->{'CONF'} })) {
        my $choice = ($count >= 10) ? chr(55 + $count) : $count;
        next if ($conf eq 'STATIC');
        my $c = $self->{'CONF'}->{$conf};
        if ($conf eq 'DEFAULT TIMEOUT') {
            $c .= ' Minutes';
        } elsif ($conf eq 'DEFAULT BAUD RATE') {
            $c .= ' bps - 300, 600, 1200, 2400, 4800, 9600, 19200, FULL';
        } elsif ($conf eq 'THREAD MULTIPLIER') {
            $c .= ' x CPU Cores';
        } elsif ($conf eq 'DEFAULT TEXT MODE') {
            $c .= ' - ANSI, ASCII, ATASCII, PETSCII';
        }
        if ($view) {
            $table->row($conf, $c);
        } else {
            if ($conf =~ /AUTHOR/) {
                $table->row(' ', $conf, $c);
            } else {
                $table->row($choice, $conf, $c);
                $count++;
            }
        } ## end else [ if ($view) ]
    } ## end foreach my $conf (sort(keys...))
    my $output = $table->boxes->draw();
    foreach my $change ('AUTHOR EMAIL', 'AUTHOR LOCATION', 'AUTHOR NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME', '300, 600, 1200, 2400, 4800, 9600, 19200, FULL', '%d = day, %m = Month, %Y = Year', 'ANSI, ASCII, ATASCII, PETSCII', 'ANSI, ASCII, ATAASCII,PETSCII') {
        if ($output =~ /$change/) {
            my $ch;
            if (/^(AUTHOR|DATABASE)/) {
                $ch = '[% YELLOW %]' . $change . '[% RESET %]';
            } else {
                $ch = '[% GREY 11 %]' . $change . '[% RESET %]';
            }
            $output =~ s/$change/$ch/gs;
        }
    } ## end foreach my $change ('AUTHOR EMAIL'...)
    {
        my $ch = colored(['cyan'], 'CHOICE');
        $output =~ s/CHOICE/$ch/gs;
        $ch = colored(['bright_yellow'], 'STATIC NAME');
        $output =~ s/STATIC NAME/$ch/gs;
        $ch = colored(['green'], 'CONFIG NAME');
        $output =~ s/CONFIG NAME/$ch/gs;
        $ch = colored(['cyan'], 'CONFIG VALUE');
        $output =~ s/CONFIG VALUE/$ch/gs;
        $output = $self->sysop_color_border($output, 'RED', 'HEAVY');
    }
    if ("$view" eq 'string') {
        return ($output);
    } elsif ($view == TRUE) {
        print $self->sysop_detokenize($output);
        print 'Press a key to continue ... ';
        return ($self->sysop_keypress(TRUE));
    } elsif ($view == FALSE) {
        print $self->sysop_detokenize($output);
        print $self->sysop_menu_choice('TOP',    '',    '');
        print $self->sysop_menu_choice('Z',      'RED', 'Return to Settings Menu');
        print $self->sysop_menu_choice('BOTTOM', '',    '');
        print $self->sysop_prompt('Choose');
        return (TRUE);
    } ## end elsif ($view == FALSE)
} ## end sub sysop_view_configuration

sub sysop_edit_configuration {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Edit Configuration']);
    $self->sysop_view_configuration(FALSE);
    my $types = {
        'BBS NAME' => {
            'max'  => 50,
            'type' => STRING,
        },
        'BBS ROOT' => {
            'max'  => 60,
            'type' => STRING,
        },
        'HOST' => {
            'max'  => 20,
            'type' => HOST,
        },
        'THREAD MULTIPLIER' => {
            'max'  => 2,
            'type' => NUMERIC,
        },
        'PORT' => {
            'max'  => 5,
            'type' => NUMERIC,
        },
        'DEFAULT BAUD RATE' => {
            'max'     => 5,
            'type'    => RADIO,
            'choices' => ['300', '600', '1200', '2400', '4800', '9600', '19200', 'FULL'],
        },
        'DEFAULT TEXT MODE' => {
            'max'     => 7,
            'type'    => RADIO,
            'choices' => ['ANSI', 'ASCII', 'ATASCII', 'PETSCII'],
        },
        'DEFAULT TIMEOUT' => {
            'max'  => 3,
            'type' => NUMERIC,
        },
        'FILES PATH' => {
            'max'  => 60,
            'type' => STRING,
        },
        'LOGIN TRIES' => {
            'max'  => 1,
            'type' => NUMERIC,
        },
        'MEMCACHED HOST' => {
            'max'  => 20,
            'type' => HOST,
        },
        'MEMCACHED NAMESPACE' => {
            'max'  => 32,
            'type' => STRING,
        },
        'MEMCACHED PORT' => {
            'max'  => 5,
            'type' => NUMERIC,
        },
        'DATE FORMAT' => {
            'max'     => 14,
            'type'    => RADIO,
            'choices' => ['MONTH/DAY/YEAR', 'DAY/MONTH/YEAR', 'YEAR/MONTH/DAY',],
        },
        'USE DUF' => {
            'max'     => 5,
            'type'    => RADIO,
            'choices' => ['TRUE', 'FALSE'],
        },
        'PLAY SYSOP SOUNDS' => {
            'max'     => 5,
            'type'    => RADIO,
            'choices' => ['TRUE', 'FALSE'],
        },
    };
    my $choice;
    do {
        $choice = uc($self->sysop_keypress(TRUE));
    } until ($choice =~ /\d|[A-G]|Z/i);
    if ($choice =~ /Z/i) {
        print "BACK\n";
        return (FALSE);
    }

    $choice = ("$choice" =~ /[A-Y]/i) ? $choice = (ord($choice) - 55) : $choice;
    my @conf = grep(!/STATIC|AUTHOR/, sort(keys %{ $self->{'CONF'} }));
    if ($types->{ $conf[$choice] }->{'type'} == RADIO) {
        print '(Edit) ', $conf[$choice], ' (' . join(' ', @{ $types->{ $conf[$choice] }->{'choices'} }) . ') ', charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE'), '  ';
    } else {
        print '(Edit) ', $conf[$choice], ' ', charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE'), '  ';
    }
    my $string;
    $self->{'debug'}->DEBUGMAX([$self->configuration()]);
    $string = $self->sysop_get_line($types->{ $conf[$choice] }, $self->configuration($conf[$choice]));
    return (FALSE) if ($string eq '');
    $self->configuration($conf[$choice], $string);
    return (TRUE);
} ## end sub sysop_edit_configuration

sub sysop_get_key {
    my $self     = shift;
    my $echo     = shift;
    my $blocking = shift;

    my $key     = undef;
    my $mode    = $self->{'USER'}->{'text_mode'};
    my $timeout = $self->{'USER'}->{'timeout'} * 60;
    local $/ = "\x{00}";
    ReadMode 'ultra-raw';
    $key = ($blocking) ? ReadKey($timeout) : ReadKey(-1);
    ReadMode 'restore';
    threads->yield;
    return ($key) if ($key eq chr(13));

    if ($key eq chr(127)) {
        $key = $self->{'ansi_sequences'}->{'BACKSPACE'};
    }
    if ($echo == NUMERIC && defined($key)) {
        unless ($key =~ /[0-9]/) {
            $key = '';
        }
    }
    threads->yield;
    return ($key);
} ## end sub sysop_get_key

sub sysop_get_line {
    my $self = shift;
    my $echo = shift;
    my $type = $echo;

    my $line;
    my $limit;
    my $choices;
    my $key;

    $self->{'CACHE'}->set('SHOW_STATUS', FALSE);
    $self->{'debug'}->DEBUG(['SysOp Get Line']);
    $self->flush_input();

    if (ref($type) eq 'HASH') {
        $limit = $type->{'max'};
        if (exists($type->{'choices'})) {
            $choices = $type->{'choices'};
            if (exists($type->{'default'})) {
                $line = $type->{'default'};
            } else {
                $line = shift;
            }
        } ## end if (exists($type->{'choices'...}))
        $echo = $type->{'type'};
    } else {
        if ($echo == STRING || $echo == ECHO || $echo == NUMERIC || $echo == HOST) {
            $limit = shift;
        }
        $line = shift;
    } ## end else [ if (ref($type) eq 'HASH')]

    $self->{'debug'}->DEBUGMAX([$type, $echo, $line]);
    $self->output($line) if ($line ne '');
    my $mode = 'ANSI';
    my $bs   = $self->{'ansi_sequences'}->{'BACKSPACE'};
    if ($echo == RADIO) {
        my $regexp = join('', @{ $type->{'choices'} });
        $self->{'debug'}->DEBUGMAX([$regexp]);
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($regexp =~ /$key/i) {
                        $self->output(uc($key));
                        $line .= uc($key);
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } elsif ($echo == NUMERIC) {
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(NUMERIC, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[0-9]/) {
                        $self->output($key);
                        $line .= $key;
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } elsif ($echo == HOST) {
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs || $key eq chr(127)) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && $key =~ /[a-z]|[0-9]|\./) {
                        $self->output(lc($key));
                        $line .= lc($key);
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs || $key eq chr(127))) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } else {
        while ($key ne chr(13) && $key ne chr(3)) {
            if (length($line) <= $limit) {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                return ('') if (defined($key) && $key eq chr(3));
                if (defined($key) && $key ne '') {
                    if ($key eq $bs) {
                        my $len = length($line);
                        if ($len > 0) {
                            $self->output("$key $key");
                            chop($line);
                        }
                    } elsif ($key ne chr(13) && $key ne chr(3) && $key ne chr(10) && ord($key) > 31 && ord($key) < 127) {
                        $self->output($key);
                        $line .= $key;
                    } else {
                        $self->output('[% RING BELL %]');
                    }
                } ## end if (defined($key) && $key...)
            } else {
                $key = $self->sysop_get_key(SILENT, BLOCKING);
                if (defined($key) && $key eq chr(3)) {
                    return ('');
                }
                if (defined($key) && ($key eq $bs)) {
                    $key = $bs;
                    $self->output("$key $key");
                    chop($line);
                } else {
                    $self->output('[% RING BELL %]');
                }
            } ## end else [ if (length($line) <= $limit)]
        } ## end while ($key ne chr(13) &&...)
    } ## end else [ if ($echo == RADIO) ]
    threads->yield();
    $line = '' if ($key eq chr(3));
    print "\n";
    $self->{'CACHE'}->set('SHOW_STATUS', TRUE);
    return ($line);
} ## end sub sysop_get_line

sub sysop_user_delete {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['SysOp User Delete']);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my $key;
    print $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(ECHO, 20, '');
    return (FALSE) if ($search eq '' || $search eq 'sysop' || $search eq '1');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($user_row)) {
        my $table = Text::SimpleTable->new(16, 60);
        $table->row('FIELD', 'VALUE');
        $table->hr();
        foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
            if ($field ne 'id' && $user_row->{$field} =~ /^(0|1)$/) {
                $user_row->{$field} = $self->sysop_true_false($user_row->{$field}, 'YN');
            } elsif ($field eq 'timeout') {
                $user_row->{$field} = $user_row->{$field} . ' Minutes';
            }
            $table->row($field, $user_row->{$field} . '');
        } ## end foreach my $field (@{ $self...})
        if ($self->sysop_pager($self->sysop_color_border($table->boxes->draw(), 'RED', 'HEAVY'))) {
            print "Are you sure that you want to delete this user (Y|N)?  ";
            my $answer = $self->sysop_decision();
            if ($answer) {
                print "\n\nDeleting ", $user_row->{'username'}, " ... ";
                $sth = $self->users_delete($user_row->{'id'});
            }
        } ## end if ($self->sysop_pager...)
    } ## end if (defined($user_row))
} ## end sub sysop_user_delete

sub sysop_user_edit {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['SysOp User Edit']);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
    my $key;
    print $self->sysop_prompt('Please enter the username or account number');
    my $search = $self->sysop_get_line(ECHO, 20, '');
    return (FALSE) if ($search eq '');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($user_row)) {
        my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
        do {
            my $valsize = 1;
            foreach my $fld (keys %{$user_row}) {
                $valsize = max($valsize, length($user_row->{$fld}));
            }
            $valsize = min($valsize, $wsize - 29);
            my $table = Text::SimpleTable->new(6, 16, $valsize);
            $table->row('CHOICE', 'FIELD', 'VALUE');
            $table->hr();
            my $count = 0;
            my %choice;
            foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
                if ($field =~ /_time|fullname|_category|id/) {
                    $table->row(' ', uc($field), $user_row->{$field} . '');
                } else {
                    if ($user_row->{$field} =~ /^(0|1)$/) {
                        $table->row($choices[$count], uc($field), $self->sysop_true_false($user_row->{$field}, 'YN'));
                    } elsif ($field eq 'access_level') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - USER, VETERAN, JUNIOR SYSOP, SYSOP');
                    } elsif ($field eq 'date_format') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - YEAR/MONTH/DAY, MONTH/DAY/YEAR, DAY/MONTH/YEAR');
                    } elsif ($field eq 'baud_rate') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - 300, 600, 1200, 2400, 4800, 9600, 19200, FULL');
                    } elsif ($field eq 'text_mode') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - ASCII, ANSI, ATASCII, PETSCII');
                    } elsif ($field eq 'timeout') {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . ' - Minutes');
                    } else {
                        $table->row($choices[$count], uc($field), $user_row->{$field} . '');
                    }
                    $count++ if ($key_exit eq $choices[$count]);
                    $choice{ $choices[$count] } = $field;
                    $count++;
                } ## end else [ if ($field =~ /_time|fullname|_category|id/)]
            } ## end foreach my $field (@{ $self...})
            my $tbl = $table->boxes->draw();
            while ($tbl =~ / (CHOICE|FIELD|VALUE|No|Yes|USER. VETERAN. JUNIOR SYSOP. SYSOP|YEAR.MONTH.DAY, MONTH.DAY.YEAR, DAY.MONTH.YEAR|300. 600. 1200. 2400. 4800. 9600. 19200. FULL|ASCII. ANSI. ATASCII. PETSCII|Minutes) /) {
                my $ch  = $1;
                my $new;
                if ($ch =~ /Yes/) {
                    $new = '[% GREEN %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /No/) {
                    $new = '[% RED %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /CHOICE|FIELD|VALUE/) {
                    $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                } else {
                    $new = '[% RGB 50,50,150 %]' . $ch . '[% RESET %]';
                }
                $tbl =~ s/$ch/$new/g;
            }
            $tbl = $self->sysop_color_border($tbl, 'BRIGHT CYAN', 'ROUNDED');
            $self->output('[% CLS %]' . $tbl . "\n");
            $self->sysop_show_choices($mapping);
            print "\n", $self->sysop_prompt('Choose');
            do {
                $key = uc($self->sysop_keypress());
            } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
            if ($key !~ /$key_exit/i) {
                print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
                if ($choice{$key} =~ /^(prefer_nickname|view_files|upload_files|download_files|remove_files|read_message|post_message|remove_message|sysop|page_sysop)$/) {
                    $user_row->{$choice{$key}} = ($user_row->{$choice{$key}} == 1) ? 0 : 1;
                    my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . $choice{ $key } . '= !' . $choice{$key} . '  WHERE id=?');
                    $sth->execute($user_row->{'id'});
                    $sth->finish();
                } else {
                    my $new = $self->sysop_get_line(ECHO, 1 + $self->{'SYSOP FIELD TYPES'}->{ $choice{$key} }->{'max'}, $user_row->{ $choice{$key} });
                    $user_row->{ $choice{$key} } = $new;
                    my $sth = $self->{'dbh'}->prepare('UPDATE users SET ' . $choice{$key} . '=? WHERE id=?');
                    $sth->execute($new, $user_row->{'id'});
                    $sth->finish();
                }
            } else {
                print "BACK\n";
            }
        } until ($key =~ /$key_exit/i);
    } elsif ($search ne '') {
        print "User not found!\n\n";
    }
    return (TRUE);
} ## end sub sysop_user_edit

sub sysop_new_user_edit {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['SysOp User Edit']);
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    delete($mapping->{'TEXT'});
    my ($key_exit) = (keys %{$mapping});
    my @choices = qw( 0 1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y );
    my $key;
    my @responses;
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE access_level=?');
    $sth->execute('USER');
    my $user_row;

    while ($user_row = $sth->fetchrow_hashref()) {
        push(@responses, $user_row);
    }
    $sth->finish();

    $self->{'debug'}->DEBUGMAX(\@responses);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    while ($user_row = pop(@responses)) {
        do {
            my $valsize = 1;
            foreach my $fld (keys %{$user_row}) {
                $valsize = max($valsize, length($user_row->{$fld}));
            }
            $valsize = min($valsize, $wsize - 29);
            my $table = Text::SimpleTable->new(6, 16, $valsize);
            $table->row('CHOICE', 'FIELD', 'VALUE');
            $table->hr();
            my $count = 0;
            my %choice;
            foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
                if ($field =~ /_time|fullname|_category|id/) {
                    $table->row(' ', $field, $user_row->{$field} . '');
                } else {
                    if ($user_row->{$field} =~ /^(0|1)$/) {
                        $table->row($choices[$count], $field, $self->sysop_true_false($user_row->{$field}, 'YN'));
                    } elsif ($field eq 'access_level') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - USER, VETERAN, JUNIOR SYSOP, SYSOP');
                    } elsif ($field eq 'date_format') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - YEAR/MONTH/DAY, MONTH/DAY/YEAR, DAY/MONTH/YEAR');
                    } elsif ($field eq 'baud_rate') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - 300, 600, 1200, 2400, 4800, 9600, 19200, FULL');
                    } elsif ($field eq 'text_mode') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - ASCII, ANSI, ATASCII, PETSCII');
                    } elsif ($field eq 'timeout') {
                        $table->row($choices[$count], $field, $user_row->{$field} . ' - Minutes');
                    } else {
                        $table->row($choices[$count], $field, $user_row->{$field} . '');
                    }
                    $count++ if ($key_exit eq $choices[$count]);
                    $choice{ $choices[$count] } = $field;
                    $count++;
                } ## end else [ if ($field =~ /_time|fullname|_category|id/)]
            } ## end foreach my $field (@{ $self...})
            my $tbl = $table->boxes->draw();
            while ($tbl =~ / (CHOICE|FIELD|VALUE|No|Yes|USER. VETERAN. JUNIOR SYSOP. SYSOP|YEAR.MONTH.DAY, MONTH.DAY.YEAR, DAY.MONTH.YEAR|300. 600. 1200. 2400. 4800. 9600. 19200. FULL|ASCII. ANSI. ATASCII. PETSCII|Minutes) /) {
                my $ch  = $1;
                my $new;
                if ($ch =~ /Yes/) {
                    $new = '[% GREEN %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /No/) {
                    $new = '[% RED %]' . $ch . '[% RESET %]';
                } elsif ($ch =~ /CHOICE|FIELD|VALUE/) {
                    $new = '[% BRIGHT YELLOW %]' . $ch . '[% RESET %]';
                } else {
                    $new = '[% RGB 50,50,150 %]' . $ch . '[% RESET %]';
                }
                $tbl =~ s/$ch/$new/g;
            }
            $tbl = $self->sysop_color_border($tbl, 'BRIGHT CYAN', 'ROUNDED');
            $self->output('[% CLS %]' . $tbl . "\n");
            $self->sysop_show_choices($mapping);
            $self->output("\n" . $self->sysop_prompt('Choose'));
            do {
                $key = uc($self->sysop_keypress());
            } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
            if ($key !~ /$key_exit/i) {
                print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
                my $new = $self->sysop_get_line(ECHO, 1 + $self->{'SYSOP FIELD TYPES'}->{ $choice{$key} }->{'max'}, $user_row->{ $choice{$key} });
                unless ($new eq '') {
                    $new =~ s/^(Yes|On)$/1/i;
                    $new =~ s/^(No|Off)$/0/i;
                }
                $user_row->{ $choice{$key} } = $new;
                if ($key =~ /prefer_nickname|view_files|upload_files|download_files|remove_files|read_message|post_message|remove_message|sysop|page_sysop/) {
                    my $sth = $self->{'dbh'}->prepare('UPDATE permissions SET ' . choice { $key } . '=? WHERE id=?');
                    $sth->execute($new, $user_row->{'id'});
                    $sth->finish();
                } else {
                    my $sth = $self->{'dbh'}->prepare('UPDATE users SET ' . $choice{$key} . '=? WHERE id=?');
                    $sth->execute($new, $user_row->{'id'});
                    $sth->finish();
                }
            } else {
                print "BACK\n";
            }
        } until ($key =~ /$key_exit/i);
    } ## end while ($user_row = pop(@responses...))
    return (TRUE);
} ## end sub sysop_new_user_edit

sub sysop_user_add {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['SysOp User Add']);
    my $flags_default = $self->{'flags_default'};
    my $mapping       = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $table = Text::SimpleTable->new(15, 150);
    my $user_template;
    my @tmp = grep(!/id|banned|fullname|_time|max_|_category/, @{ $self->{'SYSOP ORDER DETAILED'} });
    push(@tmp, 'password');

    foreach my $name (@tmp) {
        my $size = max(3, $self->{'SYSOP FIELD TYPES'}->{$name}->{'max'});
        if ($name eq 'timeout') {
            $table->row($name, '_' x $size . ' - Minutes');
        } elsif ($name eq 'baud_rate') {
            $table->row($name, '_' x $size . ' - 300 or 600 or 1200 or 2400 or 4800 or 9600 or 19200 or FULL');
        } elsif ($name =~ /username|given|family|password/) {
            if ($name eq 'given') {
                $table->row("$name (first)", '_' x $size . ' - Cannot be empty');
            } elsif ($name eq 'family') {
                $table->row("$name (last)", '_' x $size . ' - Cannot be empty');
            } else {
                $table->row($name, '_' x $size . ' - Cannot be empty');
            }
        } elsif ($name eq 'date_format') {
            $table->row($name, '_' x $size . ' - YEAR/MONTH/DAY or MONTH/DAY/YEAR or DAY/MONTH/YEAR');
        } elsif ($name eq 'access_level') {
            $table->row($name, '_' x $size . ' - USER or VETERAN or JUNIOR SYSOP or SYSOP');
        } elsif ($name eq 'text_mode') {
            $table->row($name, '_' x $size . ' - ANSI or ASCII or ATASCII or PETSCII');
        } elsif ($name eq 'birthday') {
            $table->row($name, '_' x $size . ' - YEAR-MM-DD');
        } elsif ($name =~ /(prefer_nickname|_files|_message|sysop|fortunes)/) {
            $table->row($name, '_' x $size . ' - Yes/No or True/False or On/Off or 1/0');
        } elsif ($name =~ /location|retro_systems|accomplishments/) {
            $table->row($name, '_' x ($self->{'SYSOP FIELD TYPES'}->{$name}->{'max'}));
        } else {
            $table->row($name, '_' x $size);
        }
        $user_template->{$name} = undef;
    } ## end foreach my $name (@tmp)
    my $string = $table->boxes->draw();
    while ($string =~ / (Cannot be empty|YEAR.MM.DD|USER or VETERAN or JUNIOR SYSOP or SYSOP|YEAR.MONTH.DAY or MONTH.DAY.YEAR or DAY.MONTH.YEAR|300 or 600 or 1200 or 2400 or 4800 or 9600 or 19200 or FULL|ANSI or ASCII or ATASCII or PETSCII|Minutes|Yes.No or True.False or On.Off or 1.0) /) {
        my $ch  = $1;
        my $new = '[% RGB 50,50,150 %]' . $ch . '[% RESET %]';
        $string =~ s/$ch/$new/gs;
    }
    $self->output($self->sysop_color_border($string, 'PINK', 'DEFAULT'));
    $self->sysop_show_choices($mapping);
    my $column     = 21;
    my $adjustment = $self->{'CACHE'}->get('START_ROW') - 1;
    foreach my $entry (@tmp) {
        do {
            print locate($row + $adjustment, $column), '_' x max(3, $self->{'SYSOP FIELD TYPES'}->{$entry}->{'max'}), locate($row + $adjustment, $column);
            chomp($user_template->{$entry} = $self->sysop_get_line($self->{'SYSOP FIELD TYPES'}->{$entry}));
            return ('BACK') if ($user_template->{$entry} eq '<' || $user_template->{$entry} eq chr(3));
            if ($entry =~ /text_mode|baud_rate|timeout|given|family/) {
                if ($user_template->{$entry} eq '') {
                    if ($entry eq 'text_mode') {
                        $user_template->{$entry} = 'ASCII';
                    } elsif ($entry eq 'baud_rate') {
                        $user_template->{$entry} = 'FULL';
                    } elsif ($entry eq 'timeout') {
                        $user_template->{$entry} = $self->{'CONF'}->{'DEFAULT TIMEOUT'};
                    } elsif ($entry =~ /prefer|_files|_message|sysop|_fortunes/) {
                        $user_template->{$entry} = $flags_default->{$entry};
                    } else {
                        $user_template->{$entry} = uc($user_template->{$entry});
                    }
                } elsif ($entry =~ /given|family/) {
                    my $ucuser = uc($user_template->{$entry});
                    if ($ucuser eq $user_template->{$entry}) {
                        $user_template->{$entry} = ucfirst(lc($user_template->{$entry}));
                    } else {
                        substr($user_template->{$entry}, 0, 1) = uc(substr($user_template->{$entry}, 0, 1));
                    }
                } ## end elsif ($entry =~ /given|family/)
                print locate($row + $adjustment, $column), $user_template->{$entry};
            } elsif ($entry =~ /prefer_|_files|_message|sysop|_fortunes/) {
                $user_template->{$entry} = uc($user_template->{$entry});
                print locate($row + $adjustment, $column), $user_template->{$entry};
            }
        } until ($self->sysop_validate_fields($entry, $user_template->{$entry}, $row + $adjustment, $column));
        if ($user_template->{$entry} =~ /^(yes|on|true|1)$/i) {
            $user_template->{$entry} = TRUE;
        } elsif ($user_template->{$entry} =~ /^(no|off|false|0)$/i) {
            $user_template->{$entry} = FALSE;
        }
        $adjustment++;
    } ## end foreach my $entry (@tmp)
    $self->{'debug'}->DEBUGMAX([$user_template]);
    if ($self->users_add($user_template)) {
        print "\n\n", colored(['green'], 'SUCCESS'), "\n";
        $self->{'debug'}->DEBUG(['sysop_user_add end']);
        return (TRUE);
    }
    return (FALSE);
} ## end sub sysop_user_add

sub sysop_show_choices {
    my $self    = shift;
    my $mapping = shift;

    print $self->sysop_menu_choice('TOP', '', '');
    my $keys = '';
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        print $self->sysop_menu_choice($kmenu, $mapping->{$kmenu}->{'color'}, $mapping->{$kmenu}->{'text'});
        $keys .= $kmenu;
    }
    print $self->sysop_menu_choice('BOTTOM', '', '');
    return (TRUE);
} ## end sub sysop_show_choices

sub sysop_validate_fields {
    my $self   = shift;
    my $name   = shift;
    my $val    = shift;
    my $row    = shift;
    my $column = shift;

    my $size = max(3, $self->{'SYSOP FIELD TYPES'}->{$name}->{'max'});
    if ($name =~ /(username|given|family|baud_rate|timeout|_files|_message|sysop|prefer|password)/ && $val eq '') {    # cannot be empty
        print locate($row, ($column + $size)), colored(['red'], ' Cannot Be Empty'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'baud_rate' && $val !~ /^(300|600|1200|2400|4800|9600|FULL)$/i) {
        print locate($row, ($column + $size)), colored(['red'], ' Only 300,600,1200,2400,4800,9600,FULL'), locate($row, $column);
        return (FALSE);
    } elsif ($name =~ /max_/ && $val =~ /\D/i) {
        print locate($row, ($column + $size)), colored(['red'], ' Only Numeric Values'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'timeout' && $val =~ /\D/) {
        print locate($row, ($column + $size)), colored(['red'], ' Must be numeric'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'text_mode' && $val !~ /^(ASCII|ATASCII|PETSCII|ANSI)$/) {
        print locate($row, ($column + $size)), colored(['red'], ' Only ASCII,ATASCII,PETSCII,ANSI'), locate($row, $column);
        return (FALSE);
    } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/ && $val !~ /^(yes|no|true|false|on|off|0|1)$/i) {
        print locate($row, ($column + $size)), colored(['red'], ' Only Yes/No or On/Off or 1/0'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'birthday' && $val ne '' && $val !~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
        print locate($row, ($column + $size)), colored(['red'], ' YEAR-MM-DD'), locate($row, $column);
        $self->{'debug'}->DEBUG(['sysop_validate_fields end']);
        return (FALSE);
    }
    return (TRUE);
} ## end sub sysop_validate_fields

sub sysop_prompt {
    my $self = shift;
    my $text = shift;

    my $response = '[% B_BRIGHT MAGENTA %][% BLACK %] SYSOP TOOL [% RESET %] ' . $text . ' [% PINK %][% BLACK RIGHTWARDS ARROWHEAD %][% RESET %] ';
    return ($self->sysop_detokenize($response));
} ## end sub sysop_prompt

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    # OPERATION TOKENS
    foreach my $key (keys %{ $self->{'sysop_tokens'} }) {
        my $ch = '';
        if (ref($self->{'sysop_tokens'}->{$key}) eq 'CODE') {
            $ch = $self->{'sysop_tokens'}->{$key}->($self);
        } else {
            $ch = $self->{'sysop_tokens'}->{$key};
        }
        $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
    } ## end foreach my $key (keys %{ $self...})

    $text = $self->ansi_decode($text);

    return ($text);
} ## end sub sysop_detokenize

sub sysop_menu_choice {
    my $self   = shift;
    my $choice = shift;
    my $color  = shift;
    my $desc   = shift;

    my $response;
    if ($choice eq 'TOP') {
        $response = charnames::string_vianame('BOX DRAWINGS LIGHT ARC DOWN AND RIGHT') . charnames::string_vianame('BOX DRAWINGS LIGHT HORIZONTAL') . charnames::string_vianame('BOX DRAWINGS LIGHT ARC DOWN AND LEFT') . "\n";
    } elsif ($choice eq 'BOTTOM') {
        $response = charnames::string_vianame('BOX DRAWINGS LIGHT ARC UP AND RIGHT') . charnames::string_vianame('BOX DRAWINGS LIGHT HORIZONTAL') . charnames::string_vianame('BOX DRAWINGS LIGHT ARC UP AND LEFT') . "\n";
    } else {
        $response = $self->ansi_decode(charnames::string_vianame('BOX DRAWINGS LIGHT VERTICAL') . '[% BOLD %][% ' . $color . ' %]' . $choice . '[% RESET %]' . charnames::string_vianame('BOX DRAWINGS LIGHT VERTICAL') . ' [% ' . $color . ' %]' . charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE') . '[% RESET %] ' . $desc . "\n");
    }
    return ($response);
} ## end sub sysop_menu_choice

sub sysop_showenv {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp ShowENV']);
    my $MAX  = 0;
    my $text = '';
    foreach my $e (keys %ENV) {
        $MAX = max(length($e), $MAX);
    }

    foreach my $env (sort(keys %ENV)) {
        if ($ENV{$env} =~ /\n/g) {
            my @in     = split(/\n$/, $ENV{$env});
            my $indent = $MAX + 4;
            $text .= sprintf("%${MAX}s = ---" . $env) . "\n";
            foreach my $line (@in) {
                if ($line =~ /\:/) {
                    my ($f, $l) = $line =~ /^(.*?):(.*)/;
                    chomp($l);
                    chomp($f);
                    $f = uc($f);
                    if ($f eq 'IP') {
                        $l = colored(['bright_green'], $l);
                        $f = 'IP ADDRESS';
                    }
                    my $le = 11 - length($f);
                    $f .= ' ' x $le;
                    $l = colored(['green'],    uc($l))                                                           if ($l =~ /^ok/i);
                    $l = colored(['bold red'], 'U') . colored(['bold white'], 'S') . colored(['bold blue'], 'A') if ($l =~ /^us/i);
                    $text .= colored(['bold white'], sprintf("%${indent}s", $f)) . " = $l\n";
                } else {
                    $text .= "$line\n";
                }
            } ## end foreach my $line (@in)
        } elsif ($env eq 'SSH_CLIENT') {
            my ($ip, $p1, $p2) = split(/ /, $ENV{$env});
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ip) . ' ' . colored(['cyan'], $p1) . ' ' . colored(['yellow'], $p2) . "\n";
        } elsif ($env eq 'SSH_CONNECTION') {
            my ($ip1, $p1, $ip2, $p2) = split(/ /, $ENV{$env});
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ip1) . ' ' . colored(['cyan'], $p1) . ' ' . colored(['bright_green'], $ip2) . ' ' . colored(['yellow'], $p2) . "\n";
        } elsif ($env eq 'TERM') {
            my $colorized = colored(['red'], '2') . colored(['green'], '5') . colored(['yellow'], '6') . colored(['cyan'], 'c') . colored(['bright_blue'], 'o') . colored(['magenta'], 'l') . colored(['bright_green'], 'o') . colored(['bright_blue'], 'r');
            my $line      = $ENV{$env};
            $line =~ s/256color/$colorized/;
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . $line . "\n";
        } elsif ($env eq 'WHATISMYIP') {
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . colored(['bright_green'], $ENV{$env}) . "\n";
        } else {
            $text .= colored(['bold white'], sprintf("%${MAX}s", $env)) . ' = ' . $ENV{$env} . "\n";
        }
    } ## end foreach my $env (sort(keys ...))
    return ($text);
} ## end sub sysop_showenv

sub sysop_scroll {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Scroll?']);
    print "Scroll?  ";
    if ($self->sysop_keypress(ECHO, BLOCKING) =~ /N/i) {
        $self->{'debug'}->DEBUG(['sysop_scroll end']);
        return (FALSE);
    }
    print "\r" . clline;
    return (TRUE);
} ## end sub sysop_scroll

sub sysop_list_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp List BBS']);
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view ORDER BY bbs_name');
    $sth->execute();
    my @listing;
    my ($id_size, $name_size, $hostname_size, $poster_size) = (2, 4, 14, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $id_size       = max(length('' . $row->{'bbs_id'}),  $id_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    } ## end while (my $row = $sth->fetchrow_hashref...)
    my $table = Text::SimpleTable->new($id_size, $name_size, $hostname_size, 5, $poster_size);
    $table->row('ID', 'NAME', 'HOSTNAME/PHONE', 'PORT', 'POSTER');
    $table->hr();
    foreach my $line (@listing) {
        $table->row($line->{'bbs_id'}, $line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
    }
    $self->output($self->sysop_color_border($table->boxes->draw(), 'BRIGHT BLUE', 'ROUNDED'));
    print 'Press a key to continue... ';
    $self->sysop_keypress();
} ## end sub sysop_list_bbs

sub sysop_edit_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Edit BBS']);
    my @choices = (qw( bbs_id bbs_name bbs_hostname bbs_port ));
    print $self->sysop_prompt('Please enter the ID, the hostname/phone, or the BBS name to edit');
    my $search;
    $search = $self->sysop_get_line(ECHO, 50, '');
    return (FALSE) if ($search eq '');
    print "\r", cldown, "\n";
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
    $sth->execute($search, $search, $search);

    if ($sth->rows() > 0) {
        my $bbs = $sth->fetchrow_hashref();
        $sth->finish();
        my $table = Text::SimpleTable->new(6, 12, 50);
        my $index = 1;
        $table->row('CHOICE', 'FIELD NAME', 'VALUE');
        $table->hr();
        foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port)) {
            if ($name =~ /bbs_id|bbs_poster/) {
                $table->row(' ', $name, $bbs->{$name});
            } else {
                $table->row($index, $name, $bbs->{$name});
                $index++;
            }
        } ## end foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port))
        $self->output($self->sysop_color_border($table->boxes->draw(), 'BRIGHT BLUE', 'ROUNDED'));
        print $self->sysop_prompt('Edit which field (Z=Nevermind)');
        my $choice;
        do {
            $choice = $self->sysop_keypress();
        } until ($choice =~ /[1-3]|Z/i);
        if ($choice =~ /\D/) {
            print "BACK\n";
            return (FALSE);
        }
        print "\n", $self->sysop_prompt($choices[$choice] . ' (' . $bbs->{ $choices[$choice] } . ') ');
        my $width = ($choices[$choice] eq 'bbs_port') ? 5 : 50;
        my $new   = $self->sysop_get_line(ECHO, $width, '');
        if ($new eq '') {
            $self->{'debug'}->DEBUG(['sysop_edit_bbs end']);
            return (FALSE);
        }
        $sth = $self->{'dbh'}->prepare('UPDATE bbs_listing SET ' . $choices[$choice] . '=? WHERE bbs_id=?');
        $sth->execute($new, $bbs->{'bbs_id'});
        $sth->finish();
    } else {
        $sth->finish();
    }
} ## end sub sysop_edit_bbs

sub sysop_add_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Add BBS']);
    my $table = Text::SimpleTable->new(14, 50);
    foreach my $name ('BBS NAME', 'HOSTNAME/PHONE', 'PORT') {
        my $count = ($name eq 'PORT') ? 5 : 50;
        $table->row($name, "\n" . charnames::string_vianame('OVERLINE') x $count);
        $table->hr() unless ($name eq 'PORT');
    }
    my @order = (qw(bbs_name bbs_hostname bbs_port));
    my $bbs   = {
        'bbs_name'     => '',
        'bbs_hostname' => '',
        'bbs_port'     => '',
    };
    my $index = 0;
    $self->output($self->sysop_color_border($table->boxes->draw(), 'BRIGHT BLUE', 'ROUNDED'));
    print $self->{'ansi_sequences'}->{'UP'} x 9, $self->{'ansi_sequences'}->{'RIGHT'} x 19;
    $bbs->{'bbs_name'} = $self->sysop_get_line(ECHO, 50, '');
    if ($bbs->{'bbs_name'} ne '' && length($bbs->{'bbs_name'}) > 3) {
        print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 19;
        $bbs->{'bbs_hostname'} = $self->sysop_get_line(ECHO, 50, '');
        if ($bbs->{'bbs_hostname'} ne '' && length($bbs->{'bbs_hostname'}) > 5) {
            print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 19;
            $bbs->{'bbs_port'} = $self->sysop_get_line(ECHO, 5, '');
            if ($bbs->{'bbs_port'} ne '' && $bbs->{'bbs_port'} =~ /^\d+$/) {
                my $sth = $self->{'dbh'}->prepare('INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (?,?,?,1)');
                $sth->execute($bbs->{'bbs_name'}, $bbs->{'bbs_hostname'}, $bbs->{'bbs_port'});
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
} ## end sub sysop_add_bbs

sub sysop_delete_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Delete BBS']);
    print $self->sysop_prompt('Please enter the ID, the hostname, or the BBS name to delete');
    my $search;
    $search = $self->sysop_get_line(ECHO, 50, '');
    if ($search eq '') {
        return (FALSE);
    }
    print "\r", cldown, "\n";
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view WHERE bbs_id=? OR bbs_name=? OR bbs_hostname=?');
    $sth->execute($search, $search, $search);

    if ($sth->rows() > 0) {
        my $bbs = $sth->fetchrow_hashref();
        $sth->finish();
        my $table = Text::SimpleTable->new(12, 50);
        $table->row('FIELD NAME', 'VALUE');
        $table->hr();
        foreach my $name (qw(bbs_id bbs_poster bbs_name bbs_hostname bbs_port)) {
            $table->row($name, $bbs->{$name});
        }
        $self->output($self->sysop_color_border($table->boxes->draw(), 'RED', 'ROUNDED'));
        print 'Are you sure that you want to delete this BBS from the list (Y|N)?  ';
        my $choice = $self->sysop_decision();
        unless ($choice) {
            return (FALSE);
        }
        $sth = $self->{'dbh'}->prepare('DELETE FROM bbs_listing WHERE bbs_id=?');
        $sth->execute($bbs->{'bbs_id'});
    } ## end if ($sth->rows() > 0)
    $sth->finish();
    return (TRUE);
} ## end sub sysop_delete_bbs

sub sysop_add_file {
    my $self = shift;

    opendir(my $DIR, 'files/files/');
    my @dir = grep(!/^\.+/, readdir($DIR));
    closedir($DIR);
    my $list;
    my $nw  = 0;
    my $sw  = 4;
    my $tw  = 0;
    my $sth = $self->{'dbh'}->prepare('SELECT id FROM files WHERE filename=?');
    my $search;
    my $root          = $self->configuration('BBS ROOT');
    my $files_path    = $self->configuration('FILES PATH');
    my $file_category = $self->{'USER'}->{'file_category'};

    foreach my $file (@dir) {
        $sth->execute($file);
        my $rows = $sth->rows();
        if ($rows <= 0) {
            $nw = max(length($file), $nw);
            my $raw_size = (-s "$root/$files_path/$file");
            my $size     = format_number($raw_size);
            $sw = max(length("$size"), $sw, 4);
            my ($ext, $type) = $self->files_type($file);
            $tw                          = max(length($type), $tw);
            $list->{$file}->{'raw_size'} = $raw_size;
            $list->{$file}->{'size'}     = $size;
            $list->{$file}->{'type'}     = $type;
            $list->{$file}->{'ext'}      = uc($ext);
        } ## end if ($rows <= 0)
    } ## end foreach my $file (@dir)
    $sth->finish();
    if (defined($list)) {
        my @names = grep(!/^README.md$/, (sort(keys %{$list})));
        if (scalar(@names)) {
            $self->{'debug'}->DEBUGMAX($list);
            my $table = Text::SimpleTable->new($nw, $sw, $tw);
            $table->row('FILE', 'SIZE', 'TYPE');
            $table->hr();
            foreach my $file (sort(keys %{$list})) {
                $table->row($file, $list->{$file}->{'size'}, $list->{$file}->{'type'});
            }
            my $text = $self->sysop_color_border($table->boxes->draw(),'GREEN', 'DOUBLE');
            $self->sysop_pager($text);
            while (scalar(@names)) {
                ($search) = shift(@names);
                $self->output('[% B_WHITE %][% BLACK %] Current Category [% RESET %] [% BRIGHT YELLOW %][% BLACK RIGHT-POINTING TRIANGLE %][% RESET %] [% BRIGHT WHITE %][% FILE CATEGORY %][% RESET %]' . "\n\n");
                print $self->sysop_prompt('Which file would you like to add?  ');
                $search = $self->sysop_get_line(ECHO, $nw, $search);
                my $filename = "$root/$files_path/$search";
                if (-e $filename) {
                    print $self->sysop_prompt('               What is the Title?');
                    my $title = $self->sysop_get_line(ECHO, 255, '');
                    if (defined($title) && $title ne '') {
                        print $self->sysop_prompt('                Add a description');
                        my $description = $self->sysop_get_line(ECHO, 65535, '');
                        if (defined(description) && $description ne '') {
                            my $head = "\n" . '[% REVERSE %]    Category [% RESET %] [% FILE CATEGORY %]' . "\n" . '[% REVERSE %]   File Name [% RESET %] ' . $search . "\n" . '[% REVERSE %]       Title [% RESET %] ' . $title . "\n" . '[% REVERSE %] Description [% RESET %] ' . $description . "\n\n" . $self->sysop_prompt('Is this correct?');
                            print $self->sysop_detokenize($head);
                            if ($self->sysop_decision()) {
                                $sth = $self->{'dbh'}->prepare('INSERT INTO files (filename, title, user_id, category, file_type, description, file_size) VALUES (?,?,1,?,(SELECT id FROM file_types WHERE extension=?),?,?)');
                                $sth->execute($search, $title, $self->{'USER'}->{'file_category'}, $list->{$search}->{'ext'}, $description, $list->{$search}->{'raw_size'});
                                if ($self->{'dbh'}->err) {
                                    $self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
                                }
                                $sth->finish();
                            } ## end if ($self->sysop_decision...)
                        } ## end if (defined(description...))
                    } ## end if (defined($title) &&...)
                } ## end if (-e $filename)
            } ## end while (scalar(@names))
        } else {
            $self->output("\n\n" . '[% BRIGHT RED %]NO FILES TO ADD![% RESET %]  ');
            sleep 2;
        }
    } else {
        print colored(['yellow'], 'No unmapped files found'), "\n";
        sleep 2;
    }
} ## end sub sysop_add_file
1;
