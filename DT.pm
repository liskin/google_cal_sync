# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package DT;

use strict;
use warnings;

use DateTime;
use DateTime::Format::ICal;
use DateTime::Format::ISO8601;

use Exporter 'import';
our @EXPORT = qw(dt dt_to_ical dt_to_hm dt_from_iso);

sub dt {
    my %param;
    @param{qw/day month year hour minute/} = @_;
    return DateTime->new( %param, time_zone => 'Europe/Prague' );
}

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

1;
