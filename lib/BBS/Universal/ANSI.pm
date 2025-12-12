package BBS::Universal::ANSI;
BEGIN { our $VERSION = '0.007'; }

# Returns a description of a token using the meta data.
sub ansi_description {
    my ($self, $code, $name) = @_;

    return ($self->{'ansi_meta'}->{$code}->{$name}->{'desc'});
}

sub ansi_type {
    my $self = shift;
    my $text = substr(shift,2);

    if ($text =~ /^\d+m/) {
        return('ANSI 16 COLORS');
    } elsif ($text =~ /^\d+\;\d\;\d+m/) {
        return('ANSI 256 COLOR');
    } elsif ($text =~ /^\d+\:\d\:\d+\:\d+\:\d+m/) {
        return('ANSI TRUECOLOR');
    }
}

sub ansi_decode {
    my ($self, $text) = @_;

    # Nothing to do for very short strings
    return($text) unless ((defined $text && length($text) > 1) || $text !~ /\[\%/);

    # If a literal screen reset token exists, remove it and run reset once.
    if ($text =~ /\[\%\s*SCREEN\s+RESET\s*\%\]/i) {
        $text =~ s/\[\%\s*SCREEN\s+RESET\s*\%\]//gis;
        system('reset');
    }

    # Convenience CSI
    my $am  = $self->{'ansi_meta'}->{'foreground'};
    my $csi = $self->{'ansi_meta'}->{'special'}->{'CSI'}->{'out'};

    #
    # Targeted parameterized tokens (single-pass). These are simple Regex -> CSI conversions.
    #
    $text =~ s/\[\%\s*LOCATE\s+(\d+)\s*,\s*(\d+)\s*\%\]/ $csi . "$2;$1" . 'H' /eigs;
    $text =~ s/\[\%\s*SCROLL\s+UP\s+(\d+)\s*\%\]/     $csi . $1 . 'S'           /eigs;
    $text =~ s/\[\%\s*SCROLL\s+DOWN\s+(\d+)\s*\%\]/   $csi . $1 . 'T'           /eigs;

    # HORIZONTAL RULE expands into a sequence of meta-tokens (resolved later).
    $text =~ s/\[\%\s*HORIZONTAL\s+RULE\s+(.*?)\s*\%\]/
      do {
          my $color = defined $1 && $1 ne '' ? uc $1 : 'DEFAULT';
          '[% RETURN %][% B_' . $color . ' %][% CLEAR LINE %][% RESET %]';
      }/eigs;

    $text =~ s/\[\%\s+UNDERLINE\s+COLOR\s+RGB\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s+\%\]/
      do { my ($r,$g,$b)=($1&255,$2&255,$3&255); $csi . "58:2:$r:$g:$b" }/eigs;
    $text =~ s/\[\%\s+UNDERLINE\s+COLOR\s+(.*?)\s+\%\]/
      do { my $c = substr($am->{$1}->{'out'},3); $csi . "58:5:$c" }/eigs;

    # 24-bit RGB foreground/background
    $text =~ s/\[\%\s+RGB\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s+\%\]/
      do { my ($r,$g,$b)=($1&255,$2&255,$3&255); $csi . "38:2:$r:$g:$b" . 'm' }/eigs;
    $text =~ s/\[\%\s+B_RGB\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s+\%\]/
      do { my ($r,$g,$b)=($1&255,$2&255,$3&255); $csi . "48:2:$r:$g:$b" . 'm' }/eigs;

    #
    # Flatten the ansi_meta lookup to a simple, case-insensitive hash for a single-pass
    # substitution of tokens like [% RED %], [% RESET %], etc.
    #
    if ($text =~ /CLS/i && $self->{'local_mode'}) {
        my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
        $text =~ s/\[\%\s+CLS\s+\%\]/$ch/gsi;
    }

    my %lookup;
    for my $code (qw(foreground background special clear cursor attributes)) {
        my $map = $self->{'ansi_meta'}->{$code} or next;
        while (my ($name, $info) = each %{$map}) {
            next unless (defined($info->{out}));
            $lookup{ lc $name } = $info->{out};
        }
    } ## end for my $code (qw(foreground background special clear cursor attributes))

    # Final single-pass replacement for remaining [% ... %] tokens.
    # If token matches a lookup entry, substitute; otherwise if it's a named char use charnames;
    # else leave token visible.
###
    $text =~ s/\[\%\s*(.+?)\s*\%\]/
      do {
          my $tok = $1;
          my $key = lc $tok;
          if ( exists $lookup{$key} ) {
              $lookup{$key};
          } elsif ( defined( my $char = charnames::string_vianame($tok) ) ) {
              $char;
          } else {
              $&;    # leave the original token intact
          }
      }/egis;
###
    return $text;
} ## end sub ansi_decode

sub ansi_output {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUG(['Start ANSI Output']);
    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $text = $self->ansi_decode($text);
    my $s_len = length($text);
    my $nl    = $self->{'ansi_meta'}->{'cursor'}->{'NEWLINE'}->{'out'};

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
                next;
            }
        } ## end if ($char eq "\n")
        $self->send_char($char);
    } ## end foreach my $count (0 .. $s_len)
    $self->{'debug'}->DEBUG(['End ANSI Output']);
    return (TRUE);
} ## end sub ansi_output

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27);
    my $csi = $esc . '[';

    $self->{'debug'}->DEBUG(['Start ANSI Initialize']);
    $self->{'ansi_prefix'} = $csi;

    # Helper builders to compact the meta spec
    my $pairs_to_map = sub {                                      # [name, out, desc] -> { name => { out, desc } }
        my (@defs) = @_;
        return { map { $_->[0] => { out => $_->[1], desc => $_->[2] } } @defs };
    };

    # Special sequences
    my $special = $pairs_to_map->(
        ['APC', "\e_",   'Application Program Command'],
        ['SS2', "\eN",   'Single Shift 2'],
        ['SS3', "\eO",   'Single Shift 3'],
        ['CSI', "\e[",   'Control Sequence Introducer'],
        ['OSC', "\e]",   'Operating System Command'],
        ['SOS', "\eX",   'Start Of String'],
        ['ST',  "\e\\",  'String Terminator'],
        ['DCS', "\eP",   'Device Control String'],
    );

    # Clear controls
    my $clear = $pairs_to_map->(
        ['CLS',        "\e[2J\e[H",           'Clear screen and place cursor at the top of the screen'],
        ['CLEAR',      "\e[2J",               'Clear screen and keep cursor location'],
        ['CLEAR LINE', "\e[0K",               'Clear the current line from cursor'],
        ['CLEAR DOWN', "\e[0J",               'Clear from cursor position to bottom of the screen'],
        ['CLEAR UP',   "\e[1J",               'Clear to the top of the screen from cursor position'],
    );

    # Cursor movement and control
    my $cursor = $pairs_to_map->(
        ['BACKSPACE',     chr(8),                   'Backspace'],
        ['RETURN',        chr(13),                  'Carriage Return (ASCII 13)'],
        ['LINEFEED',      chr(10),                  'Line feed (ASCII 10)'],
        ['NEWLINE',       chr(13) . chr(10),        'New line (ASCII 13 and ASCII 10)'],
        ['HOME',          "\e[H",              'Place cursor at top left of the screen'],
        ['UP',            "\e[A",              'Move cursor up one line'],
        ['DOWN',          "\e[B",              'Move cursor down one line'],
        ['RIGHT',         "\e[C",              'Move cursor right one space non-destructively'],
        ['LEFT',          "\e[D",              'Move cursor left one space non-destructively'],
        ['NEXT LINE',     "\e[E",              'Place the cursor at the beginning of the next line'],
        ['PREVIOUS LINE', "\e[F",              'Place the cursor at the beginning of the previous line'],
        ['SAVE',          "\e[s",              'Save cureent cursor position'],
        ['RESTORE',       "\e[u",              'Restore the cursor to the saved position'],
        ['CURSOR ON',     "\e[?25h",           'Turn the cursor on'],
        ['CURSOR OFF',    "\e[?25l",           'Turn the cursor off'],
        ['SCREEN 1',      "\e[?1049l",         'Set display to screen 1'],
        ['SCREEN 2',      "\e[?1049h",         'Set display to screen 2'],
    );

    # Text attributes
    my $attributes = $pairs_to_map->(
		['FONT 1',                    "\e[1m",  'ANSI FONT 1'],
		['FONT 2',                    "\e[2m",  'ANSI FONT 2'],
		['FONT 3',                    "\e[3m",  'ANSI FONT 3'],
		['FONT 4',                    "\e[4m",  'ANSI FONT 4'],
		['FONT 5',                    "\e[5m",  'ANSI FONT 5'],
		['FONT 6',                    "\e[6m",  'ANSI FONT 6'],
		['FONT 7',                    "\e[7m",  'ANSI FONT 7'],
		['FONT 8',                    "\e[8m",  'ANSI FONT 8'],
		['FONT 9',                    "\e[9m",  'ANSI FONT 9'],
        ['FONT DOUBLE-HEIGHT TOP',    "\e#3",    'Double-Height Font Top Portion'],
        ['FONT DOUBLE-HEIGHT BOTTOM', "\e#4",    'Double-Height Font Bottom Portion'],
        ['FONT DOUBLE-WIDTH',         "\e#6",    'Double-Width Font'],
        ['FONT DEFAULT SIZE',         "\e#5",    'Default Font Size'],
        ['RESET',                     "\e[0m",  'Restore all attributes and colors to their defaults'],
        ['BOLD',                      "\e[1m",  'Set to bold text'],
        ['NORMAL',                    "\e[22m", 'Turn off all attributes'],
        ['FAINT',                     "\e[2m",  'Set to faint (light) text'],
        ['ITALIC',                    "\e[3m",  'Set to italic text'],
        ['UNDERLINE',                 "\e[4m",  'Set to underlined text'],
        ['FRAMED',                    "\e[51m", 'Turn on framed text'],
        ['FRAMED OFF',                "\e[54m", 'Turn off framed text'],
        ['ENCIRCLED',                 "\e[52m", 'Turn on encircled letters'],
        ['ENCIRCLED OFF',             "\e[54m", 'Turn off encircled letters'],
        ['OVERLINED',                 "\e[53m", 'Turn on overlined text'],
        ['OVERLINED OFF',             "\e[55m", 'Turn off overlined text'],
        ['DEFAULT UNDERLINE COLOR',   "\e[59m", 'Set underline color to the default'],
        ['SUPERSCRIPT',               "\e[73m", 'Turn on superscript'],
        ['SUBSCRIPT',                 "\e[74m", 'Turn on superscript'],
        ['SUPERSCRIPT OFF',           "\e[75m", 'Turn off superscript'],
        ['SUBSCRIPT OFF',             "\e[75m", 'Turn off subscript'],
        ['SLOW BLINK',                "\e[5m",  'Set slow blink'],
        ['RAPID BLINK',               "\e[6m",  'Set rapid blink'],
        ['INVERT',                    "\e[7m",  'Invert text'],
        ['REVERSE',                   "\e[7m",  'Invert text'],
        ['HIDE',                      "\e[8m",  'Hide enclosed text'],
        ['REVEAL',                    "\e[28m", 'Reveal hidden text'],
        ['CROSSED OUT',               "\e[9m",  'Crossed out text'],
        ['FONT DEFAULT',              "\e[10m", 'Set default font'],
        ['PROPORTIONAL ON',           "\e[26m", 'Turn on proportional text'],
        ['PROPORTIONAL OFF',          "\e[50m", 'Turn off proportional text'],
        ['RING BELL',                 chr(7),   'Console bell'],
    );

    # Foreground (base 16 + bright variants)
    my @fg16 = (
        ['DEFAULT',"\e[39m",'Default foreground color'],
        ['BLACK',"\e[30m",'Black'],
        ['RED',"\e[31m",'Red'],
        ['GREEN',"\e[32m",'Green'],
        ['YELLOW',"\e[33m",'Yellow'],
        ['BLUE',"\e[34m",'Blue'],
        ['MAGENTA',"\e[35m",'Magenta'],
        ['CYAN',"\e[36m",'Cyan'],
        ['WHITE',"\e[37m",'White'],
        ['BRIGHT BLACK',"\e[90m",'Bright black'],
        ['BRIGHT RED',"\e[91m",'Bright red'],
        ['BRIGHT GREEN',"\e[92m",'Bright green'],
        ['BRIGHT YELLOW',"\e[93m",'Bright yellow'],
        ['BRIGHT BLUE',"\e[94m",'Bright blue'],
        ['BRIGHT MAGENTA',"\e[95m",'Bright magenta'],
        ['BRIGHT CYAN',"\e[96m",'Bright cyan'],
        ['BRIGHT WHITE',"\e[97m",'Bright white'],
    );

    # Foreground extensions: all named 256-color and truecolor entries

    my @fg_extra = (
        ['AIR FORCE BLUE',       "\e[38:2:93:138:168m",   'Air Force blue'],
        ['ALICE BLUE',           "\e[38:2:240:248:255m",  'Alice blue'],
        ['ALIZARIN CRIMSON',     "\e[38:2:227:38:54m",    'Alizarin crimson'],
        ['ANTIQUE WHITE',        "\e[38:2:250:235:215m",  'Antique white'],
        ['AQUA',                 "\e[38:2:0:255:255m",    'Aqua'],
        ['AQUA MARINE',          "\e[38:2:127:255:212m",  'Aqua marine'],
        ['AZURE',                "\e[38:2:240:255:255m",  'Azure'],
        ['BEIGE',                "\e[38:2:245:245:220m",  'Beige'],
        ['BISQUE',               "\e[38:2:255:228:196m",  'Bisque'],
        ['BLUE VIOLET',          "\e[38:2:138:43:226m",   'Blue violet'],
        ['BROWN',                "\e[38:2:165:42:42m",    'Brown'],
        ['BURLY WOOD',           "\e[38:2:222:184:135m",  'Burly wood'],
        ['CADET BLUE',           "\e[38:2:95:158:160m",   'Cadet blue'],
        ['CHARTREUSE',           "\e[38:2:127:255:0m",    'Chartreuse'],
        ['CHOCOLATE',            "\e[38:2:210:105:30m",   'Chocolate'],
        ['CORAL',                "\e[38:2:255:127:80m",   'Coral'],
        ['CORN FLOWER BLUE',     "\e[38:2:100:149:237m",  'Corn flower blue'],
        ['CORN SILK',            "\e[38:2:255:248:220m",  'Corn silk'],
        ['CRIMSON',              "\e[38:2:220:20:60m",    'Crimson'],
        ['DARK BLUE',            "\e[38:2:0:0:139m",      'Dark blue'],
        ['DARK CYAN',            "\e[38:2:0:139:139m",    'Dark cyan'],
        ['DARK GOLDEN ROD',      "\e[38:2:184:134:11m",   'Dark golden rod'],
        ['DARK GRAY',            "\e[38:2:169:169:169m",  'Dark gray'],
        ['DARK GREEN',           "\e[38:2:0:100:0m",      'Dark green'],
        ['DARK KHAKI',           "\e[38:2:189:183:107m",  'Dark khaki'],
        ['DARK MAGENTA',         "\e[38:2:139:0:139m",    'Dark magenta'],
        ['DARK OLIVE GREEN',     "\e[38:2:85:107:47m",    'Dark olive green'],
        ['DARK ORANGE',          "\e[38:2:255:140:0m",    'Dark orange'],
        ['DARK ORCHID',          "\e[38:2:153:50:204m",   'Dark orchid'],
        ['DARK RED',             "\e[38:2:139:0:0m",      'Dark red'],
        ['DARK SALMON',          "\e[38:2:233:150:122m",  'Dark salmon'],
        ['DARK SLATE BLUE',      "\e[38:2:72:61:139m",    'Dark slate blue'],
        ['DARK SLATE GRAY',      "\e[38:2:47:79:79m",     'Dark slate gray'],
        ['DARK TURQUOISE',       "\e[38:2:0:206:209m",    'Dark turquoise'],
        ['DEEP PINK',            "\e[38:2:255:20:147m",   'Deep pink'],
        ['DEEP SKY BLUE',        "\e[38:2:0:191:255m",    'Deep sky blue'],
        ['DIM GRAY',             "\e[38:2:105:105:105m",  'Dim gray'],
        ['DODGER BLUE',          "\e[38:2:30:144:255m",   'Dodger blue'],
        ['FIREBRICK',            "\e[38:2:178:34:34m",    'Firebrick'],
        ['FLORAL WHITE',         "\e[38:2:255:250:240m",  'Floral white'],
        ['FOREST GREEN',         "\e[38:2:34:139:34m",    'Forest green'],
        ['GAINSBORO',            "\e[38:2:220:220:220m",  'Gainsboro'],
        ['GHOST WHITE',          "\e[38:2:248:248:255m",  'Ghost white'],
        ['GOLD',                 "\e[38:2:255:215:0m",    'Gold'],
        ['GOLDEN ROD',           "\e[38:2:218:165:32m",   'Golden rod'],
        ['GREEN YELLOW',         "\e[38:2:173:255:47m",   'Green yellow'],
        ['HONEYDEW',             "\e[38:2:240:255:240m",  'Honeydew'],
        ['HOT PINK',             "\e[38:2:255:105:180m",  'Hot pink'],
        ['INDIAN RED',           "\e[38:2:205:92:92m",    'Indian red'],
        ['INDIGO',               "\e[38:2:75:0:130m",     'Indigo'],
        ['IVORY',                "\e[38:2:255:255:240m",  'Ivory'],
        ['KHAKI',                "\e[38:2:240:230:140m",  'Khaki'],
        ['LAWN GREEN',           "\e[38:2:124:252:0m",    'Lawn green'],
        ['LAVENDER',             "\e[38:2:230:230:250m",  'Lavender'],
        ['LAVENDER BLUSH',       "\e[38:2:255:240:245m",  'Lavender blush'],
        ['LEMON CHIFFON',        "\e[38:2:255:250:205m",  'Lemon chiffon'],
        ['LIGHT BLUE',           "\e[38:2:173:216:230m",  'Light blue'],
        ['LIGHT CORAL',          "\e[38:2:240:128:128m",  'Light coral'],
        ['LIGHT GRAY',           "\e[38:2:211:211:211m",  'Light gray'],
        ['LIGHT GREEN',          "\e[38:2:144:238:144m",  'Light green'],
        ['LIGHT PINK',           "\e[38:2:255:182:193m",  'Light pink'],
        ['LIGHT SALMON',         "\e[38:2:255:160:122m",  'Light salmon'],
        ['LIGHT SKY BLUE',       "\e[38:2:135:206:250m",  'Light sky blue'],
        ['LIGHT SLATE GRAY',     "\e[38:2:119:136:153m",  'Lisght slate gray'],
        ['LIGHT STEEL BLUE',     "\e[38:2:176:196:222m",  'Light steel blue'],
        ['LIGHT YELLOW',         "\e[38:2:255:255:224m",  'Light yellow'],
        ['LIME GREEN',           "\e[38:2:50:205:50m",    'Lime Green'],
        ['LINEN',                "\e[38:2:250:240:230m",  'Linen'],
        ['MAROON',               "\e[38:2:128:0:0m",      'Maroon'],
        ['MEDIUM AQUA MARINE',   "\e[38:2:102:205:170m",  'Medium aqua marine'],
        ['MEDIUM BLUE',          "\e[38:2:0:0:205m",      'Medium blue'],
        ['MEDIUM ORCHID',        "\e[38:2:186:85:211m",   'Medium orchid'],
        ['MEDIUM PURPLE',        "\e[38:2:147:112:219m",  'Medium purple'],
        ['MEDIUM SEA GREEN',     "\e[38:2:60:179:113m",   'Medium sea green'],
        ['MEDIUM SLATE BLUE',    "\e[38:2:123:104:238m",  'Medium slate blue'],
        ['MEDIUM SPRING GREEN',  "\e[38:2:0:250:154m",    'Medium spring green'],
        ['MEDIUM TURQUOISE',     "\e[38:2:72:209:204m",   'Medium turquoise'],
        ['MIDNIGHT BLUE',        "\e[38:2:25:25:112m",    'Midnight blue'],
        ['MINT CREAM',           "\e[38:2:245:255:250m",  'Mint green'],
        ['MOCCASIN',             "\e[38:2:255:228:181m",  'Moccasin'],
        ['NAVAJO WHITE',         "\e[38:2:255:222:173m",  'Navajo white'],
        ['NAVY',                 "\e[38;5;17m",           'Navy'],
        ['OLIVE',                "\e[38:2:128:128:0m",    'Olive'],
        ['OLIVE DRAB',           "\e[38:2:107:142:35m",   'Olive drab'],
        ['ORCHID',               "\e[38:2:218:112:214m",  'Orchid'],
        ['ORANGE',               "\e[38;5;202m",          'Orange'],
        ['ORANGE RED',           "\e[38:2:255:69:0m",     'Orange red'],
        ['PALE GOLDEN ROD',      "\e[38:2:238:232:170m",  'Pale golden rod'],
        ['PALE GREEN',           "\e[38:2:152:251:152m",  'Pale green'],
        ['PALE TURQUOISE',       "\e[38:2:175:238:238m",  'Pale turquoise'],
        ['PALE VIOLET RED',      "\e[38:2:219:112:147m",  'Pale violet red'],
        ['PEACH PUFF',           "\e[38:2:255:218:185m",  'Peach puff'],
        ['PERU',                 "\e[38:2:205:133:63m",   'Peru'],
        ['PINK',                 "\e[38;5;198m",          'Pink'],
        ['PLUM',                 "\e[38:2:221:160:221m",  'Plum'],
        ['POWDER BLUE',          "\e[38:2:176:224:230m",  'Powder blue'],
        ['PURPLE',               "\e[38:2:128:0:128m",    'Purple'],
        ['ROYAL BLUE',           "\e[38:2:65:105:225m",   'Royal blue'],
        ['ROSY BROWN',           "\e[38:2:188:143:143m",  'Rosy brown'],
        ['SADDLE BROWN',         "\e[38:2:139:69:19m",    'Saddle brown'],
        ['SALMON',               "\e[38:2:250:128:114m",  'Salmon'],
        ['SANDY BROWN',          "\e[38:2:244:164:96m",   'Sandy brown'],
        ['SEA GREEN',            "\e[38:2:46:139:87m",    'Sea green'],
        ['SEA SHELL',            "\e[38:2:255:245:238m",  'Sea shell'],
        ['SIENNA',               "\e[38:2:160:82:45m",    'Sienna'],
        ['SILVER',               "\e[38:2:192:192:192m",  'Silver'],
        ['SKY BLUE',             "\e[38:2:135:206:235m",  'Sky blue'],
        ['SLATE BLUE',           "\e[38:2:106:90:205m",   'Slate blue'],
        ['SLATE GRAY',           "\e[38:2:112:128:144m",  'Slate gray'],
        ['SNOW',                 "\e[38:2:255:250:250m",  'Snow'],
        ['SPRING GREEN',         "\e[38:2:0:255:127m",    'Spring green'],
        ['STEEL BLUE',           "\e[38:2:70:130:180m",   'Steel blue'],
        ['THISTLE',              "\e[38:2:216:191:216m",  'Thistle'],
        ['TOMATO',               "\e[38:2:255:99:71m",    'Tomato'],
        ['TURQUOISE',            "\e[38:2:64:224:208m",   'Turquoise'],
        ['VIOLET',               "\e[38:2:238:130:238m",  'Violet'],
        ['WHITE SMOKE',          "\e[38:2:245:245:245m",  'White smoke'],
        ['YELLOW GREEN',         "\e[38:2:154:205:50m",   'Yellow green'],
    );
	foreach my $count (16 .. 231) {
		push(@fg_extra, ["COLOR $count", "\e[38;5;${count}m", "ANSI 256 color $count"]);
	}
	foreach my $gray (232 .. 255) {
		push(@fg_extra, ['GRAY ' . ($gray - 232), "\e[38;5;${gray}m", 'ANSI 256 gray level ' . ($gray - 232)]);
	}

    # Sort all foreground lists alphabetically by the color name
    @fg16    = sort { $a->[0] cmp $b->[0] } @fg16;
    @fg_extra = sort { $a->[0] cmp $b->[0] } @fg_extra;

    my $foreground = $pairs_to_map->(
        map { [ $_->[0], $_->[1], $_->[2] ] } @fg16,
        map { [ $_->[0], $_->[1], $_->[2] ] } @fg_extra,
    );

    # Background (base 16 + bright variants)
    my @bg16 = (
        ['B_BLACK',"\e[40m",'Black'],
        ['B_BLUE',"\e[44m",'Blue'],
        ['B_BRIGHT BLACK',"\e[100m",'Bright black'],
        ['B_BRIGHT BLUE',"\e[104m",'Bright blue'],
        ['B_BRIGHT CYAN',"\e[106m",'Bright cyan'],
        ['B_BRIGHT GREEN',"\e[102m",'Bright green'],
        ['B_BRIGHT MAGENTA',"\e[105m",'Bright magenta'],
        ['B_BRIGHT RED',"\e[101m",'Bright red'],
        ['B_BRIGHT WHITE',"\e[107m",'Bright white'],
        ['B_BRIGHT YELLOW',"\e[103m",'Bright yellow'],
        ['B_CYAN',"\e[46m",'Cyan'],
        ['B_DEFAULT',"\e[49m",'Default background color'],
        ['B_GREEN',"\e[42m",'Green'],
        ['B_MAGENTA',"\e[45m",'Magenta'],
        ['B_RED',"\e[41m",'Red'],
        ['B_WHITE',"\e[47m",'White'],
        ['B_YELLOW',"\e[43m",'Yellow'],
    );

    # Derive full background extras from foreground extras by swapping 38 -> 48 in SGR
    my @bg_extra = map {
        my ($name, $code, $desc) = @$_;
        my $bg_code = $code;
        $bg_code =~ s/^\e\[38(;5;|:2:)/"\e[48".($1)/e;
        $bg_code = $bg_code =~ /^\e\[48/ ? $bg_code : ($code =~ s/^\e\[38/\e\[48/r);
        [ "B_${name}", $bg_code, $desc ]
    } @fg_extra;

    # Sort all background lists alphabetically by the color name
    @bg16     = sort { $a->[0] cmp $b->[0] } @bg16;
    @bg_extra = sort { $a->[0] cmp $b->[0] } @bg_extra;

    my $background = $pairs_to_map->(
        map { [ $_->[0], $_->[1], $_->[2] ] } @bg16,
        map { [ $_->[0], $_->[1], $_->[2] ] } @bg_extra,
    );

    $self->{'ansi_meta'} = {
        special    => $special,
        clear      => $clear,
        cursor     => $cursor,
        attributes => $attributes,
        foreground => $foreground,
        background => $background,
    };

    $self->{'debug'}->DEBUG(['End ANSI Initialize']);
	return($self);
} ## end sub ansi_initialize
1;
