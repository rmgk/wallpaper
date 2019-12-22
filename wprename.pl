use 5.014;
use warnings;
use utf8;

use File::Copy;
use File::Find;

find({wanted => sub {
	my ($name) = $_;
	return unless -f $name and $name ~~ m/%20/;
	my $dec = $name =~ s'%20' 'gr;
	move $name, $dec;
 	say $name, "\n" ,$dec;
}},"../Pictures/")

# for my $fav (<../Pictures/**>) {
# 	next unless $fav ~~ m/%20/;
# 	my $dec = $fav =~ s'%20' 'gr;
# 	move $fav, $dec;
# 	say $fav, "\n" ,$dec;
# }

