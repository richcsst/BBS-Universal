package BBS::Universal::ASCII;
BEGIN { our $VERSION = '0.001'; }

sub ascii_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['ASCII Initialized']);
    return ($self);
} ## end sub ascii_initialize

sub ascii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Send ASCII text']);
    $self->{'debug'}->DEBUGMAX([$text]);
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub ascii_output
1;
