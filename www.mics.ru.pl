#!/usr/bin/perl -I .

use strict;
use warnings;
use utf8;
use mod::Codec;
use mod::IO;
use mod::Data::Import;
use mod::Data::Host;
use mod::Data::Offer::Collection;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('name' => 'www.mics.ru');
my $ua = $host->getUA;

sub queryAPI($;@) {
	my ($method, %args) = @_;

	sleep $host->{'attrs'}{'sleep'};

	grep ref
	, map eval{&mod::Codec::getDecodeJSON(&mod::Codec::getEncodeUTF8($_->decoded_content))}
	, $ua->query($host->{'attrs'}{'api'}, 'post', undef
		, 'Content' => {
			'data' => &mod::Codec::getEncodeJSON({
				'method' => $method
				, 'login' => $host->{'attrs'}{'login'}
				, 'password' => $host->{'attrs'}{'password'}
				, %args
				,
			})
			,
		}
	)
}
my $sub = sub {
	my $items = mod::Data::Offer::Collection->new;
	my ($contract) = map $_->{'ContractSapCode'}
		, grep exists $_->{'ContractSapCode'}
		, map @$_
		, grep 'ARRAY' eq ref
		, map $_->{'Contracts'}
		, grep exists $_->{'Contracts'}
		, grep 'HASH' eq ref
		, &queryAPI('getContracts')
			or die 'No contract found';

	foreach my $group (@{$host->{'attrs'}{'group'}}) {
		my $page = 1;

		while (my ($catalogs) = &queryAPI('getCatalog',
			'contract' => $contract
			, 'group' => $group
			, 'page' => $page
			,
		)) {
			warn "page: $page";

			if (exists $catalogs->{'errorCode'}) {
				warn &mod::Codec::getEncodeJSON($catalogs);

				last
			}

			foreach my $good (values %$catalogs) {
				foreach my $storage (
					map values(%$_), grep ref, @$good{+grep m{^Склады(?!.*?_ИмяВидаОценки$)}uisx, keys %$good}
				) {
					my %item = (
						'art' => $good->{'Партномер'}
						, 'brand' => $good->{'Бренд'}
						, 'name' => $good->{'КраткоеНаименование'}
						, 'title' => $good->{'ПолноеНаименование'}
						, 'price' => $storage->{'Цена'}
						, 'attrs' => {
							'sale' => $good->{'Распродажа'}
							, 'quality' => $storage->{'ВидОценки'} || 'СТАНДАРТ'
							, 'quantity' => {
								'value' => $storage->{'ДоступноДляЗаказа'}
								, 'availability' => $storage->{'ДоступноДляЗаказа'}
								, 'free' => $storage->{'ДоступноДляЗаказа'}
								, 'transit' => $storage->{'ОжидаемыйПриход'}
								,
							}
							,
						}
						,'src' => $good
						,
					);

					$items->add(\%item)
				}
			}
		} continue {
			$page ++
		}
	}
	mod::Data::Import->doUpdate($host->{'name'}, $items)
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});