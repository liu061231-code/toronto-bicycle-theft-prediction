#!/usr/bin/env python3
"""Download the Toronto Police Service Bicycle Thefts open dataset.

Source: Toronto Police Service ArcGIS FeatureServer (updated continuously).
Fetches all records via paginated queries and saves them as CSV.

Reference:
https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/services/Bicycle_Thefts_Open_Data/FeatureServer/0

Behaviour guarantees (see handoff.md P1-06):
  - creates the output directory if it does not exist;
  - treats an ArcGIS `error` response as a hard failure, never a zero-row
    success;
  - checks the object-id primary key for duplicates before writing;
  - writes to a temporary file and atomically renames it on success, so a
    mid-download failure never leaves a truncated file that looks complete;
  - exits with a non-zero status on any failure.
"""
import csv
import json
import os
import sys
import tempfile
import urllib.parse
import urllib.request

BASE = (
    "https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/"
    "services/Bicycle_Thefts_Open_Data/FeatureServer/0"
)

# Fields requested from the server. OBJECTID is the ArcGIS object primary key
# and is kept so downstream code can reconcile records and detect duplicates.
# EVENT_UNIQUE_ID is the business event id (may repeat across rows).
FIELDS = [
    "OBJECTID", "EVENT_UNIQUE_ID", "OCC_DATE", "OCC_YEAR", "OCC_MONTH",
    "OCC_DOW", "OCC_DAY", "OCC_DOY", "OCC_HOUR", "REPORT_DATE", "REPORT_YEAR",
    "REPORT_MONTH", "REPORT_DOW", "REPORT_DAY", "REPORT_DOY", "REPORT_HOUR",
    "DIVISION", "LOCATION_TYPE", "PREMISES_TYPE", "BIKE_MAKE", "BIKE_MODEL",
    "BIKE_TYPE", "BIKE_SPEED", "BIKE_COLOUR", "BIKE_COST", "STATUS",
    "PRIMARY_OFFENCE", "HOOD_158", "NEIGHBOURHOOD_158", "HOOD_140",
    "NEIGHBOURHOOD_140", "LONG_WGS84", "LAT_WGS84",
]

PAGE_SIZE = 2000


def query_page(offset):
    """Fetch one page of records (ArcGIS caps results at 2000 per request).

    Raises RuntimeError on an API error or a non-JSON / missing body, so the
    caller never mistakes an error payload for a legitimate empty page.
    """
    params = {
        "where": "1=1",
        "outFields": ",".join(FIELDS),
        "returnGeometry": "false",
        "outSR": "4326",
        "resultOffset": offset,
        "resultRecordCount": PAGE_SIZE,
        "f": "json",
    }
    url = BASE + "/query?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=120) as resp:
        body = resp.read().decode("utf-8")
    data = json.loads(body)
    if "error" in data:
        raise RuntimeError(
            "ArcGIS API error: %s" % json.dumps(data["error"])
        )
    if "features" not in data:
        raise RuntimeError("ArcGIS response missing 'features' key")
    return data


def fetch_all():
    """Download all pages and return (rows, object_ids)."""
    rows = []
    object_ids = []
    offset = 0
    page = 0
    while True:
        data = query_page(offset)
        feats = data.get("features", [])
        if not feats:
            break
        for f in feats:
            attrs = f.get("attributes", {})
            rows.append({k: attrs.get(k) for k in FIELDS})
            object_ids.append(attrs.get("OBJECTID"))
        offset += len(feats)
        page += 1
        if not data.get("exceededTransferLimit", False):
            break
        if offset % 10000 < PAGE_SIZE:
            print("  downloaded %d rows ..." % offset, flush=True)
    return rows, object_ids


def main():
    out_path = (
        sys.argv[1] if len(sys.argv) > 1 else "data/raw/bicycle_raw_latest.csv"
    )

    # Ensure the target directory exists before writing.
    out_dir = os.path.dirname(os.path.abspath(out_path))
    os.makedirs(out_dir, exist_ok=True)

    print("Downloading from ArcGIS FeatureServer ...")
    rows, object_ids = fetch_all()

    if not rows:
        raise RuntimeError("Download produced zero rows; refusing to write")

    # Object primary-key duplicate check: OBJECTID must be unique per record.
    non_null_ids = [o for o in object_ids if o is not None]
    n_dup = len(non_null_ids) - len(set(non_null_ids))
    if n_dup > 0:
        raise RuntimeError(
            "OBJECTID primary key has %d duplicate values" % n_dup
        )

    print("Total rows downloaded: %d" % len(rows))
    print("Distinct OBJECTID   : %d" % len(set(non_null_ids)))

    # Write to a temp file in the same directory, then atomically rename so a
    # partial write can never masquerade as a complete, valid file.
    fd, tmp_path = tempfile.mkstemp(
        dir=out_dir, prefix=".bicycle_raw_", suffix=".csv.tmp"
    )
    try:
        with os.fdopen(fd, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerows(rows)
        os.replace(tmp_path, out_path)
    except BaseException:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise

    print("Saved to %s" % out_path)


if __name__ == "__main__":
    main()
