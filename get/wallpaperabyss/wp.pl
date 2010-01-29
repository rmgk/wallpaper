#!/usr/bin/perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:12 11.04.2009

use 5.010;
use strict;
use warnings;
use DBI;
use WallpaperAbyss;


our $VERSION = 1.1;


our $TERM = 0;
$SIG{'INT'} = sub { 
		print "\nTerminating (wait for page to finish)\n" ;
		$TERM = 1;
		};

print "remember: images must not be redistributed without the authors approval\n";
print "press ctrl+c to abort (or data corruption might occur)\n";
print "wpv.pl version $VERSION\n\n";

my $dbh = DBI->connect("dbi:SQLite:dbname=wp.db","","",{AutoCommit => 1,PrintError => 1});

unless($dbh->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='wallpapers'")) {
	$dbh->do("CREATE TABLE wallpapers ( id INTEGER, category, subcategory, resx INTEGER, resy INTEGER, 
				voteup INTEGER, votedown INTEGER, sha1, size INTEGER, fav, lame )");
}

$dbh->func(300000,'busy_timeout');

open (FILE, "<next_url.txt");
my $url = <FILE> // 'http://wall.alphacoders.com/newest_wallpapers.php?o=0&d=newer';
close FILE;

while (!$TERM and $url) {
	my $wpa = WallpaperAbyss->new({url=>$url, dbh=>$dbh});
	$wpa->get_page();
	last if $TERM;
	$url = $wpa->next_page();
	open (FILE, ">next_url.txt");
	print FILE $url;
	close FILE;
}

$dbh->disconnect if $dbh;
