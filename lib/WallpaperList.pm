package WallpaperList;

use 5.010;
use strict;
use warnings;

use DBI;
use Digest::SHA;

my $SHA = Digest::SHA->new();
my $DB_PATH;
my $WP_PATH;
my $DBH;
my $STH_INSERT;
my $STH_UPDATE;
my $PATHS;
my $SHAS;
my $CURRENT;
my $CHECK_DOUBLES;

sub init {
	$DB_PATH = shift;
	$WP_PATH = shift;
	$CURRENT = shift || 1;
	$CHECK_DOUBLES = shift // 0;
	say "connecting to database: " . $DB_PATH;
	$DBH = DBI->connect("dbi:SQLite:dbname=". $DB_PATH,"","",{AutoCommit => 0,PrintError => 0});

	if($DBH->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='wallpaper'")) {
		return 1;
	}
	
	say "creating wallpapers table";
	$DBH->do("CREATE TABLE wallpaper (position INTEGER UNIQUE, sha1 UNIQUE, path UNIQUE, vote INTEGER, fav, nsfw)") 
		or die "could not create table";
	
	say "adding ". $WP_PATH ." to database";
	add_folder($WP_PATH);
	say "creating random order";
	determine_order();
}

sub current {
	my @path = $DBH->selectrow_array("SELECT path FROM wallpaper WHERE position = ?",undef,$CURRENT);
	return $WP_PATH . $path[0] if $path[0];
	return undef;
}

sub current_position {
	return $CURRENT;
}

sub remove_current {
	$DBH->do("DELETE FROM wallpaper WHERE position = ?", undef, $CURRENT);
}
sub fav_current {
	$DBH->do("UPDATE wallpaper SET fav = 1 WHERE position = ?", undef, $CURRENT);
}

sub forward {
	my $mv = shift;
	$CURRENT += $mv // 1;
	if ($CURRENT < 1) {
		$CURRENT = 1;
		return;
	}
	my $cur = current();
	while (!$cur) {
		$CURRENT += $mv<=>0; #vorzeichen von $mv;
			if ($CURRENT < 1) {
				$CURRENT = 1;
				return;
			}
		$cur = current();
	}
	return $cur;
}

sub backward {
	return forward(  (- shift) // - 1 );
}

sub get_fav {
	return $DBH->selectcol_arrayref("SELECT path FROM wallpaper WHERE fav = 1");
}

sub determine_order {
	use List::Util 'shuffle';
	my @files =  shuffle @{$DBH->selectcol_arrayref("SELECT _rowid_ FROM wallpaper")};
	my $sth = $DBH->prepare("UPDATE wallpaper SET position = ? WHERE _rowid_ = ?");
	say scalar $sth->execute_array(undef, [shuffle (1..@files)], \@files);
	$DBH->commit();

}

sub add_folder {
	my ($base,$path) = @_;
	$path //= ""; # path is undef when we start at base
	$STH_INSERT = $DBH->prepare("INSERT OR FAIL INTO wallpaper (sha1,path) VALUES (?,?)");
	$STH_UPDATE = $DBH->prepare("UPDATE doubles SET path = ? WHERE sha1 = ?");
	$PATHS = $DBH->selectall_hashref("SELECT path, sha1 FROM wallpaper","path");
	$SHAS = $DBH->selectall_hashref("SELECT sha1, path FROM wallpaper","sha1");
	_add_folder($base,$path);
}

sub _add_folder {
	my ($base,$path) = @_;
	say $base.$path;

	my $PIC;
	opendir($PIC,$base.$path) or die $!;
	
	while(my $x = readdir($PIC)) {
		next if $x =~ m/^\.{1,2}$/; 
		if (-d $base.$path.$x) {
			_add_folder($base,$path.$x.'\\');
		}
		else {
			if ($x =~ m/\.(jpe?g|gif|png|bmp)$/i) {
				add_file($base,$path,$x);
			}
		}
	}
	
	closedir($PIC);
	$DBH->commit();
}

sub add_file {
	my ($base,$path,$file) = @_;
	
	return if $PATHS->{$path.$file}->{sha1};
	
	if (-e $base . $path . $file) { 
		if ($CHECK_DOUBLES) {
			my $sha = $SHA->addfile($base . $path . $file,"b")->hexdigest;
			if ($sha) {
				if (my $opath = $SHAS->{$sha}->{path}) {
					say "\n",$opath,"\n", $path , "\n";
					my $ofile = $opath;
					$ofile =~ s~^.*\\~~;
					
					if ((length($file) <= length($ofile)) and (-e $opath)) {
						unlink $path;
					}
					else {
						update_file($opath,$path,$sha);
					}
				}
				else {
					insert_file($path.$file,$sha);
				}
			}
			else {
				die "could not create";
			}
		}
		else {
			insert_file($path.$file);
		}
	}
	else {
		say "$base$path$file not found";
	}
}

sub insert_file {
	my ($path,$sha) = @_;
	$STH_INSERT->execute($sha,$path);
	$PATHS->{$path}->{sha1} = $sha;
	$SHAS->{$sha}->{path} = $path if $sha;;
}

sub update_file {
	my ($opath,$path,$sha) = @_;
	$STH_UPDATE->execute($sha,$path);
	$PATHS->{$opath} = undef;
	$SHAS->{$sha}->{path} = $path;
	$PATHS->{$path}->{sha1} = $sha;
	unlink($opath);
}

1;
