package BBS::Universal::SysOp;

use strict;
no strict 'subs';

use Debug::Easy;
use Term::ReadKey;
use Term::ANSIScreen qw( :cursor :screen );

BEGIN {
    require Exporter;

    our $VERSION = '0.001';
    our @ISA     = qw(Exporter);
    our @EXPORT  = qw(
		_sysop_parse_menu
		_sysop_user_edit
    );
    our @EXPORT_OK = qw();
} ## end BEGIN

my $sysop_special_characters = {
	'EURO' => chr(128),
	'ELIPSIS' => chr(133),
	'BULLET' => chr(149),
	'BIG_HYPHEN' => chr(150),
	'BIGGEST_HYPHEN' => chr(151),
	'TRADEMARK' => chr(153),
	'CENTS' => chr(162),
	'POUND' => chr(163),
	'YEN'   => chr(165),
	'COPYRIGHT' => chr(169),
	'DOUBLE_LT' => chr(171),
	'REGISTERED' => chr(174),
	'OVERLINE'  => chr(175),
	'DEGREE'    => chr(176),
	'SQUARED'   => chr(178),
	'CUBED'     => chr(179),
	'MICRO'     => chr(181),
	'MIDDLE_DOT' => chr(183),
	'DOUBLE_GT'  => chr(187),
	'QUARTER'    => chr(188),
	'HALF'       => chr(189),
	'THREE_QUARTERS' => chr(190),
	'INVERTED QUESTION' => chr(191),
	'DIVISION' => chr(247),
};

sub _sysop_parse_menu {
    my $debug = shift;
	my $row   = shift;

    open(my $FILE, '<', 'files/main/sysop.txt');
    my $mapping;
    my $mode = 1;
    my $text = locate($row,1) . cldown;
    while (chomp(my $line = <$FILE>)) {
        if ($mode) {
            if ($line !~ /^---/) {
                my ($k, $c, $t) = split(/\|/, $line);
                $mapping->{ uc($k) } = {
                    'command' => $c,
                    'text'    => $t,
                };
            } else {
                $mode = 0;
            }
        } else {
            $text .= "$line\n";
        }
    } ## end while (chomp(my $line = <$FILE>...))
    close($FILE);
    $debug->DEBUG(['Loaded SysOp Menu']);
    $debug->DEBUGMAX([$mapping]);
    print "$text\n";
    my $keys = '';
    foreach my $kmenu (sort(keys %{$mapping})) {
        print sprintf('%s > %s', uc($kmenu), $mapping->{$kmenu}->{'text'}), "\n";
        $keys .= $kmenu;
    }
    print "\nChoose> ";
    my $key;
    ReadMode 4;
    while (1) {
        $key = ReadKey(0);
        threads->yield();
        if (defined($key)) {
            $debug->DEBUGMAX(['Is Keypress (' . $keys . ') -> ' . $key]);
            if (exists($mapping->{ uc($key) })) {
                ReadMode 0;
                return ($mapping->{ uc($key) }->{'command'});
            }
        } ## end if (defined($key))
    } ## end while (1)
} ## end sub _sysop_parse_menu

sub _sysop_user_edit {
	return(TRUE);
}

1;
