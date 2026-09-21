#!/usr/bin/perl -I .

use strict;
use utf8;
use mod::Config;
use mod::Data::Offer;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $dbh = mod::Data::Offer->_getDBA;
my $sth_sel = $dbh->prepare(<<'.');
SELECT
	`o1`.`id`
	, upper(concat_ws(?, `o1`.`art`, `o1`.`title`, `o1`.`name`)) AS `data`
FROM
	`offer` AS `o1`

		LEFT OUTER JOIN `offer_fts` AS `f1`
			ON (`f1`.`id` = `o1`.`id`)
WHERE
	(`f1`.`id` IS null);
.
$sth_sel->execute(q{ });

my @values;
my $dumpValue = sub {
	$dbh->do(<<'.' . join(q{,}, ('(?, ?)') x (@values / 2)), undef, @values) if @values;
INSERT IGNORE INTO
	`offer_fts`(`id`, `value`)
VALUES
.
	@values = ()
};
my $addValue = sub {
	my ($id, $value) = @_;

	push @values, $id, $value;

	$dumpValue->() if @values > 400
};

while (my ($id, $fts) = $sth_sel->fetchrow_array) {
	warn $id;
	$fts =~ s{[^A-Z0-9]+}{ }guson;

	while ($fts =~ m{\b[A-Z0-9]}gcsu) {
		my $value = $&;

		$value .= substr($fts, pos $fts) =~ s{\s+}{}gusor;
		$value = substr $value, 0, 80;
		$addValue->($id, uc $value);
	}
}
$dumpValue->();

$sth_sel->finish;
$dbh->disconnect;