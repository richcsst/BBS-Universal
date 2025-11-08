package BBS::Universal::PETSCII;
BEGIN { our $VERSION = '0.004'; }

sub petscii_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start PETSCII Initialize']);
	$self->{'petscii_meta'} = {
        'UNDERLINE ON' => {
			'out' => chr(2),
			'unicode' => ' ',
			'desc' => 'Turn on underline mode',
		},
        'WHITE'        => {
			'out' => chr(5),
			'unicode' => ' ',
			'desc' => 'White text',
		},
        'RESET'        => {
			'out' => chr(5),
			'unicode' => ' ',
			'desc' => 'Reset back to white text',
		},
        'RING BELL'    => {
			'out' => chr(7),
			'unicode' => ' ',
			'desc' => 'Sound bell',
		},
        'TAB'          => {
			'out' => chr(9),
			'unicode' => ' ',
			'desc' => 'Tab',
		},
        'RETURN'       => {
			'out' => chr(13),
			'unicode' => ' ',
			'desc' => 'Carriage Return',
		},
        'LINEFEED'     => {
			'out' => chr(10),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},
        'NEWLINE'      => {
			'out' => chr(13) . chr(10),
			'unicode' => ' ',
			'desc' => 'Newline',
		},
        'CLEAR'        => {
			'out' => chr(0x93),
			'unicode' => ' ',
			'desc' => 'Clear Screen',
		},
        'CLS'          => {
			'out' => chr(0x93),
			'unicode' => ' ',
			'desc' => 'Clear Screen',
		},
        'BACKSPACE'    => {
			'out' => chr(20),
			'unicode' => ' ',
			'desc' => 'Backspace',
		},
        'DELETE'       => {
			'out' => chr(20),
			'unicode' => ' ',
			'desc' => 'Delete',
		},
        'BLACK'         => {
			'out' => chr(0x90),
			'unicode' => ' ',
			'desc' => 'Black',
		},
        'RED'           => {
			'out' => chr(0x1C),
			'unicode' => ' ',
			'desc' => 'Red',
		},
        'GREEN'         => {
			'out' => chr(0x1E),
			'unicode' => ' ',
			'desc' => 'Green',
		},
        'BLUE'          => {
			'out' => chr(0x1F),
			'unicode' => ' ',
			'desc' => 'Blue',
		},
        'DARK PURPLE'   => {
			'out' => chr(0x81),
			'unicode' => ' ',
			'desc' => 'Dark Purple',
		},
        'UNDERLINE OFF' => {
			'out' => chr(0x82),
			'unicode' => ' ',
			'desc' => 'Turn Underline Off',
		},
        'BLINK ON'      => {
			'out' => chr(0x0F),
			'unicode' => ' ',
			'desc' => 'Turn Blink On',
		},
        'BLINK OFF'     => {
			'out' => chr(0x8F),
			'unicode' => ' ',
			'desc' => 'Turn Blink On',
		},
        'REVERSE ON'    => {
			'out' => chr(0x12),
			'unicode' => ' ',
			'desc' => 'Turn Reverse On',
		},
        'REVERSE OFF'   => {
			'out' => chr(0x92),
			'unicode' => ' ',
			'desc' => 'Turn Reverse Off',
		},
        'BROWN'         => {
			'out' => chr(0x95),
			'unicode' => ' ',
			'desc' => 'Brown',
		},
        'PINK'          => {
			'out' => chr(0x96),
			'unicode' => ' ',
			'desc' => 'Pink',
		},
        'CYAN'          => {
			'out' => chr(0x97),
			'unicode' => ' ',
			'desc' => 'Cyan',
		},
        'LIGHT GRAY'    => {
			'out' => chr(0x98),
			'unicode' => ' ',
			'desc' => 'Light Gray',
		},
        'LIGHT GREEN'   => {
			'out' => chr(0x99),
			'unicode' => ' ',
			'desc' => 'Light Green',
		},
        'LIGHT BLUE'    => {
			'out' => chr(0x9A),
			'unicode' => ' ',
			'desc' => 'Light Blue',
		},
        'GRAY'          => {
			'out' => chr(0x9B),
			'unicode' => ' ',
			'desc' => 'Gray',
		},
        'PURPLE'        => {
			'out' => chr(0x9C),
			'unicode' => ' ',
			'desc' => 'Purple',
		},
        'YELLOW'        => {
			'out' => chr(0x9E),
			'unicode' => ' ',
			'desc' => 'Yellow',
		},
        'CYAN'          => {
			'out' => chr(0x9F),
			'unicode' => ' ',
			'desc' => 'Cyan',
		},
        'UP'            => {
			'out' => chr(0x91),
			'unicode' => ' ',
			'desc' => 'Move Cursor Up',
		},
        'DOWN'          => {
			'out' => chr(0x11),
			'unicode' => ' ',
			'desc' => 'Move Cursor Down',
		},
        'LEFT'          => {
			'out' => chr(0x9D),
			'unicode' => ' ',
			'desc' => 'Move Cursor Left',
		},
        'RIGHT'         => {
			'out' => chr(0x1D),
			'unicode' => ' ',
			'desc' => 'Move Cursor Right',
		},
        'ESC'           => {
			'out' => chr(0x1B),
			'unicode' => ' ',
			'desc' => 'Escape',
		},
        'LINEFEED'      => {
			'out' => chr(0x0A),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},

        'BRITISH POUND'                => {
			'out' => chr(0x5C),    # £
			'unicode' => '£',
			'desc' => 'British Pound',
		},
        'UP ARROW'                     => {
			'out' => chr(0x5E),    # ↑
			'unicode' => '↑',
			'desc' => 'Up Arrow',
		},
        'LEFT ARROW'                   => {
			'out' => chr(0x5F),    # ←
			'unicode' => '←',
			'desc' => 'Left Arrow',
		},
        'HORIZONTAL BAR'               => {
			'out' => chr(0x60),    # ─
			'unicode' => '─',
			'desc' => 'Horizontal Bar',
		},
        'SPADE'                        => {
			'out' => chr(0x61),    # ♠
			'unicode' => '♠',
			'desc' => 'Spade',
		},
        'TOP RIGHT ROUNDED CORNER'     => {
			'out' => chr(0x69),    # ╮
			'unicode' => '╮',
			'desc' => 'Top Right Rounded Corner',
		},
        'BOTTOM LEFT ROUNDED CORNER'   => {
			'out' => chr(0x6A),    # ╰
			'unicode' => '╰',
			'desc' => 'Bottom Left Rounded Corner',
		},
        'BOTTOM RIGHT ROUNDED CORNER'  => {
			'out' => chr(0x6B),    # ╯
			'unicode' => '╯',
			'desc' => 'Bottom Right Rounded Corner',
		},
        'GIANT BACKSLASH'             => {
			'out' => chr(0x6D),    # ╲
			'unicode' => '╲',
			'desc' => 'Giant Backslash',
		},
        'GIANT FORWARD SLASH'          => {
			'out' => chr(0x6E),    # ╱
			'unicode' => '╱',
		},
        'CENTER DOT'                   => {
			'out' => chr(0x71),    # •
			'unicode' => '•',
			'desc' => 'Center Dot',
		},
        'HEART'                        => {
			'out' => chr(0x73),    # ♥
			'unicode' => '♥',
			'desc' => 'Heart',
		},
        'TOP LEFT ROUNDED CORNER'      => {
			'out' => chr(0x75),    # ╭
			'unicode' => '╭',
			'desc' => 'Top Left Rounded Corner',
		},
        'GIANT X'                      => {
			'out' => chr(0x76),    # ╳
			'unicode' => '╳',
			'desc' => 'Giant X',
		},
        'THIN CIRCLE'                  => {
			'out' => chr(0x77),    # ○
			'unicode' => '○',
			'desc' => 'Thin Circle',
		},
        'CLUB'                         => {
			'out' => chr(0x78),    # ♣
			'unicode' => '♣',
			'desc' => 'Club',
		},
        'DIAMOND'                      => {
			'out' => chr(0x7A),    # ♦
			'unicode' => '♦',
			'desc' => 'Diamond',
		},
        'CROSS BAR'                    => {
			'out' => chr(0x7B),    # ┼
			'unicode' => '┼',
			'desc' => 'Cross Bar',
		},
        'GIANT VERTICAL BAR'           => {
			'out' => chr(0x7D),    # │
			'unicode' => '│',
			'desc' => 'Giant Vertical Bar',
		},
        'PI'                           => {
			'out' => chr(0x7E),    # π
			'unicode' => 'π',
			'desc' => 'Pi',
		},
        'BOTTOM LEFT WEDGE'            => {
			'out' => chr(0x7F),    # ◥
			'unicode' => '◥',
			'desc' => 'Bottom Left Wedge',
		},
        'DITHERED FULL'                => {
			'out' => chr(0x7C),
			'unicode' => ' ',
			'desc' => 'Dithered Box Full',
		},
        'LEFT HALF'                    => {
			'out' => chr(0xA1),    # ▌
			'unicode' => '▌',
			'desc' => 'Left Half',
		},
        'BOTTOM BOX'                   => {
			'out' => chr(0xA2),    # ▄
			'unicode' => '▄',
			'desc' => 'Bottom Box',
		},
        'TOP HORIZONTAL BAR'           => {
			'out' => chr(0xA3),    # ▔
			'unicode' => '▔',
			'desc' => 'Top Horizontal Bar',
		},
        'BOTTOM HORIZONTAL BAR'        => {
			'out' => chr(0xA4),    # ▁
			'unicode' => '▁',
			'desc' => 'Bottom Horizontal Bar',
		},
        'LEFT VERTICAL BAR'            => {
			'out' => chr(0xA5),    #
			'unicode' => ' ',
			'desc' => 'Left Vertical Bar',
		},
        'DITHERED BOX'                 => {
			'out' => chr(0xA6),    # ▒
			'unicode' => '▒',
			'desc' => 'Dithered Box',
		},
        'RIGHT VERTICAL BAR'           => {
			'out' => chr(0xA7),    # ▕
			'unicode' => '▕',
			'desc' => 'Right Vertical Bar',
		},
        'DITHERED LEFT'                => {
			'out' => chr(0xA8),
			'unicode' => ' ',
			'desc' => 'Dithered Left',
		},
        'BOTTOM RIGHT WEDGE'           => {
			'out' => chr(0xA9),    # ◤
			'unicode' => '◤',
			'desc' => 'Bottom Right Wedge',
		},
        'VERTICAL BAR MIDDLE LEFT'     => {
			'out' => chr(0xAB),    # ├
			'unicode' => '├',
			'desc' => 'Vertical Bar Middle Left',
		},
        'BOTTOM RIGHT BOX'             => {
			'out' => chr(0xAC),    # ▗
			'unicode' => '▗',
			'desc' => 'Bottom Right Box',
		},
        'BOTTOM LEFT CORNER'           => {
			'out' => chr(0xAD),    # └
			'unicode' => '└',
			'desc' => 'Bottom Left Corner',
		},
        'TOP RIGHT CORNER'             => {
			'out' => chr(0xAE),    # ┐
			'unicode' => '┐',
			'desc' => 'Top Right Corner',
		},
        'HORIZONTAL BAR BOTTOM'        => {
			'out' => chr(0xAF),    # ▂
			'unicode' => '▂',
			'desc' => 'Horizontal Bar Bottom',
		},
        'TOP LEFT CORNER'              => {
			'out' => chr(0xB0),    # ┌
			'unicode' => '┌',
			'desc' => 'Top Left Corner',
		},
        'HORIZONTAL BAR MIDDLE BOTTOM' => {
			'out' => chr(0xB1),    # ┴
			'unicode' => '┴',
			'desc' => 'Horizontal Bar Middle Bottom',
		},
        'HORIZONTAL BAR MIDDLE TOP'    => {
			'out' => chr(0xB2),    # ┬
			'unicode' => '┬',
			'desc' => 'Horizontal Bar Middle Top',
		},
        'VERTICAL BAR MIDDLE RIGHT'    => {
			'out' => chr(0xB3),    # ┤
			'unicode' => '┤',
			'desc' => 'Vertical Bar Middle Right',
		},
        'VERTICAL BOX LEFT'            => {
			'out' => chr(0xB4),    # ▎
			'unicode' => '▎',
			'desc' => 'Vertical Box Left',
		},
        'LEFT HALF BOX'                => {
			'out' => chr(0xB5),    # ▍
			'unicode' => '▍',
			'desc' => 'Left Half Box',
		},
        'BOTTOM HALF BOX'              => {
			'out' => chr(0xB9),    # ▃
			'unicode' => '▃',
			'desc' => 'Bottom Half Box',
		},
        'BOTTOM LEFT BOX'              => {
			'out' => chr(0xBB),    # ▖
			'unicode' => '▖',
			'desc' => 'Bottom Left Box',
		},
        'TOP RIGHT BOX'                => {
			'out' => chr(0xBC),    # ▝
			'unicode' => '▝', 
			'desc' => 'Top Right Box',
		},
        'BOTTOM RIGHT CORNER'          => {
			'out' => chr(0xBD),    # ┘
			'unicode' => '┘',
			'desc' => 'Bottom Right Corner',
		},
        'TOP LEFT BOX'                 => {
			'out' => chr(0xBE),    # ▘
			'unicode' => '▘',
			'desc' => 'Top Left Box',
		},
        'TOP LEFT BOTTOM RIGHT BOX'    => {
			'out' => chr(0xBF),    # ▚
			'unicode' => '▚',
			'desc' => 'Top Left Bottom Right Box',
		},
        'DITHERED LEFT REVERSE'        => {
			'out' => chr(0xDC),
			'unicode' => ' ',
			'desc' => 'Dithered Left Reverse',
		},
        'DITHERED BOTTOM REVERSE'      => {
			'out' => chr(0xE8),
			'unicode' => ' ',
			'desc' => 'Dithered Bottom Reverse',
		},
        'DITHERED FULL REVERSE'        => {
			'out' => chr(0xFC),
			'unicode' => ' ',
			'desc' => 'Dithered Full Reverse',
		},
	};
	foreach my $name (keys %{ $self->{'petscii_meta'} }) {
		$self->{'petscii_sequences'}->{$name} = $self->{'petscii_meta'}->{$name}->{'out'};
	}
    $self->{'debug'}->DEBUG(['End PETSCII Initialize']);
    return ($self);
} ## end sub petscii_initialize

sub petscii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start PETSCII Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        while($text =~ /\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/) {
            my $rule = "[% $1 %]" . '[% TOP HORIZONTAL BAR %]' x $self->{'USER'}->{'max_columns'} . '[% RESET %]';
            $text =~ s/\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/$rule/gs;
        }
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
    $self->{'debug'}->DEBUG(['End PETSCII Output']);
    return (TRUE);
} ## end sub petscii_output
1;
