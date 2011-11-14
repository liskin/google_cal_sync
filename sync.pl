#!/usr/bin/perl
# vim:set et:

use strict;
use warnings;

use LWP::UserAgent;
use ICal;
use GCal;
use KinoArt;

my $conf = eval `cat private.conf`;

my $ua = LWP::UserAgent->new;
my $gcal = GCal->new( user => $conf->{user}, pass => $conf->{pass} );

$gcal->set_calendar( 'Facebook events' );
$gcal->update_entries(
    map { $_->{icon} = 'http://facebook.com/favicon.ico'; $_ }
        ICal::load_ical( $ua->get( $conf->{fb_url} )->decoded_content ) );

$gcal->set_calendar( 'Kino Art' );
$gcal->update_entries( KinoArt::download );
