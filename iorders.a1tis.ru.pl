#!/usr/bin/perl -I .

use strict;
use warnings;
use locale;
use utf8;
use List::Util qw{sum all};
use mod::URL;
use mod::DBA;
use mod::Codec;
use mod::Data::Import;
use mod::Data::Host;
use mod::Data::Offer;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('name' => 'iorders.a1tis.ru');

sub getFromApi {
	+ map +({
		'art' => $_->{'ItemId'}
		, 'brand' => $_->{'VendorId'}
		, 'price' => $_->{'PriceRUR'}
		, 'title' => $_->{'ItemName'}
		, 'attrs' => {
			'quantity' => {
				'value' => $_->{'QtyOnHand'}
				,
			}
			,
		}
		, 'src' => $_
		,
	})
	, map @$_
	, grep { 'ARRAY' eq ref || ! warn $! }
	map eval{&mod::Codec::getDecodeJSON($_)}
	, map $_->decoded_content
	, map $host->getUA->query("$_", 'get')
	, map {
		$_->path('/api');
		$_->query_form(
			'apiid' => $host->{'attrs'}{'access_token'}
			, 'action' => 'getInventResourcesAndPrice'
			, 'params' => '0'
			,
		);
	
		$_
	}
	mod::URL->new($host->{'origin'})
}

sub getFromUi {
	+ map + {
		'art' => $_->{'lotID'}
		, 'brand' => $_->{'itemVendorID'}
		, 'price' => $_->{'amountRUR'}
		, 'title' => $_->{'lotName'}
		, 'attrs' => {
			'sale' => 1
			, 'quantity' => {
				'value' => $_->{'quantity'}
				,
			}
			,
		}
		, 'src' => $_
		,
	}, map {
		my $row = $_;
		my @items = grep m{\S}ugsx, delete @$row{+qw{lotQty inReserve}};

		$row->{'quantity'} = all {m{\D}ugsx} @items
			? sum @items, 0
			: join ',', @items;

		$row
	} map values %{$_->{'sellOutArr'}}
	, grep {
		'HASH' eq ref || ! warn $_
	} map &mod::Codec::getDecodeJSON($_)
	, map &mod::Codec::getEncodeUTF8($_)
	, map &mod::Codec::getRemoveBOM($_)
	, map $_->decoded_content
	, map $host->getUA->query('/', 'post', undef, {
		'action' => 'sellOutList'
		, 'itemID' => undef
		,
	})
	, $host->getUA->query('/index.php', 'post', undef, {
		'uLogin' => $host->{'attrs'}{'login'}
		, 'uPass' => $host->{'attrs'}{'passwd'}
		, 'action' => 'logon'
		,
	})
}

my $sub = sub {
	my $result = 0;

	warn(scalar localtime),
	$result += mod::Data::Offer->add(
		'host' => $host->{'name'}
		, 'realm' => $host->{'realm'}
		, %$_
	) foreach &getFromApi(), &getFromUi();

	$result
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});