#!/usr/bin/env perl

use strict;

open(my $FILE, '<', shift(@ARGV));
chomp(my @bbs = <$FILE>);
close($FILE);

foreach my $line (@bbs) {
	my ($name,$url,$port) = split(/\s\s+|:/,$line);
	$port = 23 if ($port eq '' || ! defined($port));
	my $string = "INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (\"$name\",\"$url\",$port,1);\n";
	print $string;
}

# INSERT INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES ('BBS Universal Sample','localhost',9999,1);
