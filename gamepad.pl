#!/usr/bin/perl
use 5.018;

no if $] >= 5.018, warnings => "experimental::smartmatch";

use lib "./lib";
use utf8;
use FindBin;
use lib $FindBin::Bin.'/lib';

use Change;
use WallpaperList;

use SDL ':init';
use SDL::Event;
use SDL::Events ':all';
use SDL::Joystick;
use Data::Dumper;


SDL::init(SDL_INIT_VIDEO); # Event can only be grabbed in the same thread as this
SDL::init_sub_system(SDL_INIT_JOYSTICK);

my @joysticks = map {SDL::Joystick->new($_)} 0 .. SDL::Joystick::num_joysticks() - 1;
my $event = SDL::Event->new(); # notices 'Event' ne 'Events'

my $DONE = 0;

while (not $DONE and SDL::Events::wait_event($event)) {
	given($event->type) {
		when(SDL_JOYBUTTONDOWN) {
			handle_button($event->jbutton_button);
		}
		when(SDL_JOYHATMOTION) {
			handle_hat($event->jhat_hat, $event->jhat_value);
		}
		when(SDL_JOYAXISMOTION) {
			handle_axis($event->jaxis_axis, int($event->jaxis_value/20000));
		}
		when(SDL_QUIT) {
			$DONE = 1;
		}
		say "unknown event: ", $event->type;
	}
	while (SDL::Events::poll_event($event)) {};
}

sub dispatch { Change::dispatch(@_) }

sub handle_button {
	my ($button) = @_;
	Change::reload();
	given($button) {
		# ;button 1 (a)
		when(0) { dispatch("votedown", 1); }
		# ;button 2 (b)
		when(1) { dispatch("voteup", 1); }
		# ;button 3 (x)
		when(2) { dispatch(-1); }
		# ;button 4 (y)
		when(3) { dispatch("sketchy"); }
		# ;left shoulder
		when(4) {
			my %stat = WallpaperList::get_stat($Change::INI->{current});
			`notify-send "$stat{path}"`;
		}
		# ;right shoulder
		when(5) { dispatch("upload"); }
		# ;select
		when(6) { dispatch("sfw"); }
		# ;start
		when(7) { dispatch("fav"); }
		# ;xbox button
		when(8) { exit; }
		# ;left analog stick
		when(9) { dispatch("purge"); }
		# ;right analog stick
		when(10) { dispatch("nsfw"); }
	}
	Change::cleanup_generated_wallpapers();
	Change::commit();
}

sub handle_hat {
	my ($hat, $dir) = @_;
	# say join "; ", @_;
}

sub handle_axis {
	my ($axis, $dir) = @_;
	# say join "; ", @_;
}
