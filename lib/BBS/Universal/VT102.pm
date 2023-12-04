package BBS::Universal::VT102;
BEGIN { our $VERSION = '0.001'; }

sub vt102_initialize {
    my $self = shift;

    my $esc = chr(27) . '[';

    $self->{'vt_prefix'}       = $esc;
    $self->{'vt102_sequences'} = {
        'CLEAR' => $esc . '2J',

        # Cursor
        'UP'          => $esc . 'A',
        'DOWN'        => $esc . 'B',
        'RIGHT'       => $esc . 'C',
        'LEFT'        => $esc . 'D',
        'SAVE'        => $esc . 's',
        'RESTORE'     => $esc . 'u',
        'RESET'       => $esc . '0m',
        'BOLD'        => $esc . '1m',
        'FAINT'       => $esc . '2m',
        'ITALIC'      => $esc . '3m',
        'UNDERLINE'   => $esc . '4m',
        'SLOW BLINK'  => $esc . '5m',
        'RAPID BLINK' => $esc . '6m',

        # Attributes
        'INVERT'       => $esc . '7m',
        'CROSSED OUT'  => $esc . '9m',
        'DEFAULT FONT' => $esc . '10m',
        'FONT1'        => $esc . '11m',
        'FONT2'        => $esc . '12m',
        'FONT3'        => $esc . '13m',
        'FONT4'        => $esc . '14m',
        'FONT5'        => $esc . '15m',
        'FONT6'        => $esc . '16m',
        'FONT7'        => $esc . '17m',
        'FONT8'        => $esc . '18m',
        'FONT9'        => $esc . '19m',

        # Color
        'NORMAL' => $esc . '21m',

        # Foreground color
        'BLACK'          => $esc . '30m',
        'RED'            => $esc . '31m',
        'GREEN'          => $esc . '32m',
        'YELLOW'         => $esc . '33m',
        'BLUE'           => $esc . '34m',
        'MAGENTA'        => $esc . '35m',
        'CYAN'           => $esc . '36m',
        'WHITE'          => $esc . '37m',
        'DEFAULT'        => $esc . '39m',
        'BRIGHT BLACK'   => $esc . '90m',
        'BRIGHT RED'     => $esc . '91m',
        'BRIGHT GREEN'   => $esc . '92m',
        'BRIGHT YELLOW'  => $esc . '93m',
        'BRIGHT BLUE'    => $esc . '94m',
        'BRIGHT MAGENTA' => $esc . '95m',
        'BRIGHT CYAN'    => $esc . '96m',
        'BRIGHT WHITE'   => $esc . '97m',

        # Background color
        'B_BLACK'          => $esc . '40m',
        'B_RED'            => $esc . '41m',
        'B_GREEN'          => $esc . '42m',
        'B_YELLOW'         => $esc . '43m',
        'B_BLUE'           => $esc . '44m',
        'B_MAGENTA'        => $esc . '45m',
        'B_CYAN'           => $esc . '46m',
        'B_WHITE'          => $esc . '47m',
        'B_DEFAULT'        => $esc . '49m',
        'BRIGHT B_BLACK'   => $esc . '100m',
        'BRIGHT B_RED'     => $esc . '101m',
        'BRIGHT B_GREEN'   => $esc . '102m',
        'BRIGHT B_YELLOW'  => $esc . '103m',
        'BRIGHT B_BLUE'    => $esc . '104m',
        'BRIGHT B_MAGENTA' => $esc . '105m',
        'BRIGHT B_CYAN'    => $esc . '106m',
        'BRIGHT B_WHITE'   => $esc . '107m',
    };

    $self->{'debug'}->DEBUG(['Initialized VT102']);
    return ($self);
} ## end sub vt102_initialize

sub vt102_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Send VT102 text']);
    foreach my $string (keys %{ $self->{'vt102_sequences'} }) {
        $text =~ s/\[\% $string \%\]/$self->{'vt102_sequences'}->{$string}/gi;
    }
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub vt102_output
1;
