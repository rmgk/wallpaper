use 5.010;
use strict;
use warnings;

use lib "./lib";
use WallpaperList;
use Wallpaper;
use ConfigRW;
use Cwd qw(abs_path);
use File::Copy;

use Data::Dumper;

my($image, $x);

ConfigRW::load() or die "could not load config";
my $INI = $ConfigRW::CFG;

say "loading wallpaper list";
WallpaperList::init($INI->{db_path},$INI->{wp_path},$INI->{current},$INI->{check_doubles});

given ($ARGV[0]) {
	when(undef) {usage()};
	when('delete') { delete_wp() };
	when('fav') { WallpaperList::fav_current() };
	when('getfav') { getfav() };
	when('nsfw') {WallpaperList::nsfw_current() };
	when('voteup') {vote(1) };
	when('votedown') {vote(-1) };
	when('tpu') { tpu() };
	when('teu') { teu() };
	when('foldervotelist') { make_folder_vote_list() };
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
	say "\tvoteup - increse vote value by 1 and change to next";
	say "\tvotedown - decrese vote value by 1 and change to next";
	say "\ttpu - upload to tinypic and open link";
	say "\tteu - search with tineye";
	say "\t'number' - change wallpaper by that amount";
}

sub delete_wp {
	use File::Copy;
	mkdir $INI->{trash_path} unless( -d $INI->{trash_path});
	my $current = WallpaperList::current();
	my $filename = $current;
	$filename =~ s~.*[/\\]~~;
	say "moving $current to " . $INI->{trash_path};
	move($current,$INI->{trash_path}.$filename);
	WallpaperList::remove_current();
	change_wp(1);
}

sub vote {
	my $vote = shift;
	WallpaperList::vote_current($vote);
	change_wp(1);
}

sub change_wp {
	my $mv = shift;
	my $path = WallpaperList::forward($mv);
	die "could not get next" unless $path;
	say "selecting file: \n$path";
	if (-e $path . '.pcw') {
		say "using procompiled bitmap";
		copy($path . '.pcw','wallpaper.bmp');
		set_wallpaper();
		ConfigRW::save($path,WallpaperList::current_position());
		return;
	}
	unless (-e $path) {
		delete_wp();
		return;
	}
	load_wallpaper($path);
	if (check_wallpaper()) {
		adjust_wallpaper($path);
		say "saving image";
		Wallpaper::save();
		set_wallpaper();
		ConfigRW::save($path,WallpaperList::current_position());
	}
	else {
		change_wp($mv<=>0);
	}
}

sub precompile_wallpapers {
	WallpaperList::forward(-10000000000000);
	my $path = WallpaperList::current();
	while($path) {
		say WallpaperList::current_position();
		precompile_wallpaper($path);
		$path = WallpaperList::forward(1);
	}
}

sub precompile_wallpaper {
	my $path = shift;
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
	WallpaperList::set_current_res($iw,$ih);
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

	#liquidResize($rx,$ry);
	
	if ($INI->{extend_black}) {
		Wallpaper::extendBlackNorth(split(/\D+/,$INI->{extend_black}));
	}
	
	if ($INI->{annotate} ne "none") { 
		say "annotating";
		my ($filename) = $file;
		my $p = $INI->{wp_path};
		$filename =~ s/^\Q$p\E//i;
		$filename =~ s#\\#/#g;
		if ($INI->{annotate} eq "path_multiline") {
			my @filename = reverse split '/', $filename;
			my $off = $INI->{anno_offset};
			for (@filename) {
				Wallpaper::annotate($_,$off);
				$off += 16
			}
		}
		else {
			$filename =~ s#.+[\\/]## unless $INI->{annotate} eq "path";
			Wallpaper::annotate($filename,$INI->{anno_offset});
		}
	}
	return 1;
}

sub set_wallpaper {
	say "calling api to update wallpaper";
	Wallpaper::setWallpaper();
	return 1;
}

sub getfav {
	use File::Copy;
	my $fav_dir = $INI->{fav_path};
	
	say "moving favourites to $fav_dir";
	mkdir $fav_dir;
	my $fav = WallpaperList::get_fav();
	
	foreach (@$fav) {
		say $_;
		copy($INI->{wp_path}.$_,$fav_dir);
	}
}

sub init_ua {
	use LWP;
	use LWP::UserAgent;
	use HTTP::Request::Common qw(POST);
	my $ua = new LWP::UserAgent;  
	$ua->agent("wpc.pl");
	$ua->env_proxy;
	return $ua;
}

sub teu {
	my $file = WallpaperList::current();
	my $ua = init_ua();
	
	say "posting file";
	my $request = POST 'http://www.tineye.com/search' ,
			Content_Type => 'form-data',
			Content      => [ 
								image   => [$file],
							];
							
	my $response = $ua->request($request);
	say "calling system";
	system("start " . $response->header("Location"));
}

sub tpu {
	my $file = WallpaperList::current();
	my $ua = init_ua();


	say "requesting user id";
	my $request = HTTP::Request->new(GET => "http://www.tinypic.com/");
	my $response = $ua->request($request);

	my $UI;
	my $upk;
	my $server;
	my $content = $response->content();

	if ($content =~ m#name="UPLOAD_IDENTIFIER" id="uid" value="([^"]+)"#is) {
		$UI = $1;
	}
	if ($content =~ m#name="upk" value="([^"]+)"#is) {
		$upk = $1;
	}
	if ($content =~ m#<form action="([^"]+)" method="post"#i) {
		$server = $1;
	}

	say "uploading file";
	$request = POST $server ,
			Content_Type => 'form-data',
			Content      => [ 
								the_file   => [$file],
								UPLOAD_IDENTIFIER => $UI,
								upk => $upk,
								action => "upload",
								shareopt => "true",
								file_type => "image",
								dimension => "1600",
							];
							
	$response = $ua->request($request);
	
	say "getting direct link";
	$content = $response->content();
	
	$content =~ m#<a href="([^"]+)" target="_blank">Click here</a> to view your image#si;

	$request = HTTP::Request->new(GET => $1);
	$response = $ua->request($request);

	$content = $response->content();

	$content =~ m#<a href="([^"]+)" class="thickbox">Zoom</a>#si;

	say "calling system";
	system("start " . $1);
}

sub make_folder_vote_list {
	my $ary = WallpaperList::get_folder_vote_list();
	my $h;
	for my $a (@$ary) {
		$a->[0] =~ s/^((?:[^\\]*\\){0,3}).*$/$1/;
		$h->{$a->[0]}->[$a->[1] < 0] += $a->[1];
	}
	my $f;
	open ($f,">list.txt");
	my $t = Dumper $h;
	$t =~ s/\\\\/\\/g;
	print $f $t;
	close $f;
}
