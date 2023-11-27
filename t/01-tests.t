#!/usr/bin/env perl -T

use strict;
use Test::More tests => 1;
use BBS::Universal;

my $bbs = BBS::Universal->new();
isa_ok($bbs, 'BBS::Universal');

exit(0);
