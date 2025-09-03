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
    };
    $self->{'debug'}->DEBUG(['ASCII Initialized']);
    return ($self);
} ## end sub ascii_initialize

sub ascii_output {
    my $self   = shift;
	my $text   = shift;
	my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
	my $lines  = $mlines;
	$self->{'debug'}->DEBUG(['Send ASCII text']);
	if (length($text) > 1) {
		foreach my $string (keys %{ $self->{'ascii_sequences'} }) {
			if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
				my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
				$text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
			} else {
				$text =~ s/\[\%\s+$string\s+\%\]/$self->{'ascii_sequences'}->{$string}/gi;
			}
		} ## end foreach my $string (keys %{...})
		foreach my $string (keys %{ $self->{'ascii_characters'} }) {
			$text =~ s/\[\%\s+$string\s+\%\]/$self->{'ascii_characters'}->{$string}/gi;
		}
	} ## end if (length($text) > 1)
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
			} ## end if ($char eq "\n")
			$self->send_char($char);
		} ## end foreach my $count (0 .. $s_len)
	}
	return (TRUE);
} ## end sub ascii_output
1;
