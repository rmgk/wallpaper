use 5.010;
use strict;
use warnings;

use lib "./lib";

use WallpaperList;
use Wallpaper;
use WPConfig;
use Cwd qw(abs_path);
use File::Copy;

my $INI = WPConfig::load() or die "could not load config";

#say "loading wallpaper list";
#WallpaperList::init($INI->{db_path},$INI->{wp_path},$INI->{current},$INI->{check_doubles});

foreach (@ARGV) {
	when(undef) {usage()};
	when('delete') { delete_wp() };
	when('fav') { set_fav() };
	when('getfav') { getfav() };
	when('nsfw') { set_nsfw() };
	when('voteup') {vote(1) };
	when('votedown') {vote(-1) };
	when('tpu') { tpu() };
	when('teu') { teu() };
	when('precompile') { precompile_wallpapers() };
	when('next') { next_wp() };
	when('prev') { prev_wp() };
	when(/-?\d+/) {change_wp($_)};
	default {usage()};
}

sub usage {
	say "\nThe following commandline options are available:\n";
	say "\tdelete - move to trash_path; removes from db";
	say "\tfav - set favourite flag";
	say "\tgetfav - move flagged with fav to fav_path";
	say "\tnsfw - set the nsfw flag";
	say "\tvoteup - increse vote value by 1 and change to next";
	say "\tvotedown - decrese vote value by 1 and change to next";
	say "\ttpu - upload to tinypic and open link";
	say "\tteu - search with tineye";
	say "\t'number' - change wallpaper by that amount";
}

sub set_fav {
	WallpaperList::set_fav($INI->{current});
}

sub set_nsfw {
	WallpaperList::set_nsfw($INI->{current});
}

sub delete_wp {
	my ($sha,$path) = WallpaperList::get_data($INI->{position});
	mkdir folder('trash') or die 'could not create folder'.folder('trash').": $!" unless( -d folder('trash'));
	say "moving ". $path ." to " . folder('trash');
	open my $f, ">>", folder('trash') . '_map.txt' or die "could not open ". folder('trash') . '_map.txt:' . $!;
	print $f $INI->{current} . "=" . $path;
	close $f;
	move(folder('wp') . $path,folder('trash') . $INI->{current});
	WallpaperList::delete($INI->{current});
}

sub vote {
	my $vote = shift;
	WallpaperList::vote($INI->{current},$vote);
}

sub change_wp {
	my $mv = shift;
	my ($sha,$rel_path) = WallpaperList::get_data($INI->{position}+$mv);
	my $path = folder('wp').$rel_path;
	die "could not get data" unless $sha;
	mkdir folder('gen') or die 'could not create folder'.folder('gen').": $!" unless -e folder('gen');
	say "selecting file: \n$path";
	if (-e folder('gen') . $sha ) {
		say "using pregenerated bitmap";
		set_wallpaper(folder('gen') . $sha);
	}
	else {
		unless (-e $path) {
			WallpaperList::delete($sha);
			return;
		}
		
		load_wallpaper($path);
		if (!check_wallpaper()) {
			WallpaperList::remove_position($sha);
			return change_wp($mv);
		}
		adjust_wallpaper($rel_path);
		say "saving image";
		Wallpaper::saveAs(folder('gen').$sha, 'bmp');
		set_wallpaper($sha);
	}
	
}

sub precompile_wallpapers {
	my $count = shift // -1;
	my $path = WallpaperList::forward(1);
	while($path && $count--) {
		precompile_wallpaper($path);
		$path = WallpaperList::forward(1);
	}
}

sub precompile_wallpaper {
	my $path = shift;
	return 0 if -e $path . '.pcw';
	say "precompiling $path";
	load_wallpaper($path);
	if (check_wallpaper()) {
		adjust_wallpaper($path);
		Wallpaper::saveAs($path . '.pcw','bmp');
	}
}

sub load_wallpaper {
	my $file = shift; 
	say "opening image";
	
	Wallpaper::openImage($file);
}

sub check_wallpaper {
	my ($iw,$ih) = Wallpaper::getDimensions();
	my ($rx,$ry) = split(/\D+/,$INI->{min_resulution});
	return 0 if (!defined $iw or !defined $ih);
	my $iz = $iw/$ih;
	say "image dimensions: $iw x $ih ($iz)";
	if ($iw < $rx or $ih < $ry) {
		say "image to small";
		return 0
	}
	else {
		return 1
	}
}

sub adjust_wallpaper {
	my $file = shift; 
	my ($iw,$ih) = Wallpaper::getDimensions();
	
	my $iz = $iw/$ih;

	my ($rx,$ry) = split(/\D+/,$INI->{resulution});
	my $rz = $rx/$ry;

	say "screen resolution: $rx x $ry ($rz)";

	my $abw = 1 + $INI->{max_deformation};

	if (($iz < $rz * $abw) && ($iz > $rz / $abw)) {
		say sprintf ("deformation in range %.2f < %.2f < %.2f - resizing to full screen" , $rz / $abw , $iz , $rz*$abw);
		Wallpaper::resize($rx,$ry);
	}
	else {
		say sprintf ("deformation out of range %.2f < %.2f < %.2f - resizing while keeping ratio",$rz /$abw , $iz , $rz*$abw);
		Wallpaper::resizeKeep($rx,$ry);
		say "extending image with background color";
		Wallpaper::extend($rx,$ry,$INI->{taskbar_offset});
	}

	#Wallpaper::liquidResize($rx,$ry);
	
	if ($INI->{extend_black}) {
		Wallpaper::extendBlackNorth(split(/\D+/,$INI->{extend_black}));
	}
	
	if ($INI->{annotate} ne "none") { 
		say "annotating";
		if ($INI->{annotate} eq "path_multiline") {
			my @filename = reverse split '/', $file;
			my $off = $INI->{anno_offset};
			for (@filename) {
				Wallpaper::annotate($_,$off);
				$off += 16
			}
		}
		else {
			$file =~ s#.+[\\/]## unless $INI->{annotate} eq "path";
			Wallpaper::annotate($file,$INI->{anno_offset});
		}
	}
	return 1;
}

sub set_wallpaper {
	say "calling api to update wallpaper";
	Wallpaper::setWallpaper(folder('gen') . shift);
	return 1;
}

sub getfav {
	use File::Copy;
	my $fav_dir = folders('fav');
	
	say "moving favourites to $fav_dir";
	mkdir $fav_dir or die 'could not create folder'.$fav_dir.": $!" unless -e $fav_dir;
	my $fav = WallpaperList::get_fav_list();
	
	foreach (@$fav) {
		say $_;
		copy(folder('wp').$_,$fav_dir);
	}
}

sub tpu {
	require UploadTools;
	my ($sha,$path) = WallpaperList::get_data($INI->{position});
	UploadTools::tpu(folder('wp') . $path);
}

sub teu {
	require UploadTools;
	my ($sha,$path) = WallpaperList::get_data($INI->{position});
	UploadTools::teu(folder('wp') . $path);
}

