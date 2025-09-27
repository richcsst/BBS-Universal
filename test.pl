#!/usr/bin/env perl

use strict;
use Term::ReadKey;

my $key;
do {
	ReadMode 'ultra-raw';
	$key = ord(ReadKey(10));
	ReadMode 'normal';
	print "$key\n";
} until ($key == 3);
