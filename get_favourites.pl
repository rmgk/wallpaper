#!/usr/bin/perl
use 5.010;
use strict;

use File::Copy;

mkdir "favorites";

open(FAV, "favorites.txt");
while(chomp(my $file = <FAV>)) {
	copy($file,"./favorites/");
}

