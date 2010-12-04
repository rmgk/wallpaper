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
WallpaperList::init($INI->{db_path},$INI->{wp_path});

if (!WallpaperList::max_pos()) {
	index_wp_path();
}

@ARGV or usage();
foreach (@ARGV) {
	when(undef) { usage() };
	when('delete') { delete_wp() };
	when('fav') { set_fav() };
	when('getfav') { getfav() };
	when('nsfw') { set_nsfw() };
	when('open') { open_wallpaper() };
	when('pregen') { pregenerate_wallpapers() };
	when('purge') { purge() };
	when('rand') { rand_wp() };
	when('reorder') { reorder_wp(); };
	when('rescan') { index_wp_path() };
	when('stat') { show_wp_stat() };
	when('teu') { teu() };
	when('upload') { upload() };
	when('voteup') { vote(1) };
	when('votedown') { vote(-1) };
	when(/-?\d+/) { change_wp($_)};
	default { usage() };
}

cleanup_generated_wallpapers();

sub usage {
	say "\nThe following commandline options are available:\n";
	say "\tdelete - move to trash_path; removes from db";
	say "\tfav - set favourite flag";
	say "\tgetfav - move flagged with fav to fav_path";
	say "\tnsfw - set the nsfw flag";
	say "\topen - opens the image";
	say "\tpregen - pregenerates an amount of wallpapers specified by pregen_amount";
	say "\tpurge - removes flags and votes from wallpaper";
	say "\trand - select a random wallpaper based on rand_criteria";
	say "\treorder - recreates the order of the wallpapers according to the order_criteria";
	say "\trescan - rescans the wp_path for wallpapers";
	say "\tstat - displays statistics for the current image";
	say "\tteu - search with tineye";
	say "\tupload - upload to some image hoster and open link";
	say "\tvoteup - increse vote value by 1 and change to next";
	say "\tvotedown - decrese vote value by 1 and change to next";
	say "\t'number' - change wallpaper by that amount";
}

sub index_wp_path {
	say "Indexing wp_path";
	WallpaperList::add_folder($INI->{wp_path});
	say "Adding Random Order";
	WallpaperList::determine_order("position IS NULL");
}

sub reorder_wp {
	say "removing old order";
	WallpaperList::remove_order();
	say "creating new order";
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

sub purge {
	say "PURGE: " . $INI->{current};
	WallpaperList::purge($INI->{current});
}

sub show_wp_stat {
	my $stat = WallpaperList::get_stat($INI->{current});
	say "STATS: ";
	foreach (keys %$stat) {
		say "\t$_: " . (defined $stat->{$_} ? $stat->{$_} : "undef");
	}
}

sub delete_wp {
	my $pos = shift // $INI->{position};
	my ($path,$sha) = get_data($pos);
	warn "could not get path" and return unless ($path);
	_delete($path,$sha);
	WallpaperList::delete($sha);
}

sub _delete {
	my ($path,$sha) = @_;
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
	say "Select Random";
	my $fav = WallpaperList::get_list('path IS NOT NULL AND sha1 IS NOT NULL AND (' . $INI->{rand_criteria} . ')');
	warn "nothing matching criteria" and return unless @$fav;
	my $sel = $fav->[int rand @$fav];
	say "Selected " . $sel->[0] ." from " . @$fav; 
	gen_wp($sel->[0],$sel->[1]) or return;
	say "SAVE CONFIG";
	$INI->{current} = $sel->[1];
	WPConfig::save();
	set_wallpaper($sel->[1]);

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

	say "Change To: $rel_path ($pos)";
	
	unless (gen_wp($rel_path,$sha)) {
		return change_wp($mv <=> 0);
	}
	
	say "Save Config";
	$INI->{current} = $sha;
	$INI->{position} = $pos;
	WPConfig::save();
	set_wallpaper($sha);

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
		#if (load_wallpaper($path)) {
		#	say "\twallpaper could not be loaded, removing from rotation";
		#	WallpaperList::remove_position($sha);
		#	return;
		#}
		#if (!check_wallpaper()) {
		#	say "\twallpaper failed checks, removing from rotation";
		#	WallpaperList::remove_position($sha);
		#	return;
		#}
		if (adjust_wallpaper($rel_path,$sha)) { #returns true on failure
			say "\twallpaper failed checks, removing from rotation";
			WallpaperList::remove_position($sha);
			return;
		}
		#say "\tSave As: $sha";
		#Wallpaper::saveAs($INI->{gen_path} .$sha, 'bmp');
	}
	return 1;
}

sub cleanup_generated_wallpapers {
	say "Cleanup";
	opendir(my $dh, $INI->{gen_path}) or return;
	my @dir = grep {-f $INI->{gen_path}.$_ and $_ =~ /^\w+$/ and $_ ne $INI->{current}} readdir($dh);
	closedir $dh;
    foreach my $file (@dir) {
		my $pos = WallpaperList::get_pos($file);
		my $lower = $INI->{position} - $INI->{pregen_amount};
		my $upper = $INI->{position} + $INI->{pregen_amount};
		unlink $INI->{gen_path}.$file if !$pos or $pos < $lower or $pos > $upper;
	}
}

sub pregenerate_wallpapers {
	lock_check('pregen') or return;
	lock_set('pregen');
	say "Pregenerating";
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
	my $pos = shift; 
	my ($path,$sha,$double) = WallpaperList::get_data($pos);
	if ($double) {
		say "$path has same sha as $double";
		_delete($path,$sha);
		return (undef,undef)
	}
	return ($path,$sha);
}

sub adjust_wallpaper {
	my ($file,$sha) = @_; 
	
	#my ($iw,$ih) = Wallpaper::getDimensions();

	my ($rx,$ry) = split(/\D+/,$INI->{resolution});

	my $abw = 1 + $INI->{max_deformation};
	
	my ($r2x,$r2y) = split(/\D+/,$INI->{resolution2});
	
	my ($sx,$sy) = split(/\D+/,$INI->{composite_position});
	
	my ($mx, $my) = split(/\D+/,$INI->{min_resolution});
	
	my $an1 = "";
	my $an2 = "";
	
	if ($INI->{annotate} ne "none") {
		my $f = $file;
		$f =~ s'\\'/'g;
		$f =~ s#.+/## unless $INI->{annotate} eq "path";
		$an1 = $f
	}
	if ($INI->{annotate2} ne "none") {
		my $f = $file;
		$f =~ s'\\'/'g;
		$f =~ s#.+/## unless $INI->{annotate2} eq "path";
		$an2 = $f
	}
	
	my $png_hack = 'bmp';
	if ($file ~~ /\.png$/i) {
		$png_hack = 'jpg';
	}
	
	#use Time::HiRes;
	#my $time =  Time::HiRes::time;
	
	my $ret = system('gwp.exe',$INI->{wp_path} . $file,"generated/$sha",$rx,$ry,$r2x,$r2y,$mx,$my,$abw,$sx,$sy,$an1,
							$INI->{anno_offset},$an2,$INI->{anno_offset2},'bmp',$png_hack);
	#say "system: $ret";
	#say  Time::HiRes::time - $time;
	return $ret;

	#Wallpaper::copy(1) if ($r2x and $r2y);

	#retarget_wallpaper($iw,$ih,$rx,$ry,$abw, $file ,
	#	$INI->{annotate},$INI->{anno_offset} ,
	#	$INI->{taskbar_offset},
	#	$INI->{skew});
	
	#if ($r2x and $r2y) {
	#	Wallpaper::workWith(1);
	#	retarget_wallpaper($iw,$ih,$r2x,$r2y,$abw, $file,
	#		$INI->{annotate2},$INI->{anno_offset2} ,
	#		$INI->{taskbar_offset2},
	#		$INI->{skew2});
	#	Wallpaper::append(0,$INI->{stack});
	#	Wallpaper::workWith(0);
	#}
}

sub retarget_wallpaper {
	my ($iw, $ih , $rx, $ry ,$abw,$file, $annotate,$anno_off,$off,$skew) = @_;
	my $iz = $iw/$ih;
	my $rz = $rx/$ry;
	
	if (($iz < $rz * $abw) && ($iz > $rz / $abw)) {
		say sprintf ("\tdeformation IN range (%.2f < %.2f < %.2f) - full screen" , $rz / $abw , $iz , $rz*$abw);
		Wallpaper::resize($rx,$ry);
	}
	else {
		say sprintf ("\tdeformation OUT of range (%.2f < %.2f < %.2f) - keeping ratio",$rz /$abw , $iz , $rz*$abw);
		Wallpaper::resizeKeep($rx,$ry);
		Wallpaper::extend($rx,$ry,$off);
	}
	
	for my $s (split (',',$skew)) {
		next unless $s;
		my $orientation;
		($rx,$ry,$orientation) = translate_skew($rx,$ry,$s);
		Wallpaper::extendBlack(($rx,$ry,$orientation));
	}
	
	if ($annotate ne "none") {
		$file =~ s'\\'/'g;
		if ($annotate eq "path_multiline") {
			my @filename = reverse split m'/', $file;
			my $off = $INI->{anno_offset};
			for (@filename) {
				Wallpaper::annotate($_,$off);
				$off += 16
			}
		}
		else {
			$file =~ s#.+/## unless $annotate eq "path";
			Wallpaper::annotate($file,$anno_off);
		}
	}
}

sub translate_skew {
	my ($rx,$ry, $skew ) = @_;
	my ($sx,$sy) = split(/[^\d-]+/,$skew);
	#say "skew $sx, $sy";
	my ($east_west, $north_south) = ("","");
	if ($sx) {
		if ($sx > 0) {
			$east_west = "West";
			$rx += $sx;
		}
		elsif ($sx < 0) {
			$east_west = "East";
			$rx -= $sx;
		}
	}	
	if ($sy) {
		if ($sy > 0) {
			$north_south = "South";
			$ry += $sy;
		}
		elsif ($sy < 0) {
			$north_south = "North";
			$ry -= $sy;
		}
	}
	#say "skeww:" . join(":",($rx,$ry,$north_south . $east_west));
	return ($rx,$ry,$north_south . $east_west);
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

sub upload {
	require UploadTools;
	my $sha = $INI->{current};
	my $path = WallpaperList::get_path($sha);
	$path = $INI->{wp_path} . $path;
	UploadTools::upload($path);
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
	say "Calling system";
	system($INI->{wp_path} . $path );
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
