use LWP::UserAgent;
use WWW::UserAgent::Random;
use HTTP::Cookies;
use HTTP::Headers;
use URI;
use DBI;
use XML::LibXML;

my @paths = qw{
	/options-and-supplies/
};
my $brand = 'PANTUM';
my $uri = URI->new('https://www.pantum.ru/');
my $type = join ',', qw{kartridzhi fotobarabany bunkerotrabotannogotonera optsii zapravochnyekomplekty};

$uri->query_form({'type' => $type,});

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
		, $sth_ins->execute($brand, uc) foreach map m{([a-zA-Z0-9-]{5,})}usxo, $doch->findnodes(<<'.');
//*[contains(@class, "product-card__title")]
	/text()
.
		my ($next) = $doch->findnodes(<<'.') or last;
//*[contains(@class, "current-pagination")]
	/parent::li[contains(@class, "news-pagination__item")]
		/following-sibling::li[contains(@class, "news-pagination__item")]
			/a/text()
.

		$uri->query_form({
			'pagination' => qq{$next}
			, 'type' => $type
			,
		})
	}
}

$sth_ins->finish;
$dbh->disconnect;