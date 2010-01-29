#!perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:12 11.04.2009
use 5.010;
use strict;
use warnings;

use Data::Dumper;

use lib "lib";

use Wallpaper;
use Plugins::Wallpapervoid;

my $wpv = Plugins::Wallpapervoid->new();

say "doing some voodoo";
my @cats = keys(%{$wpv->getCategories()});
say "doing some more voodoo";
my @pages = keys(%{$wpv->getPages("Anime")});
say "still doing some voodoo";
my @pics = keys(%{$wpv->getWallpaperList($pages[rand(@pages)])});
say "voodoos nearly finished";
my $picid = $pics[rand(@pics)];
my $pic = $wpv->getWallpaper($picid);
my $picname = $wpv->getName($picid);
open(OUT,">".$picname);
binmode OUT;
print OUT $pic;
close(OUT);
say "there you go";