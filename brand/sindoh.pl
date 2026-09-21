use LWP::UserAgent;
use WWW::UserAgent::Random;
use HTTP::Cookies;
use HTTP::Headers;
use URI;
use DBI;
use XML::LibXML;

my @paths = qw{
	/catalog/kartridzhi/
	/catalog/opcii-k-mfu/
};
my $brand = 'SINDOH';
my $uri = URI->new('https://sindoh-russia.ru/');

$uri->query_form({'per_page' => -1,});

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

	my $resp = $lwp->get($uri);

	return XML::LibXML->new->load_html({
		'recover' => 1
		, 'suppress_errors' => 1
		, 'string' => $resp->decoded_content
		,
	}) if $resp->is_success;

	warn $resp->status_line;

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

	while (my $doch = &getDoc()) {
		warn uc $_->value
		, $sth_ins->execute($brand, uc $_->value) foreach $doch->findnodes(<<'.');
//@data-product_sku
.

		last
	}
}

$sth_ins->finish;
$dbh->disconnect;