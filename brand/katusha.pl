use LWP::UserAgent;
use WWW::UserAgent::Random;
use HTTP::Cookies;
use HTTP::Headers;
use URI;
use DBI;
use XML::LibXML;
use utf8;
use open qw{:std :encoding(UTF-8)};

my @paths = qw{
	/consumables
};
my $brand = 'KATUSHA';
my $uri = URI->new('https://katusha-it.ru/');
my $lwp = LWP::UserAgent->new(
	'cookie_jar' => HTTP::Cookies->new
	, 'default_headers' => HTTP::Headers->new({
		'Host' => $uri->host
		, 'User-Agent' => &rand_ua('browsers')
		,
	})
);

sub getDoc {
	warn $uri;

	return XML::LibXML->new->load_html({
		'HTML_NOIMPLIED' => 1
		, 'recover' => 1
		, 'suppress_errors' => 1
		, 'string' => $_->decoded_content
		, 'encoding' => 'utf-8'
		,
	}) foreach grep $_->is_success, $lwp->get($uri);

	+()
}

my $dbh = DBI->connect('dbi:mysql:parser5', 'root', 'f2ox9erm');
my $sth_ins = $dbh->prepare(<<'.');
INSERT IGNORE INTO
	`art`
SET
	`brand` := ?
	, `value` := ?;
.

while (my $path = shift @paths) {
	$uri->path($path);
	$uri->query_form({});

	while (my $doch = &getDoc()) {
		warn($_)
		, $sth_ins->execute($brand, $_)
			foreach grep length
				, map tr{МмОоАакКсСхХнНеЕтТрР}{MMOoАаkKсСxXhHeEtTpP}r
				, map uc
				, map m{(\S+)$}usxo
				, $doch->findnodes(<<'.');
//*[contains(@class, "product-card__title")]
	/text()
.
		last
	}
}

$sth_ins->finish;
$dbh->disconnect;