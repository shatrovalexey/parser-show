#!/usr/bin/perl -I.

use mod::Config;
use mod::Data::Import;
use mod::Data::Host;
use mod::Parser;

my $config = mod::Config->getFileJSON(shift) or die q{No config};
my $host = mod::Data::Host->get(shift) or die q{No host};
my $parser = $host->getParser or die q{No parser};
my $sub = sub {
	+ $parser->perform
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});