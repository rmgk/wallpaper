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

say "loading wallpaper list";
WallpaperList::init($INI->{db_path},$INI->{wp_path},$INI->{check_doubles});

@ARGV or usage();
foreach (@ARGV) {
	when(undef) {usage()};
	when('delete') { delete_wp() };
	when('fav') { set_fav() };
	when('getfav') { getfav() };
	when('nsfw') { set_nsfw() };
	when('rand') { rand_wp() };
	when('teu') { teu() };
	when('tpu') { tpu() };
	when('voteup') {vote(1) };
	when('votedown') {vote(-1) };
	when('precompile') { precompile_wallpapers() };
	when(/-?\d+/) {change_wp($_)};
	default {usage()};
}

sub usage {
	say "\nThe following commandline options are available:\n";
	say "\tdelete - move to trash_path; removes from db";
	say "\tfav - set favourite flag";
	say "\tgetfav - move flagged with fav to fav_path";
	say "\tnsfw - set the nsfw flag";
	say "\tteu - search with tineye";
	say "\ttpu - upload to tinypic and open link";
	say "\tvoteup - increse vote value by 1 and change to next";
	say "\tvotedown - decrese vote value by 1 and change to next";
	say "\t'number' - change wallpaper by that amount";
}

sub set_fav {
	WallpaperList::set_fav($INI->{current});
}

sub set_nsfw {
	WallpaperList::set_nsfw($INI->{current});
}

sub delete_wp {
	my ($path,$sha) = WallpaperList::get_data($INI->{position});
	mkdir $INI->{trash_path} or die 'could not create folder'.$INI->{trash_path}.": $!" unless( -d $INI->{trash_path});
	say "moving ". $path ." to " . $INI->{trash_path};
	open my $f, ">>", $INI->{trash_path} . '_map.txt' or die "could not open ". $INI->{trash_path} . '_map.txt:' . $!;
	print $f $INI->{current} . "=" . $path . "\n";
	close $f;
	move($INI->{wp_path} . $path,$INI->{trash_path} . $INI->{current});
	WallpaperList::delete($INI->{current});
}

sub vote {
	my $vote = shift;
	WallpaperList::vote($INI->{current},$vote);
}

sub change_wp {
	my $mv = shift;
	my $pos = $INI->{position} + $mv;
	my $max_pos = WallpaperList::max_pos();
	my ($rel_path,$sha);
	while (1) {
		die "invalid position $pos" if ($pos < 1 or $pos > $max_pos);
		($rel_path,$sha) = WallpaperList::get_data($pos);
		last if $sha;
		return unless $mv;
		$pos += $mv <=> 0;
	}

	
	unless (gen_wp($rel_path,$sha)) {
		change_wp($mv <=> 0);
	}

	set_wallpaper($sha);
	$INI->{current} = $sha;
	$INI->{position} = $pos;
	WPConfig::save();
}

sub gen_wp {
	my ($rel_path,$sha) = @_;
	my $path = $INI->{wp_path} . $rel_path;
	mkdir $INI->{gen_path} or die 'could not create folder'.$INI->{gen_path} .": $!" unless -e $INI->{gen_path};
	say "processing file: \n$path";
	if (! -e $INI->{gen_path}  . $sha ) {
		unless (-e $path) {
			WallpaperList::delete($sha);
			return;
		}
		load_wallpaper($path);
		if (!check_wallpaper()) {
			WallpaperList::remove_position($sha);
			return;
		}
		adjust_wallpaper($rel_path);
		say "saving $sha";
		Wallpaper::saveAs($INI->{gen_path} .$sha, 'bmp');
	}
	return 1;
}

sub precompile_wallpapers {
	my $count = shift // -1;
	my $path = WallpaperList::forward(1);
	while($path && $count--) {
		precompile_wallpaper($path);
		$path = WallpaperList::forward(1);
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
	my $wp = shift;
	say "calling api to update wallpaper";
	Wallpaper::setWallpaper($INI->{gen_path} . $wp);
	return 1;
}

sub getfav {
	my $fav_dir = $INI->{fav_path} ;
	
	say "moving favourites to $fav_dir";
	mkdir $fav_dir or die 'could not create folder'.$fav_dir.": $!" unless -e $fav_dir;
	my $fav = WallpaperList::get_fav_list();
	
	foreach (@$fav) {
		say $_->[0];
		copy($INI->{wp_path} . $_->[0],$fav_dir);
	}
}

sub rand_wp {
	my $fav = WallpaperList::get_fav_list();
	my $sel = $fav->[int rand @$fav];
	gen_wp($sel->[0],$sel->[1]);
	set_wallpaper($sel->[1]);
	$INI->{current} = $sel->[1];
	WPConfig::save();
}

sub tpu {
	require UploadTools;
	my ($path,$sha) = WallpaperList::get_data($INI->{position});
	$path = $INI->{wp_path} . $path;
	UploadTools::tpu($path);
}

sub teu {
	require UploadTools;
	my ($path,$sha) = WallpaperList::get_data($INI->{position});
	$path = $INI->{wp_path} . $path;
	UploadTools::teu($path);
}

