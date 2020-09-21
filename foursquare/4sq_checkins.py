#!/usr/bin/env python3

from contextlib import contextmanager
from datetime import datetime
from foursquare import Foursquare
import icalendar
import json
import os
import pytz
import sqlite3
import sys


@contextmanager
def database():
    db = sqlite3.connect("4sq_checkins.sqlite")
    db.row_factory = sqlite3.Row
    try:
        db.execute(("CREATE TABLE IF NOT EXISTS checkins "
                    "(id TEXT PRIMARY KEY, createdAt NUMERIC, data TEXT)"))
        yield db
    finally:
        db.close()


def checkins():
    client = Foursquare(access_token=os.getenv('FOURSQUARE_TOKEN'))
    return client.users.all_checkins()


def sync(db):
    with db:  # transaction
        for checkin in checkins():
            tup = (checkin['id'], int(checkin['createdAt']), json.dumps(checkin))
            try:
                db.execute(("INSERT INTO checkins (id, createdAt, data) VALUES (?, ?, ?)"), tup)
            except sqlite3.IntegrityError:
                break

            print(datetime.fromtimestamp(checkin['createdAt']), file=sys.stderr)


def ical(db):
    cal = icalendar.Calendar()
    cal.add('prodid', "4sq_checkins.py")
    cal.add('version', "2.0")

    for checkin in db.execute("SELECT data FROM checkins"):
        checkin = json.loads(checkin['data'])

        ev = icalendar.Event()
        ev.add('uid', checkin['id'] + '@foursquare.com')
        ev.add('url', checkin['canonicalUrl'])
        ev.add('summary', "@ " + checkin['venue']['name'])
        ev.add('description', "@ " + checkin['venue']['name'])
        ev.add('location', checkin['venue']['name'])
        ev.add('dtstart', datetime.fromtimestamp(checkin['createdAt'], pytz.utc))
        ev.add('dtend', datetime.fromtimestamp(checkin['createdAt'], pytz.utc))
        cal.add_component(ev)

    sys.stdout.buffer.write(cal.to_ical())


def main():
    with database() as db:
        sync(db)
        ical(db)


if __name__ == '__main__':
    main()
