package BBS::Universal::ANSI;
BEGIN { our $VERSION = '0.001'; }

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27) . '[';

    $self->{'ansi_prefix'}    = $esc;
    $self->{'ansi_sequences'} = {
        'RETURN'   => chr(13),
        'LINEFEED' => chr(10),
        'NEWLINE'  => chr(13) . chr(10),

        'CLEAR'      => locate(1,1) . cls,
        'CLS'        => locate(1,1) . cls,
        'CLEAR LINE' => clline,
        'CLEAR DOWN' => cldown,
        'CLEAR UP'   => clup,

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
        'REVERSE'      => $esc . '7m',
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
        'PINK'           => color('ANSI198'),
        'ORANGE'         => color('ANSI202'),
        'GREEN'          => $esc . '32m',
        'YELLOW'         => $esc . '33m',
        'BLUE'           => $esc . '34m',
        'NAVY'           => color('ANSI17'),
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

        # Special
        'HORIZONTAL RULE RED'     => "\r" . $esc . '41m' . clline . $esc . '0m',
        'HORIZONTAL RULE GREEN'   => "\r" . $esc . '42m' . clline . $esc . '0m',
        'HORIZONTAL RULE YELLOW'  => "\r" . $esc . '43m' . clline . $esc . '0m',
        'HORIZONTAL RULE BLUE'    => "\r" . $esc . '44m' . clline . $esc . '0m',
        'HORIZONTAL RULE MAGENTA' => "\r" . $esc . '45m' . clline . $esc . '0m',
        'HORIZONTAL RULE CYAN'    => "\r" . $esc . '46m' . clline . $esc . '0m',
        'HORIZONTAL RULE WHITE'   => "\r" . $esc . '47m' . clline . $esc . '0m',

        'EURO'                             => chr(128),
        'ELIPSIS'                          => chr(133),
        'BULLET DOT'                       => chr(149),
        'HOLLOW BULLET DOT'                => '○',
        'BIG HYPHEN'                       => chr(150),
        'BIGGEST HYPHEN'                   => chr(151),
        'TRADEMARK'                        => chr(153),
        'CENTS'                            => chr(162),
        'POUND'                            => chr(163),
        'YEN'                              => chr(165),
        'COPYRIGHT'                        => chr(169),
        'DOUBLE LT'                        => chr(171),
        'REGISTERED'                       => chr(174),
        'OVERLINE'                         => chr(175),
        'DEGREE'                           => chr(176),
        'SQUARED'                          => chr(178),
        'CUBED'                            => chr(179),
        'MICRO'                            => chr(181),
        'MIDDLE DOT'                       => chr(183),
        'DOUBLE GT'                        => chr(187),
        'QUARTER'                          => chr(188),
        'HALF'                             => chr(189),
        'THREE QUARTERS'                   => chr(190),
        'INVERTED QUESTION'                => chr(191),
        'DIVISION'                         => chr(247),
        'HEART'                            => '♥',
        'CLUB'                             => '♣',
        'DIAMOND'                          => '♦',
        'LARGE PLUS'                       => '┼',
        'LARGE VERTICAL BAR'               => '│',
        'LARGE OVERLINE'                   => '▔',
        'LARGE UNDERLINE'                  => '▁',
        'BULLET RIGHT'                     => '▶',
        'BULLET LEFT'                      => '◀',
        'SMALL BULLET RIGHT'               => '▸',
        'SMALL BULLET LEFT'                => '◂',
        'BIG BULLET RIGHT'                 => '►',
        'BIG BULLET LEFT'                  => '◄',
        'BULLET DOWN'                      => '▼',
        'BULLET UP'                        => '▲',
        'WEDGE TOP LEFT'                   => '◢',
        'WEDGE TOP RIGHT'                  => '◣',
        'WEDGE BOTTOM LEFT'                => '◥',
        'WEDGE BOTTOM RIGHT'               => '◤',
        'LOWER ONE EIGHT BLOCK'            => '▁',
        'LOWER ONE QUARTER BLOCK'          => '▂',
        'LOWER THREE EIGHTHS BLOCK'        => '▃',
        'LOWER FIVE EIGTHS BLOCK'          => '▅',
        'LOWER THREE QUARTERS BLOCK'       => '▆',
        'LOWER SEVEN EIGHTHS BLOCK'        => '▇',
        'LEFT SEVEN EIGHTHS BLOCK'         => '▉',
        'LEFT THREE QUARTERS BLOCK'        => '▊',
        'LEFT FIVE EIGHTHS BLOCK'          => '▋',
        'LEFT THREE EIGHTHS BLOCK'         => '▍',
        'LEFT ONE QUARTER BLOCK'           => '▎',
        'LEFT ONE EIGHTH BLOCK'            => '▏',
        'MEDIUM SHADE'                     => '▒',
        'DARK SHADE'                       => ' ',
        'UPPER ONE EIGHTH BLOCK'           => '▔',
        'RIGHT ONE EIGHTH BLOCK'           => '▕',
        'LOWER LEFT QUADRANT'              => '▖',
        'LOWER RIGHT QUADRANT'             => '▗',
        'UPPER LEFT QUADRANT'              => '▘',
        'LEFT LOWER RIGHT QUADRANTS'       => '▙',
        'UPPER LEFT LOWER RIGHT QUADRANTS' => '▚',
        'LEFT UPPER RIGHT QUADRANTS'       => '▛',
        'UPPER LEFT RIGHT QUADRANTS'       => '▜',
        'UPPER RIGHT QUADRANT'             => '▝',
        'UPPER RIGHT LOWER LEFT QUADRANTS' => '▞',
        'RIGHT LOWER LEFT QUADRANTS'       => '▟',
        'THICK VERTICAL BAR'               => chr(0xA6),
        'THIN HORIZONTAL BAR'              => '─',
        'THICK HORIZONTAL BAR'             => '━',
        'THIN VERTICAL BAR'                => '│',
        'MEDIUM VERTICAL BAR'              => '┃',
        'THIN DASHED HORIZONTAL BAR'       => '┄',
        'THICK DASHED HORIZONTAL BAR'      => '┅',
        'THIN DASHED VERTICAL BAR'         => '┆',
        'THICK DASHED VERTICAL BAR'        => '┇',
        'THIN DOTTED HORIZONTAL BAR'       => '┈',
        'THICK DOTTED HORIZONTAL BAR'      => '┉',
        'MEDIUM DASHED VERTICAL BAR'       => '┊',
        'THICK DASHED VERTICAL BAR'        => '┋',
        'U250C'                            => '┌',
        'U250D'                            => '┍',
        'U250E'                            => '┎',
        'U250F'                            => '┏',
        'U2510'                            => '┐',
        'U2511'                            => '┑',
        'U2512'                            => '┒',
        'U2513'                            => '┓',
        'U2514'                            => '└',
        'U2515'                            => '┕',
        'U2516'                            => '┖',
        'U2517'                            => '┗',
        'U2518'                            => '┘',
        'U2519'                            => '┙',
        'U251A'                            => '┚',
        'U251B'                            => '┛',
        'U251C'                            => '├',
        'U251D'                            => '┝',
        'U251E'                            => '┞',
        'U251F'                            => '┟',
        'U2520'                            => '┠',
        'U2521'                            => '┡',
        'U2522'                            => '┢',
        'U2523'                            => '┣',
        'U2524'                            => '┤',
        'U2525'                            => '┥',
        'U2526'                            => '┦',
        'U2527'                            => '┧',
        'U2528'                            => '┨',
        'U2529'                            => '┩',
        'U252A'                            => '┪',
        'U252B'                            => '┫',
        'U252C'                            => '┬',
        'U252D'                            => '┭',
        'U252E'                            => '┮',
        'U252F'                            => '┯',
        'U2530'                            => '┰',
        'U2531'                            => '┱',
        'U2532'                            => '┲',
        'U2533'                            => '┳',
        'U2534'                            => '┴',
        'U2535'                            => '┵',
        'U2536'                            => '┶',
        'U2537'                            => '┷',
        'U2538'                            => '┸',
        'U2539'                            => '┹',
        'U253A'                            => '┺',
        'U253B'                            => '┻',
        'U235C'                            => '┼',
        'U253D'                            => '┽',
        'U253E'                            => '┾',
        'U253F'                            => '┿',
        'U2540'                            => '╀',
        'U2541'                            => '╁',
        'U2542'                            => '╂',
        'U2543'                            => '╃',
        'U2544'                            => '╄',
        'U2545'                            => '╅',
        'U2546'                            => '╆',
        'U2547'                            => '╇',
        'U2548'                            => '╈',
        'U2549'                            => '╉',
        'U254A'                            => '╊',
        'U254B'                            => '╋',
        'U254C'                            => '╌',
        'U254D'                            => '╍',
        'U254E'                            => '╎',
        'U254F'                            => '╏',
        'CHECK'                            => '✓',
        'PIE'                              => 'π',
        'TOP LEFT ROUNDED'                 => '╭',
        'TOP RIGHT ROUNDED'                => '╮',
        'BOTTOM RIGHT ROUNDED'             => '╯',
        'BOTTOM LEFT ROUNDED'              => '╰',
        'FULL FORWARD SLASH'               => '╱',
        'FULL BACKWZARD SLASH'             => '╲',
        'FULL X'                           => '╳',
        'THIN LEFT HALF HYPHEN'            => '╴',
        'THIN TOP HALF BAR'                => '╵',
        'THIN RIGHT HALF HYPHEN'           => '╶',
        'THIN BOTTOM HALF BAR'             => '╷',
        'THICK LEFT HALF HYPHEN'           => '╸',
        'THICK TOP HALF BAR'               => '╹',
        'THICK RIGHT HALF HYPHEN'          => '╺',
        'THICK BOTTOM HALF BAR'            => '╻',
        'RIGHT TELESCOPE'                  => '╼',
        'DOWN TELESCOPE'                   => '╽',
        'LEFT TELESCOPE'                   => '╾',
        'UP TELESCOPE'                     => '╿',
        'MIDDLE VERTICAL RULE BLACK'       => $self->sysop_locate_middle('B_BLACK'),
        'MIDDLE VERTICAL RULE RED'         => $self->sysop_locate_middle('B_RED'),
        'MIDDLE VERTICAL RULE GREEN'       => $self->sysop_locate_middle('B_GREEN'),
        'MIDDLE VERTICAL RULE YELLOW'      => $self->sysop_locate_middle('B_YELLOW'),
        'MIDDLE VERTICAL RULE BLUE'        => $self->sysop_locate_middle('B_BLUE'),
        'MIDDLE VERTICAL RULE MAGENTA'     => $self->sysop_locate_middle('B_MAGENTA'),
        'MIDDLE VERTICAL RULE CYAN'        => $self->sysop_locate_middle('B_CYAN'),
        'MIDDLE VERTICAL RULE WHITE'       => $self->sysop_locate_middle('B_WHITE'),
        'HORIZONTAL RULE RED'              => "\r" . $self->{'ansi_sequences'}->{'B_RED'} . clline . $self->{'ansi_sequences'}->{'RESET'},        # Needs color defined before actual use
        'HORIZONTAL RULE GREEN'            => "\r" . $self->{'ansi_sequences'}->{'B_GREEN'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use
        'HORIZONTAL RULE YELLOW'           => "\r" . $self->{'ansi_sequences'}->{'B_YELLOW'} . clline . $self->{'ansi_sequences'}->{'RESET'},     # Needs color defined before actual use
        'HORIZONTAL RULE BLUE'             => "\r" . $self->{'ansi_sequences'}->{'B_BLUE'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE MAGENTA'          => "\r" . $self->{'ansi_sequences'}->{'B_MAGENTA'} . clline . $self->{'ansi_sequences'}->{'RESET'},    # Needs color defined before actual use
        'HORIZONTAL RULE CYAN'             => "\r" . $self->{'ansi_sequences'}->{'B_CYAN'} . clline . $self->{'ansi_sequences'}->{'RESET'},       # Needs color defined before actual use
        'HORIZONTAL RULE WHITE'            => "\r" . $self->{'ansi_sequences'}->{'B_WHITE'} . clline . $self->{'ansi_sequences'}->{'RESET'},      # Needs color defined before actual use
    };
    foreach my $count (0 .. 255) {
        $self->{'ansi_sequences'}->{"ANSI$count"} = color("ANSI$count");
    }
    $self->{'debug'}->DEBUG(['Initialized VT102']);
    return ($self);
} ## end sub ansi_initialize

sub ansi_output {
    my $self   = shift;
    my $text   = shift;
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $self->{'debug'}->DEBUG(['Send ANSI text']);
    if (length($text) > 1) {
        foreach my $string (keys %{ $self->{'ansi_sequences'} }) {
            if ($string =~ /CLEAR|CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_sequences'}->{$string}/gi;
            }
        } ## end foreach my $string (keys %{...})
    }
    my $s_len = length($text);
    my $nl    = $self->{'ansi_sequences'}->{'NEWLINE'};
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
} ## end sub ansi_output
1;
