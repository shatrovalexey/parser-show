#!/usr/bin/perl -I .

use strict;
use warnings;
use mod::Codec;
use mod::Data::Import;
use mod::SOAP;
use mod::Data::Host;
use mod::Data::Offer;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('name' => 'b2b.merlion.com') or die 'No host';
my $sub = sub {
	my $soaph = mod::SOAP->new(%{$host->{'attrs'}}) or return;
	my $shipment_date = sub {
		return $_->{'Date'} foreach
			reverse $soaph->get('getShipmentDates', undef, undef)
	}->() or return;
	my $shipment_method = sub {
		return $_->{'Code'} foreach
			sort {
				$b->{'IsDefault'} <=> $a->{'IsDefault'}
			} $soaph->get('getShipmentMethods', undef, undef)
	}->() or return;
	my $result = 0;

	foreach my $cat ($soaph->get('getCatalog', 'ML31')) {
		my %data;

		for (
			my $page = 1;
			my @items = grep ref, $soaph->get('getItems', $cat->{'ID'}, undef, undef, $page, $host->{'attrs'}{'page_size'}, undef);
			$page ++
		) {
			$data{$_->{'No'}} = {
				'host' => $host->{'name'}
				, 'realm' => $host->{'realm'}
				, 'title' => $_->{'Name'}
				, 'name' => $_->{'Name'}
				, 'brand' => $_->{'Brand'}
				, 'art' => $_->{'Vendor_part'}
				,
			} foreach @items;
		}

		foreach my $item ($soaph->get('getItemsAvail', $cat->{'ID'}, $shipment_method, $shipment_date)) {
			next unless exists $data{$item->{'No'}};

			my $transit = grep $_ > 0, @$item{+qw{AvailableExpected AvailableExpectedNext}};

			@{$data{$item->{'No'}}}{+qw{price attrs src}} = (
				$item->{'PriceClientRUB'}
				, {
					'quantity' => {
						'value' => $item->{'AvailableClient'}
						, 'availability' => $item->{'AvailableClient'}
						, 'free' => $item->{'AvailableClient_MSK'}
						, 'transit' => ($transit || 0)
						,
					}
				},
				$item
			);

			$result += mod::Data::Offer->add(%{$data{$item->{'No'}}})
		}
	}

	$result
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});