package BBS::Universal::ATASCII;
BEGIN { our $VERSION = '0.005'; }

sub atascii_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start ATASCII Initialize']);
	$self->{'atascii_meta'} = {
        'HEART'                        => {
			'out' => chr(0),   # ♥
			'unicode' => '♥',
			'desc' => 'Heart',
		},
        'VERTICAL BAR MIDDLE LEFT'     => {
			'out' => chr(1),   # ├
			'unicode' => '├',
			'desc' => 'Vertical Bar Middle Left',
		},
        'RIGHT VERTICAL BAR'           => {
			'out' => chr(2),   #
			'unicode' => ' ',
			'desc' => 'Right Vertical Bar',
		},
        'BOTTOM RIGHT CORNER'          => {
			'out' => chr(3),   # ┘
			'unicode' => '┘',
			'desc' => 'Bottom Right Corner',
		},
        'VERTICAL BAR MIDDLE RIGHT'    => {
			'out' => chr(4),   # ┤
			'unicode' => '┤',
			'desc' => 'Vertical Bar Middle Right',
		},
        'TOP RIGHT CORNER'             => {
			'out' => chr(5),   # ┐
			'unicode' => '┐',
			'desc' => 'Top Right Corner',
		},
        'LARGE FORWARD SLASH'          => {
			'out' => chr(6),   # ╱
			'unicode' => '╱',
			'desc' => 'Large Forward Slash',
		},
        'RING BELL'                    => {
			'out' => chr(253),
			'unicode' => ' ',
			'desc' => 'Console Bell',
		},
        'LARGE BACKSLASH'             => {
			'out' => chr(7),   # ╲
			'unicode' => '╲',
			'desc' => 'Large Backslash',
		},
        'TOP LEFT WEDGE'               => {
			'out' => chr(8),   # ◢
			'unicode' => '◢',
			'desc' => 'Top Left Wedge',
		},
        'BOTTOM RIGHT BOX'             => {
			'out' => chr(9),   # ▗
			'unicode' => '▗',
			'desc' => 'Bottom Right Box',
		},
        'TOP RIGHT WEDGE'              => {
			'out' => chr(10),  # ◣
			'unicode' => '◣',
			'desc' => 'Top Right Wedge',
		},
        'LINEFEED'                     => {
			'out' => chr(10),
			'unicode' => ' ',
			'desc' => 'Linefeed',
		},
        'TOP RIGHT BOX'                => {
			'out' => chr(11),  # ▝
			'unicode' => '▝',
			'desc' => 'Top Right Box',
		},
        'TOP LEFT BOX'                 => {
			'out' => chr(12),  # ▘
			'unicode' => '▘',
			'desc' => 'Top Left Box',
		},
        'RETURN'                       => {
			'out' => chr(155),
			'unicode' => ' ',
			'desc' => 'Carriage Return',
		},
        'NEWLINE'                      => {
			'out' => chr(155),
			'unicode' => ' ',
			'desc' => 'Newline',
		},
        'TOP HORIZONTAL BAR'           => {
			'out' => chr(13),
			'unicode' => ' ',
			'desc' => 'Top Horizontal Bar',
		},
        'BOTTOM HORIZONTAL BAR'        => {
			'out' => chr(14),  # ▂
			'unicode' => '▂',
			'desc' => 'Bottom Horizontal Bar',
		},
        'BOTTOM LEFT BOX'              => {
			'out' => chr(15),  # ▖
			'unicode' => '▖',
			'desc' => 'Bottom Left Box',
		},
        'CLUB'                         => {
			'out' => chr(16),  # ♣
			'unicode' => '♣',
			'desc' => 'Club',
		},
        'TOP LEFT CORNER'              => {
			'out' => chr(17),  # ┌
			'unicode' => '┌',
			'desc' => 'Top Left Corner',
		},
        'HORIZONTAL BAR'               => {
			'out' => chr(18),  # ─
			'unicode' => '─',
			'desc' => 'Horizontal Bar',
		},
        'CROSS BAR'                    => {
			'out' => chr(19),  # ┼
			'unicode' => '┼',
			'desc' => 'Cross Bar',
		},
        'CENTER DOT'                   => {
			'out' => chr(20),  # •
			'unicode' => '•',
			'desc' => 'Center Dot',
		},
        'BOTTOM BOX'                   => {
			'out' => chr(21),  # ▄
			'unicode' => '▄',
			'desc' => 'Bottom Box',
		},
        'LEFT VERTICAL BAR'            => {
			'out' => chr(22),  # ▎
			'unicode' => '▎',
			'desc' => 'Left Vertical Bar',
		},
        'HORIZONTAL BAR MIDDLE TOP'    => {
			'out' => chr(23),  # ┬
			'unicode' => '┬',
			'desc' => 'Horizontal Bar Middle Top',
		},
        'HORIZONTAL BAR MIDDLE BOTTOM' => {
			'out' => chr(24),  # ┴
			'unicode' => '┴',
			'desc' => 'Horizontal Bar Middle Bottom',
		},
        'LEFT VERTICAL BAR'            => {
			'out' => chr(25),  # ▌
			'unicode' => '▌',
			'desc' => 'Left Vertical Bar',
		},
        'BOTTOM LEFT CORNER'           => {
			'out' => chr(26),  # └
			'unicode' => '└',
			'desc' => 'Botom Left Corner',
		},
        'ESC'                          => {
			'out' => chr(27),  # ␛
			'unicode' => '␛',
			'desc' => 'Escape',
		},
        'UP'                           => {
			'out' => chr(28),
			'unicode' => ' ',
			'desc' => 'Move Cursor Up',
		},
        'UP ARROW'                     => {
			'out' => chr(28),  # ↑
			'unicode' => '↑',
			'desc' => 'Up Arrow',
		},
        'DOWN'                         => {
			'out' => chr(29),
			'unicode' => ' ',
			'desc' => 'Move Cursor Down',
		},
        'DOWN ARROW'                   => {
			'out' => chr(29),  # ↓
			'unicode' => '↓',
			'desc' => 'Down Arrow',
		},
        'LEFT'                         => {
			'out' => chr(30),
			'unicode' => ' ',
			'desc' => 'Move Cursor Left',
		},
        'LEFT ARROW'                   => {
			'out' => chr(30),  # ←
			'unicode' => '←',
			'desc' => 'Left Arrow',
		},
        'RIGHT'                        => {
			'out' => chr(31),
			'unicode' => ' ',
			'desc' => 'Move Cursor Right',
		},
        'RIGHT ARROW'                  => {
			'out' => chr(31),  # →
			'unicode' => '→',
			'desc' => 'Right Arrow',
		},
        'DIAMOND'                      => {
			'out' => chr(96),  # ♦
			'unicode' => '♦',
			'desc' => 'Diamond',
		},
        'SPADE'                        => {
			'out' => chr(123), # ♠
			'unicode' => '♠',
			'desc' => 'Spade',
		},
        'MIDDLE VERTICAL BAR'          => {
			'out' => chr(124), # |
			'unicode' => '|',
			'desc' => 'Middle Vertical Bar',
		},
        'CLEAR'                        => {
			'out' => chr(125),
			'unicode' => ' ',
			'desc' => 'Clear Screen',
		},
        'BACK ARROW'                   => {
			'out' => chr(125), # 🢰
			'unicode' => '🢰',
			'desc' => 'Back Arrow',
		},
        'BACKSPACE'                    => {
			'out' => chr(126),
			'unicode' => ' ',
			'desc' => 'Backspace',
		},
        'LEFT TRIANGLE'                => {
			'out' => chr(126), # ◀
			'unicode' => '◀',
			'desc' => 'Left Triangle',
		},
        'TAB'                          => {
			'out' => chr(127),
			'unicode' => ' ',
			'desc' => 'Tab',
		},
        'RIGHT TRIANGLE'               => {
			'out' => chr(127), # ▶
			'unicode' => '▶',
			'desc' => 'Right Triangle',
		},
        'BOTTOM RIGHT WEDGE'           => {
			'out' => chr(136), # ◤
			'unicode' => '◤',
			'desc' => 'Bottom Right Wedge',
		},
        'TOP LEFT CORNER BOX'          => {
			'out' => chr(137), # ▛
			'unicode' => '▛',
			'desc' => 'Top Left Corner Box',
		},
        'BOTTOM LEFT WEDGE'            => {
			'out' => chr(138), # ◥
			'unicode' => '◥',
			'desc' => 'Bottom Left Wedge',
		},
        'BOTTOM LEFT CORNER BOX'       => {
			'out' => chr(139), # ▙
			'unicode' => '▙',
			'desc' => 'Bottom Left Corner Box',
		},
        'BOTTOM RIGHT CORNER BOX'      => {
			'out' => chr(140), # ▟
			'unicode' => '▟',
			'desc' => 'Bottom Right Corner Box',
		},
        'BOTTOM BOX'                   => {
			'out' => chr(141), # ▆
			'unicode' => '▆',
			'desc' => 'Bottom Box',
		},
        'TOP RIGHT CORNER BOX'         => {
			'out' => chr(143), # ▜
			'unicode' => '▜',
			'desc' => 'Top Right Corner Box',
		},
        'SOLID BLOCK'                  => {
			'out' => chr(160), # █
			'unicode' => '█',
			'desc' => 'Solid Block',
		},
        'DELETE LINE'                  => {
			'out' => chr(156),
			'unicode' => ' ',
			'desc' => 'Delete Line',
		},
        'INSERT LINE'                  => {
			'out' => chr(157),
			'unicode' => ' ',
			'desc' => 'Insert Line',
		},
        'CLEAR TAB STOP'               => {
			'out' => chr(158),
			'unicode' => ' ',
			'desc' => 'Clear Tab Stop',
		},
        'SET TAB STOP'                 => {
			'out' => chr(159),
			'unicode' => ' ',
			'desc' => 'Set Tab Stop',
		},
        # Top bit inverts
        'DELETE LINE'                  => {
			'out' => chr(156),
			'unicode' => ' ',
			'desc' => 'Delete Line',
		},
        'INSERT LINE'                  => {
			'out' => chr(157),
			'unicode' => ' ',
			'desc' => 'Insert Line',
		},
        'DELETE'                       => {
			'out' => chr(254),
			'unicode' => ' ',
			'desc' => 'Delete',
		},
        'INSERT'                       => {
			'out' => chr(255),
			'unicode' => ' ',
			'desc' => 'Insert',
		},
	};
	foreach my $name (keys %{ $self->{'atascii_meta'} }) {
		$self->{'atascii_sequences'}->{$name} = $self->{'atascii_meta'}->{$name}->{'out'};
	}
    $self->{'debug'}->DEBUG(['End ATASCII Initialize']);
    return ($self);
}

sub atascii_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start ATASCII Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;

    if (length($text) > 1) {
        while($text =~ /\[\%\s+HORIZONTAL RULE\s+\%\]/) {
            my $rule = '[% TOP HORIZONTAL BAR %]' x $self->{'USER'}->{'max_columns'};
            $text =~ s/\[\%\s+HORIZONTAL RULE\s+\%\]/$rule/gs;
        }
        foreach my $string (keys %{ $self->{'atascii_sequences'} }) {
            if ($string eq $self->{'atascii_sequences'}->{'CLEAR'} && ($self->{'sysop'} || $self->{'local_mode'})) {
                my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
            } else {
                $text =~ s/\[\% $string \%\]/$self->{'atascii_sequences'}->{$string}/gi;
            }
        }
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
        }
        $self->send_char($char);
    }
    $self->{'debug'}->DEBUG(['End ATASCII Output']);
    return (TRUE);
}
1;
