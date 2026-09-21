#!/usr/bin/perl -I .

use strict;
use utf8;
use Archive::Zip qw{:ERROR_CODES :CONSTANTS};
use LWP::UserAgent;
use mod::Data::Import;
use mod::Data::Offer;
use mod::Data::Host;
use mod::Data::Brand;
use mod::UA;
use mod::IO;
use mod::XML;
use mod::DBA;
use mod::Config;
use List::Util qw{uniqstr};
use String::Util qw{trim};
use Data::Dumper;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('name' => 'web-nld.netlab.ru');
my $ua = $host->getUA;
my $brand = mod::Data::Brand->new;
my $xml = mod::XML->new;
my $brandRX = $brand->_getRX;
my $brandRXExcept = $brand->_getRXExcept;

END {
	$ua->query('/faces/common/logout.xhtml', 'get', 0)
}

sub getBrandArt {
	my $str = shift;

	&utf8::decode($str);

	return +() if $str =~ $brandRXExcept;

	my ($brand_, $pos);

	$str =~ s{\{.*?\}}{}ngosx;

	return +() unless $str =~ s{\b$brandRX\b}{
		unless ($brand_) {
			$pos = pos $str;
			$brand_ = $&
		}

		+ ''
	}geosxn;

	($brand_) = $brand->getNearest($brand_) or return +();

	my @arts = map shift @$_
		, sort {$a->[1] <=> $b->[1]}
		map [$_ => scalar @{[m{\W}gusoxn,]},]
		, uniqstr map &trim($_)
		, grep length
		, map tr{АВЕКМНОРСТУХ}{ABEKMHOPCTYX}r =~ s{[^A-Z0-9,/\\\|-]+}{}gosur
		, grep(
			m{[0-9]}us && (5 <= length)
			, substr($str, $pos) =~ m{\b([A-ZА-Я0-9,/\\\|-]+)\b}gosu
		) or return +();

	($brand_, @arts)
}

my $sub = sub {
	my $fileName = $ua->query('/faces/common/login.xhtml', 'get' => 1) or die 'No login';
	my $viewState = $xml->getDoc($fileName, 1, 1)->findvalue(<<'.') or die 'No viewState';
//input[@type="hidden"][@name="javax.faces.ViewState"]
	/@value
.
	$ua->query('/faces/common/login.xhtml', 'post', undef, {
		'javax.faces.partial.ajax' => 'true'
		, 'javax.faces.source' => 'loginForm:loginButton'
		, 'javax.faces.partial.execute' => '@all'
		, 'javax.faces.partial.render' => 'loginForm:loginGrid loginForm:messages'
		, 'loginForm:loginButton' => 'loginForm:loginButton'
		, 'loginForm' => 'loginForm'
		, 'loginForm:j_username' => $host->{'attrs'}{'login'}
		, 'loginForm:j_password' => $host->{'attrs'}{'passwd'}
		, 'javax.faces.ViewState' => $viewState
		,
	});

	$fileName = $ua->query('/faces/secure/catalog.xhtml', 'get', 1);
	my $result = 0;

	foreach my $rowKey ($xml->getDoc($fileName, 1, 1)->findnodes(<<'.')) {
//li
	/@data-rowkey
.
		$rowKey = $rowKey->textContent;

		next unless $rowKey =~ m{^4_}uson;

		warn $rowKey;

		my $fileName = $ua->query('/faces/secure/catalog.xhtml', 'post', 1, {
			'javax.faces.partial.ajax' => 'true'
			, 'javax.faces.source' => 'treeForm:categoryTreeId'
			, 'javax.faces.partial.execute' => 'treeForm:categoryTreeId'
			, 'javax.faces.partial.render' => join(q{ }
				, 'centerContent:goodsDataTableId'
				, 'catalogToolBarForm:propertiesCmdBtnId'
				, 'catalogToolBarForm:descriptionCmdBtnId'
				, 'catalogToolBarForm:addToDocCmdBtnId'
				, 'catalogToolBarForm:complainCmdBtnId'
			)
			, 'javax.faces.behavior.event' => 'select'
			, 'javax.faces.partial.event' => 'select'
			, 'treeForm' => 'treeForm'
			, 'treeForm:j_idt263_focus' => ''
			, 'treeForm:j_idt263_input' => 'Price'
			, 'treeForm:categoryTreeId_instantSelection' =>  $rowKey
			, 'treeForm:categoryTreeId_selection' =>  $rowKey
			, 'javax.faces.ViewState' => $viewState
			,
		});

		warn $fileName;

		foreach my $tr ($xml->getDoc($fileName, 1, 1)->findnodes(<<'.')) {
//*[@id="centerContent:goodsDataTableId_data"]
	/tr
.
			my @tds = $tr->findnodes('td');
			my %item = map {
				defined $tds[$_]
					? ($host->{'attrs'}{'cols'}{$_} => &trim($tds[$_]->textContent))
					: ()
			} keys %{$host->{'attrs'}{'cols'}};

			next unless $item{'price'} > 0;

			@item{+ qw{brand art}} = &getBrandArt($item{'name'});

			next unless length $item{'brand'} && length $item{'art'};

			$result += mod::Data::Offer->add(
				%item
				, 'host' => $host->{'name'}
				, 'realm' => $host->{'realm'}
				, 'art' => $_
				, 'title' => $item{'name'}
				, 'attrs' => {
					'quantity' => {
						'value' => $item{'free'}
						, 'free' => $item{'free'}
						, 'transit' => $item{'transit'}
						, 'available' => $item{'free'}
						,
					}
					,
				}
				,
			) foreach grep 2 < length
				, map s{^\W+|\W+$}{}gusoxnr
				, split m{[,\\\|/]+}uson
					, delete $item{'art'}
		}
	}

	$result
};

mod::Data::Import->retry($host, $sub, @{$config->{'import'}}{+ qw{retryes timeout}});