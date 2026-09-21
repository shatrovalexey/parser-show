#!/usr/bin/perl -I .

use strict;
use mod::Codec;
use mod::Data::Host;
use mod::Data::Import;
use mod::Data::Offer;
use mod::UA;
use mod::Config;
use mod::Parser;
use Data::Dumper;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('b2b-rapid1.ru');
my $url = $host->getURL($host->{'attrs'}{'api'}, %{$host->{'attrs'}{'args'}});
my $sub = sub {
	my ($resp) = $host->getUA->query($url, 'get') or return;

	# open my $fh, '>:raw', '1.json';$fh->binmode;$fh->print($resp->decoded_content);$fh->close;exit;

	my $data = &mod::Codec::getDecodeJSON($resp->decoded_content) or return;
	my $result = 0;

	$result += mod::Data::Offer->add(%$_) foreach map + {
		'art' => $_->{'CodeID'}
		, 'realm' => $host->{'realm'}
		, 'host' => $host->{'name'}
		, 'brand' => $_->{'Vendor'}
		, 'name' => $_->{'Name'}
		, 'title' => $_->{'Name'}
		, 'price' => $_->{'Krup_Price_RUR'}
		, 'attrs' => {
			'quantity' => {
				'value' => $_->{'UnitsTotal'}
				, 'free' => $_->{'UnitsFree'}
				, 'transit' => $_->{'UnitsExpected'}
				, 'availability' => $_->{'UnitsRezerv'}
			}
			,
		}
		, 'src' => $_
		,
	}, grep ref eq 'HASH', @{$data->{'price'}};

	$result
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});