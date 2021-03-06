# Copyright (C) 2011, Tomas Janousek. BSD license.
# vim:set et:
package GCal;

use strict;
use warnings;
use feature 'say';

use Clone 'clone';
use Data::Dumper;
use DateTime;
use JSON::XS;
use Digest::SHA 'sha1_hex';
use Google::API::Client;
use Google::API::OAuth2::Client;

*DateTime::TO_JSON = sub { return "" . shift };

our $json = JSON::XS->new->allow_blessed( 1 )->convert_blessed( 1 )->canonical( 1 )->utf8( 1 );
our $dry_run = $ENV{'DRY_RUN'} ? 1 : 0;

# Constructor, to be called as:
# my $gcal = GCal->new();
sub new {
    my ($class, %param) = @_;
    my $self;
    $self->{service} = Google::API::Client->new->build( 'calendar', 'v3' );
    $self->{auth_driver} = Google::API::OAuth2::Client->new_from_client_secrets(
        'client_secrets.json', $self->{service}->{auth_doc} );
    get_or_restore_token( 'token.dat', $self->{auth_driver} );
    store_token( 'token.dat', $self->{auth_driver} );
    bless $self, $class;
    return $self;
}

sub list_calendars {
    my ($self) = @_;

    my @items;
    my $body = { maxResults => 100, fields => 'items(id,summary),nextPageToken' };
    my $auth = { auth_driver => $self->{auth_driver} };
    do {
        my $list = $self->{service}->calendarList->list( body => clone( $body ) )->execute( $auth );
        $body->{pageToken} = $list->{nextPageToken};
        push @items, @{ $list->{items} };
    } while defined $body->{pageToken};

    return \@items;
}

sub calendars {
    my ($self) = @_;

    return $self->{calendars} //= $self->list_calendars;
}

# Set current calendar by its name.
# $cal->set_calendar( 'Facebook events' )
#
# FIXME: get rid of this stateful shit
sub set_calendar {
    my ($self, $cal) = @_;

    my $calendars = $self->calendars;
    my @cal = grep { $_->{summary} eq $cal } @{ $self->calendars } or die;
    $self->{calendarId} = $cal[0]->{id};
}

# Fill in Net::Google::Calendar::Entry from a simple hash:
# { title    => 'event title'
# , content  => 'event description'
# , location => 'event location'
# , url      => 'event url'
# , when     => [ <DateTime> of start, <DateTime> of end ]
# , id       => 'unique event id'
# , public   => 1 (if you want people to be able to add themselves)
# , icon     => 'icon url' (or undef)
# }
sub x2entry {
    my ($ev, $entry) = @_;

    my $hash = sha1_hex( $json->encode( $ev ) );
    my $last_hash = $entry->{extendedProperties}->{shared}->{last_hash} // 'kokot';
    my $changed = $hash ne $last_hash;

    my @desc = ( $ev->{content} );
    if ( %{$ev->{extra} // {}} ) {
        unshift @desc, '';
        for ( sort keys %{$ev->{extra}} ) {
            unshift @desc, $_ . ": " . $ev->{extra}->{$_};
        }
    }

    $entry->{summary} = $ev->{title};
    $entry->{description} = join( "\n", @desc );
    $entry->{location} = $ev->{location};
    $entry->{start}->{dateTime} = $ev->{when}->[0]->strftime( "%FT%T%z" );
    $entry->{end}->{dateTime} = $ev->{when}->[1]->strftime( "%FT%T%z" );
    $entry->{extendedProperties}->{shared}->{id} = $ev->{id};
    $entry->{extendedProperties}->{shared}->{last_hash} = $hash;
    $entry->{anyoneCanAddSelf} = $ev->{public} ? \1 : \0;

    if ( length $ev->{url} ) {
        $entry->{source}->{title} = $entry->{summary};
        $entry->{source}->{url} = $ev->{url};
    }

    if ( $ev->{icon} ) {
        $entry->{gadget}->{iconLink} = $ev->{icon};
        $entry->{gadget}->{display} = 'chip';
        $entry->{gadget}->{type} = 'image/gif';
        $entry->{gadget}->{title} = '';
    } else {
        $entry->{gadget} = undef;
    }

    return $changed;
}

sub list_events {
    my ($self, $cal) = @_;

    my @items;
    my $body =
        { maxResults => 2500
        , fields => 'items(extendedProperties,id),nextPageToken'
        , calendarId => $cal };
    my $auth = { auth_driver => $self->{auth_driver} };
    do {
        my $list = $self->{service}->events->list( body => clone( $body ) )->execute( $auth );
        $body->{pageToken} = $list->{nextPageToken};
        push @items, @{ $list->{items} };
    } while defined $body->{pageToken};

    return \@items;
}

sub add_event {
    my ($self, $cal, $ev) = @_;

    my $auth = { auth_driver => $self->{auth_driver} };
    $self->{service}->events->insert( calendarId => $cal, body => $ev )->execute( $auth );
}

sub patch_event {
    my ($self, $cal, $ev) = @_;

    my $auth = { auth_driver => $self->{auth_driver} };
    $self->{service}->events->patch( calendarId => $cal, eventId => $ev->{id}, body => $ev )->execute( $auth );
}

sub del_event {
    my ($self, $cal, $ev) = @_;

    my $auth = { auth_driver => $self->{auth_driver} };
    $self->{service}->events->delete( calendarId => $cal, eventId => $ev->{id} )->execute( $auth );
}

sub get_event {
    my ($self, $cal, $ev) = @_;

    my $auth = { auth_driver => $self->{auth_driver} };
    $self->{service}->events->get( calendarId => $cal, eventId => $ev->{id} )->execute( $auth );
}

# Take a list of entries in the format expected by x2entry and put them online.
# New events are added, old are updated if changed, disappeared are deleted.
sub update_entries {
    my $self = shift;

    my $params = shift;
    my $del_filter = $params->{del_filter} // sub { 1 };

    my $entries;

    for my $entry ( @{ $self->list_events( $self->{calendarId} ) } )
    {
        my $id = $entry->{extendedProperties}->{shared}->{id};
        if ( not $id ) {
            warn "entry without id";
            next;
        }
        if ( exists $entries->{ $id } ) {
            $self->del_event( $self->{calendarId}, $entry ) unless $dry_run;
            print "deleting duplicate of " . $id . "\n";
            next;
        }
        $entries->{ $id } = $entry;
    }

    my $ev;
    while ( $ev = shift ) {
        my $entry = $entries->{ $ev->{id} };
        my $new = not defined $entry;
        my $changed = x2entry( $ev, $entry //= {} );
        my $id = $entry->{extendedProperties}->{shared}->{id};

        if ( $new ) {
            $self->add_event( $self->{calendarId}, $entry ) unless $dry_run;
            print "added " . $id . "\n";
        } else {
            if ( $changed ) {
                $self->patch_event( $self->{calendarId}, $entry ) unless $dry_run;
                print "updated " . $id . "\n";
            } else {
                print "no change " . $id . "\n";
            }
            delete $entries->{ $ev->{id} };
        }
    }

    for my $entry ( values %$entries ) {
        if ( $del_filter->( $entry ) ) {
            $self->del_event( $self->{calendarId}, $entry ) unless $dry_run;
            print "deleted " . $entry->{extendedProperties}->{shared}->{id} . "\n";
        } else {
            print "kept " . $entry->{extendedProperties}->{shared}->{id} . "\n";
        }
    }

    return;
}

# Taken from https://github.com/comewalk/google-api-perl-client
sub get_or_restore_token {
    my ($file, $auth_driver) = @_;
    my $access_token;
    if (-f $file) {
        open my $fh, '<', $file;
        if ($fh) {
            local $/;
            require JSON;
            $access_token = JSON->new->decode(<$fh>);
            close $fh;
        }
        $auth_driver->token_obj($access_token);
    } else {
        my $auth_url = $auth_driver->authorize_uri;
        say 'Go to the following link in your browser:';
        say $auth_url;

        say 'Enter verification code:';
        my $code = <STDIN>;
        chomp $code;
        $access_token = $auth_driver->exchange($code);
    }
    return $access_token;
}

sub store_token {
    my ($file, $auth_driver) = @_;
    my $access_token = $auth_driver->token_obj;
    open my $fh, '>', $file;
    if ($fh) {
        require JSON;
        print $fh JSON->new->encode($access_token);
        close $fh;
    }
}

sub del_filter_not_attended_events {
    my $self = shift;
    my $ev = shift;

    return 0 if $ev->{extendedProperties}->{shared}->{attended};

    $ev = $self->get_event( $self->{calendarId}, $ev );

    if (
        # if there's a non-negative response, keep it
        grep {
            defined( $_->{responseStatus} ) and
            $_->{responseStatus} ne 'declined'
        } @{ $ev->{attendees} }
    ) {
        # cache attendance so that we don't need to get_event all old events
        my $patch_ev;
        $patch_ev->{id} = $ev->{id};
        $patch_ev->{extendedProperties}->{shared}->{attended} = 1;
        $self->patch_event( $self->{calendarId}, $patch_ev ) unless $dry_run;

        0;
    } else {
        # drop it otherwise
        1;
    }
}

1;
