#!/usr/bin/perl -I .

use strict;
use warnings;
use mod::Config;
use mod::Data::Offer;

die 'Already running' if scalar `pgrep '$0'`;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';

until (undef) {
	eval {
		warn mod::Data::Offer->shrink;

		my $dbh = mod::Data::Offer->_getDBA;

		foreach my $table (grep !m{^v_}uson, @{$dbh->selectcol_arrayref(<<'.')}) {
SHOW TABLES;
.
			print STDERR qq{$table: };
			print STDERR $dbh->do(<<"."), "\n";
ALTER TABLE `$table` ALGORITHM COPY;
.
		}
		$dbh->do(<<'.');
PURGE BINARY LOGS BEFORE now();
.
	};

	last unless $@;

	warn $@
} continue {
	sleep 5
}