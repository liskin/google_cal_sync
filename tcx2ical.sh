#!/bin/bash

IDIR=$1
ODIR=$2

set -x
set -e

for i in $IDIR/*.tcx; do
	f=`basename "$i"`
	o=$ODIR/"$f".ics
	if [ -s "$o" ]; then continue; fi

	./tcx2ical.pl "$i" >"$o"
done
