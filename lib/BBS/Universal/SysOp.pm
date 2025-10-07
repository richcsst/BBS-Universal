package BBS::Universal::SysOp;
BEGIN { our $VERSION = '0.004'; }

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

        # Tokens
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

        'MIDDLE VERTICAL RULE BLACK'   => $self->sysop_locate_middle('B_BLACK'),
        'MIDDLE VERTICAL RULE RED'     => $self->sysop_locate_middle('B_RED'),
        'MIDDLE VERTICAL RULE GREEN'   => $self->sysop_locate_middle('B_GREEN'),
        'MIDDLE VERTICAL RULE YELLOW'  => $self->sysop_locate_middle('B_YELLOW'),
        'MIDDLE VERTICAL RULE BLUE'    => $self->sysop_locate_middle('B_BLUE'),
        'MIDDLE VERTICAL RULE MAGENTA' => $self->sysop_locate_middle('B_MAGENTA'),
        'MIDDLE VERTICAL RULE CYAN'    => $self->sysop_locate_middle('B_CYAN'),
        'MIDDLE VERTICAL RULE WHITE'   => $self->sysop_locate_middle('B_WHITE'),

        # Non-static
        'THREADS COUNT' => sub {
            my $self = shift;
            return ($self->{'CACHE'}->get('THREADS_RUNNING'));
        },
        'USERS COUNT' => sub {
            my $self = shift;
            return ($self->db_count_users());
        },
        'UPTIME' => sub {
            my $self = shift;
            my $uptime = `uptime -p`;
            chomp($uptime);
            return($uptime);
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
			return($self->sysop_view_configuration('string'));
		},
        'COMMANDS REFERENCE' => sub {
            my $self = shift;
            my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
            my @sys = (sort(keys %{$main::SYSOP_COMMANDS}));
            my @stkn = (sort(keys %{ $self->{'sysop_tokens'} }));
            my @usr = (sort(keys %{ $self->{'COMMANDS'} }));
            my @tkn = (sort(keys %{ $self->{'TOKENS'} }));
            my @anstkn = grep(!/RGB|COLOR|GREY|FONT|HORIZONTAL RULE/,(keys %{ $self->{'ansi_sequences'} }));
            push(@anstkn,'LOCATE row,column');
            push(@anstkn,'RGB 0,0,0 - RGB 255,255,255');
            push(@anstkn,'B_RGB 0,0,0 - B_RGB 255,255,255');
            push(@anstkn,'COLOR 0 - COLOR 231');
            push(@anstkn,'GREY 0 - GREY 23');
            push(@anstkn,'B_COLOR 0 - B_COLOR 231');
            push(@anstkn,'B_GREY 0 - B_GREY 23');
            push(@anstkn,'FONT 0 - FONT 9');
            push(@anstkn,'HORIZONTAL RULE [color]');
            @anstkn = sort(@anstkn);
            my @atatkn = map { "  $_" } (sort(keys %{ $self->{'atascii_sequences'} }));
            my @pettkn = map { "  $_" } (sort(keys %{ $self->{'petscii_sequences'} }));
            my @asctkn = (sort(keys %{ $self->{'ascii_sequences'} }));
            my $x   = 1;
            my $xt  = 1;
            my $y   = 1;
            my $z   = 1;
            my $ans = 1;
            my $ata = 1;
            my $pet = 1;
            my $asc = 12;
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
            my $table = Text::SimpleTable->new($x, $xt, $y, $z, $ans, $ata, $pet, $asc);
            $table->row('SYSOP MENU COMMANDS', 'SYSOP TOKENS', 'USER MENU COMMANDS', 'USER TOKENS', 'ANSI TOKENS', 'ATASCII TOKENS', 'PETSCII TOKENS','ASCII TOKENS');
            $table->hr();
            my ($sysop_names, $sysop_tokens, $user_names, $token_names, $ansi_tokens, $atascii_tokens, $petscii_tokens, $ascii_tokens);
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
            }
            my $text = $self->center($table->boxes->draw(), $wsize);
            $text =~ s/(SYSOP MENU COMMANDS|SYSOP TOKENS|USER MENU COMMANDS|USER TOKENS|ANSI TOKENS|ATASCII TOKENS|PETSCII TOKENS|ASCII TOKENS)/\[\% BRIGHT YELLOW \%\]$1\[\% RESET \%\]/g;
            $text =~ s/│   (BOTTOM HORIZONTAL BAR)/│ \[\% LOWER ONE QUARTER BLOCK \%\] $1/g;
            $text =~ s/│   (TOP HORIZONTAL BAR)/│ \[\% UPPER ONE QUARTER BLOCK \%\] $1/g;
            $text =~ s/│(\s+)(REVERSE|FAINT|INVERT|SLOW BLINK|RAPID BLINK|ITALIC|BRIGHT BLACK|NAVY|B_NAVY|BOLD|ORANGE|B_ORANGE|RED|GREEN|YELLOW|MAGENTA|CYAN|BLUE|PINK|BRIGHT RED|BRIGHT GREEN|BRIGHT YELLOW|BRIGHT MAGENTA|BRIGHT CYAN|BRIGHT BLUE|BRIGHT WHITE|B_RED|B_GREEN|B_YELLOW|B_MAGENTA|B_CYAN|B_BLUE|B_PINK|BRIGHT B_RED|BRIGHT B_GREEN|BRIGHT B_YELLOW|BRIGHT B_MAGENTA|BRIGHT B_CYAN|BRIGHT B_BLUE|BRIGHT B_WHITE|BRIGHT B_BLACK)/│$1\[\% $2 \%\]$2\[\% RESET \%\]/g;
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
            $text =~ s/│   (LEFT VERTICAL BAR)/│ \[\% LEFT ONE QUARTER BLOCK \%\] $1/g; # Why twice?  Ask Perl as one doesn't replace all
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
            $text =~ s/│(\s+)(OVERLINE)  /│$1\[\% OVERLINE \%\]$2\[\% RESET \%\]  /g;
            $text =~ s/│(\s+)(SUPERSCRIPT)  /│$1\[\% SUPERSCRIPT \%\]$2\[\% RESET \%\]  /g;
            $text =~ s/│(\s+)(SUBSCRIPT)  /│$1\[\% SUBSCRIPT \%\]$2\[\% RESET \%\]  /g;
            $text =~ s/│(\s+)(UNDERLINE)  /│$1\[\% UNDERLINE \%\]$2\[\% RESET \%\]  /g;
            return ($self->ansi_decode($text));
        },
    };

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
    $self->{'SYSOP HEADING WIDTHS'} = {
        'id'              => 2,
        'username'        => 16,
        'fullname'        => 20,
        'given'           => 12,
        'family'          => 12,
        'nickname'        => 12,
        'email'           => 20,
        'birthday'        => 10,
        'location'        => 20,
        'date_format'     => 14,
        'access_level'    => 11,
        'baud_rate'       => 4,
        'login_time'      => 10,
        'logout_time'     => 10,
        'text_mode'       => 9,
        'max_rows'        => 5,
        'max_columns'     => 5,
        'timeout'         => 5,
        'retro_systems'   => 20,
        'accomplishments' => 20,
        'prefer_nickname' => 2,
        'view_files'      => 2,
        'upload_files'    => 2,
        'download_files'  => 2,
        'remove_files'    => 2,
        'read_message'    => 2,
        'post_message'    => 2,
        'remove_message'  => 2,
        'play_fortunes'   => 2,
        'sysop'           => 2,
        'page_sysop'      => 2,
        'password'        => 64,
    };

    return ($self);
}

sub sysop_online_count {
    my $self = shift;

    my $count = $self->{'CACHE'}->get('ONLINE');
    $self->{'debug'}->DEBUG(["SysOp Online Count $count"]);
    return ($count);
}

sub sysop_versions_format {
    my $self     = shift;
    my $sections = shift;
    my $bbs_only = shift;

    $self->{'debug'}->DEBUG(['SysOp Versions Format']);
    my $versions = "\n\t";
    my $heading  = "\t";
    my $counter  = $sections;

    for (my $count = $sections - 1; $count > 0; $count--) {
        $heading .= ' NAME                         VERSION ';
        if ($count) {
            $heading .= "\t\t";
        } else {
            $heading .= "\n";
        }
    }
    $heading = colored(['bold bright_yellow on_red'], $heading);
    foreach my $v (keys %{ $self->{'VERSIONS'} }) {
        next if ($bbs_only && $v !~ /^BBS/);
        $versions .= "\t\t " . sprintf('%-28s %.03f',$v,$self->{'VERSIONS'}->{$v});
        $counter--;
        if ($counter <= 1) {
            $counter = $sections;
            $versions .= "\n\t";
        }
    }
    chop($versions) if (substr($versions, -1, 1) eq "\t");
    return ($heading . $versions . "\n");
}

sub sysop_disk_free {    # Show the Disk Free portion of Statistics
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Disk Free']);
    my $diskfree = '';
    if ((-e '/usr/bin/duf' || -e '/usr/local/bin/duf') && $self->configuration('USE DUF') eq 'TRUE') {
        my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
        $diskfree = "\n" . `duf -theme ansi -width $wsize`;
    } else {
        my @free     = split(/\n/, `nice df -h -T`);    # Get human readable disk free showing type
        my $width    = 1;
        foreach my $l (@free) {
            $width = max(length($l), $width);           # find the width of the widest line
        }
        foreach my $line (@free) {
            next if ($line =~ /tmp|boot/);
            if ($line =~ /^Filesystem/) {
                $diskfree .= "\t" . colored(['bold bright_yellow on_blue'], " $line " . ' ' x ($width - length($line))) . "\n";    # Make the heading the right width
            } else {
                $diskfree .= "\t\t\t $line\n";
            }
        }
    }
    return ($diskfree);
}

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
    }
    close($FILE);
    return ($mapping);
}

sub sysop_pager {
    my $self   = shift;
    my $text   = shift;
    my $offset = shift;

    $self->{'debug'}->DEBUG(['SysOp Pager']);
    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my @lines  = split(/\n/, $text);
    my $size   = ($hsize - ($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')));
    my $scroll = TRUE;
    my $row    = $size - $offset;
    foreach my $line (@lines) {
        if (length($line) > $wsize) {
            my $count = int(length($line) / $wsize) + 1;
            $row -= $count;
            if ($row < 0) {
                $scroll = $self->sysop_scroll();
                last unless ($scroll);
                $row = $size - $count;
            }
            $self->ansi_output("$line\n");
        } else {
            $self->ansi_output("$line\n");
            $row--;
        }
        if ($row <= 0) {
            $row    = $size;
            $scroll = $self->sysop_scroll();
            last unless ($scroll);
        }
    }
    return ($scroll);
}

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
}

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
}

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
}

sub sysop_ip_address {
    my $self = shift;

    chomp(my $ip = `nice hostname -I`);
    $self->{'debug'}->DEBUG(["SysOp IP Address:  $ip"]);
    return ($ip);
}

sub sysop_hostname {
    my $self = shift;

    chomp(my $hostname = `nice hostname`);
    $self->{'debug'}->DEBUG(["SysOp Hostname:  $hostname"]);
    return ($hostname);
}

sub sysop_locate_middle {
    my $self  = shift;
    my $color = (scalar(@_)) ? shift : 'B_WHITE';

    my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
    my $middle = int($wsize / 2);
    my $string = "\r" . $self->{'ansi_sequences'}->{'RIGHT'} x $middle . $self->{'ansi_sequences'}->{$color} . ' ' . $self->{'ansi_sequences'}->{'RESET'};
    return ($string);
}

sub sysop_memory {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Memory']);
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
}

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
}

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
        $sql = q{ SELECT * FROM users_view };
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
            }
        }
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
            }
        }
        $sth->finish();
        my $string = $table->boxes->draw();
        my $ch = colored(['bright_yellow'],'NAME');
        $string =~ s/ NAME / $ch /;
        $ch = colored(['bright_yellow'],'VALUE');
        $string =~ s/ VALUE / $ch /;
        $self->sysop_pager("$string\n");
    } else {    # Horizontal
        my @hw;
        foreach my $name (@order) {
            push(@hw, $self->{'SYSOP HEADING WIDTHS'}->{$name});
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
        }
        $table->hr();
        while (my $row = $sth->fetchrow_hashref()) {
            my @vals = ();
            foreach my $name (@order) {
                push(@vals, $row->{$name} . '');
                $self->{'debug'}->DEBUGMAX([$name, $row->{$name}]);
            }
            $table->row(@vals);
        }
        $sth->finish();
        my $string = $table->boxes->draw();
        $self->sysop_pager("$string\n");
    }
    print 'Press a key to continue ... ';
    return ($self->sysop_keypress(TRUE));
}

sub sysop_delete_files {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Delete Files']);
    return (TRUE);
}

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
        }
    }
    $sth->finish();
    my $table;
    if ($wsize > 150) {
        $table = Text::SimpleTable->new(max(5,$sizes->{'title'}), max(8, $sizes->{'filename'}), max(4, $sizes->{'type'}), max(11, $sizes->{'description'}), max(8, $sizes->{'username'}), max(4, $sizes->{'file_size'}), max(8, $sizes->{'uploaded'}));
        $table->row('TITLE', 'FILENAME', 'TYPE', 'DESCRIPTION', 'UPLOADER', 'SIZE', 'UPLOADED');
    } else {
        $table = Text::SimpleTable->new(max(5, $sizes->{'filename'}), max(8, $sizes->{'title'}), max(4, $sizes->{'extension'}), max(11, $sizes->{'description'}), max(8, $sizes->{'username'}), max(4, $sizes->{'file_size'}));
        $table->row( 'TITLE', 'FILENAME', 'TYPE', 'DESCRIPTION', 'UPLOADER', 'SIZE');
    }
    $table->hr();
    $sth = $self->{'dbh'}->prepare('SELECT * FROM files_view');
    $sth->execute();
    my $category;

    while (my $row = $sth->fetchrow_hashref()) {
        if ($wsize > 150) {
            $table->row($row->{'title'}, $row->{'filename'}, $row->{'type'}, $row->{'description'}, $row->{'username'}, format_number($row->{'file_size'}), $row->{'uploaded'});
        } else {
            $table->row($row->{'title'}, $row->{'filename'}, $row->{'extension'}, $row->{'description'}, $row->{'username'}, format_number($row->{'file_size'}));
        }
        $category = $row->{'category'};
    }
    $sth->finish();
    print "\nCATEGORY:  ", $category, "\n", $table->boxes->draw(), "\n", 'Press a Key To Continue ...';
    $self->sysop_keypress();
    print " BACK\n";
    return (TRUE);
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
    print $table->boxes->draw(), "\n", $self->sysop_prompt('Choose ID (< = Nevermind)');
    my $line;
    do {
        $line = uc($self->sysop_get_line(ECHO,3,''));
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
}
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
    print $table->boxes->draw(), "\n", $self->sysop_prompt('Choose ID (A = Add, < = Nevermind)');
    my $line;
    do {
        $line = uc($self->sysop_get_line(ECHO,3,''));
    } until ($line =~ /^(\d+|A|\<)/i);
    if ($line eq 'A') {    # Add
        print "\nADD NEW FILE CATEGORY\n";
        $table = Text::SimpleTable->new(11, 80);
        $table->row('TITLE',       "\n" . charnames::string_vianame('OVERLINE') x 80);
        $table->row('DESCRIPTION', "\n" . charnames::string_vianame('OVERLINE') x 80);
        print "\n",                                  $table->boxes->draw();
        print $self->{'ansi_sequences'}->{'UP'} x 5, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
        my $title = $self->sysop_get_line(ECHO,80,'');
        if ($title ne '') {
            print "\r", $self->{'ansi_sequences'}->{'DOWN'}, $self->{'ansi_sequences'}->{'RIGHT'} x 16;
            my $description = $self->sysop_get_line(ECHO,80,'');
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
}

sub sysop_vertical_heading {
    my $self = shift;
    my $text = shift;

    my $heading = '';
    for (my $count = 0; $count < length($text); $count++) {
        $heading .= substr($text, $count, 1) . "\n";
    }
    return ($heading);
}

sub sysop_view_configuration {
    my $self = shift;
    my $view = shift;

    $self->{'debug'}->DEBUG(['SysOp View Configuration']);
    # Get maximum widths
    my $name_width  = 6;
    my $value_width = 45;
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
    }

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
    }
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
            $c .= ' bps - 300,1200,2400,4800,9600,19200,FULL';
        } elsif ($conf eq 'THREAD MULTIPLIER') {
            $c .= ' x CPU Cores';
        } elsif ($conf eq 'DEFAULT TEXT MODE') {
            $c .= ' - ANSI,ASCII,ATASCII,PETSCII';
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
        }
    }
    my $output = $table->boxes->draw();
    foreach my $change ('AUTHOR EMAIL', 'AUTHOR LOCATION', 'AUTHOR NAME', 'DATABASE USERNAME', 'DATABASE NAME', 'DATABASE PORT', 'DATABASE TYPE', 'DATBASE USERNAME', 'DATABASE HOSTNAME', '300,1200,2400,4800,9600,19200,FULL', '%d = day, %m = Month, %Y = Year', 'ANSI,ASCII,ATASCII,PETSCII', 'ANS,ASC,ATA,PET') {
        if ($output =~ /$change/) {
            my $ch = ($change =~ /^(AUTHOR|DATABASE)/) ? colored(['yellow'], $change) : colored(['grey11'], $change);
            $output =~ s/$change/$ch/gs;
        }
    }
    {
        my $ch = colored(['cyan'], 'CHOICE');
        $output =~ s/CHOICE/$ch/gs;
        $ch = colored(['bright_yellow'], 'STATIC NAME');
        $output =~ s/STATIC NAME/$ch/gs;
        $ch = colored(['green'], 'CONFIG NAME');
        $output =~ s/CONFIG NAME/$ch/gs;
        $ch = colored(['cyan'], 'CONFIG VALUE');
        $output =~ s/CONFIG VALUE/$ch/gs;
    }
	if ("$view" eq 'string') {
		return($output);
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
    }
}

sub sysop_edit_configuration {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Edit Configuration']);
    $self->sysop_view_configuration(FALSE);
	my $types = {
		'BBS NAME'            => {
			'max'  => 50,
			'type' => STRING,
		},
		'BBS ROOT'            => {
			'max'  => 60,
			'type' => STRING,
		},
        'HOST'                => {
			'max'  => 20,
			'type' => HOST,
		},
        'THREAD MULTIPLIER'   => {
			'max'  => 2,
			'type' => NUMERIC,
		},
        'PORT'                => {
			'max'  => 5,
			'type' => NUMERIC,
		},
        'DEFAULT BAUD RATE'   => {
			'max'     => 5,
			'type'    => RADIO,
			'choices' => ['300', '1200', '2400', '4800', '9600', '19200', 'FULL'],
		},
        'DEFAULT TEXT MODE'   => {
			'max'     => 7,
			'type'    => RADIO,
			'choices' => ['ANSI', 'ASCII', 'ATASCII', 'PETSCII'],
		},
        'DEFAULT TIMEOUT'     => {
			'max'  => 3,
			'type' => NUMERIC,
		},
        'FILES PATH'          => {
			'max'  => 60,
			'type' => STRING,
		},
        'LOGIN TRIES'         => {
			'max'  => 1,
			'type' => NUMERIC,
		},
        'MEMCACHED HOST'      => {
			'max'  => 20,
			'type' => HOST,
		},
        'MEMCACHED NAMESPACE' => {
			'max'  => 32,
			'type' => STRING,
		},
        'MEMCACHED PORT'      => {
			'max'  => 5,
			'type' => NUMERIC,
		},
        'DATE FORMAT'         => {
			'max'     => 14,
			'type'    => RADIO,
			'choices' => [
				'MONTH/DAY/YEAR',
				'DAY/MONTH/YEAR',
				'YEAR/MONTH/DAY',
			],
		},
		'USE DUF'             => {
			'max'     => 5,
			'type'    => RADIO,
			'choices' => ['TRUE', 'FALSE'],
		},
		'PLAY SYSOP SOUNDS'   => {
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
	if ($types->{$conf[$choice]}->{'type'} == RADIO) {
		print '(Edit) ', $conf[$choice], ' (' . join(' ',@{$types->{$conf[$choice]}->{'choices'}}) . ') ', charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE'), '  ';
	} else {
		print '(Edit) ', $conf[$choice], ' ', charnames::string_vianame('BLACK RIGHT-POINTING TRIANGLE'), '  ';
	}
    my $string;
	$self->{'debug'}->DEBUGMAX([$self->configuration()]);
	$string = $self->sysop_get_line(
		$types->{$conf[$choice]},
		$self->configuration($conf[$choice])
	);
    return(FALSE) if ($string eq '');
    $self->configuration($conf[$choice], $string);
    return(TRUE);
}

sub sysop_get_key {
    my $self     = shift;
	my $echo     = shift;
	my $blocking = shift;

	my $key = undef;
	my $mode = $self->{'USER'}->{'text_mode'};
	my $timeout = $self->{'USER'}->{'timeout'} * 60;
	local $/ = "\x{00}";
	ReadMode 'ultra-raw';
	$key = ($blocking) ? ReadKey($timeout) : ReadKey(-1);
	ReadMode 'restore';
	threads->yield;
	return($key) if ($key eq chr(13));
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
}

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
			$line  = shift;
		}
		$echo = $type->{'type'};
	} else {
		if ($echo == STRING || $echo == ECHO || $echo == NUMERIC || $echo == HOST) {
			$limit = shift;
		}
		$line  = shift;
	}

	$self->{'debug'}->DEBUGMAX([$type,$echo,$line]);
	$self->output($line) if ($line ne '');
	my $mode = 'ANSI';
	my $bs = $self->{'ansi_sequences'}->{'BACKSPACE'};
	if ($echo == RADIO) {
        my $regexp = join('',@{$type->{'choices'}});
		$self->{'debug'}->DEBUGMAX([$regexp]);
		while ($key ne chr(13) && $key ne chr(3)) {
		    if (length($line) <= $limit) {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				return('') if (defined($key) && $key eq chr(3));
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
				}
			} else {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				if (defined($key) && $key eq chr(3)) {
					return('');
				}
				if (defined($key) && ($key eq $bs)) {
					$key = $bs;
					$self->output("$key $key");
					chop($line);
				} else {
					$self->output('[% RING BELL %]');
				}
			}
		}
	} elsif ($echo == NUMERIC) {
		while ($key ne chr(13) && $key ne chr(3)) {
			if (length($line) <= $limit) {
				$key = $self->sysop_get_key(NUMERIC, BLOCKING);
				return('') if (defined($key) && $key eq chr(3));
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
				}
			} else {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				if (defined($key) && $key eq chr(3)) {
					return('');
				}
				if (defined($key) && ($key eq $bs || $key eq chr(127))) {
					$key = $bs;
					$self->output("$key $key");
					chop($line);
				} else {
					$self->output('[% RING BELL %]');
				}
			}
		}
	} elsif ($echo == HOST) {
		while ($key ne chr(13) && $key ne chr(3)) {
			if (length($line) <= $limit) {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				return('') if (defined($key) && $key eq chr(3));
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
				}
			} else {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				if (defined($key) && $key eq chr(3)) {
					return('');
				}
				if (defined($key) && ($key eq $bs || $key eq chr(127))) {
					$key = $bs;
					$self->output("$key $key");
					chop($line);
				} else {
					$self->output('[% RING BELL %]');
				}
			}
		}
	} else {
		while ($key ne chr(13) && $key ne chr(3)) {
			if (length($line) <= $limit) {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				return('') if (defined($key) && $key eq chr(3));
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
				}
			} else {
				$key = $self->sysop_get_key(SILENT, BLOCKING);
				if (defined($key) && $key eq chr(3)) {
					return('');
				}
				if (defined($key) && ($key eq $bs)) {
					$key = $bs;
					$self->output("$key $key");
					chop($line);
				} else {
					$self->output('[% RING BELL %]');
				}
			}
		}
	}
	threads->yield();
	$line = '' if ($key eq chr(3));
	print "\n";
	$self->{'CACHE'}->set('SHOW_STATUS', TRUE);
	return($line);
}

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
    my $search = $self->sysop_get_line(ECHO,20,'');
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
        }
        if ($self->sysop_pager($table->boxes->draw())) {
            print "Are you sure that you want to delete this user (Y|N)?  ";
            my $answer = $self->sysop_decision();
            if ($answer) {
                print "\n\nDeleting ", $user_row->{'username'}, " ... ";
                $sth = $self->users_delete($user_row->{'id'});
            }
        }
    }
}

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
    my $search = $self->sysop_get_line(ECHO,20,'');
    return (FALSE) if ($search eq '');
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM users_view WHERE id=? OR username=?');
    $sth->execute($search, $search);
    my $user_row = $sth->fetchrow_hashref();
    $sth->finish();

    if (defined($user_row)) {
        my ($wsize, $hsize, $wpixels, $hpixels) = GetTerminalSize();
        my $valsize = 1;
        foreach my $fld (keys %{ $user_row }) {
            $valsize = max($valsize,length($user_row->{$fld}));
        }
        $valsize = min($valsize,$wsize - 29);
        my $table = Text::SimpleTable->new(6, 16, $valsize);
        $table->row('CHOICE', 'FIELD', 'VALUE');
        $table->hr();
        my $count = 0;
        my %choice;
        foreach my $field (@{ $self->{'SYSOP ORDER DETAILED'} }) {
            if ($field =~ /_time|fullname|_category|id/) {
                $table->row(' ', $field, $user_row->{$field} . '');
            } else {
                if ($field ne 'id' && $user_row->{$field} =~ /^(0|1)$/) {
                    $user_row->{$field} = $self->sysop_true_false($user_row->{$field}, 'YN');
                } elsif ($field eq 'timeout') {
                    $user_row->{$field} = $user_row->{$field} . ' Minutes';
                }
                $count++ if ($key_exit eq $choices[$count]);
                $table->row($choices[$count], $field, $user_row->{$field} . '');
                $choice{ $choices[$count] } = $field;
                $count++;
            }
        }
        print $table->boxes->draw(), "\n";
        $self->sysop_show_choices($mapping);
        print "\n", $self->sysop_prompt('Choose');
        do {
            $key = uc($self->sysop_keypress());
        } until ('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ' =~ /$key/i);
        if ($key !~ /$key_exit/i) {
            print 'Edit > (', $choice{$key}, ' = ', $user_row->{ $choice{$key} }, ') > ';
            my $new = $self->sysop_get_line(ECHO,1 + $self->{'SYSOP HEADING WIDTHS'}->{ $choice{$key} }, $choice{$key});
            unless ($new eq '') {
                $new =~ s/^(Yes|On)$/1/i;
                $new =~ s/^(No|Off)$/0/i;
            }
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
    } elsif ($search ne '') {
        print "User not found!\n\n";
    }
    return (TRUE);
}

sub sysop_user_add {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    $self->{'debug'}->DEBUG(['SysOp User Add']);
    my $flags_default = $self->{'flags_default'};
    my $mapping = $self->sysop_load_menu($row, $file);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $table = Text::SimpleTable->new(15, 64);
    my $user_template;
    push(@{ $self->{'SYSOP ORDER DETAILED'} }, 'password');

    foreach my $name (@{ $self->{'SYSOP ORDER DETAILED'} }) {
        next if ($name =~ /id|fullname|_time|max_|_category/);
        if ($name eq 'timeout') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Minutes\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name eq 'baud_rate') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (300,1200,2400,4800,9600,FULL)\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /username|given|family|password/) {
            if ($name eq 'given') {
                $table->row("$name (first)", ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            } elsif ($name eq 'family') {
                $table->row("$name (last)", ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            } else {
                $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " Cannot be empty\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
            }
        } elsif ($name eq 'text_mode') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (ASCII,ATASCII,PETSCII,ANSI)\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name eq 'birthday') {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " YEAR-MM-DD\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/) {
            $table->row($name, ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}) . " (Yes/No or On/Off or 1/0)\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        } elsif ($name =~ /location|retro_systems|accomplishments/) {
            $table->row($name, "\n" . charnames::string_vianame('OVERLINE') x ($self->{'SYSOP HEADING WIDTHS'}->{$name} * 4));
        } else {
            $table->row($name, "\n" . charnames::string_vianame('OVERLINE') x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}));
        }
        $user_template->{$name} = undef;
    }
    print $table->boxes->draw();
    $self->sysop_show_choices($mapping);
    my $column     = 21;
    my $adjustment = 7;
    foreach my $entry (@{ $self->{'SYSOP ORDER DETAILED'} }) {
        next if ($entry =~ /id|fullname|_time/);
        do {
            print locate($row + $adjustment, $column), ' ' x max(3, $self->{'SYSOP HEADING WIDTHS'}->{$entry}), locate($row + $adjustment, $column);
            chomp($user_template->{$entry} = <STDIN>);
            return ('BACK') if ($user_template->{$entry} eq '<');
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
                        substr($user_template->{$entry}, 0, 1) = uc(substr($user_template->{$entry}, 0, 1));
                    }
                }
                print locate($row + $adjustment, $column), $user_template->{$entry};
            } elsif ($entry =~ /prefer_|_files|_message|sysop/) {
                $user_template->{$entry} = ucfirst($user_template->{$entry});
                print locate($row + $adjustment, $column), $user_template->{$entry};
            }
        } until ($self->sysop_validate_fields($entry, $user_template->{$entry}, $row + $adjustment, $column));
        if ($user_template->{$entry} =~ /^(yes|on|true)$/i) {
            $user_template->{$entry} = TRUE;
        } elsif ($user_template->{$entry} =~ /^(no|off|false)$/i) {
            $user_template->{$entry} = FALSE;
        }
        $adjustment += 2;
    }
    pop(@{ $self->{'SYSOP ORDER DETAILED'} });
    if ($self->users_add($user_template)) {
        print "\n\n", colored(['green'], 'SUCCESS'), "\n";
        $self->{'debug'}->DEBUG(['sysop_user_add end']);
        return (TRUE);
    }
    return (FALSE);
}

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
}

sub sysop_validate_fields {
    my $self   = shift;
    my $name   = shift;
    my $val    = shift;
    my $row    = shift;
    my $column = shift;

    if ($name =~ /(username|given|family|baud_rate|timeout|_files|_message|sysop|prefer|password)/ && $val eq '') {    # cannot be empty
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Cannot Be Empty'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'baud_rate' && $val !~ /^(300|1200|2400|4800|9600|FULL)$/i) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only 300,1200,2400,4800,9600,FULL'), locate($row, $column);
        return (FALSE);
    } elsif ($name =~ /max_/ && $val =~ /\D/i) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only Numeric Values'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'timeout' && $val =~ /\D/) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Must be numeric'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'text_mode' && $val !~ /^(ASCII|ATASCII|PETSCII|ANSI)$/) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only ASCII,ATASCII,PETSCII,ANSI'), locate($row, $column);
        return (FALSE);
    } elsif ($name =~ /(prefer_nickname|_files|_message|sysop)/ && $val !~ /^(yes|no|true|false|on|off|0|1)$/i) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' Only Yes/No or On/Off or 1/0'), locate($row, $column);
        return (FALSE);
    } elsif ($name eq 'birthday' && $val ne '' && $val !~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
        print locate($row, ($column + max(3, $self->{'SYSOP HEADING WIDTHS'}->{$name}))), colored(['red'], ' YEAR-MM-DD'), locate($row, $column);
        $self->{'debug'}->DEBUG(['sysop_validate_fields end']);
        return (FALSE);
    }
    return (TRUE);
}

sub sysop_prompt {
    my $self     = shift;
    my $text     = shift;

    my $response = '[% B_MAGENTA %][% BLACK %] SYSOP TOOL [% RESET %] ' . $text . ' [% PINK %]' . charnames::string_vianame('BLACK RIGHTWARDS ARROWHEAD') . '[% RESET %] ';
    return ($self->sysop_detokenize($response));
}

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
    }

    $text = $self->ansi_decode($text);

    return ($text);
}

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
}

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
            my @in     = split(/\n/, $ENV{$env});
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
            }
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
    }
    return ($text);
}

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
}

sub sysop_list_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp List BBS']);
    my $sth = $self->{'dbh'}->prepare('SELECT * FROM bbs_listing_view');
    $sth->execute();
    my @listing;
    my ($id_size, $name_size, $hostname_size, $poster_size) = (1, 1, 1, 6);
    while (my $row = $sth->fetchrow_hashref()) {
        push(@listing, $row);
        $name_size     = max(length($row->{'bbs_name'}),     $name_size);
        $hostname_size = max(length($row->{'bbs_hostname'}), $hostname_size);
        $id_size       = max(length('' . $row->{'bbs_id'}),  $id_size);
        $poster_size   = max(length($row->{'bbs_poster'}),   $poster_size);
    }
    my $table = Text::SimpleTable->new($id_size, $name_size, $hostname_size, 5, $poster_size);
    $table->row('ID', 'NAME', 'HOSTNAME', 'PORT', 'POSTER');
    $table->hr();
    foreach my $line (@listing) {
        $table->row($line->{'bbs_id'}, $line->{'bbs_name'}, $line->{'bbs_hostname'}, $line->{'bbs_port'}, $line->{'bbs_poster'});
    }
    print $table->boxes->draw();
    print 'Press a key to continue... ';
    $self->sysop_keypress();
}

sub sysop_edit_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Edit BBS']);
    my @choices = (qw( bbs_id bbs_name bbs_hostname bbs_port ));
    print $self->prompt('Please enter the ID, the hostname, or the BBS name to edit');
    my $search;
    $search = $self->sysop_get_line(ECHO,50,'');
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
        }
        print $table->boxes->draw();
        print $self->prompt('Edit which field (Z=Nevermind)');
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
        my $new   = $self->sysop_get_line(ECHO,$width,'');
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
}

sub sysop_add_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Add BBS']);
    my $table = Text::SimpleTable->new(12, 50);
    foreach my $name (qw(bbs_name bbs_hostname bbs_port)) {
        my $count = ($name eq 'bbs_port') ? 5 : 50;
        $table->row($name, "\n" . charnames::string_vianame('OVERLINE') x $count);
        $table->hr() unless ($name eq 'bbs_port');
    }
    my @order = (qw(bbs_name bbs_hostname bbs_port));
    my $bbs   = {
        'bbs_name'     => '',
        'bbs_hostname' => '',
        'bbs_port'     => '',
    };
    my $index = 0;
    print $table->boxes->draw();
    print $self->{'ansi_sequences'}->{'UP'} x 9, $self->{'ansi_sequences'}->{'RIGHT'} x 17;
    $bbs->{'bbs_name'} = $self->sysop_get_line(ECHO,50,'');
    if ($bbs->{'bbs_name'} ne '' && length($bbs->{'bbs_name'}) > 3) {
        print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 17;
        $bbs->{'bbs_hostname'} = $self->sysop_get_line(ECHO,50,'');
        if ($bbs->{'bbs_hostname'} ne '' && length($bbs->{'bbs_hostname'}) > 5) {
            print $self->{'ansi_sequences'}->{'DOWN'} x 2, "\r", $self->{'ansi_sequences'}->{'RIGHT'} x 17;
            $bbs->{'bbs_port'} = $self->sysop_get_line(ECHO,5,'');
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
}

sub sysop_delete_bbs {
    my $self = shift;

    $self->{'debug'}->DEBUG(['SysOp Delete BBS']);
    print $self->prompt('Please enter the ID, the hostname, or the BBS name to delete');
    my $search;
    $search = $self->sysop_get_line(ECHO,50,'');
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
        print $table->boxes->draw();
        print 'Are you sure that you want to delete this BBS from the list (Y|N)?  ';
        my $choice = $self->sysop_decision();
        unless ($choice) {
            return (FALSE);
        }
        $sth = $self->{'dbh'}->prepare('DELETE FROM bbs_listing WHERE bbs_id=?');
        $sth->execute($bbs->{'bbs_id'});
    }
    $sth->finish();
    return (TRUE);
}

sub sysop_add_file {
    my $self = shift;

    opendir(my $DIR,'files/files/');
    my @dir = grep(!/^\.+/,readdir($DIR));
    closedir($DIR);
    my $list;
    my $nw = 0;
    my $sw = 0;
    my $tw = 0;
    my $sth = $self->{'dbh'}->prepare('SELECT id FROM files WHERE filename=?');
	my $search;
	my $root = $self->configuration('BBS ROOT');
	my $files_path = $self->configuration('FILES PATH');
	my $file_category = $self->{'USER'}->{'file_category'};
    foreach my $file (@dir) {
        $sth->execute($file);
		my $rows = $sth->rows();
        if ($rows <= 0) {
            $nw = max(length($file),$nw);
            my $raw_size = (-s "$root/$files_path/$file");
            my $size = format_number($raw_size);
            $sw = max(length("$size"),$sw);
            my ($ext,$type) = $self->files_type($file);
            $tw = max(length($type),$tw);
			$list->{$file}->{'raw_size'} = $raw_size;
            $list->{$file}->{'size'}     = $size;
            $list->{$file}->{'type'}     = $type;
			$list->{$file}->{'ext'}      = uc($ext);
        }
    }
    $sth->finish();
    if (defined($list)) {
		my @names = (sort(keys %{$list}));
        $self->{'debug'}->DEBUGMAX($list);
        my $table = Text::SimpleTable->new($nw, $sw, $tw);
        $table->row('FILE','SIZE','TYPE');
        $table->hr();
        foreach my $file (sort(keys %{$list})) {
            $table->row($file, $list->{$file}->{'size'}, $list->{$file}->{'type'});
        }
        my $text = $table->boxes->draw();
        $self->sysop_pager($text);
		while(scalar(@names)) {
			($search) = shift(@names);
			print $self->sysop_prompt('Which file would you like to add?');
			$search = $self->sysop_get_line(ECHO, $nw, $search);
			my $filename = "$root/$files_path/$search";
			if (-e $filename) {
				print $self->sysop_prompt('               What is the Title?');
				my $title       = $self->sysop_get_line(ECHO, 255, '');

				if (defined($title) && $title ne '') {
					print $self->sysop_prompt('                Add a description');
					my $description = $self->sysop_get_line(ECHO, 65535, '');

					if (defined(description) && $description ne '') {
						my $head = "\n" .
						  '[% REVERSE %]    Category [% RESET %] [% FILE CATEGORY %]' . "\n" .
						  '[% REVERSE %]   File Name [% RESET %] ' . $search . "\n" .
						  '[% REVERSE %]       Title [% RESET %] ' . $title . "\n" .
						  '[% REVERSE %] Description [% RESET %] ' . $description . "\n\n" .
						  $self->sysop_prompt('Is this correct?');
						print $self->sysop_detokenize($head);
						if ($self->sysop_decision()) {
							$sth = $self->{'dbh'}->prepare('INSERT INTO files (filename, title, user_id, category, file_type, description, file_size) VALUES (?,?,1,?,(SELECT id FROM file_types WHERE extension=?),?,?)');
							$sth->execute($search, $title, $self->{'USER'}->{'file_category'}, $list->{$search}->{'ext'}, $description, $list->{$search}->{'raw_size'});
							if ($self->{'dbh'}->err) {
								$self->{'debug'}->ERROR([$self->{'dbh'}->errstr]);
							}
							$sth->finish();
						}
					}
				}
			}
		}
    } else {
        print colored(['yellow'],'No unmapped files found'),"\n";
        sleep 2;
    }
}
1;
