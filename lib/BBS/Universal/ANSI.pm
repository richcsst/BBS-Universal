package BBS::Universal::ANSI;
BEGIN { our $VERSION = '0.002'; }

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27) . '[';

    $self->{'ansi_prefix'}    = $esc;
    $self->{'ansi_sequences'} = {
        'RETURN'    => chr(13),
        'LINEFEED'  => chr(10),
        'NEWLINE'   => chr(13) . chr(10),
		'RING BELL' => chr(7),

        'CLEAR'      => $esc . '2J',
        'CLS'        => $esc . '2J',
        'CLEAR LINE' => $esc . '0K',
        'CLEAR DOWN' => $esc . '0J',
        'CLEAR UP'   => $esc . '1J',

        # Cursor
        'UP'      => $esc . 'A',
        'DOWN'    => $esc . 'B',
        'RIGHT'   => $esc . 'C',
        'LEFT'    => $esc . 'D',
        'SAVE'    => $esc . 's',
        'RESTORE' => $esc . 'u',
        'RESET'   => $esc . '0m',

        # Attributes
        'BOLD'         => $esc . '1m',
        'FAINT'        => $esc . '2m',
        'ITALIC'       => $esc . '3m',
        'UNDERLINE'    => $esc . '4m',
        'OVERLINE'     => $esc . '53m',
        'SLOW BLINK'   => $esc . '5m',
        'RAPID BLINK'  => $esc . '6m',
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
        'NORMAL' => $esc . '22m',

        # Foreground color
        'BLACK'          => $esc . '30m',
        'RED'            => $esc . '31m',
        'PINK'           => $esc . '38;5;198m',
        'ORANGE'         => $esc . '38;5;202m',
        'NAVY'           => $esc . '38;5;17m',
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
        'B_PINK'           => $esc . '48;5;198m',
        'B_ORANGE'         => $esc . '48;5;202m',
        'B_NAVY'           => $esc . '48;5;17m',
        'BRIGHT B_BLACK'   => $esc . '100m',
        'BRIGHT B_RED'     => $esc . '101m',
        'BRIGHT B_GREEN'   => $esc . '102m',
        'BRIGHT B_YELLOW'  => $esc . '103m',
        'BRIGHT B_BLUE'    => $esc . '104m',
        'BRIGHT B_MAGENTA' => $esc . '105m',
        'BRIGHT B_CYAN'    => $esc . '106m',
        'BRIGHT B_WHITE'   => $esc . '107m',

		# Horizontal Rules
		'HORIZONTAL RULE ORANGE'         => '[% RETURN %]' . $esc . '48;5;202m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE PINK'           => '[% RETURN %]' . $esc . '48;5;198m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE RED'            => '[% RETURN %]' . $esc . '41m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT RED'     => '[% RETURN %]' . $esc . '101m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE GREEN'          => '[% RETURN %]' . $esc . '42m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT GREEN'   => '[% RETURN %]' . $esc . '102m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE YELLOW'         => '[% RETURN %]' . $esc . '43m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT YELLOW'  => '[% RETURN %]' . $esc . '103m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BLUE'           => '[% RETURN %]' . $esc . '44m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT BLUE'    => '[% RETURN %]' . $esc . '104m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE MAGENTA'        => '[% RETURN %]' . $esc . '45m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT MAGENTA' => '[% RETURN %]' . $esc . '105m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE CYAN'           => '[% RETURN %]' . $esc . '46m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT CYAN'    => '[% RETURN %]' . $esc . '106m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE WHITE'          => '[% RETURN %]' . $esc . '47m' . $esc . '0K' . $esc . '0m',
		'HORIZONTAL RULE BRIGHT WHITE'   => '[% RETURN %]' . $esc . '107m' . $esc . '0K' . $esc . '0m',
		@_,
	};

    # Generate generic colors
    foreach my $count (0 .. 255) {
        $self->{'ansi_sequences'}->{"ANSI$count"}   = $esc . '38;5;' . $count . 'm';
        $self->{'ansi_sequences'}->{"B_ANSI$count"} = $esc . '48;5;' . $count . 'm';
        if ($count >= 232 && $count <= 255) {
            my $num = $count - 232;
            $self->{'ansi_sequences'}->{"GREY$num"}   = $esc . '38;5;' . $count . 'm';
            $self->{'ansi_sequences'}->{"B_GREY$num"} = $esc . '48;5;' . $count . 'm';
        }
    } ## end foreach my $count (0 .. 255)

    # Generate symbols
    my $start  = 0x2010;
    my $finish = 0x2BFF;

    my $name = charnames::viacode(0x1F341);    # Maple Leaf
    $self->{'ansi_characters'}->{$name} = charnames::string_vianame($name);
    foreach my $u ($start .. $finish) {
        $name = charnames::viacode($u);
        next if ($name eq '');
        my $char = charnames::string_vianame($name);
        $char = '?' unless (defined($char));
        $self->{'ansi_characters'}->{$name} = $char;
    } ## end foreach my $u ($start .. $finish)
    $start  = 0x1F300;
    $finish = 0x1FBFF;
    foreach my $u ($start .. $finish) {
        $name = charnames::viacode($u);
        next if ($name eq '');
        my $char = charnames::string_vianame($name);
        $char = '?' unless (defined($char));
        $self->{'ansi_characters'}->{$name} = $char;
    } ## end foreach my $u ($start .. $finish)
    $self->{'debug'}->DEBUG(['Initialized ANSI']);
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
        foreach my $string (keys %{ $self->{'ansi_characters'} }) {
            $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_characters'}->{$string}/gi;
        }
    } ## end if (length($text) > 1)
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
