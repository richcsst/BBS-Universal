package BBS::Universal::VT102;

use strict;
use constant {
    TRUE  => 1,
    FALSE => 0
};

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      vt102_output
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

my $esc       = chr(27) . '[';
my $sequences = {
    'CLEAR'            => $esc . '2J',
    'UP'               => $esc . 'A',
    'DOWN'             => $esc . 'B',
    'RIGHT'            => $esc . 'C',
    'LEFT'             => $esc . 'D',
    'SAVE'             => $esc . 's',
    'RESTORE'          => $esc . 'u',
    'RESET'            => $esc . '0m',
    'BOLD'             => $esc . '1m',
    'FAINT'            => $esc . '2m',
    'ITALIC'           => $esc . '3m',
    'UNDERLINE'        => $esc . '4m',
    'SLOW BLINK'       => $esc . '5m',
    'RAPID BLINK'      => $esc . '6m',
    'INVERT'           => $esc . '7m',
    'CROSSED OUT'      => $esc . '9m',
    'DEFAULT FONT'     => $esc . '10m',
    'FONT1'            => $esc . '11m',
    'FONT2'            => $esc . '12m',
    'FONT3'            => $esc . '13m',
    'FONT4'            => $esc . '14m',
    'FONT5'            => $esc . '15m',
    'FONT6'            => $esc . '16m',
    'FONT7'            => $esc . '17m',
    'FONT8'            => $esc . '18m',
    'FONT9'            => $esc . '19m',
    'NORMAL'           => $esc . '21m',
    'BLACK'            => $esc . '30m',
    'RED'              => $esc . '31m',
    'GREEN'            => $esc . '32m',
    'YELLOW'           => $esc . '33m',
    'BLUE'             => $esc . '34m',
    'MAGENTA'          => $esc . '35m',
    'CYAN'             => $esc . '36m',
    'WHITE'            => $esc . '37m',
    'DEFAULT'          => $esc . '39m',
    'BRIGHT BLACK'     => $esc . '90m',
    'BRIGHT RED'       => $esc . '91m',
    'BRIGHT GREEN'     => $esc . '92m',
    'BRIGHT YELLOW'    => $esc . '93m',
    'BRIGHT BLUE'      => $esc . '94m',
    'BRIGHT MAGENTA'   => $esc . '95m',
    'BRIGHT CYAN'      => $esc . '96m',
    'BRIGHT WHITE'     => $esc . '97m',
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

sub vt102_output {
    my $self = shift;
    my $text = shift;

    foreach my $string (keys %{$sequences}) {
        $text =~ s/\[\% $string \%\]/$sequences->{$string}/gi;
    }
    my $s_len = length($text);
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub vt102_output

1;
