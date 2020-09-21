#!/usr/bin/env bash

set -eu -o pipefail

export FOURSQUARE_TOKEN=$(perl -MPath::Tiny -M5.010 -e 'say eval(path("private.conf")->slurp_utf8)->{foursquare_token}')
./foursquare/.venv/bin/4sq_checkins.py >4sq_checkins.ics.tmp
mv 4sq_checkins.ics.tmp 4sq_checkins.ics
