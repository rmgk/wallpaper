package Wallpaper;

use 5.010;
use strict;
use warnings;

use Win32::API;
use Image::Magick;

use Cwd qw(abs_path);

my $iM;

use constant SPI_SETDESKWALLPAPER  => 20;
use constant SPIF_UPDATEANDSENDINI => 3;

my $cwd = Cwd::getcwd() .'\\' ;
my $PNG_HACK;

my $IMG = 0;


sub setWallpaper {
	my $wp = shift;
	my $syspinf = Win32::API->new('user32','SystemParametersInfo', ["I","I","P","I"], "I") or die "Could not import function.\n";
	$syspinf->Call(SPI_SETDESKWALLPAPER, 0, $cwd . $wp, SPIF_UPDATEANDSENDINI);
}

sub openImage {
	my $file = shift;
	$PNG_HACK = 0;
	$PNG_HACK = 1 if ($file =~ /\.png$/i);
	$iM = Image::Magick->new(); 
	$iM->Read($file);
}


sub getDimensions {
	return $iM->[$IMG]->get("width"), $iM->[$IMG]->get("height");
}

sub resize {
	my ($x,$y) = @_;
	$iM->[$IMG]->Resize(width=>$x,height=>$y);
}


sub resizeKeep {
	my ($x,$y) = @_;
	$iM->[$IMG]->Resize(geometry=>$x."x".$y);
}

sub liquidResize {
	my ($x,$y) = @_;
	$iM->[$IMG]->LiquidResize(geometry=>$x."x".$y,width=>$x,height=>$y);
}

sub annotate {
	my ($text,$off) = @_;
	#undercolor=>'rgba(255,255,255,0.5)',translate=>($off,0)
	$iM->[$IMG]->Annotate(stroke=>'rgba(0,0,0,0.3)', text=>$text, gravity=>'SouthEast', antialias=>'true',strokewidth=>2,geometry=>"+0+$off");
	$iM->[$IMG]->Annotate(fill=>'rgba(255,255,255,0.9)', text=>$text, gravity=>'SouthEast', antialias=>'true',geometry=>"+0+$off");
}

sub annotateleft {
	my ($text,$off) = @_;
	#undercolor=>'rgba(255,255,255,0.5)',translate=>($off,0)
	$iM->[$IMG]->Annotate(stroke=>'rgba(0,0,0,0.3)', text=>$text, gravity=>'SouthWest', antialias=>'true',strokewidth=>2,geometry=>"+0+$off");
	$iM->[$IMG]->Annotate(fill=>'rgba(255,255,255,0.9)', text=>$text, gravity=>'SouthWest', antialias=>'true',geometry=>"+0+$off");
}

sub sumArray {
	my ($a,$b,$c) = @_;
	my $most;
	my $count = 0;
	my $i;
	my @std;
	my @m;
	my ($c1, $c2, $c3);
	foreach (0..$#$a) {
		$c1 = int($a->[$_]/16);
		$c2 = int($b->[$_]/16);
		$c3 = int($c->[$_]/16);
		my $ti = ++ $i->{$c1}->{$c2}->{$c3};
		if ($ti>$count) {
			$count = $ti;
			$m[0] = $c1;
			$m[1] = $c2;
			$m[2] = $c3;
		}
		$most->{$c1}->{$c2}->{$c3}->[0] += $a->[$_];
		$most->{$c1}->{$c2}->{$c3}->[1] += $b->[$_];
		$most->{$c1}->{$c2}->{$c3}->[2] += $c->[$_];
		$std[0] += $a->[$_];
		$std[1] += $b->[$_];
		$std[2] += $c->[$_];
	}
	
	if ($count > (@$a/20)) {
		say "\tuse average MAIN border color";
		return $most->{$m[0]}->{$m[1]}->{$m[2]}->[0]/$count,$most->{$m[0]}->{$m[1]}->{$m[2]}->[1]/$count,$most->{$m[0]}->{$m[1]}->{$m[2]}->[2]/$count;
	}
	else {
		say "\tuse average GENERAL border color";
		my ($r,$g,$b) = ($std[0]/@$a,$std[1]/@$a,$std[2]/@$a);
		return ($r,$g,$b);
	}
}

sub extend {
	my ($x,$y,$offset) = @_;
	my ($w,$h) = getDimensions();
	
	my ($red,$green,$blue);
	$iM->[$IMG]->Set(magick=>"rgb");
	my @image = unpack "C*", $iM->[$IMG]->ImageToBlob(); # rgb triples
	
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
		$iM->[$IMG]->Extent(geometry=>$half."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"East");
		($red,$green,$blue)  = sumArray($R->[1],$G->[1],$B->[1]);
		$iM->[$IMG]->Extent(geometry=>$x."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"West");
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
			$iM->[$IMG]->Extent(geometry=>$x."x".$half,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"South");
		}
		($red,$green,$blue)  = sumArray($R->[1],$G->[1],$B->[1]);
		$iM->[$IMG]->Extent(geometry=>$x."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"North");
	}


}

sub saveAs {
	my ($filename,$filetype,$png_hack) = @_;
	$png_hack //= $PNG_HACK;

	#$iM->[$IMG]->Quantize(colorspace=>'gray');
	#say $iM->[$IMG]->get("colorspace");
	#$iM->[$IMG]->Quantize(colorspace=>"RGB");
	#$iM->[$IMG]->Set(depth=>24);
	#$iM->[$IMG]->Set(depth => 8);
	#$iM->[$IMG]->Deskew();
	#$iM->[$IMG]->Separate(channel=>"RGB");
	
	$iM->[$IMG]->Set(alpha=>"Off");
	$iM->[$IMG]->Strip();
	
	if ($png_hack) {
		say "(using png hack)";
		$iM->[$IMG]->Set(magick => "jpg");
		my $temp = $iM->[$IMG]->ImageToBlob();
		$iM->[$IMG]->BlobToImage($temp);
		$iM->[$IMG] = $iM->[$IMG]->[1];
	}
	$iM->[$IMG]->Write(filename=>"$filetype:$filename",depth=>"24", compression=>'None');
}

sub extendAlphaSaveAsNoHack {
	my ($x,$y,$filename,$filetype) = @_;
	$iM->[$IMG]->Extent(geometry=>$x."x".$y,background=>"rgba(0,0,0,0)");
	$iM->[$IMG]->Write(filename=>"$filetype:$filename");
}

sub extendBlack {
	my ($x,$y,$grav) = @_;
	$iM->[$IMG]->Extent(geometry=>$x."x".$y,background=>"rgba(0,0,0,255)",gravity=>$grav);
}


sub copy {
	my $target = shift;
	$iM->[$target] = $iM->[$IMG]->clone()->[$IMG];
}

sub workWith {
	$IMG = shift;
}

sub append {
	my $target = shift;
	my $stack = shift // "false";
	$iM->[$target] = $iM->append(stack=>$stack);
}


1;