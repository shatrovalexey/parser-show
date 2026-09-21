#!/usr/bin/perl -I .

use strict;
use warnings;
use mod::Config;
use mod::Codec;
use mod::Data::Host;
use mod::Data::Import;
use mod::Data::Offer;
use mod::IO;
use Mail::IMAPClient;
use Email::MIME;
use Text::CSV;
use File::Basename;
use DateTime::Format::Strptime;
use IO::Socket::SSL;

my $config = mod::Config->getFileJSON(shift @ARGV) or die 'No config';
my $host = mod::Data::Host->get('trade.aide.ru');
my $imap = $host->{'attrs'}{'imap'};

# Подключаемся через Mail::IMAPClient
my $imaph = Mail::IMAPClient->new(
    Server   => $imap->{'server'},
    Port     => $imap->{'port'},
    User     => $imap->{'email'},
    Password => $imap->{'password'},
    Ssl      => 1,
    Uid      => 1,  # используем UID вместо номеров сообщений
) or die "Cannot connect: $@";

die "Authentication failed: " . $imaph->LastError unless $imaph->IsAuthenticated;
die "Cannot select INBOX: " . $imaph->LastError unless $imaph->select('INBOX');

my $parser = DateTime::Format::Strptime->new(
    'pattern' => '%a, %d %b %Y %H:%M:%S %z',
    'locale' => 'en',
    'on_error' => 'undef',
);

my ($datetimeCurrent, $msgId);

foreach my $msg_id ($imaph->messages) {
    next if -1 == index lc $imaph->get_header($msg_id, 'From'), 'noreply@smart.aide.ru';

    my $date = $imaph->get_header($msg_id, 'Date') or next;
    my $datetime = $parser->parse_datetime($date) or next;

    ($datetimeCurrent, $msgId) = ($datetime, $msg_id)
        unless $datetimeCurrent && ($datetimeCurrent ge $datetime);
}

unless ($msgId) {
    $imaph->logout;
    die '1. No message found';
}

my $emailRaw = $imaph->body_string($msgId) or die '2. No message found';

$imaph->create($imap->{'folder'}) unless $imaph->exists($imap->{'folder'});

die $imaph->LastError if $imaph->LastError;
$imaph->delete_message($msgId) if $imaph->copy($msgId, $imap->{'folder'});
$imaph->logout;

sub getCSV {
    my $part = shift;
    
    # Получаем все части (включая вложенные)
    my @all_parts = $part->parts;
    
    foreach my $subpart (@all_parts) {
        # Если это multipart - рекурсивно обрабатываем
        if ($subpart->content_type =~ m{^multipart/}i) {
            my $result = getCSV($subpart);
            return $result if $result;
        }
        # Проверяем вложение
        elsif (my $filename = $subpart->filename) {
            warn "Found attachment: $filename (type: " . $subpart->content_type . ")";
            
            if ($filename =~ /\.xlsx?$/i) {
                warn "Processing Excel: $filename";
                my $xlsxFilename = mod::IO::getTempName();
                mod::IO::doPutFile($xlsxFilename, $subpart->body);
                return mod::IO::getXLSX2CSV($xlsxFilename);
            }
        }
    }
    
    return undef;
}

my $email = Email::MIME->new($emailRaw);
my $csvFilename = getCSV($email) or die '3. No CSV file found in email';

my $fh = &mod::IO::getFileHandle($csvFilename) or die 'Can not create file';
my $csv = &mod::IO::getCSV('sep_char' => ',') or die 'Cannot create CSV parser';

my $getFields = sub {
    my $line = shift;
    
    # Удаляем BOM если есть
    $line =~ s/^\x{FEFF}//;
    
    die $csv->error_diag() unless $csv->parse($line);
    return [$csv->fields()];
};

# Пропускаем первые две строки (обычно это заголовки или пустые строки)
scalar <$fh>;
scalar <$fh>;

# Читаем строку с заголовками
my $header_line = <$fh>;
die "Cannot read header line" unless $header_line;
my $header_fields = $getFields->($header_line);

my %fields;
for (my $i = 0; $i < @$header_fields; $i++) {
    $fields{$header_fields->[$i]} = $i;
}

# Проверяем наличие необходимых полей
my @required_fields = ('Производитель', 'Артикул', 'Наименование', 'Наличие', 'Цена, рубли (с НДС)');
foreach my $field (@required_fields) {
    die "Required field '$field' not found in CSV" unless exists $fields{$field};
}

my $result = 0;

while (<$fh>) {
    chomp;
    next unless $_;  # Пропускаем пустые строки
    
    my $row_ref = $getFields->($_);
    my @row = @$row_ref;
	my %row = map {$_ => $row[$fields{$_}] // ''} keys %fields;
    
    # Пропускаем строки с пустыми обязательными полями
    next unless $row{'Артикул'} && $row{'Наименование'};
    
    # Обработка наличия (значение может быть с пробелами)
    my $quantity_value = $row{'Наличие'};
    $quantity_value =~ s/\s//g if defined $quantity_value;
    
    my $transit_value = $row{'Транзит'} // '';
    $transit_value =~ s/\s//g if $transit_value;
    
    # Обработка цены (замена запятой на точку)
    my $price = $row{'Цена, рубли (с НДС)'};
    $price =~ s/,/./ if defined $price;
    $price =~ s/\s//g if defined $price;
    
	use Data::Dumper;
	
	die Dumper + {

        'host' => $host->{'name'},
        'realm' => $host->{'realm'},
        'brand' => $row{'Производитель'},
        'art' => $row{'Артикул'},
        'title' => $row{'Наименование'},
        'name' => $row{'Наименование'},
        'quantity' => {
            'value' => $quantity_value,
            'transit' => $transit_value,
        },
        'price' => $price,
	};

    $result += mod::Data::Offer->add(
        'host' => $host->{'name'},
        'realm' => $host->{'realm'},
        'brand' => $row{'Производитель'},
        'art' => $row{'Артикул'},
        'title' => $row{'Наименование'},
        'name' => $row{'Наименование'},
        'quantity' => {
            'value' => $quantity_value,
            'transit' => $transit_value,
        },
        'price' => $price,
    );
}

$fh->close;
unlink $csvFilename;

warn "Processed $result offers";