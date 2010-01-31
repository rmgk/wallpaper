use 5.010;
use strict;
use warnings;
use DBI;
use Digest::SHA;
use util;

my $SHA = Digest::SHA->new();

my $dbh = DBI->connect("dbi:SQLite:dbname=doubles.db","","",{AutoCommit => 0,PrintError => 0});

unless($dbh->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='doubles'")) {
	$dbh->do("CREATE TABLE doubles (sha1 UNIQUE,path UNIQUE)");
}

my $insert = $dbh->prepare("INSERT OR FAIL INTO doubles (sha1,path) VALUES (?,?)");
my $select = $dbh->prepare("SELECT path FROM doubles WHERE sha1 = ?");
my $update = $dbh->prepare("UPDATE doubles SET path = ? WHERE sha1 = ?");
#my $stq = $dbh->prepare("SELECT path FROM doubles WHERE path = ?");

my $paths = $dbh->selectall_hashref("SELECT path, sha1 FROM doubles","path");
my $shas = $dbh->selectall_hashref("SELECT sha1, path FROM doubles","sha1");

my $ini = readINI("config.ini")->{default};

check_dir($ini->{directory});

sub check_dir {
	my $basedir = shift;
	my $adddir = shift // "";
	my @list;
	say $basedir.$adddir;
	my $PIC;
	
	opendir($PIC,$basedir.$adddir) or die $!;
	
	while(my $x = readdir($PIC)) {
		next if $x =~ m/^\.{1,2}$/; 
		if (-d $basedir.$adddir.$x) {
			check_dir($basedir,$adddir.$x.'\\');
		}
		else {
			if ($x =~ m/\.(jpe?g|gif|png|bmp)$/i) {
				check_double($basedir,$adddir,$x);
			}
		}
	}
	
	closedir($PIC);
	$dbh->commit();
}

sub check_double {
	my $basedir = shift;
	my $addir = shift;
	my $file = shift;
	my $path = $basedir . $addir . $file;
	#$stq->execute($path);
	#return if $stq->fetchrow_arrayref();
	return if $paths->{$path}->{sha1};
	if ($file) {
		if (-e $path) { 
			my $sha = $SHA->addfile($path,"b")->hexdigest;
			if ($sha) {
				if (my $opath = $shas->{$sha}->{path}) {
					#$select->execute($sha);
					#my ($opath,$ofile) = $select->fetchrow_array();
					#return if ($opath eq $path);
					say $opath,"\n", $path , "\n";
					my $ofile = $opath;
					$ofile =~ s~^.*\\~~;
					
					if ((length($file) <= length($ofile)) and (-e $opath)) {
						unlink $path;
					}
					else {
						$update->execute($path,$sha);
						$paths->{$opath} = undef;
						$shas->{$sha}->{path} = $path;
						$paths->{$path}->{sha1} = $sha;
						unlink($opath);
					}
				}
				else {
					$insert->execute($sha,$path);
					$paths->{$path}->{sha1} = $sha;
					$shas->{$sha}->{path} = $path;
				}
			}
			else {
				say "no sha for $path";
			}
		}
		else {
			say "$path not found";
		}
	}
	else {
		say "no file passed";
	}
}
$dbh->commit();

