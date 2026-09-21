#!/usr/bin/perl -I .

use strict;
use mod::UA;
use mod::Config;
use mod::Codec;
use mod::Data::Host;
use mod::Data::Import;
use mod::Data::Offer;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('trade.aide.ru');
my $lwp = mod::UA->new;
my $makeRequest = sub {
	my $sub = shift;
	my @result;

	sleep 1 until @result = $sub->();

	@result
};
my %header = (
	'Content-Type' => 'application/json'
	, 'Accept' => 'application/json'
	,
);

$lwp->{'debug'} = 1;

@header{ + qw{X-Auth-Id X-Auth-Code} } = $makeRequest->(sub {
	my $resp = $lwp->query('https://smart-system.aide.ru/api/v1.0/auth/login/', 'post', undef, 'Content' => &mod::Codec::getEncodeJSON({
		'email' => $host->{'attrs'}{'user'}
		, 'password' => $host->{'attrs'}{'passwd'}
		,
	}), %header, 'Host' => 'smart-system.aide.ru') or return;
	my $data = &mod::Codec::getDecodeJSON($resp->decoded_content) or return;

	@{$data->{'data'}[0]}{+ qw{idAuthorization uCode}}
});

my $getKey = sub {
	my $item = shift;

	&mod::Codec::getHash($item->{'part'}, $item->{'brand_part'}{'name'})
};

my %items;

$header{'Host'} = 'api.aide.ru';

foreach my $uuid (
	$makeRequest->(sub {
		my $resp = $lwp->query('https://api.aide.ru/api/v1/supply-contracts', 'get', undef, %header) or return;

		return unless $lwp->{'last_status'} eq 200;

		my $data = &mod::Codec::getDecodeJSON($resp->decoded_content) or return;

		map $_->{'uuid'}, @$data
	})
) {
	$items{$getKey->($_)} = {
		'art' => uc $_->{'part'}
		, 'brand' => uc $_->{'brand_part'}{'name'}
		, 'price' => $_->{'price'}
		, 'title' => $_->{'description'}
		, 'name' => $_->{'description_alt'}
		, 'quantity' => {
			'value' => $_->{'count'}
		}
	} foreach $makeRequest->(sub {
		my ($cursor, @items, $data);

		do {
			my $url = qq{https://api.aide.ru/api/v1/parts/catalog/supply-contract/$uuid/in-stock?in-rubles=true};

			$url .= qq{&cursor=$cursor} if $cursor;

			my $resp = $lwp->query($url, 'get', undef, %header) or redo;

			redo unless $lwp->{'last_status'} eq '200';

			$data = &mod::Codec::getDecodeJSON($resp->decoded_content) or redo;

			last unless 'ARRAY' eq ref $data->{'items'};

			push @items, @{$data->{'items'}}
		} while length($cursor = $data->{'next_cursor'});

		@items
	});

	foreach my $item ($makeRequest->(sub {
		my ($cursor, @items, $data);

		do {
			my $url = qq{https://api.aide.ru/api/v1/parts/catalog/supply-contract/$uuid/in-transit?in-rubles=true};

			$url .= qq{&cursor=$cursor} if $cursor;

			my $resp = $lwp->query($url, 'get', undef, %header) or redo;

			redo unless $lwp->{'last_status'} eq '200';

			$data = &mod::Codec::getDecodeJSON($resp->decoded_content) or redo;

			last unless 'ARRAY' eq ref $data->{'items'};

			push @items, @{$data->{'items'}}
		} while length($cursor = $data->{'next_cursor'});

		@items
	})) {
		my $key = $getKey->($item);

		if (exists $items{$key}) {
			$items{$key}{'quantity'}{'transit'} => $item->{'count'}
		} else {
			$items{$key} = {
				'art' => uc $item->{'part'}
				, 'brand' => uc $item->{'brand_part'}{'name'}
				, 'price' => $item->{'price'}
				, 'title' => $item->{'description'}
				, 'name' => $item->{'description_alt'}
				, 'quantity' => {
					'transit' => $item->{'count'}
				}
			}
		}
	}

	mod::Data::Offer->add('host' => $host->{'name'}, 'realm' => $host->{'realm'}, %$_) foreach values %items
} continue {
	sleep 1
}