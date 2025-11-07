package BBS::Universal::Text_Editor;
BEGIN { our $VERSION = '0.001'; }

sub text_editor_initialize {
    my $self = shift;

    $self->{'debug'}->DEBUG(['Start Text Editor Initialize']);
    $self->{'debug'}->DEBUG(['End Text Editor Initialize']);
    return ($self);
}

sub text_editor_edit {
	my $self = shift;

    $self->{'debug'}->DEBUG(['Start Text Editor Edit']);
    $self->{'debug'}->DEBUG(['End Text Editor Edit']);
}
1;
