use 5.010;
use strict;
use warnings;

use Win32::API;
use constant SPI_SETDESKWALLPAPER  => 20;
use constant SPIF_UPDATEANDSENDINI => 3;

sub setWallpaper {
	my ($file) = @_ ;
	my $syspinf = Win32::API->new('user32','SystemParametersInfo', ["I","I","P","I"], "I") or die "Could not import function.\n";
	$syspinf->Call(SPI_SETDESKWALLPAPER, 0, $file , SPIF_UPDATEANDSENDINI);
}

sub readINI {
	my ($file) = @_;
	return unless defined $file;
	return unless -e $file;
	my $data = {};
	my $block = 'default';
	
	open (FILE, $file);
	while (my $line = <FILE>) {
		if ($line =~ /^\s*\[(.*?)\]\s*$/) {
			$block = $1;
			next;
		}
		next if $line =~ /^\s*\;/;
		next if $line =~ /^\s*\#/;
		next if $line =~ /^\s*$/;
		next if length $line == 0;
		
		my ($what,$is) = split(/=/, $line, 2);
		$what = "url_start" unless $what;
		$what =~ s/^\s*//g;
		$what =~ s/\s*$//g;
		$is =~ s/^\s*//g;
		$is =~ s/\s*$//g;

		$data->{$block}->{$what} = $is;
	}
	close (FILE);
	return $data;
}

sub piclist {
	my $basedir = shift;
	my $adddir = shift // "";
	my @list;
	say $basedir.$adddir;
	my $PIC;
	
	opendir($PIC,$basedir.$adddir) or die $!;
	
	while(my $x = readdir($PIC)) {
		next if $x =~ m/^\.{1,2}$/; 
		if (-d $basedir.$adddir.$x) {
			push(@list,piclist($basedir,$adddir.$x.'\\'));
		}
		else {
			if ($x =~ m/\.(jpe?g|gif|png|bmp)$/) {
				push(@list,$adddir.$x);
			}
		}
	}
	
	closedir($PIC);
	return @list;
}


sub check_list {
	my ($in_list,$dn) = @_;
	unless (-e $in_list) {
		use List::Util 'shuffle';
		my @pictures = piclist($dn);
		my %in;
		$in{$_} = 1 for @pictures;
		@pictures = shuffle keys %in;
		open(LST,">",$in_list) or die "could not write list";
		foreach (@pictures) {
			print LST $_ . "\n";
		}
		close(LST)
		
	}
}

1;