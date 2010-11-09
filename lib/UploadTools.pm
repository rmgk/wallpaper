package UploadTools;

use 5.010;
use strict;
use warnings;

use LWP;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
my $hasClipboard = eval { require Win32::Clipboard; };


# -> $ua
#initialises the user agent
sub init_ua {
	my $ua = new LWP::UserAgent;  
	$ua->agent("wpc.pl");
	$ua->env_proxy;
	return $ua;
}

#$file
#uploads $file to tineye and calls browser
sub teu {
	my $file = shift;
	my $ua = init_ua();
	
	say "posting file";
	my $request = POST 'http://www.tineye.com/search' ,
			Content_Type => 'form-data',
			Content      => [ 
								image   => [$file],
							];
							
	my $response = $ua->request($request);
	if ($hasClipboard) {
		say "setting clipboard";
		Win32::Clipboard()->Set($response->header("Location"));
	}
	else {
		say "install Win32::Clipboard to get the uploaded link directly into your clipboard";
	}
	say "calling system";
	system("start " . $response->header("Location"));
	return $response->header("Location");
}

sub upload {
	my $url = directupload(@_);
	if ($hasClipboard) {
		say "setting clipboard";
		Win32::Clipboard()->Set($url);
	}
	else {
		say "install Win32::Clipboard to get the uploaded link directly into your clipboard";
	}
	say "calling system";
	system("start " . $url);
}

#$file
#uploads $file to tinypic and calls browser
sub tpu {
	my $file = shift;
	my $ua = init_ua();


	say "requesting user id";
	my $request = HTTP::Request->new(GET => "http://www.tinypic.com/");
	my $response = $ua->request($request);

	my $UI;
	my $upk;
	my $server;
	my $content = $response->content();

	if ($content =~ m#name="UPLOAD_IDENTIFIER" id="uid" value="([^"]+)"#is) {
		$UI = $1;
	}
	if ($content =~ m#name="upk" value="([^"]+)"#is) {
		$upk = $1;
	}
	if ($content =~ m#<form action="([^"]+)" method="post"#i) {
		$server = $1;
	}

	say "uploading file";
	$request = POST $server ,
			Content_Type => 'form-data',
			Content      => [ 
								the_file   => [$file],
								UPLOAD_IDENTIFIER => $UI,
								upk => $upk,
								action => "upload",
								shareopt => "true",
								file_type => "image",
								dimension => "1600",
							];
							
	$response = $ua->request($request);
	
	say "getting direct link";
	$content = $response->content();
	
	$content =~ m#<a href="([^"]+)" target="_blank">Click here</a> to view your image#si;

	$request = HTTP::Request->new(GET => $1);
	$response = $ua->request($request);

	$content = $response->content();

	$content =~ m#<a href="([^"]+)" class="thickbox">Zoom</a>#si;

	return $1;
}

sub directupload {
	my $file = shift;
	my $ua = init_ua();
	say "uploading file";
	my $request = POST 'http://www.directupload.net/index.php?mode=upload' ,
			Content_Type => 'multipart/form-data',
			Content      => [ 
								bilddatei   => [$file],
							];
							
	my $response = $ua->request($request);
	my $body = $response->content();
	$body =~ m#(http://\w+.directupload.net/images/\w+/\w+\.\w{3,4})#i;
	return $1;
}


1;
