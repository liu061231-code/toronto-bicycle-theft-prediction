#!/usr/bin/env python3
"""Convert the official Toronto Bicycle Thefts dataset to project schema.

Input : data/raw/bicycle_raw_latest.csv  (ArcGIS export, 2014-2026, 40583 rows)
Output:
  - data/raw/bicycle.csv          : aligned to the legacy pipeline schema
                                    (date, quarter, day_of_week, neighborhood,
                                     bike_cost, location, long, lat)
  - data/raw/bicycle_enhanced.csv : full schema including new signal fields
                                    (hour, premises_type, location_type,
                                     division) for daily/hourly modelling
"""
import csv
from datetime import datetime, date, timezone
from collections import Counter

SRC = "data/raw/bicycle_raw_latest.csv"
DST_LEGACY = "data/raw/bicycle.csv"
DST_ENHANCED = "data/raw/bicycle_enhanced.csv"

# Map PREMISES_TYPE -> the legacy "location" coarse category.
PREMISES_TO_LOCATION = {
    "Apartment": "Residential Structures",
    "House": "Residential Structures",
    "Outside": "Open/Public Spaces",
    "Commercial": "Commercial Areas",
    "Transit": "Transportation",
    "Educational": "Public Institutions",
    "Other": "Others",
}

def parse_date(s):
    """Parse an ArcGIS epoch-milliseconds timestamp or ISO date string."""
    if s is None or s == "":
        return None
    try:
        # ArcGIS may return milliseconds since epoch.
        ms = int(s)
        return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).date()
    except (ValueError, TypeError):
        pass
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None

def main():
    rows = list(csv.DictReader(open(SRC, encoding="utf-8")))

    legacy_rows = []
    enhanced_rows = []
    skipped = 0
    object_ids = []
    event_ids = []

    for r in rows:
        occ_date = parse_date(r.get("OCC_DATE"))
        if occ_date is None:
            skipped += 1
            continue
        # Restrict to the stable reporting period (2014 onward).
        if occ_date.year < 2014:
            skipped += 1
            continue

        object_ids.append(r.get("OBJECTID"))
        event_ids.append(r.get("EVENT_UNIQUE_ID"))

        neighborhood = (r.get("NEIGHBOURHOOD_140") or "").strip()
        lon = r.get("LONG_WGS84") or ""
        lat = r.get("LAT_WGS84") or ""
        bike_cost = r.get("BIKE_COST") or ""
        premises = (r.get("PREMISES_TYPE") or "").strip()
        location_type = (r.get("LOCATION_TYPE") or "").strip()
        division = (r.get("DIVISION") or "").strip()
        hour = r.get("OCC_HOUR") or ""

        # Legacy row. Coordinates are kept raw; NSA rows carry 0/"" and are
        # flagged downstream (see make_neighborhood_coordinates in R).
        legacy_rows.append({
            "objectid": object_ids[-1],
            "event_unique_id": event_ids[-1],
            "date": occ_date.isoformat(),
            "quarter": occ_date.isoformat(),  # placeholder; derived in R
            "day_of_week": occ_date.strftime("%A"),
            "neighborhood": neighborhood,
            "bike_cost": bike_cost,
            "location": PREMISES_TO_LOCATION.get(premises, "Others"),
            "long": lon,
            "lat": lat,
        })

        # Enhanced row (keeps the fine-grained signals).
        enhanced_rows.append({
            "objectid": object_ids[-1],
            "event_unique_id": event_ids[-1],
            "date": occ_date.isoformat(),
            "neighborhood": neighborhood,
            "long": lon,
            "lat": lat,
            "bike_cost": bike_cost,
            "premises_type": premises,
            "location_type": location_type,
            "location": PREMISES_TO_LOCATION.get(premises, "Others"),
            "division": division,
            "hour": hour,
        })

    def write(path, fieldnames, data):
        with open(path, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(data)

    write(DST_LEGACY,
          ["objectid", "event_unique_id", "date", "quarter", "day_of_week",
           "neighborhood", "bike_cost", "location", "long", "lat"],
          legacy_rows)

    write(DST_ENHANCED,
          ["objectid", "event_unique_id", "date", "neighborhood", "long",
           "lat", "bike_cost", "premises_type", "location_type", "location",
           "division", "hour"],
          enhanced_rows)

    print(f"rows processed : {len(rows)}")
    print(f"rows kept      : {len(legacy_rows)}")
    print(f"rows skipped   : {skipped} (pre-2014 or missing date)")

    # Counting-calibre audit (see data_dictionary.md): rows != events.
    non_null_oid = [o for o in object_ids if o not in (None, "")]
    non_null_eid = [e for e in event_ids if e not in (None, "")]
    print(f"distinct OBJECTID       : {len(set(non_null_oid))}")
    print(f"distinct EVENT_UNIQUE_ID: {len(set(non_null_eid))}")

    print(f"legacy output  : {DST_LEGACY}")
    print(f"enhanced output: {DST_ENHANCED}")

    # Quick sanity summary.
    years = sorted({r['date'][:4] for r in legacy_rows})
    print(f"year range     : {years[0]} - {years[-1]}")
    print(f"neighbourhoods : {len({r['neighborhood'] for r in legacy_rows})}")
    print(f"premises types : {Counter(r['premises_type'] for r in enhanced_rows).most_common(8)}")

if __name__ == "__main__":
    main()
