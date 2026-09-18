#!/usr/bin/env python3
"""Download the Toronto Police Service Bicycle Thefts open dataset.

Source: Toronto Police Service ArcGIS FeatureServer (updated continuously).
Fetches all records via paginated queries and saves them as CSV.

Reference:
https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/services/Bicycle_Thefts_Open_Data/FeatureServer/0
"""
import json
import sys
import urllib.request
import urllib.parse

BASE = (
    "https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/"
    "services/Bicycle_Thefts_Open_Data/FeatureServer/0"
)

FIELDS = [
    "EVENT_UNIQUE_ID", "OCC_DATE", "OCC_YEAR", "OCC_MONTH", "OCC_DOW",
    "OCC_DAY", "OCC_DOY", "OCC_HOUR", "REPORT_DATE", "REPORT_YEAR",
    "REPORT_MONTH", "REPORT_DOW", "REPORT_DAY", "REPORT_DOY", "REPORT_HOUR",
    "DIVISION", "LOCATION_TYPE", "PREMISES_TYPE", "BIKE_MAKE", "BIKE_MODEL",
    "BIKE_TYPE", "BIKE_SPEED", "BIKE_COLOUR", "BIKE_COST", "STATUS",
    "PRIMARY_OFFENCE", "HOOD_158", "NEIGHBOURHOOD_158", "HOOD_140",
    "NEIGHBOURHOOD_140", "LONG_WGS84", "LAT_WGS84",
]


def query_page(offset):
    """Fetch one page of records (ArcGIS caps results at 2000 per request)."""
    params = {
        "where": "1=1",
        "outFields": ",".join(FIELDS),
        "returnGeometry": "false",
        "outSR": "4326",
        "resultOffset": offset,
        "resultRecordCount": 2000,
        "f": "json",
    }
    url = BASE + "/query?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=120) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "data/raw/bicycle_raw_latest.csv"

    # First request to learn the total count and field names.
    first = query_page(0)
    features = first.get("features", [])
    total = first.get("exceededTransferLimit", False)

    rows = []
    offset = 0
    page = 0
    while True:
        data = query_page(offset) if page > 0 else first
        feats = data.get("features", [])
        if not feats:
            break
        for f in feats:
            attrs = f.get("attributes", {})
            rows.append({k: attrs.get(k) for k in FIELDS})
        offset += len(feats)
        page += 1
        if not data.get("exceededTransferLimit", False):
            break
        if offset % 10000 == 0:
            print(f"  downloaded {offset} rows ...", flush=True)

    print(f"Total rows downloaded: {len(rows)}")

    # Write CSV.
    import csv
    with open(out_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Saved to {out_path}")


if __name__ == "__main__":
    main()
