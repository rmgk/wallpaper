package ConfigRW;

use 5.010;
use strict;
use warnings;

my $CFG_PATH = 'config.ini';
my $CURRENT_PATH = 'current.txt';
our $CFG;

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
		$what =~ s/^\s*//g;
		$what =~ s/\s*$//g;
		$is =~ s/^\s*//g;
		$is =~ s/\s*$//g;

		$data->{$block}->{$what} = $is;
	}
	close (FILE);
	return $data;
}

sub load {
	return 0 unless -e $CFG_PATH;
	$CFG = readINI($CFG_PATH)->{default};
	if (-e $CURRENT_PATH) {
		my $d;
		open($d, "<$CURRENT_PATH");
		<$d>;
		chomp($CFG->{current} = <$d>);
		close $d;
	}
	else {
		$CFG->{current} = 1;
	}
	return $CFG;
}

sub save {
	my $d;
	open($d, ">$CURRENT_PATH");
		print $d join("\n",@_);
	close $d;
}

1;
