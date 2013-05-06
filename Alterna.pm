# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package Alterna;

use strict;
use warnings;
use utf8;

use XML::Feed;
use DT;
use Digest::SHA 'sha1_hex';

sub download {
    my $feed = XML::Feed->parse( URI->new( 'http://www.alterna.cz/action/rss/' ) )
	or die XML::Feed->errstr;

    my @events;
    for my $entry ( $feed->entries ) {
	unless ( $entry->title =~ /^(.*) \((\d+)\.(\d+)\.(\d+) - (\d+)\.(\d+)\)$/ ) {
	    warn "Unparsable title: $entry->title";
	    next;
	}
	my $start = dt( $2, $3, $4, $5, $6 );
	my $end   = $start + DateTime::Duration->new( hours => 2 );
	push @events, { title    => $1 . " (Alterna)"
		      , content  => ''
		      , location => 'Alterna, Kounicova 48, Brno'
		      , url      => $entry->link
		      , when     => [ $start, $end ]
		      , id       => $entry->link
		      , public   => 1
		      , icon     => 'http://www.alterna.cz/favicon.ico'
		      };
    }

    return @events;
}

1;
