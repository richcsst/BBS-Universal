package BBS::Universal::ATASCII;
BEGIN { our $VERSION = '0.002'; }

sub atascii_initialize {
    my $self = shift;

    $self->{'atascii_sequences'} = {
        'HEART'                        => chr(0),
        'VERTICAL BAR MIDDLE RIGHT'    => chr(1),
		'VERTICAL BAR'                 => chr(2),
		'BOTTOM RIGHT'                 => chr(3),
		'VERTICAL BAR MIDDLE LEFT'     => chr(4),
		'TOP RIGHT'                    => chr(5),
		'FORWARD SLASH'                => chr(6),
		'RING BELL'                    => chr(253),
		'BACKSLASH'                    => chr(7),
		'TOP LEFT WEDGE'               => chr(8),
		'BOTTOM RIGHT BOX'             => chr(9),
		'TOP RIGHT WEDGE'              => chr(10),
        'LINEFEED'                     => chr(10),
		'TOP RIGHT BOX'                => chr(11),
		'TOP LEFT BOX'                 => chr(12),
        'RETURN'                       => chr(155),
        'NEWLINE'                      => chr(155),
		'OVERLINE BAR'                 => chr(13),
		'UNDERLINE BAR'                => chr(14),
		'BOTTOM LEFT BOX'              => chr(15),
		'CLUB'                         => chr(16),
		'TOP LEFT'                     => chr(17),
		'HORIZONATAL BAR'              => chr(18),
		'CROSS BAR'                    => chr(19),
		'CENTER DOT'                   => chr(20),
		'BOTTOM BOX'                   => chr(21),
		'BOTTOM VERTICAL BAR'          => chr(22),
		'HORIZONTAL BAR MIDDLE BOTTOM' => chr(23),
		'HORIZONTAL BAR MIDDLE TOP'    => chr(24),
		'VERTICAL BAR LEFT'            => chr(25),
		'BOTTOM LEFT'                  => chr(26),
        'ESC'                          => chr(27),
        'UP'                           => chr(28),
        'DOWN'                         => chr(29),
        'LEFT'                         => chr(30),
        'RIGHT'                        => chr(31),
		'SPADE'                        => chr(0x7B),
		'VERTICAL LINE'                => chr(0x7C),
		'BACK ARROW'                   => chr(0x7D),
        'CLEAR'                        => chr(125),
        'BACKSPACE'                    => chr(126),
		'LEFT TRIANGLE'                => chr(126),
        'TAB'                          => chr(127),
		'RIGHT TRIANGLE'               => chr(127),
		'DELETE LINE'                  => chr(156),
		'INSERT LINE'                  => chr(157),
		'CLEAR TAB STOP'               => chr(158),
		'SET TAB STOP'                 => chr(159),
		# Top bit inverts
        'DELETE LINE'                  => chr(156),
        'INSERT LINE'                  => chr(157),
        'BELL'                         => chr(253),
        'DELETE'                       => chr(254),
        'INSERT'                       => chr(255),
    };
    return ($self);
}

sub atascii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
            if ($string eq $self->{'atascii_sequences'}->{'CLEAR'} && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
            }
        }
    }
    my $s_len = length($text);
    my $nl    = $self->{'atascii_sequences'}->{'NEWLINE'};
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
