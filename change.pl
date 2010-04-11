use 5.010;
use strict;
use warnings;

use lib "./lib";

use WallpaperList;
use Wallpaper;
use WPConfig;
use Cwd qw(abs_path);
use File::Copy;


say "Initialise";
my $INI = WPConfig::load() or die "could not load config";
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
	when('pregen') { pregenerate_wallpapers() };
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
	say "Fav: " . $INI->{current};
	WallpaperList::set_fav($INI->{current});
}

sub set_nsfw {
	say "NSFW: " . $INI->{current};
	WallpaperList::set_nsfw($INI->{current});
}

sub delete_wp {
	my ($path,$sha) = WallpaperList::get_data($INI->{position});
	mkdir $INI->{trash_path} or die 'could not create folder'.$INI->{trash_path}.": $!" unless( -d $INI->{trash_path});
	say "Move: ". $path ." To " . $INI->{trash_path};
	open my $f, ">>", $INI->{trash_path} . '_map.txt' or die "could not open ". $INI->{trash_path} . '_map.txt:' . $!;
	print $f $INI->{current} . "=" . $path . "\n";
	close $f;
	move($INI->{wp_path} . $path,$INI->{trash_path} . $INI->{current});
	WallpaperList::delete($INI->{current});
}

sub vote {
	my $vote = shift;
	say "Vote ($vote): " . $INI->{current};
	WallpaperList::vote($INI->{current},$vote);
}

sub rand_wp {
	say "Select Random";
	my $fav = WallpaperList::get_list($INI->{rand_criteria});
	warn "nothing matching criteria" and return unless @$fav;
	my $sel = $fav->[int rand @$fav];
	say "Selected " . $sel->[0] ." from " . @$fav; 
	gen_wp($sel->[0],$sel->[1]) or return;
	set_wallpaper($sel->[1]);
	say "SAVE CONFIG";
	$INI->{current} = $sel->[1];
	WPConfig::save();
}

sub change_wp {
	my $mv = shift;
	my $pos = $INI->{position} + $mv;
	my $max_pos = WallpaperList::max_pos();
	my ($rel_path,$sha);
	while (1) {
		warn "invalid position $pos" and return if ($pos < 1 or $pos > $max_pos);
		($rel_path,$sha) = WallpaperList::get_data($pos);
		last if $sha;
		return unless $mv;
		$pos += $mv <=> 0;
	}

	say "Change To: $rel_path ($pos)";
	
	unless (gen_wp($rel_path,$sha)) {
		change_wp($mv <=> 0);
	}

	set_wallpaper($sha);
	say "Save Config";
	$INI->{current} = $sha;
	$INI->{position} = $pos;
	WPConfig::save();
}

sub gen_wp {
	my ($rel_path,$sha) = @_;
	my $path = $INI->{wp_path} . $rel_path;
	mkdir $INI->{gen_path} or die 'could not create folder'.$INI->{gen_path} .": $!" unless -e $INI->{gen_path};
	if (! -e $INI->{gen_path}  . $sha ) {
		say "Processing: \n\t$rel_path";
		unless (-e $path) {
			say "\t$path does not exist, deleting from db" ;
			WallpaperList::delete($sha);
			return;
		}
		load_wallpaper($path);
		if (!check_wallpaper()) {
			say "\twallpaper failed checks, removing from rotation";
			WallpaperList::remove_position($sha);
			return;
		}
		adjust_wallpaper($rel_path);
		say "\tSave As: $sha";
		Wallpaper::saveAs($INI->{gen_path} .$sha, 'bmp');
	}
	return 1;
}

sub pregenerate_wallpapers {
	my $pct = $INI->{pregenerate_to} // $INI->{position};
	my $pcf = $INI->{pregenerate_from} // $INI->{position};
 	my $amount = $INI->{pregenerate_amount} // 0;
	if (($pct - $INI->{position}) < $amount) {
		my $pos = $pct;
		$pct = $INI->{position} + $amount;
		say "Pregenerate from $pos to $pct";
		$INI->{pregenerate_to} = $pct;
		WPConfig::save();
		
		while(++$pcf <= ($INI->{position} - $amount)) {
			my ($path,$sha) = WallpaperList::get_data($pcf);
			next unless $sha;
			unlink($INI->{gen_path} . $sha);
		}
		
		$INI->{pregenerate_from} = $pcf;
		WPConfig::save();
		while(++$pos <= $pct) {
			my ($path,$sha) = WallpaperList::get_data($pos);
			next unless $path and $sha;
			gen_wp($path,$sha);
		}
	}
}

sub load_wallpaper {
	my $file = shift; 
	Wallpaper::openImage($file);
}

sub check_wallpaper {
	my ($iw,$ih) = Wallpaper::getDimensions();
	my ($rx,$ry) = split(/\D+/,$INI->{min_resulution});
	return 0 if (!defined $iw or !defined $ih);
	my $iz = $iw/$ih;
	say "\tDIMENSIONS: $iw x $ih ($iz)";
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

	my $abw = 1 + $INI->{max_deformation};

	if (($iz < $rz * $abw) && ($iz > $rz / $abw)) {
		say sprintf ("\tdeformation IN range (%.2f < %.2f < %.2f) - full screen" , $rz / $abw , $iz , $rz*$abw);
		Wallpaper::resize($rx,$ry);
	}
	else {
		say sprintf ("\tdeformation OUT of range (%.2f < %.2f < %.2f) - keeping ratio",$rz /$abw , $iz , $rz*$abw);
		Wallpaper::resizeKeep($rx,$ry);
		Wallpaper::extend($rx,$ry,$INI->{taskbar_offset});
	}

	#Wallpaper::liquidResize($rx,$ry);
	
	if ($INI->{extend_black}) {
		Wallpaper::extendBlackNorth(split(/\D+/,$INI->{extend_black}));
	}
	
	if ($INI->{annotate} ne "none") { 
		say "\tAnnotating (".$INI->{annotate}.')';
		$file =~ s'\\'/'g;
		if ($INI->{annotate} eq "path_multiline") {
			my @filename = reverse split m'/', $file;
			my $off = $INI->{anno_offset};
			for (@filename) {
				Wallpaper::annotate($_,$off);
				$off += 16
			}
		}
		else {
			$file =~ s#.+/## unless $INI->{annotate} eq "path";
			Wallpaper::annotate($file,$INI->{anno_offset});
		}
	}
	return 1;
}

sub set_wallpaper {
	my $wp = shift;
	say "Call API to set wallpaper $wp";
	Wallpaper::setWallpaper($INI->{gen_path} . $wp);
	return 1;
}

sub getfav {
	my $fav_dir = $INI->{fav_path} ;
	
	say "MOVE favourites to $fav_dir";
	mkdir $fav_dir or die 'could not create folder'.$fav_dir.": $!" unless -e $fav_dir;
	my $fav = WallpaperList::get_list('fav = 1');
	
	foreach (@$fav) {
		say $_->[0];
		copy($INI->{wp_path} . $_->[0],$fav_dir);
	}
}

sub tpu {
	require UploadTools;
	my $sha = $INI->{current};
	my $path = WallpaperList::get_path($sha);
	$path = $INI->{wp_path} . $path;
	UploadTools::tpu($path);
}

sub teu {
	require UploadTools;
	my $sha = $INI->{current};
	my $path = WallpaperList::get_path($sha);
	$path = $INI->{wp_path} . $path;
	UploadTools::teu($path);
}

