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
use Data::Dumper;



my $ini = readINI("config.ini")->{default};

tie ( my (@out_list), 'Tie::File', $ini->{out_list}) or die "$!";

my $file = $out_list[-1];

untie(@out_list);

my $ua = new LWP::UserAgent;  
$ua->agent("wpc.pl");
#$ua->show_progress( 1 );
#$ua->timeout(15);
$ua->env_proxy;
#$ua->show_progress(1);
$ua->cookie_jar( {} );


say "requesting user id";
my $request = HTTP::Request->new(GET => "http://www.tinypic.com/");
my $response = $ua->request($request);

my $UI;
my $upk;
my $content = $response->content();

if ($content =~ m#name="UPLOAD_IDENTIFIER" id="uid" value="([^"]+)"#is) {
	$UI = $1;
}
if ($content =~ m#name="upk" value="([^"]+)"#is) {
	$upk = $1;
}

say "uploading file";
$request = POST 'http://s6.tinypic.com/upload.php' ,
		Content_Type => 'form-data',
		Content      => [ 
							the_file   => [$ini->{directory}.$file],
							UPLOAD_IDENTIFIER => $UI,
							upk => $upk,
							action => "upload",
							shareopt => "true",
							file_type => "image",
							dimension => "1600",
						];

#my $tmp =  Dumper($request);
#$tmp =~ s/\a//g;
#say $tmp;
						
$response = $ua->request($request);

# my $tmp2 =  Dumper($response);
# $tmp2 =~ s/\a//g;
# say $tmp2;

say "getting direct link";
$content = $response->content();
$content =~ m#<a href="([^"]+)" target="_blank">Click here</a> to view your image#si;

$request = HTTP::Request->new(GET => $1);
$response = $ua->request($request);

$content = $response->content();

$content =~ m#<a href="([^"]+)" class="thickbox">Zoom</a>#si;

system("start " . $1);



# $request = HTTP::Request->new(GET => "http://de.tinypic.com/?t=postupload");
# $response = $ua->request($request);

# my $tmp3 =  Dumper($response);
# $tmp3 =~ s/\a//g;
# say $tmp3;
