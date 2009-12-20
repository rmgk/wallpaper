#!perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:11 11.04.2009
package util;

use 5.010;
use strict;
use warnings;

=head1 NAME

dlutil - download utility

=head1 DESCRIPTION

provides download utility functions

=cut

our($ua,@EXPORT,@EXPORT_OK);

require Exporter;

@EXPORT = qw(get);
@EXPORT_OK = qw($ua);

our($VERSION);
$VERSION = '6w';

=head1 functions

=cut

sub _init_ua {
	require LWP;
	require LWP::UserAgent;
	require LWP::ConnCache;
	#require HTTP::Status;
	#require HTTP::Date;
	$ua = new LWP::UserAgent;  # we create a global UserAgent object
	$ua->agent("walcol/$VERSION");
	$ua->timeout(15);
	$ua->env_proxy;
	$ua->conn_cache(LWP::ConnCache->new());
	$ua->cookie_jar( {} );
}

=head2 getref

	dlutil::getref($url,$referer);
	
gets C<$url> with referer set to C<$referer> and returns contents. if C<$referer> is omitted it uses C<$url> as referer

returns: fetched content on success, errorcode otherwise.

=cut

sub getref {
	my($url, $referer) = @_;
	_init_ua() unless $ua;
	unless (defined $referer) {
		(my $referer = $url) =~ s/[\?\&]//;
		$referer =~ s#/[^/]*$#/#;
	}
	my $request = HTTP::Request->new(GET => $url);
	$request->referer($referer);
	my $response = $ua->request($request);
	return ($response->code , $response->content);
}

=head2 readINI

	dbutil::readINI($filename);
	
will read I<$filename> and load it into a hashref

returns: hashref with parsed file content

=cut

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


1;