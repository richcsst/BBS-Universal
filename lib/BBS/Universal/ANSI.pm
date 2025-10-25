package BBS::Universal::ANSI;
BEGIN { our $VERSION = '0.004'; }

sub ansi_initialize {
    my $self = shift;

    my $esc = chr(27);
    my $csi = $esc . '[';

    $self->{'ansi_prefix'}    = $csi;
    $self->{'ansi_sequences'} = {
        'SS2'                       => $esc . 'N',          # Single Shift Two
        'SS3'                       => $esc . 'O',          # Single Shift Three
        'CSI'                       => $esc . '[',          # Control Sequence Introducer
        'OSC'                       => $esc . ']',          # Operating System Command
        'SOS'                       => $esc . 'X',          # Start of String
        'ST'                        => $esc . "\\",         # String Terminator
        'DCS'                       => $esc . 'P',          # Device Control String
        'PM'                        => $esc . '^',          # Privacy Message
        'APC'                       => $esc . '_',          # Application Program Command
        'RING BELL'                 => chr(7),
        'BACKSPACE'                 => chr(8),
		'TAB'                       => chr(9),
        'RETURN'                    => chr(13),
        'LINEFEED'                  => chr(10),
        'NEWLINE'                   => chr(13) . chr(10),
        'FONT DOUBLE-HEIGHT TOP'    => $esc . '#3',
        'FONT DOUBLE-HEIGHT BOTTOM' => $esc . '#4',
        'FONT DEFAULT'              => $esc . '#5',
        'FONT DOUBLE-WIDTH'         => $esc . '#6',

        'CLS'        => $csi . '2J' . $csi . 'H',
        'CLEAR'      => $csi . '2J',
        'CLEAR LINE' => $csi . '0K',
        'CLEAR DOWN' => $csi . '0J',
        'CLEAR UP'   => $csi . '1J',
        'HOME'       => $csi . 'H',

        # Cursor
        'QUERY LOCATION' => $csi . '6n',
        'UP'             => $csi . 'A',
        'DOWN'           => $csi . 'B',
        'RIGHT'          => $csi . 'C',
        'LEFT'           => $csi . 'D',
        'NEXT LINE'      => $csi . 'E',
        'PREVIOUS LINE'  => $csi . 'F',
        'SAVE'           => $csi . 's',
        'RESTORE'        => $csi . 'u',
        'RESET'          => $csi . '0m',
        'CURSOR ON'      => $csi . '?25h',
        'CURSOR OFF'     => $csi . '?25l',
        'SCREEN 1'       => $csi . '?1049l',
        'SCREEN 2'       => $csi . '?1049h',

        # Attributes
        'BOLD'                    => $csi . '1m',
        'NORMAL'                  => $csi . '22m',
        'FAINT'                   => $csi . '2m',
        'ITALIC'                  => $csi . '3m',
        'UNDERLINE'               => $csi . '4m',
        'FRAMED ON'               => $csi . '51m',
        'FRAMED OFF'              => $csi . '54m',
        'ENCIRCLE ON'             => $csi . '52m',
        'ENCIRCLE OFF'            => $csi . '54m',
        'OVERLINE ON'             => $csi . '53m',
        'OVERLINE OFF'            => $csi . '55m',
        'DEFAULT UNDERLINE COLOR' => $csi . '59m',
        'SUPERSCRIPT ON'          => $csi . '73m',
        'SUBSCRIPT ON'            => $csi . '74m',
        'SUPERSCRIPT OFF'         => $csi . '75m',
        'SUBSCRIPT OFF'           => $csi . '75m',
        'SLOW BLINK'              => $csi . '5m',
        'RAPID BLINK'             => $csi . '6m',
        'INVERT'                  => $csi . '7m',
        'REVERSE'                 => $csi . '7m',
        'HIDE'                    => $csi . '8m',
        'REVEAL'                  => $csi . '28m',
        'CROSSED OUT'             => $csi . '9m',
        'DEFAULT FONT'            => $csi . '10m',
        'PROPORTIONAL ON'         => $csi . '26m',
        'PROPORTIONAL OFF'        => $csi . '50m',

        # Color

        # Foreground color
        'DEFAULT'                 => $csi . '39m',
        'BLACK'                   => $csi . '30m',
        'RED'                     => $csi . '31m',
        'DARK RED'                => $csi . '38:2:139:0:0m',
        'PINK'                    => $csi . '38;5;198m',
        'ORANGE'                  => $csi . '38;5;202m',
        'NAVY'                    => $csi . '38;5;17m',
        'BROWN'                   => $csi . '38:2:165:42:42m',
        'MAROON'                  => $csi . '38:2:128:0:0m',
        'OLIVE'                   => $csi . '38:2:128:128:0m',
        'PURPLE'                  => $csi . '38:2:128:0:128m',
        'TEAL'                    => $csi . '38:2:0:128:128m',
        'GREEN'                   => $csi . '32m',
        'YELLOW'                  => $csi . '33m',
        'BLUE'                    => $csi . '34m',
        'MAGENTA'                 => $csi . '35m',
        'CYAN'                    => $csi . '36m',
        'WHITE'                   => $csi . '37m',
        'BRIGHT BLACK'            => $csi . '90m',
        'BRIGHT RED'              => $csi . '91m',
        'BRIGHT GREEN'            => $csi . '92m',
        'BRIGHT YELLOW'           => $csi . '93m',
        'BRIGHT BLUE'             => $csi . '94m',
        'BRIGHT MAGENTA'          => $csi . '95m',
        'BRIGHT CYAN'             => $csi . '96m',
        'BRIGHT WHITE'            => $csi . '97m',
        'FIREBRICK'               => $csi . '38:2:178:34:34m',
        'CRIMSON'                 => $csi . '38:2:220:20:60m',
        'TOMATO'                  => $csi . '38:2:255:99:71m',
        'CORAL'                   => $csi . '38:2:255:127:80m',
        'INDIAN RED'              => $csi . '38:2:205:92:92m',
        'LIGHT CORAL'             => $csi . '38:2:240:128:128m',
        'DARK SALMON'             => $csi . '38:2:233:150:122m',
        'SALMON'                  => $csi . '38:2:250:128:114m',
        'LIGHT SALMON'            => $csi . '38:2:255:160:122m',
        'ORANGE RED'              => $csi . '38:2:255:69:0m',
        'DARK ORANGE'             => $csi . '38:2:255:140:0m',
        'GOLD'                    => $csi . '38:2:255:215:0m',
        'DARK GOLDEN'             => $csi . '38:2:184:134:11m',
        'GOLDEN ROD'              => $csi . '38:2:218:165:32m',
        'PALE GOLDEN ROD'         => $csi . '38:2:238:232:170m',
        'DARK KHAKI'              => $csi . '38:2:189:183:107m',
        'KHAKI'                   => $csi . '38:2:240:230:140m',
        'YELLOW GREEN'            => $csi . '38:2:154:205:50m',
        'DARK OLIVE GREEN'        => $csi . '38:2:85:107:47m',
        'OLIVE DRAB'              => $csi . '38:2:107:142:35m',
        'LAWN GREEN'              => $csi . '38:2:124:252:0m',
        'CHARTREUSE'              => $csi . '38:2:127:255:0m',
        'GREEN YELLOW'            => $csi . '38:2:173:255:47m',
        'DARK GREEN'              => $csi . '38:2:0:100:0m',
        'FOREST GREEN'            => $csi . '38:2:34:139:34m',
        'LIME GREEN'              => $csi . '38:2:50:205:50m',
        'LIGHT GREEN'             => $csi . '38:2:144:238:144m',
        'PALE GREEN'              => $csi . '38:2:152:251:152m',
        'DARK SEA GREEN'          => $csi . '38:2:143:188:143m',
        'MEDIUM SPRING GREEN'     => $csi . '38:2:0:250:154m',
        'SPRING GREEN'            => $csi . '38:2:0:255:127m',
        'SEA GREEN'               => $csi . '38:2:46:139:87m',
        'MEDIUM AQUA MARINE'      => $csi . '38:2:102:205:170m',
        'MEDIUM SEA GREEN'        => $csi . '38:2:60:179:113m',
        'LIGHT SEA GREEN'         => $csi . '38:2:32:178:170m',
        'DARK SLATE GRAY'         => $csi . '38:2:47:79:79m',
        'DARK CYAN'               => $csi . '38:2:0:139:139m',
        'AQUA'                    => $csi . '38:2:0:255:255m',
        'LIGHT CYAN'              => $csi . '38:2:224:255:255m',
        'DARK TURQUOISE'          => $csi . '38:2:0:206:209m',
        'TURQUOISE'               => $csi . '38:2:64:224:208m',
        'MEDIUM TURQUOISE'        => $csi . '38:2:72:209:204m',
        'PALE TURQUOISE'          => $csi . '38:2:175:238:238m',
        'AQUA MARINE'             => $csi . '38:2:127:255:212m',
        'POWDER BLUE'             => $csi . '38:2:176:224:230m',
        'CADET BLUE'              => $csi . '38:2:95:158:160m',
        'STEEL BLUE'              => $csi . '38:2:70:130:180m',
        'CORN FLOWER BLUE'        => $csi . '38:2:100:149:237m',
        'DEEP SKY BLUE'           => $csi . '38:2:0:191:255m',
        'DODGER BLUE'             => $csi . '38:2:30:144:255m',
        'LIGHT BLUE'              => $csi . '38:2:173:216:230m',
        'SKY BLUE'                => $csi . '38:2:135:206:235m',
        'LIGHT SKY BLUE'          => $csi . '38:2:135:206:250m',
        'MIDNIGHT BLUE'           => $csi . '38:2:25:25:112m',
        'DARK BLUE'               => $csi . '38:2:0:0:139m',
        'MEDIUM BLUE'             => $csi . '38:2:0:0:205m',
        'ROYAL BLUE'              => $csi . '38:2:65:105:225m',
        'BLUE VIOLET'             => $csi . '38:2:138:43:226m',
        'INDIGO'                  => $csi . '38:2:75:0:130m',
        'DARK SLATE BLUE'         => $csi . '38:2:72:61:139m',
        'SLATE BLUE'              => $csi . '38:2:106:90:205m',
        'MEDIUM SLATE BLUE'       => $csi . '38:2:123:104:238m',
        'MEDIUM PURPLE'           => $csi . '38:2:147:112:219m',
        'DARK MAGENTA'            => $csi . '38:2:139:0:139m',
        'DARK VIOLET'             => $csi . '38:2:148:0:211m',
        'DARK ORCHID'             => $csi . '38:2:153:50:204m',
        'MEDIUM ORCHID'           => $csi . '38:2:186:85:211m',
        'THISTLE'                 => $csi . '38:2:216:191:216m',
        'PLUM'                    => $csi . '38:2:221:160:221m',
        'VIOLET'                  => $csi . '38:2:238:130:238m',
        'ORCHID'                  => $csi . '38:2:218:112:214m',
        'MEDIUM VIOLET RED'       => $csi . '38:2:199:21:133m',
        'PALE VIOLET RED'         => $csi . '38:2:219:112:147m',
        'DEEP PINK'               => $csi . '38:2:255:20:147m',
        'HOT PINK'                => $csi . '38:2:255:105:180m',
        'LIGHT PINK'              => $csi . '38:2:255:182:193m',
        'ANTIQUE WHITE'           => $csi . '38:2:250:235:215m',
        'BEIGE'                   => $csi . '38:2:245:245:220m',
        'BISQUE'                  => $csi . '38:2:255:228:196m',
        'BLANCHED ALMOND'         => $csi . '38:2:255:235:205m',
        'WHEAT'                   => $csi . '38:2:245:222:179m',
        'CORN SILK'               => $csi . '38:2:255:248:220m',
        'LEMON CHIFFON'           => $csi . '38:2:255:250:205m',
        'LIGHT GOLDEN ROD YELLOW' => $csi . '38:2:250:250:210m',
        'LIGHT YELLOW'            => $csi . '38:2:255:255:224m',
        'SADDLE BROWN'            => $csi . '38:2:139:69:19m',
        'SIENNA'                  => $csi . '38:2:160:82:45m',
        'CHOCOLATE'               => $csi . '38:2:210:105:30m',
        'PERU'                    => $csi . '38:2:205:133:63m',
        'SANDY BROWN'             => $csi . '38:2:244:164:96m',
        'BURLY WOOD'              => $csi . '38:2:222:184:135m',
        'TAN'                     => $csi . '38:2:210:180:140m',
        'ROSY BROWN'              => $csi . '38:2:188:143:143m',
        'MOCCASIN'                => $csi . '38:2:255:228:181m',
        'NAVAJO WHITE'            => $csi . '38:2:255:222:173m',
        'PEACH PUFF'              => $csi . '38:2:255:218:185m',
        'MISTY ROSE'              => $csi . '38:2:255:228:225m',
        'LAVENDER BLUSH'          => $csi . '38:2:255:240:245m',
        'LINEN'                   => $csi . '38:2:250:240:230m',
        'OLD LACE'                => $csi . '38:2:253:245:230m',
        'PAPAYA WHIP'             => $csi . '38:2:255:239:213m',
        'SEA SHELL'               => $csi . '38:2:255:245:238m',
        'MINT CREAM'              => $csi . '38:2:245:255:250m',
        'SLATE GRAY'              => $csi . '38:2:112:128:144m',
        'LIGHT SLATE GRAY'        => $csi . '38:2:119:136:153m',
        'LIGHT STEEL BLUE'        => $csi . '38:2:176:196:222m',
        'LAVENDER'                => $csi . '38:2:230:230:250m',
        'FLORAL WHITE'            => $csi . '38:2:255:250:240m',
        'ALICE BLUE'              => $csi . '38:2:240:248:255m',
        'GHOST WHITE'             => $csi . '38:2:248:248:255m',
        'HONEYDEW'                => $csi . '38:2:240:255:240m',
        'IVORY'                   => $csi . '38:2:255:255:240m',
        'AZURE'                   => $csi . '38:2:240:255:255m',
        'SNOW'                    => $csi . '38:2:255:250:250m',
        'DIM GRAY'                => $csi . '38:2:105:105:105m',
        'DARK GRAY'               => $csi . '38:2:169:169:169m',
        'SILVER'                  => $csi . '38:2:192:192:192m',
        'LIGHT GRAY'              => $csi . '38:2:211:211:211m',
        'GAINSBORO'               => $csi . '38:2:220:220:220m',
        'WHITE SMOKE'             => $csi . '38:2:245:245:245m',

        # Background color
        'B_DEFAULT'                 => $csi . '49m',
        'B_BLACK'                   => $csi . '40m',
        'B_RED'                     => $csi . '41m',
        'B_DARK RED'                => $csi . '48:2:139:0:0m',
        'B_PINK'                    => $csi . '48;5;198m',
        'B_ORANGE'                  => $csi . '48;5;202m',
        'B_NAVY'                    => $csi . '48;5;17m',
        'B_BROWN'                   => $csi . '48:2:165:42:42m',
        'B_MAROON'                  => $csi . '48:2:128:0:0m',
        'B_OLIVE'                   => $csi . '48:2:128:128:0m',
        'B_PURPLE'                  => $csi . '48:2:128:0:128m',
        'B_TEAL'                    => $csi . '48:2:0:128:128m',
        'B_GREEN'                   => $csi . '42m',
        'B_YELLOW'                  => $csi . '43m',
        'B_BLUE'                    => $csi . '44m',
        'B_MAGENTA'                 => $csi . '45m',
        'B_CYAN'                    => $csi . '46m',
        'B_WHITE'                   => $csi . '47m',
        'B_BRIGHT BLACK'            => $csi . '100m',
        'B_BRIGHT RED'              => $csi . '101m',
        'B_BRIGHT GREEN'            => $csi . '102m',
        'B_BRIGHT YELLOW'           => $csi . '103m',
        'B_BRIGHT BLUE'             => $csi . '104m',
        'B_BRIGHT MAGENTA'          => $csi . '105m',
        'B_BRIGHT CYAN'             => $csi . '106m',
        'B_BRIGHT WHITE'            => $csi . '107m',
        'B_FIREBRICK'               => $csi . '48:2:178:34:34m',
        'B_CRIMSON'                 => $csi . '48:2:220:20:60m',
        'B_TOMATO'                  => $csi . '48:2:255:99:71m',
        'B_CORAL'                   => $csi . '48:2:255:127:80m',
        'B_INDIAN RED'              => $csi . '48:2:205:92:92m',
        'B_LIGHT CORAL'             => $csi . '48:2:240:128:128m',
        'B_DARK SALMON'             => $csi . '48:2:233:150:122m',
        'B_SALMON'                  => $csi . '48:2:250:128:114m',
        'B_LIGHT SALMON'            => $csi . '48:2:255:160:122m',
        'B_ORANGE RED'              => $csi . '48:2:255:69:0m',
        'B_DARK ORANGE'             => $csi . '48:2:255:140:0m',
        'B_GOLD'                    => $csi . '48:2:255:215:0m',
        'B_DARK GOLDEN'             => $csi . '48:2:184:134:11m',
        'B_GOLDEN ROD'              => $csi . '48:2:218:165:32m',
        'B_PALE GOLDEN ROD'         => $csi . '48:2:238:232:170m',
        'B_DARK KHAKI'              => $csi . '48:2:189:183:107m',
        'B_KHAKI'                   => $csi . '48:2:240:230:140m',
        'B_YELLOW GREEN'            => $csi . '48:2:154:205:50m',
        'B_DARK OLIVE GREEN'        => $csi . '48:2:85:107:47m',
        'B_OLIVE DRAB'              => $csi . '48:2:107:142:35m',
        'B_LAWN GREEN'              => $csi . '48:2:124:252:0m',
        'B_CHARTREUSE'              => $csi . '48:2:127:255:0m',
        'B_GREEN YELLOW'            => $csi . '48:2:173:255:47m',
        'B_DARK GREEN'              => $csi . '48:2:0:100:0m',
        'B_FOREST GREEN'            => $csi . '48:2:34:139:34m',
        'B_LIME GREEN'              => $csi . '48:2:50:205:50m',
        'B_LIGHT GREEN'             => $csi . '48:2:144:238:144m',
        'B_PALE GREEN'              => $csi . '48:2:152:251:152m',
        'B_DARK SEA GREEN'          => $csi . '48:2:143:188:143m',
        'B_MEDIUM SPRING GREEN'     => $csi . '48:2:0:250:154m',
        'B_SPRING GREEN'            => $csi . '48:2:0:255:127m',
        'B_SEA GREEN'               => $csi . '48:2:46:139:87m',
        'B_MEDIUM AQUA MARINE'      => $csi . '48:2:102:205:170m',
        'B_MEDIUM SEA GREEN'        => $csi . '48:2:60:179:113m',
        'B_LIGHT SEA GREEN'         => $csi . '48:2:32:178:170m',
        'B_DARK SLATE GRAY'         => $csi . '48:2:47:79:79m',
        'B_DARK CYAN'               => $csi . '48:2:0:139:139m',
        'B_AQUA'                    => $csi . '48:2:0:255:255m',
        'B_LIGHT CYAN'              => $csi . '48:2:224:255:255m',
        'B_DARK TURQUOISE'          => $csi . '48:2:0:206:209m',
        'B_TURQUOISE'               => $csi . '48:2:64:224:208m',
        'B_MEDIUM TURQUOISE'        => $csi . '48:2:72:209:204m',
        'B_PALE TURQUOISE'          => $csi . '48:2:175:238:238m',
        'B_AQUA MARINE'             => $csi . '48:2:127:255:212m',
        'B_POWDER BLUE'             => $csi . '48:2:176:224:230m',
        'B_CADET BLUE'              => $csi . '48:2:95:158:160m',
        'B_STEEL BLUE'              => $csi . '48:2:70:130:180m',
        'B_CORN FLOWER BLUE'        => $csi . '48:2:100:149:237m',
        'B_DEEP SKY BLUE'           => $csi . '48:2:0:191:255m',
        'B_DODGER BLUE'             => $csi . '48:2:30:144:255m',
        'B_LIGHT BLUE'              => $csi . '48:2:173:216:230m',
        'B_SKY BLUE'                => $csi . '48:2:135:206:235m',
        'B_LIGHT SKY BLUE'          => $csi . '48:2:135:206:250m',
        'B_MIDNIGHT BLUE'           => $csi . '48:2:25:25:112m',
        'B_DARK BLUE'               => $csi . '48:2:0:0:139m',
        'B_MEDIUM BLUE'             => $csi . '48:2:0:0:205m',
        'B_ROYAL BLUE'              => $csi . '48:2:65:105:225m',
        'B_BLUE VIOLET'             => $csi . '48:2:138:43:226m',
        'B_INDIGO'                  => $csi . '48:2:75:0:130m',
        'B_DARK SLATE BLUE'         => $csi . '48:2:72:61:139m',
        'B_SLATE BLUE'              => $csi . '48:2:106:90:205m',
        'B_MEDIUM SLATE BLUE'       => $csi . '48:2:123:104:238m',
        'B_MEDIUM PURPLE'           => $csi . '48:2:147:112:219m',
        'B_DARK MAGENTA'            => $csi . '48:2:139:0:139m',
        'B_DARK VIOLET'             => $csi . '48:2:148:0:211m',
        'B_DARK ORCHID'             => $csi . '48:2:153:50:204m',
        'B_MEDIUM ORCHID'           => $csi . '48:2:186:85:211m',
        'B_THISTLE'                 => $csi . '48:2:216:191:216m',
        'B_PLUM'                    => $csi . '48:2:221:160:221m',
        'B_VIOLET'                  => $csi . '48:2:238:130:238m',
        'B_ORCHID'                  => $csi . '48:2:218:112:214m',
        'B_MEDIUM VIOLET RED'       => $csi . '48:2:199:21:133m',
        'B_PALE VIOLET RED'         => $csi . '48:2:219:112:147m',
        'B_DEEP PINK'               => $csi . '48:2:255:20:147m',
        'B_HOT PINK'                => $csi . '48:2:255:105:180m',
        'B_LIGHT PINK'              => $csi . '48:2:255:182:193m',
        'B_ANTIQUE WHITE'           => $csi . '48:2:250:235:215m',
        'B_BEIGE'                   => $csi . '48:2:245:245:220m',
        'B_BISQUE'                  => $csi . '48:2:255:228:196m',
        'B_BLANCHED ALMOND'         => $csi . '48:2:255:235:205m',
        'B_WHEAT'                   => $csi . '48:2:245:222:179m',
        'B_CORN SILK'               => $csi . '48:2:255:248:220m',
        'B_LEMON CHIFFON'           => $csi . '48:2:255:250:205m',
        'B_LIGHT GOLDEN ROD YELLOW' => $csi . '48:2:250:250:210m',
        'B_LIGHT YELLOW'            => $csi . '48:2:255:255:224m',
        'B_SADDLE BROWN'            => $csi . '48:2:139:69:19m',
        'B_SIENNA'                  => $csi . '48:2:160:82:45m',
        'B_CHOCOLATE'               => $csi . '48:2:210:105:30m',
        'B_PERU'                    => $csi . '48:2:205:133:63m',
        'B_SANDY BROWN'             => $csi . '48:2:244:164:96m',
        'B_BURLY WOOD'              => $csi . '48:2:222:184:135m',
        'B_TAN'                     => $csi . '48:2:210:180:140m',
        'B_ROSY BROWN'              => $csi . '48:2:188:143:143m',
        'B_MOCCASIN'                => $csi . '48:2:255:228:181m',
        'B_NAVAJO WHITE'            => $csi . '48:2:255:222:173m',
        'B_PEACH PUFF'              => $csi . '48:2:255:218:185m',
        'B_MISTY ROSE'              => $csi . '48:2:255:228:225m',
        'B_LAVENDER BLUSH'          => $csi . '48:2:255:240:245m',
        'B_LINEN'                   => $csi . '48:2:250:240:230m',
        'B_OLD LACE'                => $csi . '48:2:253:245:230m',
        'B_PAPAYA WHIP'             => $csi . '48:2:255:239:213m',
        'B_SEA SHELL'               => $csi . '48:2:255:245:238m',
        'B_MINT CREAM'              => $csi . '48:2:245:255:250m',
        'B_SLATE GRAY'              => $csi . '48:2:112:128:144m',
        'B_LIGHT SLATE GRAY'        => $csi . '48:2:119:136:153m',
        'B_LIGHT STEEL BLUE'        => $csi . '48:2:176:196:222m',
        'B_LAVENDER'                => $csi . '48:2:230:230:250m',
        'B_FLORAL WHITE'            => $csi . '48:2:255:250:240m',
        'B_ALICE BLUE'              => $csi . '48:2:240:248:255m',
        'B_GHOST WHITE'             => $csi . '48:2:248:248:255m',
        'B_HONEYDEW'                => $csi . '48:2:240:255:240m',
        'B_IVORY'                   => $csi . '48:2:255:255:240m',
        'B_AZURE'                   => $csi . '48:2:240:255:255m',
        'B_SNOW'                    => $csi . '48:2:255:250:250m',
        'B_DIM GRAY'                => $csi . '48:2:105:105:105m',
        'B_DARK GRAY'               => $csi . '48:2:169:169:169m',
        'B_SILVER'                  => $csi . '48:2:192:192:192m',
        'B_LIGHT GRAY'              => $csi . '48:2:211:211:211m',
        'B_GAINSBORO'               => $csi . '48:2:220:220:220m',
        'B_WHITE SMOKE'             => $csi . '48:2:245:245:245m',
        @_,
    };
    return ($self);
} ## end sub ansi_initialize

sub ansi_decode {
    my $self = shift;
    my $text = shift;

    if (length($text) > 1) {
        while ($text =~ /\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/) {
            my $color = $1;
            $color =~ s/_/ /;
            my $new = '[% RETURN %][% B_' . $color . ' %][% CLEAR LINE %][% RESET %]';
            $text =~ s/\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/$new/;
        } ## end while ($text =~ /\[\%\s+HORIZONTAL RULE (.*?)\s+\%\]/)
        while ($text =~ /\[\%\s+LOCATE (\d+),(\d+)\s+\%\]/) {
            my ($c, $r) = ($1, $2);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "$r;$c" . 'H';
            $text =~ s/\[\%\s+LOCATE $r,$c\s+\%\]/$replace/g;
        }
        while ($text =~ /\[\%\s+SCROLL UP (\d+)\s+\%\]/) {
            my $s       = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . $s . 'S';
            $text =~ s/\[\%\s+SCROLL UP $s\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+SCROLL DOWN (\d+)\s+\%\]/) {
            my $s       = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . $s . 'T';
            $text =~ s/\[\%\s+SCROLL DOWN $s\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+RGB (\d+),(\d+),(\d+)\s+\%\]/) {
            my ($r, $g, $b) = ($1 & 255, $2 & 255, $3 & 255);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "38:2:$r:$g:$b" . 'm';
            $text =~ s/\[\%\s+RGB $r,$g,$b\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+B_RGB (\d+),(\d+),(\d+)\s+\%\]/) {
            my ($r, $g, $b) = ($1 & 255, $2 & 255, $3 & 255);
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "48:2:$r:$g:$b" . 'm';
            $text =~ s/\[\%\s+B_RGB $r,$g,$b\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+(COLOR|COLOUR) (\d+)\s+\%\]/) {
            my $n       = $1;
            my $c       = $2 & 255;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "38:5:$c" . 'm';
            $text =~ s/\[\%\s+$n $c\s+\%\]/$replace/gi;
        } ## end while ($text =~ /\[\%\s+(COLOR|COLOUR) (\d+)\s+\%\]/)
        while ($text =~ /\[\%\s+(B_COLOR|B_COLOUR) (\d+)\s+\%\]/) {
            my $n       = $1;
            my $c       = $2 & 255;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . "48:5:$c" . 'm';
            $text =~ s/\[\%\s+$n $c\s+\%\]/$replace/gi;
        } ## end while ($text =~ /\[\%\s+(B_COLOR|B_COLOUR) (\d+)\s+\%\]/)
        while ($text =~ /\[\%\s+GREY (\d+)\s+\%\]/) {
            my $g       = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . '38:5:' . (232 + $g) . 'm';
            $text =~ s/\[\%\s+GREY $g\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+B_GREY (\d+)\s+\%\]/) {
            my $g       = $1;
            my $replace = $self->{'ansi_sequences'}->{'CSI'} . '48:5:' . (232 + $g) . 'm';
            $text =~ s/\[\%\s+B_GREY $g\s+\%\]/$replace/gi;
        }
        while ($text =~ /\[\%\s+BOX (.*?),(\d+),(\d+),(\d+),(\d+),(.*?)\s+\%\](.*?)\[\%\s+ENDBOX\s+\%\]/i) {
            my $replace = $self->box($1, $2, $3, $4, $5, $6, $7);
            $text =~ s/\[\%\s+BOX.*?\%\].*?\[\%\s+ENDBOX.*?\%\]/$replace/i;
        }
        while ($text =~ /\[\%\s+(.*?)\s+\%\]/ && (exists($self->{'ansi_sequences'}->{$1}) || defined(charnames::string_vianame($1)))) {
            my $string = $1;
            if (exists($self->{'ansi_sequences'}->{$string})) {
                if ($string =~ /CLS/i && ($self->{'sysop'} || $self->{'local_mode'})) {
                    my $ch = locate(($self->{'CACHE'}->get('START_ROW') + $self->{'CACHE'}->get('ROW_ADJUST')), 1) . cldown;
                    $text =~ s/\[\%\s+$string\s+\%\]/$ch/gi;
                } else {
                    $text =~ s/\[\%\s+$string\s+\%\]/$self->{'ansi_sequences'}->{$string}/gi;
                }
            } else {
                my $char = charnames::string_vianame($string);
                $char = '?' unless (defined($char));
                $text =~ s/\[\%\s+$string\s+\%\]/$char/gi;
            }
        } ## end while ($text =~ /\[\%\s+(.*?)\s+\%\]/...)
    } ## end if (length($text) > 1)
    return ($text);
} ## end sub ansi_decode

sub ansi_output {
    my $self = shift;
    my $text = shift;

    my $mlines = (exists($self->{'USER'}->{'max_rows'})) ? $self->{'USER'}->{'max_rows'} - 3 : 21;
    my $lines  = $mlines;
    $text = $self->ansi_decode($text);
    my $s_len = length($text);
    my $nl    = $self->{'ansi_sequences'}->{'NEWLINE'};

	if (0) { # $self->{'local_mode'}) {
		my @lines = split(/\n/,$text);
		my $size = $self->{'USER'}->{'max_rows'};
		while (scalar(@lines)) {
			my $line = shift(@lines);
			print $line;
			$size--;
			if ($size <= 0) {
				$size = $self->{'USER'}->{'max_rows'};
				last unless ($self->scroll(("\n")));
			} else {
				print "\n";
			}
		}
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
					next;
				}
			} ## end if ($char eq "\n")
			$self->send_char($char);
		} ## end foreach my $count (0 .. $s_len)
	}
    return (TRUE);
} ## end sub ansi_output
1;
