package BBS::Universal::ASCII;

# Pragmas
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
      ascii_output
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

sub ascii_output {
    my $self  = shift;
    my $text  = shift;
    my $s_len = length($text);

    foreach my $count (0 .. $s_len) {
        $self->send_char(substr($text, $count, 1));
    }
    return (TRUE);
} ## end sub ascii_output

1;
