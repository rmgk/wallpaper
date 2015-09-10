package Change;

use 5.010;
use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";

use lib "./lib";
use utf8;
use FindBin;
use lib $FindBin::Bin.'/lib';

use WallpaperList;
use WPConfig;
use Cwd qw(abs_path);
use File::Copy;
use Time::HiRes;


my $TIME = Time::HiRes::time;
our $START_TIME = $TIME;
our $INI;

sub timing {
	my $ct = Time::HiRes::time;
	my $ret = sprintf "(%.3f | %.3f)", $ct - $TIME, $ct - $START_TIME;
	$TIME = $ct;
	return $ret;
}

sub say_timed {
	say @_, " ", timing
}

sub reload {
	say_timed "Load";
	$INI = WPConfig::load($FindBin::Bin . "/") or die "could not load config";
	WallpaperList::init($INI->{db_path},$INI->{wp_path});
}

sub commit {
	WallpaperList::commit();
	say_timed "commited";
}

sub dispatch {
	for (@_) {
		when(undef) { usage() };
		when('delete') { delete_wp() };
		when('delete_all') { delete_all() };
		when('delete_deleted') { delete_deleted() };
		when('delete_missing') { delete_missing() };
		when('export') { export() };
		when('fav') { set_fav() };
		when('hash_all') { hash_all() };
		when('nsfw') { set_nsfw() };
		when('open') { open_wallpaper() };
		when('pregen') { pregenerate_wallpapers() };
		when('purge') { purge() };
		when('rand') { rand_wp() };
		when('reorder') { reorder_wp(); };
		when('rescan') { index_wp_path() };
		when('sketchy') { set_sketchy() };
		when('stat') { show_wp_stat() };
		when('teu') { teu() };
		when('upload') { upload() };
		when('vacuum') { vacuum() };
		when('voteup') { vote(1) };
		when('votedown') { vote(-1) };
		when(qr/^rand\s+(.+)/i) { display_query($1) };
		when(/-?\d+/) { change_wp($_)};
		default { usage() };
	}
}

sub usage {
	say "\nThe following commandline options are available:\n";
	say "\tdelete - move to trash_path";
	say "\tdelete_all - mark all matching delete_criteria as deleted";
	say "\tdelete_deleted - move all files marked as deleted to trash";
	say "\tdelete_missing - mark all wallpapers that are missing on disk as manually deleted";
	say "\texport - export selection to export_path";
	say "\tfav - set favourite flag";
	say "\thash_all - hash all unhashed files";
	say "\tnsfw - set the nsfw flag";
	say "\topen - opens the image";
	say "\tpregen - pregenerates an amount of wallpapers specified by pregen_amount";
	say "\tpurge - removes flags and votes from wallpaper";
	say "\trand - select a random wallpaper based on rand_criteria";
	say "\treorder - recreates the order of the wallpapers according to the order_criteria";
	say "\trescan - rescans the wp_path for wallpapers";
	say "\tsketchy - sets the nsfw level to sketchy";
	say "\tstat - displays statistics for the current image";
	say "\tteu - search with tineye";
	say "\tupload - upload to some image hoster and open link";
	say "\tvacuum - rebuild the database to reclaim free space";
	say "\tvoteup - vote wallpaper up";
	say "\tvotedown - vote wallpaper down";
	say "\t\"rand <query where clause>\" - executes the query and displays a random result";
	say "\t'number' - change wallpaper by that amount";
}

sub index_wp_path {
	say_timed "Indexing wp_path";
	WallpaperList::add_folder($INI->{wp_path});
	say_timed "Adding Random Order", ;
	WallpaperList::determine_order($INI->{order_criteria});
}

sub hash_all {
	say_timed "Hashing all files";
	my $files = WallpaperList::get_list('path IS NOT NULL AND sha1 IS NULL');
	for (@$files) {
		my ($path, $sha) = @$_;
		say $path;
		WallpaperList::gen_sha($path);
	}
}

sub reorder_wp {
	say_timed "removing old order";
	WallpaperList::remove_order();
	say_timed "creating new order";
	WallpaperList::determine_order($INI->{order_criteria});
	$INI->{position} = 1;
	WPConfig::save();
}

sub set_fav {
	say "Fav: " . $INI->{current};
	WallpaperList::set_fav($INI->{current});
}

sub set_nsfw {
	say "NSFW: " . $INI->{current};
	WallpaperList::set_nsfw($INI->{current});
}

sub set_sketchy {
	say "Sketchy: " . $INI->{current};
	WallpaperList::set_sketchy($INI->{current});
}

sub purge {
	say "PURGE: " . $INI->{current};
	WallpaperList::purge($INI->{current});
}

sub show_wp_stat {
	my %gstat = WallpaperList::get_global_stats();
	my %stat = WallpaperList::get_stat($INI->{current});
	say "STATS (global): ";
	foreach (sort keys %gstat) {
		say "\t$_: " . (defined $gstat{$_} ? $gstat{$_} : "undef");
	}
	say "STATS (current): ";
	foreach (sort keys %stat) {
		say "\t$_: " . (defined $stat{$_} ? $stat{$_} : "undef");
	}
}

sub delete_wp {
	my $pos = shift // $INI->{position};
	my ($path,$sha) = get_data($pos);
	warn "could not get path" and return unless ($path);
	WallpaperList::mark_deleted($sha, 1);
	_delete($path,$sha);
}

sub delete_all {
	say_timed "marking as deleted";
	my $list = WallpaperList::mark_all_deleted($INI->{delete_all_criteria});
}

sub delete_missing {
	say_timed "checking for missing files";
	WallpaperList::mark_missing_as_deleted(-1);
}

sub delete_deleted {
	my $list = WallpaperList::get_deleted();
	foreach (@$list) {
		_delete(@$_);
	}
}

sub _delete {
	my ($path,$sha) = @_;
	return unless -e $INI->{wp_path} . $path;
	mkdir $INI->{trash_path} or die 'could not create folder'.$INI->{trash_path}.": $!" unless( -d $INI->{trash_path});
	say "Move: ". $path ." To " . $INI->{trash_path};
	open my $f, ">>", $INI->{trash_path} . '_map.txt' or die "could not open ". $INI->{trash_path} . '_map.txt:' . $!;
	print $f $sha . "=" . $path . "\n";
	close $f;
	move($INI->{wp_path} . $path,$INI->{trash_path} . $sha);
}

sub vote {
	my $vote = shift;
	say "Vote ($vote): " . $INI->{current};
	WallpaperList::vote($INI->{current},$vote);
}

sub rand_wp {
	say_timed "Select Random";
	display_query($INI->{rand_criteria});
}

sub change_wp {
	my $mv = shift;
	my $pos = $INI->{position} + $mv;
	my $max_pos = WallpaperList::max_pos();
	my ($rel_path,$sha);
	while (1) {
		warn "invalid position $pos" and return if ($pos < 1 or $pos > $max_pos);
		($rel_path,$sha) = get_data($pos);
		last if $sha and $rel_path;
		return unless $mv;
		$pos += $mv <=> 0;
	}

	say_timed "Change To:";
	say "\t$rel_path ($pos)";

	unless (gen_wp($rel_path,$sha,"set")) {
		return change_wp($mv <=> 0);
	}

	say_timed "Save Config";
	$INI->{current} = $sha;
	$INI->{position} = $pos;
	# set_wallpaper($rel_path, $sha);
	WPConfig::save();
}

sub gen_wp {
	my ($rel_path,$sha,$set_wp) = @_;

	# do not pregen anything, if no gen path
	if (! $INI->{gen_path}) {
		if ($set_wp) {
			# no gen path, but still should set wallpaper
			return !set_wallpaper($rel_path, $sha);
		}
		return 1;
	}

	my $path = $INI->{wp_path} . $rel_path;
	mkdir $INI->{gen_path} or die 'could not create folder'.$INI->{gen_path} .": $!" unless -e $INI->{gen_path};
	my $gen_path = $INI->{gen_path}  . $sha;
	if (! -e $gen_path ) {
		say_timed "Processing:";
		say "\t$rel_path";
		unless (-e $path) {
			say "\t$path does not exist, remove position" ;
			WallpaperList::mark_deleted($sha, -1);
			return;
		}

		my $ret = exec_command($set_wp?"convert_set":"convert",
			path => $path,
			sha => $sha,
			gen_path => $gen_path,
			);

		if ($ret) { #returns true on failure
			say_timed "\twallpaper failed checks, removing from rotation";
			WallpaperList::mark_deleted($sha, 2);
			return;
		}

	}
	elsif($set_wp) {
		return !set_wallpaper($rel_path, $sha);
	}
	return 1;
}


sub set_wallpaper {
	my ($rel_path, $sha) = @_;
	return exec_command("set",
		path => $INI->{wp_path} . $rel_path,
		sha => $sha,
		gen_path => $INI->{gen_path} . $sha,
		);
}

sub exec_command {
	my ($type, %params) = @_;
	my $command = "";
	$command = $INI->{command_convert_set} if $type eq "convert_set";
	$command = $INI->{command_convert} if $type eq "convert";
	$command = $INI->{command_set} if $type eq "set";
	$command = $INI->{command_open_file} if $type eq "open_file";
	$command = $INI->{command_open_url} if $type eq "open_url";
	die "unknown command type: $type" unless $command;

	my @command = split /\s+/, $command;

	for my $key (keys %params) {
		s/\{$key\}/$params{$key}/egi for @command;
	}

	say_timed "Executing ", join " ", @command;

	return system(@command);
}

sub cleanup_generated_wallpapers {
	say_timed "Cleanup" ;
	opendir(my $dh, $INI->{gen_path}) or return;
	my @dir = grep {-f $INI->{gen_path}.$_ and $_ =~ /^\w+$/ and $_ ne $INI->{current}} readdir($dh);
	closedir $dh;
    foreach my $file (@dir) {
		my $pos = WallpaperList::get_pos($file);
		my $lower = $INI->{position} - $INI->{pregen_amount};
		my $upper = $INI->{position} + $INI->{pregen_amount};
		unlink $INI->{gen_path}.$file if !$pos or $pos < $lower or $pos > $upper;
	}
	say_timed "Cleanup Done";
}

sub pregenerate_wallpapers {
	lock_check('pregen') or return;
	lock_set('pregen');
	say_timed "Pregenerating";
 	my $count = $INI->{pregen_amount};
	my $pos = $INI->{position};
	while($count--) {
		my ($path,$sha) = get_data(++$pos);
		next unless $path and $sha;
		gen_wp($path,$sha);
	}
	lock_release('pregen');
}

sub get_data {
	my ($pos, $qpath) = @_;
	my ($path, $sha, $double) = $pos ?
		WallpaperList::get_data($pos) :
		WallpaperList::gen_sha($qpath);
	if ($double) {
		say "$path has same sha as $double";
		_delete($path,$sha);
		return (undef,undef)
	}
	return ($path,$sha);
}

sub export {
	my $export_dir = $INI->{export_path};
	my $export_criteria = $INI->{export_criteria};

	say "copy selected to $export_dir";
	mkdir $export_dir or die 'could not create folder'.$export_dir.": $!" unless -e $export_dir;
	my $selected = WallpaperList::get_list($export_criteria);

	foreach (@$selected) {
		say $_->[0];
		copy($INI->{wp_path} . $_->[0],$export_dir);
	}
}

sub upload {
	require UploadTools;
	my $sha = $INI->{current};
	my $path = WallpaperList::get_path($sha);
	$path = $INI->{wp_path} . $path;
	my $url = UploadTools::upload($path);
	exec_command("open_url", path => $url) if ($url);
}

sub teu {
	require UploadTools;
	my $sha = $INI->{current};
	my $path = WallpaperList::get_path($sha);
	$path = $INI->{wp_path} . $path;
	UploadTools::teu($path);
}

sub open_wallpaper {
	my $sha = $INI->{current};
	my $path = WallpaperList::get_path($sha);
	say_timed "Calling system";
	exec_command("open_file", path => $INI->{wp_path} . $path);
}

sub lock_check {
	my $lock = shift;
	return !-e $lock;
}

sub lock_set {
	my $lock = shift;
	my $r = open my $f, '>', $lock;
	close $f;
	return $r;
}

sub lock_release {
	my $lock = shift;
	return unlink $lock;
}

sub display_query {
	my ($query) = @_;
	say_timed "Select randomly from query";
	my $fav = WallpaperList::get_list('path IS NOT NULL AND (' . $query. ')', "ORDER BY RANDOM() LIMIT 1");
	warn "nothing matching criteria" and return unless @$fav;
	my $sel = $fav->[0];
	my ($path, $sha) = @$sel;
	($path, $sha) = get_data(0, $path) if $path and not $sha;
	say_timed "Selected " . $path;
	gen_wp($path,$sha, 'set') or return;
	say_timed "SAVE CONFIG";
	$INI->{current} = $sha;
	WPConfig::save();
}

sub vacuum {
	say_timed "vacuum wallpaper list";
	WallpaperList::vacuum();
}

1;
