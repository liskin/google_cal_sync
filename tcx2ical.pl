#!/usr/bin/perl
# vim:set et:

# Convert TCX obtained from Strava using Tapiriik to iCal

use 5.010;
use strict;
use warnings;

use Data::ICal::Entry::Event;
use Data::ICal;
use DateTime::Format::ICal;
use DateTime::Format::ISO8601;
use Geo::Coder::Googlev3;
use XML::Simple;

my $f = shift or die;

my $xml = XMLin( $f );
my $activity = $xml->{Activities}->{Activity};
my $uid = $activity->{Id};
my $name = $activity->{Notes};
my $sport = $activity->{Sport};
my $distance = $activity->{Lap}->{DistanceMeters};
my $track = $activity->{Lap}->{Track}->{Trackpoint};

my $geocoder = Geo::Coder::Googlev3->new;
my $first = $track->[0];
my $last = $track->[-1];
my $dtstart = dt_from_iso( $first->{Time} );
my $dtend = dt_from_iso( $last->{Time} );
my $locstart = $first;
my $locend = $last;

my $locs;
my $tmp = $first;
for my $next ( @$track ) {
    my $delta = dt_from_iso( $next->{Time} ) - dt_from_iso( $tmp->{Time} );
    if ( $delta->in_units( 'minutes' ) >= 3 ) {
        push @$locs, $tmp;
    }
    $tmp = $next;
}
unshift @$locs, $locstart;
push @$locs, $locend;
@$locs = map { ppr_loc( $_ ) } @$locs;

my $calendar = Data::ICal->new();
my $entry = Data::ICal::Entry::Event->new();
$entry->add_properties(
    summary => $name . ' (' . sprintf( "%.1f km", $distance / 1000 ) . ', ' . $sport . ')',
    description => join( "\n", @$locs ),
    location => $locs->[0],
    dtstart => dt_to_ical( $dtstart ),
    dtend => dt_to_ical( $dtend ),
    uid => $uid,
    url => '',
);
$calendar->add_entry( $entry );

binmode STDOUT, ":utf8";
print $calendar->as_string;

sub dt_to_ical {
    DateTime::Format::ICal->format_datetime( shift );
}

sub dt_to_hm {
    my $dt = shift;
    $dt = $dt->clone->set_time_zone( 'Europe/Prague' );
    return sprintf( "%02d:%02d", $dt->hour, $dt->minute );
}

sub dt_from_iso {
    DateTime::Format::ISO8601->parse_datetime( shift );
}

sub ppr_loc {
    my $loc = shift;
    return dt_to_hm( dt_from_iso( $loc->{Time} ) ) . ' - ' . get_loc( $loc );
}

sub get_loc {
    my $trackpoint = shift;
    my $pos = $trackpoint->{Position};
    my $loc = $pos->{LatitudeDegrees} . ',' . $pos->{LongitudeDegrees};
    my @reply = $geocoder->geocode( location => $loc ) or die;
    return $reply[0]->{formatted_address};
}
