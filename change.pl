use 5.010;
use strict;
use warnings;

use lib ".";
use util;
use Tie::File;
use Cwd qw(abs_path);

my($image, $x);

my $ini = readINI("config.ini")->{default};
my @pictures;

die "no in_list specified" unless $ini->{in_list};

unless (-e $ini->{in_list}) {
	use List::Util 'shuffle';
	my $dn = $ini->{directory};
	@pictures = piclist($dn);
	my %in;
	$in{$_} = 1 for @pictures;
	@pictures = shuffle keys %in;
	open(LST,">",$ini->{in_list}) or die "could not write list";
	foreach (@pictures) {
		print LST $_ . "\n";
	}
	close(LST)
	
}

say "loading list";

tie ( my (@in_list), 'Tie::File', $ini->{in_list}) or die "$!";

my $change = $ARGV[0];
if ((defined $change) and $ini->{out_list}) {
	tie ( my (@out_list), 'Tie::File', $ini->{out_list}) or die "$!";
	if ($change eq "lame") {
		use File::Copy;
		my $file = pop (@out_list);
		say "adding $file to lame list";
		move($file,'./lame/');
		if ($ini->{lame_list}) {
			open(LST,">>",$ini->{lame_list});
			print LST $file . "\n";
			close LST;
		}
	}
	elsif ($change eq "fav") {
		my $file = $out_list[-1];
		say "adding $file to favorites";
		if ($ini->{fav_list}) {
			open(LST,">>",$ini->{fav_list});
			print LST $file . "\n";
			close LST;
		}
		exit;
	}
	elsif ($change <= 0) {
		$change *= -1;
		for (0..$change) {
			unshift(@in_list,pop(@out_list));
		}
	}
	else {
		for (2..$change) {
			push(@out_list,shift(@in_list));
		}
	}
	untie(@out_list);
}

my $file = shift @in_list;
die "no file found" unless $file;
untie @in_list or die "$!";

if ($ini->{out_list}) {
	open(LST,">>",$ini->{out_list});
	print LST $file . "\n";
	close LST;
}

say "selecting file: \n$file";

die "does not exist!" unless -e $file;

say "opening image";
openImage($file);

my ($iw,$ih) = getDimensions();
my $iz = $iw/$ih;

say "image dimensions: $iw x $ih ($iz)";

my ($rx,$ry) = split(/\D+/,$ini->{resulution});
my $rz = $rx/$ry;

say "screen resolution: $rx x $ry ($rz)";

my $abw = 1 + $ini->{max_deformation};


if (($iz < $rz * $abw) && ($iz > $rz / $abw)) {
	say sprintf ("deformation in range %.2f < %.2f < %.2f - resizing to full screen" , $rz / $abw , $iz , $rz*$abw);
	resize($rx,$ry);
}
else {
	say sprintf ("deformation out of range %.2f < %.2f < %.2f - resizing while keeping ratio",$rz /$abw , $iz , $rz*$abw);
	resizeKeep($rx,$ry);
	say "extending image with background color";
	extend($rx,$ry,$ini->{taskbar_offset});
}

#liquidResize($rx,$ry);

say "annotating";
my ($filename) = $file;
$filename =~ s#.+[\\/]##;
annotate($filename,$ini->{anno_offset});

my $filetype = $ini->{filetype} // "bmp";
say "saving image as $filetype";
saveAs("wallpaper.$filetype",$filetype,$file =~ /\.png$/i);

say "calling api to update wallpaper";
setWallpaper(abs_path("wallpaper.$filetype")); # 

if ($ini->{thumbnail}) {
	say "creating thumbnail";
	openImage($file);
	resizeKeep(split('x',$ini->{thumbnail}));
	extendAlphaSaveAsNoHack(split('x',$ini->{thumbnail}),"thumb.png","png");
}

say "done";