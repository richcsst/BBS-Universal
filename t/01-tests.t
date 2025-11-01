#!/usr/bin/env perl -T

use strict;
use Test::More tests => 14;
use Term::ANSIColor;

BEGIN {
	use_ok('BBS::Universal');
}

my $green = colored(['bright_green'], ' ok');
my $red   = colored(['red'],          ' not ok');

my $tree = {
    'BBS::Universal'               => $BBS::Universal::VERSION,
    'BBS::Universal::ASCII'        => $BBS::Universal::ASCII_VERSION,
    'BBS::Universal::ATASCII'      => $BBS::Universal::ATASCII_VERSION,
    'BBS::Universal::ANSI'         => $BBS::Universal::ANSI_VERSION,
    'BBS::Universal::PETSCII'      => $BBS::Universal::PETSCII_VERSION,
    'BBS::Universal::BBS_List'     => $BBS::Universal::BBS_LIST_VERSION,
    'BBS::Universal::CPU'          => $BBS::Universal::CPU_VERSION,
    'BBS::Universal::Messages'     => $BBS::Universal::MESSAGES_VERSION,
    'BBS::Universal::SysOp'        => $BBS::Universal::SYSOP_VERSION,
    'BBS::Universal::FileTransfer' => $BBS::Universal::FILETRANSFER_VERSION,
    'BBS::Universal::Users'        => $BBS::Universal::USERS_VERSION,
    'BBS::Universal::DB'           => $BBS::Universal::DB_VERSION,
    'BBS::Universal::Text_Editor'  => $BBS::Universal::TEXT_EDITOR_VERSION,
};

foreach my $name (sort(keys %{$tree})) {
	my $string = '';
	ok((defined($tree->{$name}) && $tree->{$name} > 0), $name);
    if (defined($tree->{$name}) && $tree->{$name} > 0) {
        $string .= colored(['bright_white'], sprintf('%-30s', $name)) . colored(['bright_yellow'], $tree->{$name}) . $green . "\n";
    } else {
        $string .= colored(['bright_white'], sprintf('%-30s', $name)) . 'undef' . $red . "\n";
    }
	diag($string);
}

exit(0);
