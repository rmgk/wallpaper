use 5.010;
use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";

use lib "./lib";
use utf8;
use FindBin;
use lib $FindBin::Bin.'/lib';

use Change;


# the below block, will stop duplicate instances of this program from running
# it may however not provide any feedback as to why, and will not work well
# with image pregeneration
# use Fcntl ':flock';
# say "huh";
# open my $self_lock, '<', $0 or die "Couldn't open self: $!";
# flock $self_lock, LOCK_EX | LOCK_NB or die "This script is already running";

Change::reload();

@ARGV or Change::usage();

Change::dispatch(@ARGV);

Change::cleanup_generated_wallpapers();

Change::commit();
