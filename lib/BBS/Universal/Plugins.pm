package BBS::Universal::Plugins;
BEGIN { our $VERSION = '0.001'; }

sub plugins_initialize {
    my $self = shift;
    return ($self);
}

sub plugin {
    my $self  = shift;
    my $count = shift;    # Corresponds to the number of extra commands added.

    if ($count == 1) {    # Add as many elsif statements for more than 1 custom plugin
    }
} ## end sub plugin
1;
