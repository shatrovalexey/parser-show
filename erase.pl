#!/usr/bin/perl -I .

# use strict;
use warnings;
use mod::Config;
use mod::Data::Offer;
use mod::String;
use List::Util qw{all};
use String::Util qw{trim};

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $dbh = mod::Data::Offer->_getDBA;
my $sth_del = $dbh->prepare(<<'.');
DELETE
	`o1`.*
FROM
	`offer` AS `o1`
WHERE
	position(? IN `o1`.`fts`);
.
foreach my $brand (mod::Data::Brand->_getList(1)) {
	my $_brand = &mod::String::getAlnum($brand);

	warn qq{$brand: } . int $sth_del->execute($_brand) if length $_brand
}
$sth_del->finish;

my $rxReplace = qr{^(?:${\mod::Data::Brand->_getRX}|${\mod::Data::Brand->_getRXExcept})\s*};
my $sth_sel = $dbh->prepare(<<'.');
SELECT
	`o1`.`id`
	, `o1`.`art`
FROM
	`offer` AS `o1`
		, `brand` AS `b1`
WHERE
	position(`b1`.`name` IN `o1`.`art`)
		OR (
			char_length(`b1`.`alt`)
				AND position(`b1`.`alt` IN `o1`.`art`)
		);
.
my $sth_upd = $dbh->prepare(<<'.');
UPDATE IGNORE
	`offer` AS `o1`
SET
	`o1`.`art` := ?
WHERE
	(`o1`.`id` = ?);
.
$sth_sel->execute;

while (my ($id, $art) = $sth_sel->fetchrow_array) {
	warn qq{$id: $&: } . int $sth_upd->execute($art, $id)
		if $art =~ s{$rxReplace}{}ugosin
}

$sth_upd->finish;
$sth_sel->finish;

$sth_sel = $dbh->prepare(<<'.');
SELECT
	`o1`.*
FROM
	`v_offer` AS `o1`
WHERE
	position(? IN `o1`.`art`);
.
$sth_del = $dbh->prepare(<<'.');
DELETE
	`o1`.*
FROM
	`offer` AS `o1`
WHERE
	(`o1`.`id` = ?);
.
my $sth_ins = $dbh->prepare(<<'.');
INSERT IGNORE INTO
	`offer`
SET
	`art` := ?
	, `host` := ?
	, `brand` := ?
	, `realm` := ?
	, `title` := ?
	, `name` := ?
	, `price` := ?
	, `attrs` := ?
	, `src` := ?;
.
$sth_sel->execute(q{/});
while (my $row = $sth_sel->fetchrow_hashref) {
	next unless $row->{'art'} =~ m{[A-Z0-9-]{5,}\s*/\s*[A-Z0-9-]{5,}}uson;

	my @arts = map &trim($_), split m{\s*/\s*}uson, delete $row->{'art'};

	next unless all {length > 4} @arts or next;

	warn $row->{'id'};

	$sth_ins->execute($_, delete @$row{+ qw{host brand realm title name price attrs src}})
		foreach @arts;

	$sth_del->execute($row->{'id'})
}
$sth_del->finish;
$sth_ins->finish;
$sth_sel->finish;

$sth_sel = $dbh->prepare(<<'.');
SELECT
	`o1`.`id`
	, `o1`.`art`
FROM
	`v_offer` AS `o1`
WHERE
	position(? IN `o1`.`art`);
.
$sth_upd = $dbh->prepare(<<'.');
UPDATE IGNORE
	`offer` AS `o1`
SET
	`o1`.`art` := ?
WHERE
	(`o1`.`id` = ?);
.
=end
$sth_del = $dbh->prepare(<<'.');
DELETE
	`o1`.*
FROM
	`offer` AS `o1`
WHERE
	(`o1`.`id` = ?);
.
=cut
$sth_sel->execute(q{-});
while (my ($id, $art) = $sth_sel->fetchrow_array) {
	warn $id;

	# $sth_del->execute($id) unless
	$sth_upd->execute($art =~ s{\-}{}ugosr, $id) > 0
}
# $sth_del->finish;
$sth_upd->finish;
$sth_sel->finish;
$dbh->disconnect;