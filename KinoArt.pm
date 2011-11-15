# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package KinoArt;

use strict;
use warnings;
use utf8;

use LWP::UserAgent;
use Digest::SHA1 'sha1_hex';
use DT;

sub download {
    my $ua = LWP::UserAgent->new;
    return parse( $ua->get( 'http://www.kinoartbrno.cz/' )->decoded_content );
}

sub parse {
    my $page = shift;
    my (@dates, @events);

    while ( $page =~ m|<h2 class="barva_mesice">.. \&nbsp;\&nbsp;(\d+)\. (\d+). (\d+)</h2>|gs ) {
        push @dates, [ pos $page, $1, $2, $3 ];
    }

    while ( my $date = shift @dates ) {
        pos $page = $date->[0];
        while ( $page =~ m|<td class="casVS".*?(\d+)\.(\d+).*?href="(\S+?)">(.*?)</a>|gs ) {
            last if @dates and pos $page > $dates[0]->[0];
            my $start = dt( @$date[1..3], $1, $2 );
            my $end   = $start + DateTime::Duration->new( hours => 2 );
            my $event = { title    => $4 . " (kino Art)"
                        , content  => ''
                        , location => 'Kino Art, Cihlářská 19'
                        , url      => $3
                        , when     => [ $start, $end ]
                        , id       => sha1_hex( "$3 $start" )
                        , public   => 1
                        , icon     => 'http://openiconlibrary.sourceforge.net/gallery2/open_icon_library-full/icons/png/16x16/categories/applications-multimedia-4.png'
                        };
            next if $event->{title} =~ /kino nehraje/;
            push @events, $event;
        }
    }

    return @events;
}

1;
