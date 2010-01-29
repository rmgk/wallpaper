#!/usr/bin/perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:12 11.04.2009

package WallpaperAbyss;

use 5.010;
use strict;
use warnings;

use DBI;
use dlutil;
use Data::Dumper;

use Digest::SHA;
use Time::HiRes;

our $VERSION = 1.1;
our $SHA = Digest::SHA->new();



sub new {
	my ($class,$self) = @_;
	$self //= {};
	bless($self,$class);
}

sub dbh {
	my ($s) = @_;
	return $s->{dbh};
}

sub url {
	my ($s) = @_;
	return $s->{url};
}

sub referrer {
	my ($s) = @_;
	return $s->{referrer};
}

sub body {
	my $s = shift;
	unless ($s->{body}) {
		return undef if $s->{no_body};
		my $res = dlutil::get($s->url,$s->referrer);
		if ($res->is_error()) {
				die "could not get body: " . $res->status_line();;
		}
		$s->{body} = $res->content();
	}
	return $s->{body};
}

sub get_page {
	my ($self) = shift;
	my $body = $self->body();
	my $regex = q~<span class='info'><strong>(?<width>\d+)x(?<height>\d+)</strong>.*?<span id='(?<id>\d+)'><strong>\s*<a href='#' onclick="showChange\(1, \d+\); return false;">\s*(?<voteup>\d+)<img src='rate_up_small.png' border=0></a>\s*<a href='#' onclick="showChange\(-1, \d+\); return false;">\s*(?<votedown>\d+)<img src='rate_down_small.png' border=0></a></strong></span>\s*<span class='info'>\s*<br>Category: <strong><a href='[^']*?' title='[^']*?'>(?<category>[\w\s]+)</a></strong> - <strong><a href='[^']*?' title='[^']*?'>(?<subcategory>[\s\w]+)</a></strong>~;
	while (!$main::TERM and $body =~ /$regex/gims ) {
		my ($id,$cat,$subcat,$votedown,$voteup,$resx,$resy) = ($+{id},$+{category},$+{subcategory},$+{votedown},$+{voteup},$+{width},$+{height});
		my ($sha1,$size) = $self->download($id,$cat,$subcat);
		die unless $sha1;
		next unless $size;
		$self->dbh->do('INSERT INTO wallpapers (id,category,subcategory,votedown,voteup,resx,resy,sha1,size) VALUES (?,?,?,?,?,?,?,?,?)',{}
						,$id,$cat,$subcat,$votedown,$voteup,$resx,$resy,$sha1,$size);
	}
}

sub download {
	my $s = shift;
	my ($id,$cat,$subcat) = @_;
	
	my $dir = 'wpa/'. $cat . "/" . $subcat."/";
	my $file = $id . '.jpg';
	($id =~ /^(\d{1,3})/);
	my $urlfolder = $1;
	if (length($urlfolder) < 3) {
		$urlfolder = $urlfolder x 3 if length($urlfolder) == 1;
		$urlfolder = $urlfolder . substr($urlfolder,1,1) if length($urlfolder) == 2;
	}
	my $url = 'http://wall.alphacoders.com/images/'.$urlfolder.'/'.$id.'.jpg';
	
	mkdir 'wpa/';
	mkdir 'wpa/'. $cat . "/";
	mkdir $dir;
	
	if (-e $dir.$file) {
		say "exists: $dir$file";
		return 2;
	}
	

	local $| = 1; #dont wait for newline to print the text
	print "GET: " . $url . " => " . $dir.$file;
	
	my $time = Time::HiRes::time;
	my $img_res = dlutil::get($url);
	$time = Time::HiRes::time - $time;
	if ($img_res->is_error) {
		say " error"; #were waiting for speed and newline
		$s->{error_download} = $img_res->status_line();
		if ($img_res->code() == 404) {
			return -2;
		}
		return 0;
	}
	if (open(my $fh,'>'.$dir.$file)) {
		binmode $fh;
		my $img = \$img_res->content();
		my $sha1 = $SHA->add($$img)->hexdigest();
		print $fh $$img;
		my $size = (-s $fh);
		say " (".int($size/($time*1000)) ." kb/s)";
		close $fh;
		return ($sha1,$size);
	}
	else {
		say " error"; #were waiting for speed and newline
		return undef
	}
	return 1;
}

sub next_page {
	my $s = shift;
	$s->body =~ m~<span class='title'><a href='(newest_wallpapers.php\?o=\d+&d=newer)'><< Newer Wallpapers</a>~;
	return "http://wall.alphacoders.com/" . $1;
}


1;