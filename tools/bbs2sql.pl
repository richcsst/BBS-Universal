#!/usr/bin/env perl

use strict;

open(my $FILE, '<', shift(@ARGV));
chomp(my @bbs = <$FILE>);
close($FILE);

open(my $out,'>','bbs_list.sql');
print $out "USE BBSUniversal\n";

foreach my $line (@bbs) {
	my ($name,$url,$port) = split(/\s\s+|:/,$line);
	$port = 23 if ($port eq '' || ! defined($port));
	my $string = "REPLACE INTO bbs_listing (bbs_name,bbs_hostname,bbs_port,bbs_poster_id) VALUES (\"$name\",\"$url\",$port,1);\n";
	print $out $string;
	print $string;
}
close($out);
