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
	$DBH = DBI->connect("dbi:SQLite:dbname=". $DB_PATH,"","",{AutoCommit => 0,PrintError => 1});

	if($DBH->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='wallpaper'")) {
		return 1;
	}

	say "Creating Wallpaper Table";
	$DBH->do("CREATE TABLE wallpaper (position INT UNIQUE, sha1 CHAR UNIQUE, path CHAR UNIQUE, vote INT, fav INT, nsfw INT, deleted INT)")
		or die "could not create table";
	return 1;
}

#$position -> ($path,$sha)
#returns the path and sha value for the given $position
sub get_data {
	my $position = shift;
	my ($path,$sha) = $DBH->selectrow_array("SELECT path, sha1 FROM wallpaper WHERE position = ?",undef,$position);
	if ($path and !$sha) {
		return gen_sha($path);
	}
	return ($path , $sha) if $path and $sha;
	return undef;
}

#$path -> ($path,$sha,$double)
#calculates the sha value and updates the database
#returns undef if sha could not be calculated
#returns $double if the sha already existed
sub gen_sha {
	my ($path, $sha) = @_;
	if (! -e $WP_PATH . $path) {
		$DBH->do("DELETE FROM wallpaper WHERE path = ?", undef, $path);
	}
	else {
		$sha = $SHA->addfile($WP_PATH . $path,"b")->hexdigest;
		$sha or die "could not get sha of $path";
		unless ($DBH->do("UPDATE OR FAIL wallpaper SET sha1 = ? WHERE path = ?",undef,$sha,$path)) {
			$DBH->do("DELETE FROM wallpaper WHERE path = ?", undef, $path);
			my ($double) = $DBH->selectrow_array("SELECT path FROM wallpaper WHERE sha1 = ?",undef,$sha);
			return ($path,$sha,$double);
		}
	}
	$DBH->commit();
	return ($path, $sha);
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
#markes $sha as deleted
sub mark_deleted {
	my $sha = shift;
	$DBH->do("UPDATE wallpaper SET deleted = 1, position = - _rowid_ WHERE sha1 = ?", undef, $sha);
	$DBH->commit();
}

#$criteria -> \@[$path,$sha]
#takes a sql string of criteria and returns a list of paths and shas
sub mark_all_deleted {
	my ($criteria) = @_;
	$DBH->do("UPDATE wallpaper SET deleted = 1 WHERE ($criteria) ");
	$DBH->commit();
}

#$sha
#removes the position of $sha
sub remove_position {
	my ($sha) = shift;
	# my $position = $DBH->selectrow_array("SELECT position FROM wallpaper WHERE sha1 = ?",undef,$sha);
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
#set vote of $sha to $vote
sub vote {
	my ($sha,$vote) = @_;
	$DBH->do("UPDATE OR FAIL wallpaper SET vote = ? WHERE sha1 = ?", undef, $vote, $sha)
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

#$sha
#sets sketchy for $sha
sub set_sketchy {
	my $sha = shift;
	$DBH->do("UPDATE wallpaper SET nsfw = 0 WHERE sha1 = ?", undef, $sha);
	$DBH->commit();
}

#$sha
#removes nsfw, fav and vote
sub purge {
	my $sha = shift;
	$DBH->do("UPDATE wallpaper SET nsfw = NULL, fav = NULL, vote = NULL WHERE sha1 = ?", undef, $sha);
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
	my ($criteria, $additional_clauses) = @_;
	return $DBH->selectall_arrayref("SELECT path,sha1 FROM wallpaper WHERE ($criteria) AND deleted IS NULL " . ($additional_clauses // ""));
}

#-> \@[$path,$sha]
#returns a list of deleted paths and shas
sub get_deleted {
	return $DBH->selectall_arrayref("SELECT path,sha1 FROM wallpaper WHERE deleted IS NOT NULL ");
}

#$sha -> \%{column => value}
sub get_stat {
	my $sha = shift;
	return $DBH->selectrow_hashref("SELECT * FROM wallpaper WHERE sha1 = ?",undef , $sha);
}

#creates a random position value for each entry
sub determine_order {
	my $criteria = shift;
	use List::Util 'shuffle';
	my $old_autocommit = $DBH->{AutoCommit};
	$DBH->{AutoCommit} = 0;
	my @ids =  shuffle @{$DBH->selectcol_arrayref("SELECT _rowid_ FROM wallpaper WHERE ($criteria) AND deleted IS NULL")};
	my $sth = $DBH->prepare("UPDATE wallpaper SET position = ? WHERE _rowid_ = ?");
	my $from = (max_pos() // 0) + 1;
	my $to = $from - 1 + @ids;
	$sth->execute_array(undef, [shuffle ($from..$to)], \@ids);
	$DBH->commit();
	$DBH->{AutoCommit} = $old_autocommit;
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
	my $old_autocommit = $DBH->{AutoCommit};
	$DBH->{AutoCommit} = 0;
	_add_folder($base,$path);
	$DBH->{AutoCommit} = $old_autocommit;
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

#vacuum the database which reclaims free space
sub vacuum {
	$DBH->do('vacuum');
	$DBH->commit();
}

1;
