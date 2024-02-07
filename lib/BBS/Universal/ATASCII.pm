package BBS::Universal::ATASCII;
BEGIN { our $VERSION = '0.001'; }

sub atascii_initialize {
    my $self = shift;

    $self->{'atascii_sequences'} = {
        'HEART' => chr(0),
        '0x01'  => chr(1),

        'RETURN'      => chr(13),
        'LINEFEED'    => chr(10),
        'NEWLINE'     => chr(13) . chr(10),
        'ESC'         => chr(27),
        'UP'          => chr(28),
        'DOWN'        => chr(29),
        'LEFT'        => chr(30),
        'RIGHT'       => chr(31),
        'CLEAR'       => chr(125),
        'BACKSPACE'   => chr(126),
        'TAB'         => chr(127),
        'EOL'         => chr(155),
        'DELETE LINE' => chr(156),
        'INSERT LINE' => chr(157),
        'BELL'        => chr(253),
        'DELETE'      => chr(254),
        'INSERT'      => chr(255),
    };
    return ($self);
} ## end sub atascii_initialize

sub atascii_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    $self->{'debug'}->DEBUG(['Send ATASCII text']);
    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
            if ($string eq $self->{'atascii_sequences'}->{'CLEAR'} && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
            }
        } ## end foreach my $string (keys %{...})
    }
    my $s_len = length($text);
    my $nl    = $self->{'atascii_sequences'}->{'NEWLINE'};
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
    return (TRUE);
} ## end sub atascii_output
1;
