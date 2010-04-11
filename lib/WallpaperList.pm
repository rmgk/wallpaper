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
my $STH_UPDATE;
my $PATHS;
my $SHAS;
my $CHECK_DOUBLES;

sub init {
	$DB_PATH = shift or croak 'db_path not defined';
	$WP_PATH = shift or croak 'wp_path not defined';
	$CHECK_DOUBLES = shift // 0;
	say "connecting to database: " . $DB_PATH;
	$DBH = DBI->connect("dbi:SQLite:dbname=". $DB_PATH,"","",{AutoCommit => 0,PrintError => 1});

	if($DBH->selectrow_array("SELECT name FROM sqlite_master WHERE type='table' AND name='wallpaper'")) {
		return 1;
	}
	
	say "creating wallpapers table";
	$DBH->do("CREATE TABLE wallpaper (position INT UNIQUE, sha1 CHAR UNIQUE, path CHAR UNIQUE, vote INT, fav INT, nsfw INT)") 
		or die "could not create table";
	
	say "adding ". $WP_PATH ." to database";
	add_folder($WP_PATH);
	say "creating random order";
	determine_order();
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
				die "failed to update sha1 value. maybe duplicate? (not implemented yet)";
			}
		}
		$DBH->commit();
	}
	return ($path , $sha) if $path;
	return undef;
}
#$sha -> $path
#returns the $path for $sha
sub get_path {
	my $sha = shift;
	$DBH->selectrow_array("SELECT path FROM wallpaper WHERE sha1 = ?",undef,$sha)
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
	$DBH->do("UPDATE wallpaper SET position = NULL WHERE sha1 = ?", undef, $sha);
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
	$DBH->do("UPDATE wallpaper SET nsfw = 1 WHERE position = ?", undef, $sha);
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

sub determine_order {
	use List::Util 'shuffle';
	my @files =  shuffle @{$DBH->selectcol_arrayref("SELECT _rowid_ FROM wallpaper")};
	my $sth = $DBH->prepare("UPDATE wallpaper SET position = ? WHERE _rowid_ = ?");
	$sth->execute_array(undef, [shuffle (1..@files)], \@files);
	$DBH->commit();

}

sub add_folder {
	my ($base,$path) = @_;
	$path //= ""; # path is undef when we start at base
	$STH_INSERT = $DBH->prepare("INSERT OR FAIL INTO wallpaper (path,sha1) VALUES (?,?)");
	$STH_UPDATE = $DBH->prepare("UPDATE wallpaper SET path = ? WHERE sha1 = ?");
	$PATHS = $DBH->selectall_hashref("SELECT path, sha1 FROM wallpaper","path");
	$SHAS = $DBH->selectall_hashref("SELECT sha1, path FROM wallpaper","sha1");
	$DBH->{AutoCommit} = 0;
	_add_folder($base,$path);
	$DBH->{AutoCommit} = 1;
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
	$STH_INSERT->execute($path,$sha);
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
