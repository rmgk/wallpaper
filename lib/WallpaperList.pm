package WallpaperList;

use 5.010;
use strict;
use warnings;

use Carp;

use DBI;
use Digest::SHA;

my $SHA = Digest::SHA->new();
my $DB_PATH;
my $WP_PATH;
my $DBH;
my $STH_INSERT;
my $PATHS;

#$db_path, $wp_path
#initialises the database creating tables if necessaray
sub init {
	$DB_PATH = shift or croak 'db_path not defined';
	$WP_PATH = shift or croak 'wp_path not defined';
	$DBH = DBI->connect("dbi:SQLite:dbname=". $DB_PATH,"","",{AutoCommit => 1,PrintError => 1});

	if($DBH->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='wallpaper'")) {
		return 1;
	}
	
	say "Creating Wallpaper Table";
	$DBH->do("CREATE TABLE wallpaper (position INT UNIQUE, sha1 CHAR UNIQUE, path CHAR UNIQUE, vote INT, fav INT, nsfw INT)") 
		or die "could not create table";
	return 1;
}

#$position -> ($path,$sha)
#returns the path and sha value for the given $position
sub get_data {
	my $position = shift;
	my ($path,$sha) = $DBH->selectrow_array("SELECT path, sha1 FROM wallpaper WHERE position = ?",undef,$position);
	if ($path and !$sha) {
		if (! -e $WP_PATH . $path) {
			$DBH->do("DELETE FROM wallpaper WHERE position = ?", undef, $position);
		}
		else {
			$sha = $SHA->addfile($WP_PATH . $path,"b")->hexdigest;
			$sha or die "could not get sha of $path";
			unless ($DBH->do("UPDATE OR FAIL wallpaper SET sha1 = ? WHERE position = ?",undef,$sha,$position)) {
				my ($double) = $DBH->selectrow_array("SELECT path FROM wallpaper WHERE sha1 = ?",undef,$sha);
				return ($sha,$path,$double);
			}
		}
		$DBH->commit();
	}
	return ($path , $sha) if $path and $sha;
	return undef;
}
#$sha -> $path
#returns the $path for $sha
sub get_path {
	my $sha = shift;
	return $DBH->selectrow_array("SELECT path FROM wallpaper WHERE sha1 = ?",undef,$sha)
}

#$sha -> $pos
#returns the $pos for $sha
sub get_pos {
	my $sha = shift;
	return $DBH->selectrow_array("SELECT position FROM wallpaper WHERE sha1 = ?",undef,$sha)
}

#$sha
#deletes row of $sha from table
sub delete {
	my $sha = shift;
	$DBH->do("DELETE FROM wallpaper WHERE sha1 = ?", undef, $sha);
	$DBH->commit();
}

#$sha
#removes the position of $sha
sub remove_position {
	my ($sha) = shift;
	my $position = $DBH->selectrow_array("SELECT position FROM wallpaper WHERE sha1 = ?",undef,$sha);
	$DBH->do("UPDATE wallpaper SET position = - _rowid_ WHERE sha1 = ?", undef, $sha);
	$DBH->commit();
}

#$sha
#sets fav for $sha
sub set_fav {
	my $sha = shift;
	$DBH->do("UPDATE wallpaper SET fav = 1 WHERE sha1 = ?", undef, $sha);
	$DBH->commit();
}

#$sha, $vote
#increases vote amount of $sha by $vote
sub vote {
	my ($sha,$vote) = @_;
	$DBH->do("UPDATE OR FAIL wallpaper SET vote = vote + ? WHERE sha1 = ?" , undef , $vote,$sha)
		or die 'failed to update vote';
	$DBH->commit();
}

#$sha
#sets nsfw for $sha
sub set_nsfw {
	my $sha = shift;
	$DBH->do("UPDATE wallpaper SET nsfw = 1 WHERE sha1 = ?", undef, $sha);
	$DBH->commit();
}

# -> $max_pos
#returns the $max_pos
sub max_pos {
	return $DBH->selectrow_array("SELECT MAX(position) FROM wallpaper");
}

#$criteria -> \@[$path,$sha]
#takes a sql string of criteria and returns a list of paths and shas
sub get_list {
	my $criteria = shift;
	return $DBH->selectall_arrayref("SELECT path,sha1 FROM wallpaper WHERE ($criteria)");
}

#creates a random position value for each entry
sub determine_order {
	use List::Util 'shuffle';
	my @ids =  shuffle @{$DBH->selectcol_arrayref("SELECT _rowid_ FROM wallpaper WHERE position IS NULL")};
	my $sth = $DBH->prepare("UPDATE wallpaper SET position = ? WHERE _rowid_ = ?");
	my $from = (max_pos() // 0) + 1;
	my $to = $from - 1 + @ids;
	$sth->execute_array(undef, [shuffle ($from..$to)], \@ids);
	$DBH->commit();
}

#removes the order
sub remove_order {
	$DBH->do("UPDATE wallpaper SET position = NULL");
	$DBH->commit();
}

#$base
#search $base for wallpapers
sub add_folder {
	my ($base,$path) = @_;
	$path //= ""; # path is undef when we start at base
	$STH_INSERT = $DBH->prepare("INSERT OR FAIL INTO wallpaper (path) VALUES (?)");
	$PATHS = $DBH->selectall_hashref("SELECT path FROM wallpaper","path");
	$DBH->{AutoCommit} = 0;
	_add_folder($base,$path);
	$DBH->{AutoCommit} = 1;
}

#$base,$path
#recursive adds wallpapers in $base.$path
sub _add_folder {
	my ($base,$path) = @_;
	say $base.$path;

	opendir my $PIC, $base.$path or die $!;
	
	while(my $x = readdir($PIC)) {
		next if $x =~ m/^\.{1,2}$/; 
		if (-d $base.$path.$x) {
			_add_folder($base,$path.$x.'\\');
		}
		elsif (-f _) {
			if ($x =~ m/\.(jpe?g|gif|png|bmp)$/i) {
				insert_file($path.$x);
			}
		}
	}
	
	closedir($PIC);
	$DBH->commit();
}

#$path
#inserts a path into the database (if it is not present)
sub insert_file {
	my ($path) = @_;
	return if $PATHS->{$path}->{path};
	$STH_INSERT->execute($path);
	$PATHS->{$path}->{path} = $path;
}

1;
