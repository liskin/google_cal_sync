# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package DT;

use strict;
use warnings;

use DateTime;

use Exporter 'import';
our @EXPORT = qw(dt);

sub dt {
    my %param;
    @param{qw/day month year hour minute/} = @_;
    return DateTime->new( %param, time_zone => 'Europe/Prague' );
}

1;
