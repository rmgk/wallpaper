#!perl
#this program is free software it may be redistributed under the same terms as perl itself
package Comic;

use 5.010;
use strict;
use warnings;

use Image::Magick;

sub new {
	my $class = shift;
	my $s = shift || {};
	bless $s,$class;
	$s->{iM} = Image::Magick->new; 
	$s->{filename} //= "wallpaper";
	$s->{filetype} //= "bmp"
}

sub iM {
	my $s = shift;
	return $s->{iM};
}

sub openImage {
	my $s = shift;
	my $file = $s->{file};
	$s->iM->Read($file);
}


sub getDimensions {
	my $s = shift;
	return $s->iM->get("width"), $s->iM->get("height");
}

sub resize {
	my $s = shift;
	my ($x,$y) = @_;
	$s->iM->Resize(width=>$x,height=>$y);
}


sub resizeKeep {
	my $s = shift;
	my ($x,$y) = @_;
	$iM->Resize(geometry=>$x."x".$y);
}

sub liquidResize 
	my $s = shift;
	my ($x,$y) = @_;
	$s->iM->LiquidResize(geometry=>$x."x".$y,width=>$x,height=>$y);
}

sub annotate {
	my $s = shift;
	my ($text,$off) = @_;
	$text //= $s->{file};
	$off //= $s->{anno_offset}
	#undercolor=>'rgba(255,255,255,0.5)',translate=>($off,0)
	$s->iM->Annotate(stroke=>'rgba(0,0,0,0.3)', text=>$text, gravity=>'SouthEast', antialias=>'true',strokewidth=>2,geometry=>"+0+$off");
	$s->iM->Annotate(fill=>'rgba(255,255,255,0.9)', text=>$text, gravity=>'SouthEast', antialias=>'true',geometry=>"+0+$off");
}

sub sumArray {
	my $s = shift;
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
	my $s = shift;
	my ($x,$y,$offset) = @_;
	$x //= $s->{new_x};
	$y //= $s->{new_y};
	$offset //= $s->{extend_offset};
	my ($w,$h) = getDimensions();
	
	my ($red,$green,$blue);
	$s->iM->Set(magick=>"rgb");
	my @image = unpack "C*", $s->iM->ImageToBlob(); # rgb triples
	
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
		$s->iM->Extent(geometry=>$half."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"East");
		($red,$green,$blue)  = sumArray($R->[1],$G->[1],$B->[1]);
		$s->iM->Extent(geometry=>$x."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"West");
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
			$s->iM->Extent(geometry=>$x."x".$half,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"South");
		}
		($red,$green,$blue)  = sumArray($R->[1],$G->[1],$B->[1]);
		$s->iM->Extent(geometry=>$x."x".$y,background=>sprintf("rgb(%d,%d,%d)",$red,$green,$blue),gravity=>"North");
	}


}

sub saveAs {
	my $s = shift;
	my ($filename,$filetype,$png_hack) = @_;
	$filename //= $s->{filename};
	$filetype //= $s->{filetype};
	$png_hack //= $s->{file} =~ /\.png$/i;

	#$iM->Quantize(colorspace=>'gray');
	#say $iM->get("colorspace");
	#$iM->Quantize(colorspace=>"RGB");
	#$iM->Set(depth=>24);
	#$iM->Set(depth => 8);
	#$iM->Deskew();
	#$iM->Separate(channel=>"RGB");
	
	$s->iM->Set(alpha=>"Off");
	$s->iM->Strip();
	
	if ($png_hack) {
		say "using png hack";
		$s->iM->Set(magick => "jpg");
		my $temp = $iM->ImageToBlob();
		$s = Wallpaper->new($s);
		$s->iM->BlobToImage($temp);
	}
	$s->iM->Write(filename=>"$filetype:$filename",depth=>"24", compression=>'None');
}

sub extendAlphaSaveAsNoHack {
	my $s = shift;
	my ($x,$y,$filename,$filetype) = @_;
	
	$x //= $s->{new_x};
	$y //= $s->{new_y};
	$filename //= $s->{filename};
	$filetype //= $s->{filetype};
	
	$s->iM->Extent(geometry=>$x."x".$y,background=>"rgba(0,0,0,0)");
	$s->iM->Write(filename=>"$filetype:$filename");
}

1;