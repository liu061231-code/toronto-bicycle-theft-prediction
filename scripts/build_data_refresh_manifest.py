#!/usr/bin/env python3
"""Build a deterministic provenance report for the latest downloaded data.

Raw snapshots are intentionally ignored by git.  This small manifest is the
auditable, reviewable record committed by the scheduled refresh workflow.
"""
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw"
OUT = ROOT / "output/data_refresh_manifest.json"
SOURCE_URL = (
    "https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/"
    "services/Bicycle_Thefts_Open_Data/FeatureServer/0"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def summarize_csv(path: Path) -> dict:
    with path.open(newline="", encoding="utf-8") as fh:
        rows = csv.DictReader(fh)
        values = list(rows)
    dates = [r.get("occ_date") or r.get("date") or r.get("OCC_DATE") for r in values]
    dates = [
        datetime.fromtimestamp(int(d) / 1000, tz=timezone.utc).date().isoformat()
        if d and str(d).isdigit() and len(str(d)) >= 10 else d
        for d in dates
    ]
    dates = sorted(d for d in dates if d)
    object_ids = {r.get("objectid") or r.get("OBJECTID") for r in values if r.get("objectid") or r.get("OBJECTID")}
    event_ids = {r.get("event_unique_id") or r.get("EVENT_UNIQUE_ID") for r in values if r.get("event_unique_id") or r.get("EVENT_UNIQUE_ID")}
    return {
        "sha256": sha256(path),
        "rows": len(values),
        "distinct_objectid": len(object_ids),
        "distinct_event_unique_id": len(event_ids),
        "occurrence_date_min": dates[0] if dates else None,
        "occurrence_date_max": dates[-1] if dates else None,
    }


def build_manifest() -> dict:
    names = ("bicycle_raw_latest.csv", "bicycle.csv", "bicycle_enhanced.csv")
    files = {name: summarize_csv(RAW / name) for name in names}
    conversion_path = RAW / "conversion_manifest.json"
    conversion = json.loads(conversion_path.read_text(encoding="utf-8"))
    return {
        "schema_version": 1,
        "source": SOURCE_URL,
        "conversion_manifest": conversion,
        "files": files,
    }


def main() -> None:
    manifest = build_manifest()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    # Avoid a noisy commit when the source snapshot has not changed.
    if OUT.exists() and OUT.read_text(encoding="utf-8") == rendered:
        print(f"unchanged: {OUT}")
        return
    OUT.write_text(rendered, encoding="utf-8")
    print(f"wrote: {OUT}")


if __name__ == "__main__":
    main()
