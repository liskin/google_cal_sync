# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package ICal;

use strict;
use warnings;

use iCal::Parser;

# Load all events from an iCal data in a string into a simple structure as
# expected by my GCal module.
sub load_ical {
    my $data = shift;
    my $parser = iCal::Parser->new( start => '20100101', end => '20200101' );
    my $hash = $parser->parse_strings( $data );
    return uniq( map { ical2x( $_ ) }
                 map { values %$_ } map { values %$_ }
                 map { values %$_ } map { values %$_ }
                 $hash->{events} );
}

# Convert to the simple structure used in GCal.
sub ical2x {
    my $ev = shift;

    my $x = {
        title    => ical_unescape( "$ev->{SUMMARY}"     ),
        content  => ical_unescape( "$ev->{DESCRIPTION}" ),
        location => ical_unescape( "$ev->{LOCATION}"    ),
        url      => ical_unescape( "$ev->{URL}"         ),
        id       => "$ev->{UID}",
        when     => [ $ev->{DTSTART}, $ev->{DTEND} ],
        extra    => {}
    };

    $x->{extra}->{'URL'} = $x->{url} if length $x->{url};
    $x->{extra}->{'Organizer'} = ical_unescape( "$ev->{ORGANIZER}->{CN}" ) if defined $ev->{ORGANIZER}->{CN};
    $x->{extra}->{'Participation status'} = ical_unescape( "$ev->{PARTSTAT}" ) if defined $ev->{PARTSTAT};

    return $x;
}

sub ical_unescape {
    local $_ = shift;
    s/\\([;,])/$1/g;
    s/\\n/\n/ig;
    s/\\\\/\\/g;
    return $_;
}

# Bloody iCal::Parser splits events, so I join them again. So stupid.
sub uniq {
    my $evs;

    while ( my $ev = shift ) {
        push @{ $evs->{ $ev->{id} } }, $ev;
    }

    for my $ev ( values %$evs ) {
        @$ev = sort { DateTime->compare( $a->{when}->[0], $b->{when}->[0] ) } @$ev;
        $ev->[0]->{when} = [ $ev->[0]->{when}->[0], $ev->[ $#$ev ]->{when}->[1] ];
        @$ev = ( $ev->[0] );
    }

    return map { @$_ } values %$evs;
}

1;
