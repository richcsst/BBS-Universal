package BBS::Universal::ANSI;
BEGIN { our $VERSION = '0.003'; }

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27);
    my $csi = $esc . '[';

    $self->{'ansi_prefix'}    = $csi;
    $self->{'ansi_sequences'} = {
        'SS2'       => $esc . 'N',
        'SS3'       => $esc . 'O',
        'CSI'       => $esc . '[',
        'OSC'       => $esc . ']',
        'SOS'       => $esc . 'X',
        'ST'        => $esc . "\\",
        'DCS'       => $esc . 'P',
        'RING BELL' => chr(7),
        'BACKSPACE' => chr(8),
        'RETURN'    => chr(13),
        'LINEFEED'  => chr(10),
        'NEWLINE'   => chr(13) . chr(10),

        'CLS'        => $csi . '2J' . $csi . 'H',
        'CLEAR'      => $csi . '2J',
        'CLEAR LINE' => $csi . '0K',
        'CLEAR DOWN' => $csi . '0J',
        'CLEAR UP'   => $csi . '1J',
        'HOME'       => $csi . 'H',

        # Cursor
        'UP'            => $csi . 'A',
        'DOWN'          => $csi . 'B',
        'RIGHT'         => $csi . 'C',
        'LEFT'          => $csi . 'D',
        'NEXT LINE'     => $csi . 'E',
        'PREVIOUS LINE' => $csi . 'F',
        'SAVE'          => $csi . 's',
        'RESTORE'       => $csi . 'u',
        'RESET'         => $csi . '0m',
        'CURSOR ON'     => $csi . '?25h',
        'CURSOR OFF'    => $csi . '?25l',
        'SCREEN 1'      => $csi . '?1049l',
        'SCREEN 2'      => $csi . '?1049h',

        # Attributes
        'BOLD'                    => $csi . '1m',
        'NORMAL'                  => $csi . '22m',
        'FAINT'                   => $csi . '2m',
        'ITALIC'                  => $csi . '3m',
        'UNDERLINE'               => $csi . '4m',
        'FRAMED'                  => $csi . '51m',
        'FRAMED OFF'              => $csi . '54m',
        'ENCIRCLE'                => $csi . '52m',
        'ENCIRCLE OFF'            => $csi . '54m',
        'OVERLINE'                => $csi . '53m',
        'OVERLINE OFF'            => $csi . '55m',
        'DEFAULT UNDERLINE COLOR' => $csi . '59m',
        'SUPERSCRIPT'             => $csi . '73m',
        'SUBSCRIPT'               => $csi . '74m',
        'SUPERSCRIPT OFF'         => $csi . '75m',
        'SUBSCRIPT OFF'           => $csi . '75m',
        'SLOW BLINK'              => $csi . '5m',
        'RAPID BLINK'             => $csi . '6m',
        'INVERT'                  => $csi . '7m',
        'REVERSE'                 => $csi . '7m',
        'HIDE'                    => $csi . '8m',
        'REVEAL'                  => $csi . '28m',
        'CROSSED OUT'             => $csi . '9m',
        'DEFAULT FONT'            => $csi . '10m',
        'PROPORTIONAL ON'         => $csi . '26m',
        'PROPORTIONAL OFF'        => $csi . '50m',

        # Color

        # Foreground color
        'DEFAULT'        => $csi . '39m',
        'BLACK'          => $csi . '30m',
        'RED'            => $csi . '31m',
        'PINK'           => $csi . '38;5;198m',
        'ORANGE'         => $csi . '38;5;202m',
        'NAVY'           => $csi . '38;5;17m',
        'GREEN'          => $csi . '32m',
        'YELLOW'         => $csi . '33m',
        'BLUE'           => $csi . '34m',
        'MAGENTA'        => $csi . '35m',
        'CYAN'           => $csi . '36m',
        'WHITE'          => $csi . '37m',
        'BRIGHT BLACK'   => $csi . '90m',
        'BRIGHT RED'     => $csi . '91m',
        'BRIGHT GREEN'   => $csi . '92m',
        'BRIGHT YELLOW'  => $csi . '93m',
        'BRIGHT BLUE'    => $csi . '94m',
        'BRIGHT MAGENTA' => $csi . '95m',
        'BRIGHT CYAN'    => $csi . '96m',
        'BRIGHT WHITE'   => $csi . '97m',

        # Background color
        'B_DEFAULT'        => $csi . '49m',
        'B_BLACK'          => $csi . '40m',
        'B_RED'            => $csi . '41m',
        'B_GREEN'          => $csi . '42m',
        'B_YELLOW'         => $csi . '43m',
        'B_BLUE'           => $csi . '44m',
        'B_MAGENTA'        => $csi . '45m',
        'B_CYAN'           => $csi . '46m',
        'B_WHITE'          => $csi . '47m',
        'B_DEFAULT'        => $csi . '49m',
        'B_PINK'           => $csi . '48;5;198m',
        'B_ORANGE'         => $csi . '48;5;202m',
        'B_NAVY'           => $csi . '48;5;17m',
        'BRIGHT B_BLACK'   => $csi . '100m',
        'BRIGHT B_RED'     => $csi . '101m',
        'BRIGHT B_GREEN'   => $csi . '102m',
        'BRIGHT B_YELLOW'  => $csi . '103m',
        'BRIGHT B_BLUE'    => $csi . '104m',
        'BRIGHT B_MAGENTA' => $csi . '105m',
        'BRIGHT B_CYAN'    => $csi . '106m',
        'BRIGHT B_WHITE'   => $csi . '107m',

        # MACROS
        'HORIZONTAL RULE ORANGE'         => '[% RETURN %][% B_ORANGE %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE PINK'           => '[% RETURN %][% B_PINK %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE RED'            => '[% RETURN %][% B_RED %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT RED'     => '[% RETURN %][% BRIGHT B_RED %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE GREEN'          => '[% RETURN %][% B_GREEN %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT GREEN'   => '[% RETURN %][% BRIGHT B_GREEN %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE YELLOW'         => '[% RETURN %][% B_YELLOW %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT YELLOW'  => '[% RETURN %][% BRIGHT B_YELLOW %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BLUE'           => '[% RETURN %][% B_BLUE %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT BLUE'    => '[% RETURN %][% BRIGHT B_BLUE %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE MAGENTA'        => '[% RETURN %][% B_MAGENTA %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT MAGENTA' => '[% RETURN %][% BRIGHT B_MAGENTA %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE CYAN'           => '[% RETURN %][% B_CYAN %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT CYAN'    => '[% RETURN %][% BRIGHT B_CYAN %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE WHITE'          => '[% RETURN %][% B_WHITE %][% CLEAR LINE %][% RESET %]',
        'HORIZONTAL RULE BRIGHT WHITE'   => '[% RETURN %][% BRIGHT B_WHITE %][% CLEAR LINE %][% RESET %]',
        @_,
    };

    # Generate symbols
    my $start  = 0x2010;
    my $finish = 0x2BFF;
    if (0) {
        foreach my $u ($start .. $finish) {
            my $name = charnames::viacode($u);
            next if ($name eq '');
            my $char = charnames::string_vianame($name);
            $char = '?' unless (defined($char));
            $self->{'ansi_characters'}->{$name} = $char;
        }
        $start  = 0x1F300;
        $finish = 0x1FBFF;
        foreach my $u ($start .. $finish) {
            my $name = charnames::viacode($u);
            next if ($name eq '');
            my $char = charnames::string_vianame($name);
            $char = '?' unless (defined($char));
            $self->{'ansi_characters'}->{$name} = $char;
        }
    }
    return ($self);
}

sub ansi_decode {
    my $self = shift;
    my $text = shift;

    if (length($text) > 1) {
        while ($text =~ /\[\%\s+LOCATE (\d+),(\d+)\s+\%\]/) {
            my ($r,$c) = ($1,$2);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "$r;$c" . 'H';
            $text =~ s/\[\%\s+LOCATE $r,$c\s+\%\]/$replace/g;
        }
        while ($text =~ /\[\%\s+SCROLL UP (\d+)\s+\%\]/) {
            my $s = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . $s . 'S';
            $text =~ s/\[\%\s+SCROLL UP $s\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+SCROLL DOWN (\d+)\s+\%\]/) {
            my $s = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . $s . 'T';
            $text =~ s/\[\%\s+SCROLL DOWN $s\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+RGB (\d+),(\d+),(\d+)\s+\%\]/) {
            my ($r,$g,$b) = ($1 & 255, $2 & 255, $3 & 255);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "38:2:$r:$g:$b" . 'm';
            $text =~ s/\[\%\s+RGB $r,$g,$b\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+B_RGB (\d+),(\d+),(\d+)\s+\%\]/) {
            my ($r,$g,$b) = ($1 & 255, $2 & 255, $3 & 255);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "48:2:$r:$g:$b" . 'm';
            $text =~ s/\[\%\s+B_RGB $r,$g,$b\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+(COLOR|COLOUR) (\d+)\s+\%\]/) {
            my $n = $1;
            my $c = $2 & 255;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "38:5:$c" . 'm';
            $text =~ s/\[\%\s+$n $c\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+(B_COLOR|B_COLOUR) (\d+)\s+\%\]/) {
            my $n = $1;
            my $c = $2 & 255;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "48:5:$c" . 'm';
            $text =~ s/\[\%\s+$n $c\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+GREY (\d+)\s+\%\]/) {
            my $g = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . '38:5:' . (232 + $g) . 'm';
            $text =~ s/\[\%\s+GREY $g\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+B_GREY (\d+)\s+\%\]/) {
            my $g = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . '48:5:' . (232 + $g) . 'm';
            $text =~ s/\[\%\s+B_GREY $g\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+BOX (.*?),(\d+),(\d+),(\d+),(\d+),(.*?)\s+\%\](.*?)\[\%\s+ENDBOX\s+\%\]/i) {
            my $replace = $self->box($1, $2, $3, $4, $5, $6, $7);
            $text =~ s/\[\%\s+BOX.*?\%\].*?\[\%\s+ENDBOX.*?\%\]/$replace/i;
        }

        while ($text =~ /\[\%\s+(.*?)\s+\%\]/ && (exists($self->{'ansi_sequences'}->{$1}) || defined(charnames::string_vianame($1)))) {
            my $string = $1;
            if (exists($self->{'ansi_sequences'}->{$string})) {
                if ($string =~ /CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                    my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                    $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
                } else {
                    $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_sequences'}->{$string}/gi;
                }
            } else {
                my $char = charnames::string_vianame($string);
                $char = '?' unless (defined($char));
                $text =~ s/\[\%\s+$string\s+\%\]/$char/gi;
            }
        }
    }
    return($text);
}

sub ansi_output {
    my $self   = shift;
    my $text   = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $text = $self->ansi_decode($text);
    my $s_len = length($text);
    my $nl    = $self->{'ansi_sequences'}->{'NEWLINE'};

	foreach my $count (0 .. $s_len) {
		my $char = substr($text, $count, 1);
		if ($char eq "\n") {
			if ($char eq "\n") {
				if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
					$char = $nl;
				}
				$lines--;
				if ($lines <= 0) {
					$lines = $mlines;
					last unless ($self->scroll($nl));
					next;
				}
			}
		}
		$self->send_char($char);
	}
    return (TRUE);
}
1;
