#!/usr/bin/env perl

use strict;
use XML::RSS::LibXML;
use Data::Dumper::Simple;

my $rss = XML::RSS::LibXML->new;
my $feed = `curl https://moxie.foxnews.com/google-publisher/world.xml 2>/dev/null`;

$rss->parse($feed);

my $version     = $rss->version;
my $base        = $rss->base;
my $hash        = $rss->namespaces;
my $list        = $rss->items;
my $encoding    = $rss->encoding;
my $modules     = $rss->modules;
my $output      = $rss->output;
my $stylesheets = $rss->stylesheets;
my $num_items   = $rss->num_items;

foreach my $item (@{$list}) {
	print "      Title:  ",$item->{'title'},"\n";
	print "Description:  ",$item->{'description'},"\n";
	print "       Link:  ",$item->{'link'},"\n\n";
}

print Dumper($list);
