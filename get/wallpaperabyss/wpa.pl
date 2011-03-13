#!/usr/bin/perl
#this program is free software it may be redistributed under the same terms as perl itself
#22:12 11.04.2009
package wpv v1.2.0;

use 5.012;
use warnings;
use autodie;

use DlUtil;
use URI;



#our $TERM = 0;
#$SIG{'INT'} = sub {
#	print "\nTerminating (wait for page to finish)\n" ;
#	$TERM = 1;
#};

my $purl = 'http://wall.alphacoders.com/newest_wallpapers.php?v=small&page=';

sub main {
	print "remember: images must not be redistributed without the authors approval\n";
	print "press ctrl+c to abort (or data corruption might occur)\n";

	mkdir "wpa" unless -e "wpa"; 

	my $id;
	if (-e "id.txt") {
		open (my $fh, '<', 'id.txt');
		chomp($id = <$fh>);
		close $fh;
	}
	$id ||= 1;
	say $id;
	
	my $tree = DlUtil::get_tree($purl . 1);
	my $pagi = $$tree->look_down(_tag => 'div', class => 'options_bottom')->look_down(_tag => 'div', class => 'pagination');
	my @pages = $pagi->content_list();
	my $last_page = $pages[-2]->attr('href');
	($last_page) = ($last_page =~ m'page=(\d+)$');
	my ($newest_id) = (($$tree->look_down(_tag => 'img', class => 'small_square'))[-1]->parent->attr("href") =~ m'i=(\d+)$');
	undef $tree;
	say $last_page, " ", $newest_id;
	
	my ($page,$ftree) = search_id($id,$newest_id,1,1,$last_page);
	start_download($id,$page,$ftree);
}

sub search_id {
	my ($id, $left_id, $left_page, $right_id, $right_page) = @_;
	
	my $page_range = $right_page - $left_page;
	my $id_range = $left_id - $right_id;
	my $guessed_page = int($right_page - ($id - $right_id) / $id_range * $page_range);
	if ($guessed_page == $left_page) {
		$guessed_page++;
	}
	
	say "guessed page $guessed_page";
	
	my $tree = DlUtil::get_tree($purl . $guessed_page);
	my @images = $$tree->look_down(_tag => 'img', class => 'small_square');
	my ($new_id) = ($images[-1]->parent->attr("href") =~ m'i=(\d+)$');
	my ($upto_id) = ($images[0]->parent->attr("href") =~ m'i=(\d+)$');
	return ($guessed_page,$tree) if $id <= $upto_id and $id >= $new_id;
	if ($id > $upto_id) {
		return search_id($id,$left_id,$left_page,$new_id,$guessed_page);
	}
	elsif ($id < $new_id) {
		return search_id($id,$new_id,$guessed_page,$right_id,$right_page);
	}
}

sub start_download {
	my ($id,$page,$tree) = @_;
	
	while ($page >= 1 and $tree) {
		my @images = reverse map {$_->parent->attr('href') =~ m'i=(\d+)$'; $1 } $$tree->look_down(_tag => 'img', class => 'small_square');
		
		my $downloaded = 0;
		for my $i (@images) {
			next if $i < $id;
			$id = $i;
			open (my $fh, '>', 'id.txt');
			print $fh $id;
			close $fh;
			$id++;
			download($i);
			$downloaded = 1;
		}
		$page-- if !$downloaded;
		$tree = DlUtil::get_tree($purl . $page);
	}

}

sub download {
	my ($id) = @_;
	say "download $id";
	my $url = 'http://wall.alphacoders.com/wallpaper.php?i='.$id;
	my $tree = DlUtil::get_tree($url);
	my $img = $$tree->look_down(_tag => 'img', src => qr'alphacoders.com/\d\d\d/\d+\.');
	
	my ($cat,$sub) = split /\s+-\s+/, $img->attr('alt'), 2;
	my ($imgurl) = $img->attr('src');
	my ($file) = $imgurl =~ m'/(\d+\.\w+)$'; 
	
	mkdir "wpa/$cat" unless -e "wpa/$cat";
	mkdir "wpa/$cat/$sub" unless -e "wpa/$cat/$sub";
	
	open(my $fh,'>',"wpa/$cat/$sub/".$file);
	binmode $fh;
	my $res = DlUtil::get($imgurl,$url);
	print $fh $res->decoded_content();
	close $fh;
}

main();
