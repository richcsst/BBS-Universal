package BBS::Universal::ATASCII;
BEGIN { our $VERSION = '0.001'; }

sub atascii_initialize {
    my $self = shift;

    $self->{'atascii_sequences'} = {
        'HEART'       => chr(0),
        '0x01'        => chr(1),
        
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

    $self->{'debug'}->DEBUG(['Send ATASCII text']);
    foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
        $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
    }
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub atascii_output
1;
