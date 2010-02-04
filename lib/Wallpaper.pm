package Wallpaper;

use 5.010;
use strict;
use warnings;

use Win32::API;
use Image::Magick;

use Cwd qw(abs_path);

my $iM = Image::Magick->new; 

use constant SPI_SETDESKWALLPAPER  => 20;
use constant SPIF_UPDATEANDSENDINI => 3;

my $OUTPUT_FILE = Cwd::getcwd() . '/wallpaper.bmp';
my $PNG_HACK;


sub setWallpaper {
	my $syspinf = Win32::API->new('user32','SystemParametersInfo', ["I","I","P","I"], "I") or die "Could not import function.\n";
	$syspinf->Call(SPI_SETDESKWALLPAPER, 0, $OUTPUT_FILE, SPIF_UPDATEANDSENDINI);
}

sub openImage {
	my $file = shift;
	$PNG_HACK = 1 if ($file =~ /\.png$/i);
	@$iM = ();
	$iM->Read($file);
	if (@$iM > 1) {
		my $tmp = $iM->[0];
		@$iM = ();
		$iM->[0] = $tmp;
	}
}


sub getDimensions {
	return $iM->get("width"), $iM->get("height");
}

sub resize {
	my ($x,$y) = @_;
	$iM->Resize(width=>$x,height=>$y);
}


sub resizeKeep {
	my ($x,$y) = @_;
	$iM->Resize(geometry=>$x."x".$y);
}

sub liquidResize {
	my ($x,$y) = @_;
	$iM->LiquidResize(geometry=>$x."x".$y,width=>$x,height=>$y);
}

sub annotate {
	my ($text,$off) = @_;
	#undercolor=>'rgba(255,255,255,0.5)',translate=>($off,0)
	$iM->Annotate(stroke=>'rgba(0,0,0,0.3)', text=>$text, gravity=>'SouthEast', antialias=>'true',strokewidth=>2,geometry=>"+0+$off");
	$iM->Annotate(fill=>'rgba(255,255,255,0.9)', text=>$text, gravity=>'SouthEast', antialias=>'true',geometry=>"+0+$off");
}

sub sumArray {
	my ($a,$b,$c) = @_;
	my @most;
	my $count = 0;
	my $i;
	my $n = 0;
	my @std;
	foreach (0..$#$a) {
		my $ti = ++ $i->{int($a->[$_]/32)}->{int($b->[$_]/32)}->{int($c->[$_]/32)};
		if ($ti>$count) {
			$count = $ti;
			$most[0] += $a->[$_];
			$most[1] += $b->[$_];
			$most[2] += $c->[$_];
			$n ++;
		}
		else {
			$std[0] += $a->[$_];
			$std[1] += $b->[$_];
			$std[2] += $c->[$_];
		}
	}
	
	if ($n > (@$a/5)) {
		say "using averaged main border color";
		return $most[0]/$n,$most[1]/$n,$most[2]/$n;
	}
	else {
		say "using general average border color";
		$std[0] += $most[0];
		$std[1] += $most[1];
		$std[2] += $most[2];
		
		my ($r,$g,$b) = ($std[0]/@$a,$std[1]/@$a,$std[2]/@$a);
		# my $avg = ($r+$b+$g) / 3;
		# if ((abs($r-$avg)<30) and (abs($g-$avg)<30) and (abs($b-$avg)<30)) {
			# if ($avg < 128) {
				# say "meh its grey brown whatever .. lets just use black";
				# return (0,0,0);
			# }
			# else {
				# say "meh its grey brown whatever .. lets just use white";
				# return (255,255,255);
			# }
		# }
		return ($r,$g,$b);
	}
}

sub extend {
	my ($x,$y,$offset) = @_;
	my ($w,$h) = getDimensions();
	
	my ($red,$green,$blue);
	$iM->Set(magick=>"rgb");
	my @image = unpack "C*", $iM->ImageToBlob(); # rgb triples
	
	my ($R,$G,$B);
	
	if ($w/$h < $x/$y) {
		#linksrechts	
		for (0..($h-1)) {
			#links
			my $p = (3*$_*$w);
			my ($r,$g,$b) = @image[$p..($p+2)];
			
			$R->[0]->[$_] += $r;
			$G->[0]->[$_] += $g;
			$B->[0]->[$_] += $b;
			
			#rechts
			$p = (3*($_*$w+$w-1));
			($r,$g,$b) = @image[$p..($p+2)];
			
			$R->[1]->[$_] += $r;
			$G->[1]->[$_] += $g;
			$B->[1]->[$_] += $b;
		}
		
		my $half = $x - int(($x - $w)/2);
		($red,$green,$blue)  = sumArray($R->[0],$G->[0],$B->[0]);
		$iM->Extent(geometry=>$half."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"East");
		($red,$green,$blue)  = sumArray($R->[1],$G->[1],$B->[1]);
		$iM->Extent(geometry=>$x."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"West");
	}
	else {
		#obenunten
		
		my @o;
		for (0..($w-1)) {
			#oben
			my $p = ($_*3);
			my ($r,$g,$b) = @image[$p..($p+2)];
			$R->[0]->[$_] += $r;
			$G->[0]->[$_] += $g;
			$B->[0]->[$_] += $b;
			
			#unten
			$p = ((($h-1)*$w+$_)*3);
			($r,$g,$b) = @image[$p..($p+2)];
			$R->[1]->[$_] += $r;
			$G->[1]->[$_] += $g;
			$B->[1]->[$_] += $b;
		}

		
		my $half = $y - int(($y - $h)/2) - $offset;
		if ($half > $h) {
			($red,$green,$blue)  = sumArray($R->[0],$G->[0],$B->[0]);
			$iM->Extent(geometry=>$x."x".$half,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"South");
		}
		($red,$green,$blue)  = sumArray($R->[1],$G->[1],$B->[1]);
		$iM->Extent(geometry=>$x."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"North");
	}


}

sub save {
	return saveAs($OUTPUT_FILE,'bmp',$PNG_HACK);
}

sub saveAs {
	my ($filename,$filetype,$png_hack) = @_;

	#$iM->Quantize(colorspace=>'gray');
	#say $iM->get("colorspace");
	#$iM->Quantize(colorspace=>"RGB");
	#$iM->Set(depth=>24);
	#$iM->Set(depth => 8);
	#$iM->Deskew();
	#$iM->Separate(channel=>"RGB");
	
	$iM->Set(alpha=>"Off");
	$iM->Strip();
	
	if ($png_hack) {
		say "using png hack";
		$iM->Set(magick => "jpg");
		my $temp = $iM->ImageToBlob();
		@$iM = ();
		$iM->BlobToImage($temp);
	}
	$iM->Write(filename=>"$filetype:$filename",depth=>"24", compression=>'None');
}

sub extendAlphaSaveAsNoHack {
	my ($x,$y,$filename,$filetype) = @_;
	$iM->Extent(geometry=>$x."x".$y,background=>"rgba(0,0,0,0)");
	$iM->Write(filename=>"$filetype:$filename");
}

sub extendBlackNorth {
	my ($x,$y) = @_;
	$iM->Extent(geometry=>$x."x".$y,background=>"rgba(0,0,0,255)",gravity=>"North");
}



1;