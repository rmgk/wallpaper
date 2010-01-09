#!/usr/bin/perl
use 5.010;
use strict;

use File::Copy;

use lib ".";
use util;

my $ini = readINI("config.ini")->{default};

mkdir "favorites";

open(FAV, "favorites.txt");
while(chomp(my $file = <FAV>)) {
	copy($ini->{directory}.$file,"./favorites/");
}

