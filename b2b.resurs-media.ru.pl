#!/usr/bin/perl -I .

use strict;
use mod::Data::Brand;
use mod::Data::Offer;
use mod::Data::Import;
use mod::UA;
use mod::IO;
use mod::Data::Host;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $requested_from = '/netcat';
my $auth_path = $requested_from . 'modules/auth/';
my ($host) = mod::Data::Host->get('b2b.resurs-media.ru');
my $ua = $host->getUA('Referer' => $auth_path);
my @fields = map $_->[0], @{$host->{'attrs'}{'fields'}};
my %fields = map @$_, @{$host->{'attrs'}{'fields'}};
my $sub = sub {
	$ua->query;
	$ua->query('/netcat/modules/auth/', 'post', undef, {
		'AuthPhase' => 1
		, 'REQUESTED_FROM' => '/'
		, 'REQUESTED_BY' => 'GET'
		, 'catalogue' => 1
		, 'sub' => 334
		, 'cc' => 202
		, 'AUTH_USER' => $host->{'attrs'}{'login'}
		, 'AUTH_PW' => $host->{'attrs'}{'passwd'}
		, 'submit' => 'Авторизоваться'
		,
	});
	my ($file_tmp) = $ua->query('/excelPrice/price.xlsx', 'get', 1);
	my $result = 0;

	$result += mod::Data::Offer->add(%$_, 'host' => $host->{'name'}, 'realm' => $host->{'realm'})
		foreach map mod::Data::Offer::loadCSV(
			$_
			, sub {
				my ($csv, $fh) = @_;

				scalar <$fh>
			}
			, sub {
				my ($csv, $fh, $row) = @_;
				my %item;

				@item{@fields} = @$row[@fields{@fields}];

				return +() unless
					$item{'price'} =~ m{^[1-9]}usox
					&& $item{'art'} =~ m{\S}uosx
					&& (@item{'brand'} = mod::Data::Brand->getNearest($item{'brand'}));

				$item{'attrs'} = {
					'quantity' => {
						'value' => delete $item{'quantity'}
						, 'availability' => delete $item{'availability'}
						, 'free' => delete $item{'free'}
						, 'transit' => delete $item{'transit'}
						,
					}
					,
				};

				\%item
			}
		)->getList, &mod::IO::getXLSX2CSV($file_tmp);

	$result
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});