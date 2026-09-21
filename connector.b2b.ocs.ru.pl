#!/usr/bin/perl -I .

use strict ;
use warnings ;
use mod::Codec;
use mod::IO;
use mod::Data::Import;
use mod::Data::Host;
use mod::Data::Offer;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my ($host) = mod::Data::Host->get('connector.b2b.ocs.ru');
my $ua = $host->getUA('X-API-Key' => $host->{'attrs'}{'access_token'});
my $url = $host->getURL($host->{'attrs'}{'api'}, %{$host->{'attrs'}{'args'}});
my $sub = sub {
	my $result = 0;

	foreach my $item (map @{$_->{'result'}}, map &mod::Codec::getDecodeJSON($_->decoded_content), $ua->query($url, 'get')) {
		my $price = $item->{'price'};

		foreach my $key (qw{priceList endUser order}) {
			next unless exists($price->{$key})
				&& ($price->{$key}{'currency'} eq 'RUR')
				&& ($price->{$key}{'value'} > 0);

			$price = $price->{$key}{'value'};

			last
		}

		next if ref $price;

		my %quantity = do {
			my ($can_reserve, $can_reserve_not) = (0) x 2;

			($_->{'canReserve'} > 0 ? $can_reserve : $can_reserve_not)
				+= $_->{'quantity'}{'value'} foreach @{$item->{'locations'}};

			+ (
				'value' => $can_reserve
				, 'availability' => $can_reserve
				, 'free' => $can_reserve
				, 'transit' => $can_reserve_not
				,
			)
		};

		my $quality = lc $item->{'product'}{'condition'};
		my %attrs = ('quantity' => \%quantity,);

		if ($quality) {
			if ($quality eq 'sale') {
				$attrs{'sale'} = 1
			} else {
				$attrs{'quality'} = $quality
			}
		}

		$result += mod::Data::Offer->add(
			'host' => $host->{'name'}
			, 'realm' => $host->{'realm'}
			, 'art' => $item->{'product'}{'partNumber'}
			, 'brand' => $item->{'product'}{'producer'}
			, 'title' => join(' ', @{$item->{'product'}}{+ qw{itemNameRus productName}})
			, 'name' => $item->{'product'}{'itemNameRus'}
			, 'price' => $price
			, 'attrs' => \%attrs
			, 'src' => $item
		)
	}

	$result
};
mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});