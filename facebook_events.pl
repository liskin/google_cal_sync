#!/usr/bin/perl
# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:

use strict;
use warnings;

use LWP::UserAgent;
use ICal;
use GCal;

my $fb_url = "http://www.facebook.com/ical/u.php?uid=...&key=...";

my $ua = LWP::UserAgent->new;
my $gcal = GCal->new( user => '...', pass => '...' );

$gcal->set_calendar( 'Facebook events' );
$gcal->update_entries( ICal::load_ical( $ua->get( $fb_url )->content ) );
