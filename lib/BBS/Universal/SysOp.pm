package BBS::Universal::SysOp;

use strict;
no strict 'subs';

use Debug::Easy;
use Term::ReadKey;

BEGIN {
    require Exporter;

    our $VERSION   = '0.001';
    our @ISA       = qw(Exporter);
    our @EXPORT    = qw(
		_sysop_parse_menu
	);
    our @EXPORT_OK = qw();
} ## end BEGIN

sub _sysop_parse_menu {
	my $debug = shift;
	open(my $FILE,'<','files/main/sysop.txt');
	my $mapping;
	my $mode = 1;
	my $text = '';
	while(chomp(my $line = <$FILE>)) {
		if ($mode) {
			if ($line !~ /^---/) {
				my ($k,$c,$t) = split(/\|/,$line);
				$mapping->{uc($k)} = {
					'command' => $c,
					'text' => $t,
				};
			} else {
				$mode = 0;
			}
		} else {
			$text .= "$line\n";
		}
	}
	close($FILE);
	$debug->DEBUG(['Loaded SysOp Menu']);
	$debug->DEBUGMAX([$mapping]);
	print "$text\n";
	my $keys = '';
	foreach my $kmenu (sort(keys %{$mapping})) {
		print sprintf('%s > %s',uc($kmenu),$mapping->{$kmenu}->{'text'}),"\n";
		$keys .= $kmenu;
	}
	print "\nChoose> ";
	my $key;
	ReadMode 4;
	while(1) {
		$key = ReadKey(0);
		threads->yield();
		if (defined($key)) {
			$debug->DEBUGMAX(['Is Keypress (' . $keys . ') -> ' . $key]);
			if (exists($mapping->{uc($key)})) {
				ReadMode 0;
				return($mapping->{uc($key)}->{'command'});
			}
		}
	}
}

1;
