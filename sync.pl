#!/usr/bin/perl
# vim:set et:

use 5.010;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::RealBin";

use GCal;
use ICal;
use LWP::UserAgent;
use Path::Tiny;

use Carp;
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

my $conf = eval `cat private.conf`;

my $ua = LWP::UserAgent->new(agent => 'curl/7.47.0');
my $gcal = GCal->new( user => $conf->{user}, pass => $conf->{pass} );

my $do = {};

$do->{facebook} = sub {
    $gcal->set_calendar( 'Facebook events' );
    $gcal->update_entries(
        { del_filter => sub { $gcal->del_filter_not_attended_events( @_ ) } },
        map { $_->{icon} = 'https://facebook.com/favicon.ico'; $_ }
        ICal::load_ical( $ua->get( $conf->{fb_url} )->decoded_content ) );
} if defined $conf->{fb_url};

$do->{meetup} = sub {
    $gcal->set_calendar( 'Meetup events' );
    $gcal->update_entries(
        { del_filter => sub { $gcal->del_filter_not_attended_events( @_ ) } },
        ICal::load_ical( $ua->get( $conf->{meetup_url} )->decoded_content ) );
} if defined $conf->{meetup_url};

$do->{foursquare} = sub {
    $gcal->set_calendar( 'Foursquare' );
    my @entries =
        map { $_->{icon} = 'https://foursquare.com/favicon.ico'; $_ }
            ICal::load_ical( path( '4sq_checkins.ics' )->slurp_utf8 );
    die 'no foursquare entries, probably an error' unless @entries;
    $gcal->update_entries( {}, @entries );
} if defined $conf->{foursquare_token};

$do->{strava} = sub {
    $gcal->set_calendar( 'Strava' );
    $gcal->update_entries( {},
        map { $_->{icon} = 'https://d3nn82uaxijpm6.cloudfront.net/assets/favicon-3578624dbca1eda01ff67d8723f17d5e.ico'; $_ }
        map { ICal::load_ical( path( $_ )->slurp_utf8 ) }
        glob( $conf->{strava_dir} . '/*.ics' ) );
} if defined $conf->{strava_dir};

my @todo = @ARGV ? @ARGV : keys %$do;
$_->() for @$do{ @todo };
