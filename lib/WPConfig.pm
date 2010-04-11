package WPConfig;

use 5.010;
use strict;
use warnings;
use Carp;

my $CFG_PATH = 'config.ini';
my $DEF_CFG_PATH = 'DEFAULT_config.ini';
our $CFG;
my %def_cfg;

#$filename, \%data? -> \%data
#reads from $filename into \%data
sub readINI {
	my ($file) = shift;
	croak 'first parameter needs to be filename' unless defined $file;
	croak "could not find $file" unless -e $file;
	my $data = shift // {};
	open my $f , $file or die "error opening $file: $!";
	while (my $line = <$f>) {
		#ignoring comments and empty lines
		next if $line =~ /^ \s* ( [ \; | \# ] .* )? $/x;
		next if length $line == 0;
		
		#parting values and stripping whitespace
		my ($what,$is) = split(/\s*=\s*/, $line, 2);
		$what =~ s/^\s*//g;
		$is =~ s/\s*$//g;

		$data->{$what} = $is;
	}
	close ($f);
	return $data;
}

# -> \%$CFG
# loads config from $DEF_CFG_PATH and $CFG_PATH into $CFG
sub load {
	die "$DEF_CFG_PATH does not exist" unless -e $DEF_CFG_PATH;
	$CFG = readINI($DEF_CFG_PATH); #loading the default config
	%def_cfg = %$CFG;
	readINI($CFG_PATH,$CFG) if -e $CFG_PATH;  #overwriting default config with user config if it exists
	return $CFG;
}

# \%config?
# saves \%config or $CFG to $CFG_PATH
sub save {
	my $config = shift // $CFG;
	open my $f, '>' , $CFG_PATH or die "could not open $CFG_PATH: $!";
	print $f join( "\n", 
		map {$_ . '=' . $config->{$_} } 
			grep { defined $def_cfg{$_} and $config->{$_} ne $def_cfg{$_} }
				keys %$config );
	close $f;
}

1;
