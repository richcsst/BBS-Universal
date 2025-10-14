package BBS::Universal::PETSCII;
BEGIN { our $VERSION = '0.003'; }

sub petscii_initialize {
    my $self = shift;

    $self->{'petscii_sequences'} = {
        'UNDERLINE ON' => chr(2),
        'WHITE'        => chr(5),
        'RESET'        => chr(5),
        'RING BELL'    => chr(7),
        'TAB'          => chr(9),
        'RETURN'       => chr(13),
        'LINEFEED'     => chr(10),
        'NEWLINE'      => chr(13) . chr(10),
        'CLEAR'        => chr(0x93),
        'CLS'          => chr(0x93),
        'BACKSPACE'    => chr(20),
        'DELETE'       => chr(20),

        'BLACK'         => chr(0x90),
        'RED'           => chr(0x1C),
        'GREEN'         => chr(0x1E),
        'BLUE'          => chr(0x1F),
        'DARK PURPLE'   => chr(0x81),
        'UNDERLINE OFF' => chr(0x82),
        'BLINK ON'      => chr(0x0F),
        'BLINK OFF'     => chr(0x8F),
        'REVERSE ON'    => chr(0x12),
        'REVERSE OFF'   => chr(0x92),
        'BROWN'         => chr(0x95),
        'PINK'          => chr(0x96),
        'CYAN'          => chr(0x97),
        'LIGHT GRAY'    => chr(0x98),
        'LIGHT GREEN'   => chr(0x99),
        'LIGHT BLUE'    => chr(0x9A),
        'GRAY'          => chr(0x9B),
        'PURPLE'        => chr(0x9C),
        'YELLOW'        => chr(0x9E),
        'CYAN'          => chr(0x9F),
        'UP'            => chr(0x91),
        'DOWN'          => chr(0x11),
        'LEFT'          => chr(0x9D),
        'RIGHT'         => chr(0x1D),
        'ESC'           => chr(0x1B),
        'LINE FEED'     => chr(0x0A),

        'BRITISH POUND'                => chr(0x5C),    # £
        'UP ARROW'                     => chr(0x5E),    # ↑
        'LEFT ARROW'                   => chr(0x5F),    # ←
        'HORIZONTAL BAR'               => chr(0x60),    # ─
        'SPADE'                        => chr(0x61),    # ♠
        'TOP RIGHT ROUNDED CORNER'     => chr(0x69),    # ╮
        'BOTTOM LEFT ROUNDED CORNER'   => chr(0x6A),    # ╰
        'BOTTOM RIGHT ROUNDED CORNER'  => chr(0x6B),    # ╯
        'GIANT BACK SLASH'             => chr(0x6D),    # ╲
        'GIANT FORWARD SLASH'          => chr(0x6E),    # ╱
        'CENTER DOT'                   => chr(0x71),    # •
        'HEART'                        => chr(0x73),    # ♥
        'TOP LEFT ROUNDED CORNER'      => chr(0x75),    # ╭
        'GIANT X'                      => chr(0x76),    # ╳
        'THIN CIRCLE'                  => chr(0x77),    # ○
        'CLUB'                         => chr(0x78),    # ♣
        'DIAMOND'                      => chr(0x7A),    # ♦
        'CROSS BAR'                    => chr(0x7B),    # ┼
        'GIANT VERTICAL BAR'           => chr(0x7D),    # │
        'PI'                           => chr(0x7E),    # π
        'BOTTOM LEFT WEDGE'            => chr(0x7F),    # ◥
        'DITHERED FULL'                => chr(0x7C),
        'LEFT HALF'                    => chr(0xA1),    # ▌
        'BOTTOM BOX'                   => chr(0xA2),    # ▄
        'TOP HORIZONTAL BAR'           => chr(0xA3),    # ▔
        'BOTTOM HORIZONTAL BAR'        => chr(0xA4),    # ▁
        'LEFT VERTICAL BAR'            => chr(0xA5),    #
        'DITHERED BOX'                 => chr(0xA6),    # ▒▏
        'RIGHT VERTICAL BAR'           => chr(0xA7),    # ▕
        'DITHERED LEFT'                => chr(0xA8),
        'BOTTOM RIGHT WEDGE'           => chr(0xA9),    # ◤
        'VERTICAL BAR MIDDLE LEFT'     => chr(0xAB),    # ├
        'BOTTOM RIGHT BOX'             => chr(0xAC),    # ▗
        'BOTTOM LEFT CORNER'           => chr(0xAD),    # └
        'TOP RIGHT CORNER'             => chr(0xAE),    # ┐
        'HORIZONTAL BAR BOTTOM'        => chr(0xAF),    # ▂
        'TOP LEFT CORNER'              => chr(0xB0),    # ┌
        'HORIZONTAL BAR MIDDLE BOTTOM' => chr(0xB1),    # ┴
        'HORIZONTAL BAR MIDDLE TOP'    => chr(0xB2),    # ┬
        'VERTICAL BAR MIDDLE RIGHT'    => chr(0xB3),    # ┤
        'VERTICAL BOX LEFT'            => chr(0xB4),    # ▎
        'LEFT HALF BOX'                => chr(0xB5),    # ▍
        'BOTTOM HALF BOX'              => chr(0xB9),    # ▃
        'BOTTOM LEFT BOX'              => chr(0xBB),    # ▖
        'TOP RIGHT BOX'                => chr(0xBC),    # ▝
        'BOTTOM RIGHT CORNER'          => chr(0xBD),    # ┘
        'TOP LEFT BOX'                 => chr(0xBE),    # ▘
        'TOP LEFT BOTTOM RIGHT BOX'    => chr(0xBF),    # ▚
        'DITHERED LEFT REVERSE'        => chr(0xDC),
        'DITHERED BOTTOM REVERSE'      => chr(0xE8),
        'DITHERED FULL REVERSE'        => chr(0xFC),
    };
    return ($self);
} ## end sub petscii_initialize

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
        } ## end foreach my $string (keys %{...})
    } ## end if (length($text) > 1)
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
        $| = 1;
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
    } ## end else [ if ($self->{'local_mode'...})]
    return (TRUE);
} ## end sub petscii_output
1;
