package BBS::Universal::PETSCII;

use strict;
no strict 'subs';

use Debug::Easy;

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      petscii_output
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

my $sequences = {
    'CLEAR'         => chr(hex('0x93')),
    'WHITE'         => chr(5),
    'BLACK'         => chr(hex('0x90')),
    'RED'           => chr(hex('0x1C')),
    'GREEN'         => chr(hex('0x1E')),
    'BLUE'          => chr(hex('0x1F')),
    'DARK PURPLE'   => chr(hex('0x81')),
    'UNDERLINE ON'  => chr(2),
    'UNDERLINE OFF' => chr(hex('0x82')),
    'BLINK ON'      => chr(hex('0x0F')),
    'BLINK OFF'     => chr(hex('0x8F')),
    'REVERSE ON'    => chr(hex('0x12')),
    'REVERSE OFF'   => chr(hex('0x92')),
    'BROWN'         => chr(hex('0x95')),
    'PINK'          => chr(hex('0x96')),
    'DARK CYAN'     => chr(hex('0x97')),
    'GRAY'          => chr(hex('0x98')),
    'LIGHT GREEN'   => chr(hex('0x99')),
    'LIGHT BLUE'    => chr(hex('0x9A')),
    'LIGHT GRAY'    => chr(hex('0x9B')),
    'PURPLE'        => chr(hex('0x9C')),
    'YELLOW'        => chr(hex('0x9E')),
    'CYAN'          => chr(hex('0x9F')),
    'UP'            => chr(hex('0x91')),
    'DOWN'          => chr(hex('0x11')),
    'LEFT'          => chr(hex('0x9D')),
    'RIGHT'         => chr(hex('0x1D')),
    'ESC'           => chr(hex('0x1B')),
    'LINE FEED'     => chr(hex('0x0A')),
    'TAB'           => chr(9),
    'BELL'          => chr(7),
};

sub petscii_output {
    my $self  = shift;
    my $text  = shift;
    my $s_len = length($text);

    foreach my $string (keys %{$sequences}) {    # Decode macros
        $text =~ s/\[\% $string \%\]/$sequences->{$string}/gi;
    }
    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub petscii_output

1;
