package BBS::Universal::PETSCII;
BEGIN { our $VERSION = '0.002'; }

sub petscii_initialize {
    my $self = shift;

    $self->{'petscii_sequences'} = {
        'RETURN'            => chr(13),
        'LINEFEED'          => chr(10),
        'NEWLINE'           => chr(13) . chr(10),
        'CLEAR'             => chr(hex('0x93')),
        'CLS'               => chr(hex('0x93')),
		'BACKSPACE'         => chr(20),
		'DELETE'            => chr(20),
        'WHITE'             => chr(5),
        'RESET'             => chr(5),
        'BLACK'             => chr(hex('0x90')),
        'RED'               => chr(hex('0x1C')),
        'GREEN'             => chr(hex('0x1E')),
        'BLUE'              => chr(hex('0x1F')),
        'DARK PURPLE'       => chr(hex('0x81')),
        'UNDERLINE ON'      => chr(2),
        'UNDERLINE OFF'     => chr(hex('0x82')),
        'BLINK ON'          => chr(hex('0x0F')),
        'BLINK OFF'         => chr(hex('0x8F')),
        'REVERSE ON'        => chr(hex('0x12')),
        'REVERSE OFF'       => chr(hex('0x92')),
        'BROWN'             => chr(hex('0x95')),
        'PINK'              => chr(hex('0x96')),
        'CYAN'              => chr(hex('0x97')),
        'LIGHT GREY'        => chr(hex('0x98')),
        'LIGHT GREEN'       => chr(hex('0x99')),
        'LIGHT BLUE'        => chr(hex('0x9A')),
        'GRAY'              => chr(hex('0x9B')),
        'PURPLE'            => chr(hex('0x9C')),
        'YELLOW'            => chr(hex('0x9E')),
        'CYAN'              => chr(hex('0x9F')),
        'UP'                => chr(hex('0x91')),
        'DOWN'              => chr(hex('0x11')),
        'LEFT'              => chr(hex('0x9D')),
        'RIGHT'             => chr(hex('0x1D')),
        'ESC'               => chr(hex('0x1B')),
        'LINE FEED'         => chr(hex('0x0A')),
        'TAB'               => chr(9),
        'RING BELL'         => chr(7),
        'DOTTED CENTER'     => chr(hex('0x7C')),
        'PIPE'              => chr(hex('0x7D')),
        'DOTTED RIGHT'      => chr(hex('0x7E')),
        'LEFT ANGLED BARS'  => chr(hex('0x7F')),
        'LEFT HALF'         => chr(hex('0xA1')),
        'BOTTOM HALF'       => chr(hex('0xA2')),
        'OVERLINE'          => chr(hex('0xA3')),
        'UNDERLINE'         => chr(hex('0xA4')),
        'VERTICAL LEFT'     => chr(hex('0x45')),
        'VERTICAL RIGHT'    => chr(hex('0xA6')),
        'DOTTED LEFT'       => chr(hex('0xA7')),
        'DOTED BOTTOM'      => chr(hex('0xA8')),
        'RIGHT ANGLED BARS' => chr(hex('0xA9')),
    };
    return ($self);
}

sub petscii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'petscii_sequences'} }) {    # Decode macros
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'petscii_sequences'}->{$string}/gi;
            }
        }
    }
    my $s_len = length($text);
    my $nl    = $self->{'petscii_sequences'}->{'NEWLINE'};
    if ($self->{'local_mode'} || $self->{'sysop'} || $self->{'USER'}->{'baud_rate'} eq 'FULL') {
		$text =~ s/\n/$nl/gs;
		if ($self->{'local_mode'} || $self->{'sysop'}) {
			print STDOUT $text;
		} else {
			my $handle = $self->{'cl_socket'};
			print $handle $text;
		}
		$|=1;
	} else {
		foreach my $count (0 .. $s_len) {
			my $char = substr($text, $count, 1);
			if ($char eq "\n") {
				if ($text !~ /$nl/ && !$self->{'local_mode'}) {    # translate only if the file doesn't have ASCII newlines
					$char = $nl;
				}
				$lines--;
				if ($lines <= 0) {
					$lines = $mlines;
					last unless ($self->scroll($nl));
				}
			}
			$self->send_char($char);
		}
    }
    return (TRUE);
}
1;
