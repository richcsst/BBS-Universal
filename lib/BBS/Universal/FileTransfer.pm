package BBS::Universal::FileTransfer;
BEGIN { our $VERSION = '0.001'; }

sub filetransfer_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['FileTransfer initialized']);
    return ($self);
} ## end sub filetransfer_initialize

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
