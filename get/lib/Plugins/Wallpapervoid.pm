#!perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:12 11.04.2009
package Plugins::Wallpapervoid;

use 5.010;
use strict;
use warnings;

use Wallpaper;

our @ISA=qw(Wallpaper);

sub getCategories {
	my ($s) = @_;

	return $s->{categories} if $s->{categories};
	
	my ($code,$body) = util::getref('http://www.wallpapervoid.com/');
	return undef if ($code >= 300);
	
	my $re = qr{<div class="category_link_block" style="margin-right: 10px;"><a href="(?<link>[^"]+)" alt="[^"]+">(?<name>[^<]+)</a></div>}is;
	while ($body =~ m/$re/g) {
		$s->{categories}->{$+{name}} = $s->concatUrl('http://www.wallpapervoid.com/',$+{link});
	}
	return $s->{categories};
}

sub getPages {
	my ($s,$cat) = @_;
	$cat //= $s->{category}; 
	$s->{category} = $cat;
	
	return $s->{pages}->{$cat} if $s->{pages}->{$cat};
	
	my ($code,$body) = util::getref($s->getCategories()->{$cat});
	return undef if ($code >= 300);
	
	$s->{pages}->{current} = $s->{categories}->{$cat};
	
	my $re = qr{<a href="(?<link>index\.php\?b=[^"]+?&page=\d+)">(?<name>[^<]+)</a>}is;
	
	while ($body =~ m/$re/g) {
		$s->{pages}->{$+{name}} = $s->concatUrl('http://www.wallpapervoid.com/',$+{link});
	}
	
	return $s->{pages};
}

sub getWallpaperList {
	my ($s,$page) = @_;
	$page //= $s->{page};
	$s->{page} = $page;
	
	my ($code,$body) = util::getref($s->getPages->{$page});
	return undef if ($code >= 300);
	
	my $re = qr{<div class="wallpaper_thumbnail">(.+?)<div id="rating_link_end}is;
	
	while ($body =~ m/$re/gis) {
		my $inf = $1;
		
		my $ire = qr{<a href="([^"]+=([^"]+))">};
		my ($link,$name) = ($inf =~ m/$ire/is);
		my ($res) = ($inf =~ m/(\d{3,4}x\d{3,4})/i);
		$s->{wallpapers}->{$name}->{link} = $s->concatUrl('http://www.wallpapervoid.com/',$link);;
		$s->{wallpapers}->{$name}->{resolution} = $res;
	}
	
	return $s->{wallpapers};
}

sub getWallpaper {
	my ($s,$wall) = @_;
	
	my ($code,$body) = util::getref($s->getWallpaperList->{$wall}->{link});
	return undef if ($code >= 300);
	
	my $re = qr{<img id="wallpaper" style="width: 1000px; height: auto" src="([^"]+)" />}is;
	my $link;
	if ($body =~ m/$re/) {
		$link = $1;
	}
	else {
		warn("oh noes regex not working!");
	}
	$link = $s->concatUrl('http://www.wallpapervoid.com/',$link);
	my ($code2,$pic) = util::getref($link);
	return undef if ($code >= 300);
	
	return $pic;
	
}

sub getName {
	my ($s,$wall) = @_;
	return $wall . ".jpg";
}

1;