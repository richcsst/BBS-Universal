package BBS::Universal::ASCII;
BEGIN { our $VERSION = '0.001'; }

sub ascii_initialize {
    my $self = shift;

    $self->{'ascii_sequences'} = {
        'RETURN'   => chr(13),
        'LINEFEED' => chr(10),
        'NEWLINE'  => chr(13) . chr(10),
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
    $self->{'debug'}->DEBUGMAX([$text]);
    my $s_len = length($text);
    my $nl    = $self->{'ascii_sequences'}->{'NEWLINE'};
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
} ## end sub ascii_output
1;
