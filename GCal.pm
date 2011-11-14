# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package GCal;

use strict;
use warnings;

use Net::Google::Calendar;
use Data::Dumper;
use DateTime;
use JSON::XS;
use Digest::SHA1 'sha1_hex';
use Encode;

*DateTime::TO_JSON = sub { return "" . shift };

our $json = JSON::XS->new->allow_blessed( 1 )->convert_blessed( 1 );

# Constructor, to be called as:
# my $gcal = GCal->new( user => '...', pass => '... );
sub new {
    my ($class, %param) = @_;
    my $self = { cal => Net::Google::Calendar->new, %param };
    $self->{cal}->login( $self->{user}, $self->{pass} ) or die;
    bless $self, $class;
    return $self;
}

# Set current calendar by its name.
# $cal->set_calendar( 'Facebook events' )
sub set_calendar {
    my ($self, $cal) = @_;
    $self->{cal}->set_calendar( grep { $_->title eq $cal }
        $self->{cal}->get_calendars( 1 ) ) or die;
}

# Fill in Net::Google::Calendar::Entry from a simple hash:
# { title    => 'event title'
# , content  => 'event description'
# , location => 'event location'
# , url      => 'event url'
# , when     => [ <DateTime> of start, <DateTime> of end ]
# , id       => 'unique event id'
# }
sub x2entry {
    my ($ev, $entry) = @_;

    my $hash = sha1_hex( encode( 'UTF-8', $json->encode( $ev ) ) );
    my $changed =
        $entry->extended_property->{last_hash}
        ? $hash ne $entry->extended_property->{last_hash}
        : 0;

    $entry->title(    $ev->{title}    );
    $entry->content(  $ev->{url} . "\n\n" . $ev->{content}  );
    $entry->location( $ev->{location} );
    $entry->when(  @{ $ev->{when} }   );
    $entry->extended_property( 'id',        $ev->{id} );
    $entry->extended_property( 'last_hash', $hash     );

    return $changed;
}

# Take a list of entries in the format expected by x2entry and put them online.
# New events are added, old are updated if changed, disappeared are deleted.
sub update_entries {
    my $self = shift;
    my $entries;

    for my $entry ( $self->{cal}->get_events ) {
        my $id = $entry->extended_property->{id};
        if ( not $id ) {
            warn "entry without id";
            next;
        }
        $entries->{ $id } = $entry;
    }

    my $ev;
    while ( $ev = shift ) {
        my $new = 0;
        my $entry = $entries->{ $ev->{id} };
        unless ( $entry ) {
            $entry = Net::Google::Calendar::Entry->new;
            $new   = 1;
        }

        my $changed = x2entry( $ev, $entry );

        if ( $new ) {
            $self->{cal}->add_entry( $entry );
            print "adding " . $entry->extended_property->{id} . "\n";
        } else {
            if ( $changed ) {
                $self->{cal}->update_entry( $entry );
                print "updating " . $entry->extended_property->{id} . "\n";
            } else {
                print "no change " . $entry->extended_property->{id} . "\n";
            }
            delete $entries->{ $ev->{id} };
        }
    }

    for my $entry ( values %$entries ) {
        $self->{cal}->delete_entry( $entry );
        print "deleting " . $entry->extended_property->{id} . "\n";
    }

    return;
}

1;
