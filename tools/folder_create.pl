#!/usr/bin/env perl

use strict;

foreach my $name (
	qw(
		BBS
		General
		A800
		Atari-ST
		Atari-TT
		Atari-Falcon
		Commodore-PET
		Commodore-VIC20
		Commodore-C64
		Commodore-TED
		Commodore-Amiga
		TS-1000
		TS-2048
		TS-2068
		ZX-Spectrum
		Heathkit
		CP-M
		TRS-80-CoCo
		TRS-80-Portables
		TRS-80-Z80
		TRS-80-68000
		Apple-II
		Apple-Macintosh-68000
		Apple-Macintosh-PPC
		Apple-Macintosh-OS-X
		MS-DOS
		Win-3.11
		Win-NT
		Modern-Windows
		Linux
		FreeBSD
		Homebrew
		MSX
		Wang
		Oric
		Tektronix
	)
) {
	print "$name\n";
	mkdir $name unless (-d $name);
	system("touch 'files/files/$name/.empty'");
}
