#!/usr/bin/env perl

use strict;

use Class::Inspector;
use BBS::Universal;
use Data::Dumper::Simple;
$Data::Dumper::Sortkeys=1;$Data::Dumper::Purity=1;
my $results = {
	'sub-classes' => Class::Inspector->subclasses('BBS::Universal'),
	'methods' => Class::Inspector->methods('BBS::Universal'),
};

print Dumper($results);
