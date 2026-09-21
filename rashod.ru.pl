#!/usr/bin/perl -I .

use strict;
use mod::Data::Host;
use mod::Data::Offer;
use mod::Data::Import;
use mod::UA;
use mod::IO;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('rashod.ru');
my $sub = sub {
	my $filePath = mod::UA->getInstance($host->getOrigin)->query($host->{'attrs'}{'xlsx'}, 'get' => 1) or die 'No xlsx';
	my $csvPath = &mod::IO::getXLSX2CSV($filePath) or die 'Error xlsx2csv';
	my $csv = &mod::IO::getCSV(qw{sep_char ,});
	my %cols = qw{
3	brand
5	art
7	title
11	name
8	price
4	path
6	activity
9	action
	};
	my $result = 0;
	my $fh = &mod::IO::getFileHandle($csvPath);
	while (my $row = $csv->getline($fh)) {
		my %item = map {$cols{$_} => $row->[$_]} keys %cols;

		warn($result)
		, $result += mod::Data::Offer->add(
			'price' => $item{'price'}
			, 'name' => $item{'name'}
			, 'title' => $item{'title'}
			, 'art' => $item{'art'}
			, 'brand' => $item{'brand'}
			, 'host' => $host->{'name'}
			, 'realm' => $host->{'realm'}
			, 'attrs' => {
				'path' => $item{'path'}
				, 'activity' => $item{'activity'}
				, 'action' => $item{'action'}
				,
			}
		);
	}
	$fh->close;

	$result
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});