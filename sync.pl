#!/usr/bin/perl
# vim:set et:

use 5.010;
use strict;
use warnings;

use File::Slurp qw( read_file );
use LWP::UserAgent;
use ICal;
use GCal;

my $conf = eval `cat private.conf`;

my $ua = LWP::UserAgent->new;
my $gcal = GCal->new( user => $conf->{user}, pass => $conf->{pass} );

my $do = {};

$do->{facebook} = sub {
    $gcal->set_calendar( 'Facebook events' );
    $gcal->update_entries(
        map { $_->{icon} = 'http://facebook.com/favicon.ico'; $_ }
        ICal::load_ical( $ua->get( $conf->{fb_url} )->decoded_content ) );
} if defined $conf->{fb_url};

$do->{foursquare} = sub {
    $gcal->set_calendar( 'Foursquare' );
    $gcal->update_entries(
        map { $_->{icon} = 'https://foursquare.com/favicon.ico'; $_ }
            ICal::load_ical( $ua->get( $conf->{foursq_url} )->decoded_content ) );
} if defined $conf->{foursq_url};

$do->{kinoart} = sub {
    use KinoArt;
    $gcal->set_calendar( 'Kino Art' );
    $gcal->update_entries( KinoArt::download );
};

$do->{alterna} = sub {
    use Alterna;
    $gcal->set_calendar( 'Alterna' );
    $gcal->update_entries( Alterna::download );
};

$do->{strava} = sub {
    $gcal->set_calendar( 'Strava' );
    $gcal->update_entries(
        map { $_->{icon} = 'http://d3nn82uaxijpm6.cloudfront.net/assets/favicon-3578624dbca1eda01ff67d8723f17d5e.ico'; $_ }
        map { ICal::load_ical( scalar read_file( $_ ) ) }
        glob( $conf->{strava_dir} . '/*.ics' ) );
} if defined $conf->{strava_dir};

my @todo = @ARGV ? @ARGV : keys %$do;
$_->() for @$do{ @todo };
