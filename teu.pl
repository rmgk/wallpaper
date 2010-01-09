use 5.010;
use strict;
use warnings;
use LWP;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

use lib ".";
use util;
use Tie::File;
#use Getopt::Long;
#use File::Basename;
#use Data::Dumper;



my $ini = readINI("config.ini")->{default};

tie ( my (@out_list), 'Tie::File', $ini->{out_list}) or die "$!";

my $file = $out_list[-1];

untie(@out_list);

my $ua = new LWP::UserAgent;  
$ua->agent("wpc.pl");
#$ua->timeout(15);
$ua->env_proxy;
#$ua->show_progress(1);


my $request = POST 'http://www.tineye.com/search' ,
		Content_Type => 'form-data',
		Content      => [ 
							image   => [$ini->{directory}.$file],
						];

#my $tmp =  Dumper($request);
#$tmp =~ s/\a//g;
#say $tmp;
						
my $response = $ua->request($request);

#my $tmp2 =  Dumper($response);
#$tmp2 =~ s/\a//g;
#say $tmp2;

system("start " . $response->header("Location"));