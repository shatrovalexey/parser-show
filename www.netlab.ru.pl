#!/usr/bin/perl -I .

use strict;
use Archive::Zip qw{:ERROR_CODES :CONSTANTS};
use LWP::UserAgent;
use mod::DBA;
use mod::Data::Import;
use mod::Data::Offer;
use mod::Data::Host;
use mod::Data::Brand;
use mod::UA;
use mod::IO;
use mod::Config;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('name' => 'www.netlab.ru');
my $ua = $host->getUA('-' => sub {
	my ($headers) = @_;

	delete @$headers{+grep m{^Accept\b}uisx, keys %$headers}
});
my $sub = sub {
	my ($file_zip) = $ua->query('/products/dealerD.zip', 'get', 1) or die 'Error loading';
	my $file_xlsx = &mod::IO::getTempName();

	foreach (Archive::Zip->new($file_zip)->members) {
		last if $_->fileName =~ m{\.xlsx$}uisx
			&& ($_->extractToFileNamed($file_xlsx) == &AZ_OK())
	}

	unlink $file_zip;
	die 'XLSX not found' if -z $file_xlsx;

	my $file_csv = &mod::IO::getXLSX2CSV($file_xlsx) or die 'No data';
	my (@fields, %header) = qw{art name title price quantity};

	@header{@fields} = qw{2 4 4 9 15};

	my $usd_rub;
	my @data = mod::Data::Offer::loadCSV($file_csv, sub {
		my ($csv, $fh) = @_;

		undef until $fh->eof || <$fh> =~ m{,USD,(\d+\.\d+),}uisx;

		return +() unless $1 > 0;

		$usd_rub = $1;

		undef until $fh->eof || <$fh> =~ m{,PartNumber,Артикул,Наименование,}uisx;

		$usd_rub
	}, sub {
		my ($csv, $fh, $row) = @_;

		my %item = (
			'host' => $host->{'name'}
			, 'realm' => $host->{'realm'}
		);

		@item{@fields} = @$row[@header{@fields}];

		return +() unless $item{'price'} =~ m{^[1-9]}uosx
			&& (@item{'brand'} = mod::Data::Brand->getSuggested($item{'name'}));

		$item{'price'} *= $usd_rub;
		$item{'attrs'} = {'quantity' => {'value' => $item{'quantity'},},};
		$item{'src'} = $row;

		$_ = uc foreach @item{+qw{name art}};

		\%item
	});

	mod::Data::Import->doUpdate($host->{'name'}, @data)
};
mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});