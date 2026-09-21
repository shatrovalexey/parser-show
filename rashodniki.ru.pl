#!/usr/bin/perl -I .

use strict;
use warnings;
use DBI;
use mod::Data::Offer::Collection;
use mod::Data::Host;
use mod::Data::Import;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('name' => 'rashodniki.ru', 'is_visible' => 0);
my $dsn = qq{dbi:mysql:$host->{'attrs'}{'database'};host=$host->{'attrs'}{'host'};port=$host->{'attrs'}{'port'}};
my $items = mod::Data::Offer::Collection->new('reverse' => 1);
my $dbh = DBI->connect($dsn, @{$host->{'attrs'}}{+qw{login password}}, $host->{'attrs'}{'attrs'});

$dbh->do(<<'.');
SET NAMES utf8mb4;
.
$items->add($_) foreach @{$dbh->selectall_arrayref(<<'.', {'Slice' => {},}, 0, 0)};
SELECT
	`fvp1`.`product_sku` AS `art`
	, `fvpmrr1`.`mf_name` AS `brand`
	, `fvprr1`.`product_name` AS `title`
	, `fvprr1`.`product_name` AS `name`
	, `fvpp1`.`product_price` AS `price`
FROM
	`f3agw_virtuemart_products` AS `fvp1`

		INNER JOIN `f3agw_virtuemart_product_prices` AS `fvpp1`
			ON (`fvp1`.`virtuemart_product_id` = `fvpp1`.`virtuemart_product_id`)

		INNER JOIN `f3agw_virtuemart_product_manufacturers` AS `fvpm1`
			ON (`fvp1`.`virtuemart_product_id` = `fvpm1`.`virtuemart_product_id`)

		INNER JOIN `f3agw_virtuemart_manufacturers_ru_ru` AS `fvpmrr1`
			ON (`fvpm1`.`virtuemart_manufacturer_id` = `fvpmrr1`.`virtuemart_manufacturer_id`)

		INNER JOIN `f3agw_virtuemart_products_ru_ru` AS `fvprr1`
			ON (`fvp1`.`virtuemart_product_id` = `fvprr1`.`virtuemart_product_id`)
WHERE 
	(`fvp1`.`published` > ?)
		AND (`fvpp1`.`product_price` > ?)
		AND char_length(`fvp1`.`product_sku`)
		AND char_length(`fvpmrr1`.`mf_name`);
.
$dbh->disconnect;

warn mod::Data::Import->doUpdate($host, $items)