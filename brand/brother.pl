use LWP::UserAgent;
use WWW::UserAgent::Random;
use HTTP::Cookies;
use HTTP::Headers;
use URI;
use DBI;
use XML::LibXML;

my @paths = qw{
	/catalog/raskhodnye-materialy/
	/catalog/kartridzhi-brother/
	/catalog/fotobarabany-brother/
	/catalog/bumaga-brother/
};
my $brand = 'BROTHER';
my $uri = URI->new('https://brother-printers.ru/');
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
		'recover' => 1
		, 'suppress_errors' => 1
		, 'string' => $_->decoded_content
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
		warn uc
		, $sth_ins->execute($brand, uc) foreach $doch->findnodes(<<'.');
//*[contains(@class, "catalog-list__item")]
	//*[contains(@class, "catalog-list-item__article")]
		/text()
.
		$uri->query_form({'PAGEN_1' => qq{$_},})
			foreach $doch->findnodes(<<'.') or last()
//*[contains(@class, "paging__item--active")]
	/following-sibling::a[1]
		/text()
.
	}
}

$sth_ins->finish;
$dbh->disconnect;