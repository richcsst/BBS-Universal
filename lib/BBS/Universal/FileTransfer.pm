package BBS::Universal::FileTransfer;

use strict;
no strict qw( subs refs );

use Debug::Easy;
use File::Basename;

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
      load_file
      save_file
      send_file
      receive_file
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

sub load_file {
    my $self = shift;
    my $file = shift;

    my $filename = sprintf('%s.%s', $file, $self->{'suffixes'}->[$self->{'mode'}]);
    open(my $FILE, '<', $filename);
    my @text = <$FILE>;
    close($FILE);
    chomp(@text);
    return (join("\n", @text));
} ## end sub load_file

sub save_file {
    my $self = shift;
    return (TRUE);
}

sub receive_file {
    my $self = shift;
}

sub send_file {
    my $self = shift;
    return (TRUE);
}

1;
