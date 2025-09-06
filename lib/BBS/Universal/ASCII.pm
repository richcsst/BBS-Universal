package BBS::Universal::ASCII;
BEGIN { our $VERSION = '0.002'; }

sub ascii_initialize {
    my $self = shift;

    $self->{'ascii_sequences'} = {
        'RETURN'    => chr(13),
        'LINEFEED'  => chr(10),
        'NEWLINE'   => chr(13) . chr(10),
		'BACKSPACE' => chr(8),
		'DELETE'    => chr(127),
        'CLS'       => chr(12), # Formfeed
        'CLEAR'     => chr(12),
		'RING BELL' => chr(7),

		# Color (ASCII doesn't have any, but we have placeholders
		'NORMAL' => '',

		# Foreground color
		'BLACK'          => '',
		'RED'            => '',
		'PINK'           => '',
		'ORANGE'         => '',
		'NAVY'           => '',
		'GREEN'          => '',
		'YELLOW'         => '',
		'BLUE'           => '',
		'MAGENTA'        => '',
		'CYAN'           => '',
		'WHITE'          => '',
		'DEFAULT'        => '',
		'BRIGHT BLACK'   => '',
		'BRIGHT RED'     => '',
		'BRIGHT GREEN'   => '',
		'BRIGHT YELLOW'  => '',
		'BRIGHT BLUE'    => '',
		'BRIGHT MAGENTA' => '',
		'BRIGHT CYAN'    => '',
		'BRIGHT WHITE'   => '',

		# Background color
		'B_BLACK'          => '',
		'B_RED'            => '',
		'B_GREEN'          => '',
		'B_YELLOW'         => '',
		'B_BLUE'           => '',
		'B_MAGENTA'        => '',
		'B_CYAN'           => '',
		'B_WHITE'          => '',
		'B_DEFAULT'        => '',
		'B_PINK'           => '',
		'B_ORANGE'         => '',
		'B_NAVY'           => '',
		'BRIGHT B_BLACK'   => '',
		'BRIGHT B_RED'     => '',
		'BRIGHT B_GREEN'   => '',
		'BRIGHT B_YELLOW'  => '',
		'BRIGHT B_BLUE'    => '',
		'BRIGHT B_MAGENTA' => '',
		'BRIGHT B_CYAN'    => '',
		'BRIGHT B_WHITE'   => '',
    };
    return ($self);
}

sub ascii_output {
    my $self   = shift;
	my $text   = shift;

	my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
	my $lines  = $mlines;
	if (length($text) > 1) {
		foreach my $string (keys %{ $self->{'ascii_sequences'} }) {
			if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
				my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
				$text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
			} else {
				$text =~ s/\[\%\s+$string\s+\%\]/$self->{'ascii_sequences'}->{$string}/gi;
			}
		}
		foreach my $string (keys %{ $self->{'ascii_characters'} }) {
			$text =~ s/\[\%\s+$string\s+\%\]/$self->{'ascii_characters'}->{$string}/gi;
		}
	}
	my $s_len = length($text);
	my $nl    = $self->{'ascii_sequences'}->{'NEWLINE'};
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
