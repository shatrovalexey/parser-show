#!/usr/bin/perl -I .

use strict;
use mod::UA;
use mod::Config;
use mod::Data::Host;
use mod::Data::Import;
use mod::Data::Offer;
use String::Util qw{trim};
use Data::Dumper;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('trade.aide.ru');
my $lwp = $host->getUA;

until (undef) {
	my $token = $lwp->queryXML('https://trade.aide.ru/login', 'get')->findvalue(<<'.') or warn('No token') and next;
(//input[@type="hidden"][@name="_token"])[1]/@value
.
	last if length $lwp->queryXML('https://trade.aide.ru/login', 'post', {
		'email' => $host->{'attrs'}{'user'}
		, 'password' => $host->{'attrs'}{'passwd'}
		, '_token' => $token
		,
	})->findvalue(<<'.')
//*[@data-action="side_overlay_toggle"]
.
} continue {
	sleep 1
}

while (my ($brand, $id_brand) = each %{$host->{'attrs'}{'brands'}}) {
	my $page = 1;

	warn '=' x 10;
	warn qq{brand: $brand};
	warn qq{page: $page};

	while (1) {
		my $doc = $lwp->queryXML($host->getOrigin . qq{search?brand=$id_brand&page=$page&in_stock_only=true}, 'get');

		next unless $lwp->{'last_status'} eq 200;
		next unless $doc;

		my $result = 0;

		foreach my $item ($doc->findnodes(<<'.')) {
//*[@class="block block-rounded mb-3"]
.
			my %item = map {$_ => $item->findvalue($host->{'attrs'}{'attrs'}{$_}),} keys %{$host->{'attrs'}{'attrs'}};

			$_ = &trim($_) foreach values %item;

			$item{'price'} = delete($item{'price'}) =~ s{[^\d\.\,]}{}gusor =~ tr{,}{.}r;
			$item{'quantity'} = {
				'value' => delete($item{'quantity'}) =~ s{^Под\s+заказ\s+}{}usoir
				, 'transit' => delete($item{'transit'}) =~ s{^В\s+наличии\s+}{}usoir
				,
			};
			$item{'attrs'} = {
				'image' => delete $item{'image'}
				, 'url' => delete $item{'url'}
				,
			};
			$item{'host'} = $host->{'name'};
			$item{'realm'} = $host->{'realm'};

			$result += mod::Data::Offer->add(%item)
		}

		warn 'count: ', $result;

		last unless $doc->findnodes(<<'.');
//button[@dusk="nextPage"]
.
	} continue {
		warn 'page: ', $page ++;
		sleep 2
	}
}