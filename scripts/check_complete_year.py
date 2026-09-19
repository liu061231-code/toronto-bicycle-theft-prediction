#!/usr/bin/env python3
"""Fail unless the refreshed snapshot contains every month of a year."""
import csv
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_complete_year.py YEAR")
    year = int(sys.argv[1])
    path = Path(__file__).resolve().parents[1] / "data/raw/bicycle_raw_latest.csv"
    months = Counter()
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            value = row.get("OCC_DATE") or ""
            if value.isdigit():
                value = datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc).date().isoformat()
            if value.startswith(f"{year}-"):
                months[value[5:7]] += 1
    missing = [f"{month:02d}" for month in range(1, 13) if f"{month:02d}" not in months]
    if missing:
        raise SystemExit(f"year {year} is incomplete; missing months: {', '.join(missing)}")
    print(f"complete year {year}: {sum(months.values())} occurrence rows")


if __name__ == "__main__":
    main()
