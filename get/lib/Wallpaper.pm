#!perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:12 11.04.2009
package Wallpaper;

use 5.010;
use strict;
use warnings;

use Carp qw(carp croak);

use util;

#use DBI;
use URI;
$URI::ABS_REMOTE_LEADING_DOTS = 1;


use Digest::MD5 qw(md5_hex);
use Digest::SHA qw(sha1_hex);
use Time::HiRes;

sub new {
	my $class = shift;
	my $s = shift || {};
	bless $s,$class;
	return $s;
}

sub getCategories {
	carp("not implemented");
	return undef;
}

sub setCategory {
	my ($s,$cat) = @_;
	$s->{category} = $cat;
}

sub getPages {
	carp("not implemented");
	return undef;
}

sub concatUrl {
	my ($s,$base,$part) = @_;
	$part =~ s!([^&])&amp;|&#038;!$1&!gs;
	return URI->new($part)->abs($base)->as_string;
}

sub setPage {
	my ($s,$page) = @_;
	$s->{page} = $page;
}

sub getWallpaperList {
	carp("not implemented");
	return undef;
}

sub getWallpaper {
	carp("not implemented");
	return undef;
}

sub getName {
	my ($s,$wall) = @_;
	return $wall;
}

1;