#!/usr/bin/perl
# vim:set et:

use 5.010;
use strict;
use warnings;

use File::Touch;
use FindBin;
chdir $FindBin::Bin;

my $conf = eval `cat private.conf`;
my $tsfile = $conf->{tsfile} // 'last_sync';
my $syncinterval = $conf->{syncinterval} // 1; # day
my $enabledwifis = $conf->{enabledwifis};

if ( defined $enabledwifis ) {
    my $eth = `/sbin/ip -o ro g 8.8.8.8 2>/dev/null | grep eth`; chomp $eth;
    my $wifi = `/sbin/iw dev wlan1 link | awk '/SSID:/ { print \$2 }'`; chomp $wifi;
    unless ( $eth or grep $wifi eq $_, @$enabledwifis ) {
        say 'Skipping sync, not enabled wifi.';
        exit;
    }
}

if ( (-M $tsfile // 999) < $syncinterval ) {
    say 'Skipping sync, too early.';
    exit;
}

system './sync.pl';

if ( $? == 0 ) {
    touch $tsfile;
} else {
    die $?;
}
