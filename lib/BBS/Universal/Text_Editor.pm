package BBS::Universal::Text_Editor;
BEGIN { our $VERSION = '0.001'; }

sub text_editor_initialize {
	my $self = shift;

	$self->{'debug'}->DEBUG(['Text Editor Initialized']);
	return ($self);
} ## end sub ascii_initialize

sub text_editor {
	my $self = shift;
}
1;
