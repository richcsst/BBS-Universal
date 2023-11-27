package BBS::Universal::ATASCII;

use strict;
no strict 'subs';

use Debug::Easy;

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      atascii_output
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

my $sequences = {
    'ESC'         => chr(27),
    'UP'          => chr(28),
    'DOWN'        => chr(29),
    'LEFT'        => chr(30),
    'RIGHT'       => chr(31),
    'CLEAR'       => chr(125),
    'BACKSPACE'   => chr(126),
    'TAB'         => chr(127),
    'EOL'         => chr(155),
    'DELETE LINE' => chr(156),
    'INSERT LINE' => chr(157),
    'BELL'        => chr(253),
    'DELETE'      => chr(254),
    'INSERT'      => chr(255),
};

sub atascii_output {
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
} ## end sub atascii_output

1;
