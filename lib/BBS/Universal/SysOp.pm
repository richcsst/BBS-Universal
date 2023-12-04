package BBS::Universal::SysOp;
BEGIN { our $VERSION = '0.001'; }

sub sysop_initialize {
    my $self = shift;

    my $versions = "\t" . colored(['bold yellow on_red'], ' NAME                          VERSION') . colored(['on_red'], clline) . "\n";
    foreach my $v (qw( perl bbs db filetransfer messages sysop users ascii atascii petscii vt102 )) {
        $versions .= "\t\t\t " . $self->{'CONF'}->{'VERSIONS'}->{$v} . "\n";
    }

    $self->{'sysop_special_characters'} = {
        'EURO'               => chr(128),
        'ELIPSIS'            => chr(133),
        'BULLET DOT'         => chr(149),
        'BIG HYPHEN'         => chr(150),
        'BIGGEST HYPHEN'     => chr(151),
        'TRADEMARK'          => chr(153),
        'CENTS'              => chr(162),
        'POUND'              => chr(163),
        'YEN'                => chr(165),
        'COPYRIGHT'          => chr(169),
        'DOUBLE LT'          => chr(171),
        'REGISTERED'         => chr(174),
        'OVERLINE'           => chr(175),
        'DEGREE'             => chr(176),
        'SQUARED'            => chr(178),
        'CUBED'              => chr(179),
        'MICRO'              => chr(181),
        'MIDDLE DOT'         => chr(183),
        'DOUBLE GT'          => chr(187),
        'QUARTER'            => chr(188),
        'HALF'               => chr(189),
        'THREE QUARTERS'     => chr(190),
        'INVERTED QUESTION'  => chr(191),
        'DIVISION'           => chr(247),
        'BULLET RIGHT'       => '▶',
        'BULLET LEFT'        => '◀',
        'SMALL BULLET RIGHT' => '▸',
        'SMALL BULLET LEFT'  => '◂',
        'BIG BULLET RIGHT'   => '►',
        'BIG BULLET LEFT'    => '◄',
        'BULLET DOWN'        => '▼',
        'BULLET UP'          => '▲',
        'WEDGE TOP LEFT'     => '◢',
        'WEDGE TOP RIGHT'    => '◣',
        'WEDGE BOTTOM LEFT'  => '◥',
        'WEDGE BOTTOM RIGHT' => '◤',

        # Tokens
        'CPU CORES'       => $self->{'CPU'}->{'CPU CORES'},
        'UPTIME'          => $self->get_uptime(),
        'VERSIONS'        => $versions,
        'BBS NAME'        => colored(['green'], $self->{'CONF'}->{'BBS NAME'}),
        'USERS COUNT'     => $self->users_count($self),
        'THREADS COUNT'   => int($self->{'CPU'}->{'CPU CORES'} * $self->{'CONF'}->{'THREAD MULTIPLIER'}),
        'DISK FREE SPACE' => sub {
            my @free     = split(/\n/, `df -h`);
            my $diskfree = '';
            foreach my $line (@free) {
                next if ($line =~ /tmp|boot/);
                if ($line =~ /^Filesystem/) {
                    $diskfree .= "\t" . colored(['bold yellow on_blue'], " $line") . colored(['on_blue'], clline) . "\n";
                } else {
                    $diskfree .= "\t\t\t $line\n";
                }
            } ## end foreach my $line (@free)
            return ($diskfree);
        },
    };

    #$self->{'debug'}->ERROR($self);exit;
    $self->{'debug'}->DEBUG(['Initialized SysOp object']);
    return ($self);
} ## end sub sysop_initialize

sub sysop_load_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = { 'TEXT' => '' };
    my $mode    = 1;
    my $text    = locate($row, 1) . cldown;
    open(my $FILE, '<', $file);

    while (chomp(my $line = <$FILE>)) {
        $self->{'debug'}->DEBUGMAX([$line]);
        if ($mode) {
            if ($line !~ /^---/) {
                my ($k, $c, $t) = split(/\|/, $line);
                $k = uc($k);
                $c = uc($c);
                $self->{'debug'}->DEBUGMAX([$k, $c, $t]);
                $mapping->{$k} = {
                    'command' => $c,
                    'text'    => $t,
                };
            } else {
                $mode = 0;
            }
        } else {
            $mapping->{'TEXT'} .= $self->sysop_detokenize($line) . "\n";
        }
    } ## end while (chomp(my $line = <$FILE>...))
    close($FILE);
    return ($mapping);
} ## end sub sysop_load_menu

sub sysop_parse_menu {
    my $self = shift;
    my $row  = shift;
    my $file = shift;

    my $mapping = $self->sysop_load_menu($row, $file);
    $self->{'debug'}->DEBUG(['Loaded SysOp Menu']);
    $self->{'debug'}->DEBUGMAX([$mapping]);
    print locate($row, 1), cldown, $mapping->{'TEXT'};
    my $keys = '';
    foreach my $kmenu (sort(keys %{$mapping})) {
        next if ($kmenu eq 'TEXT');
        print sprintf('%s%s%s %s %s', $self->{'sysop_special_characters'}->{'WEDGE TOP LEFT'}, colored(['reverse'], ' ' . uc($kmenu) . ' '), $self->{'sysop_special_characters'}->{'WEDGE BOTTOM RIGHT'}, $self->{'sysop_special_characters'}->{'BIG BULLET RIGHT'}, $mapping->{$kmenu}->{'text'}), "\n";
        $keys .= $kmenu;
    }
    print "\nChoose> ";
    my $key;
    do {
        $key = uc($self->sysop_keypress());
    } until (exists($mapping->{$key}));
    print $mapping->{$key}->{'command'}, "\n";
    return ($mapping->{$key}->{'command'});
} ## end sub sysop_parse_menu

sub sysop_keypress {
    my $self = shift;
    my $key;
    ReadMode 4;
    do {
        $key = ReadKey(0);
        threads->yield();
    } until (defined($key));
    ReadMode 0;
    return ($key);
} ## end sub sysop_keypress

sub sysop_user_edit {
    my $self = shift;

    return (TRUE);
}

sub sysop_detokenize {
    my $self = shift;
    my $text = shift;

    $self->{'debug'}->DEBUGMAX([$text]);    # Before
    foreach my $key (keys %{ $self->{'sysop_special_characters'} }) {
        my $ch = '';
        if ($key =~ /DISK FREE SPACE/) {
            $ch = $self->{'sysop_special_characters'}->{$key}->($self);
        } else {
            $ch = $self->{'sysop_special_characters'}->{$key};
        }
        $text =~ s/\[\%\s+$key\s+\%\]/$ch/gi;
    } ## end foreach my $key (keys %{ $self...})
    foreach my $name (keys %{ $self->{'vt102_sequences'} }) {
        my $ch = $self->{'vt102_sequences'}->{$name};
        $text =~ s/\[\%\s+$name\s+\%\]/$ch/gi;
    }
    $self->{'debug'}->DEBUGMAX([$text]);    # After

    return ($text);
} ## end sub sysop_detokenize

1;
