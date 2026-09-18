#!/usr/bin/env python3
"""Tests for the download/convert scripts' error handling and reproducibility.

Run with: python3 -m pytest test/ -q   (or: python3 test/test_scripts.py)
Covers (handoff.md P1-06):
  - ArcGIS `error` responses are treated as failures, not zero-row success;
  - the output directory is created automatically;
  - atomic write leaves no truncated file on failure;
  - duplicate OBJECTID is rejected.

These tests mock `urllib` and the filesystem; they do NOT hit the network.
"""
import csv
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

# Make scripts/ importable.
SCRIPT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
sys.path.insert(0, SCRIPT_DIR)

import download_data  # noqa: E402


def _fake_response(payload):
    """Build a urllib response-like object returning JSON bytes."""
    class Resp:
        def __init__(self, data):
            self._data = data

        def read(self):
            return json.dumps(self._data).encode("utf-8")

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    return Resp(payload)


class TestQueryPage(unittest.TestCase):
    def test_error_response_raises(self):
        payload = {"error": {"code": 400, "message": "bad"}}
        with mock.patch.object(
            download_data.urllib.request,
            "urlopen",
            return_value=_fake_response(payload),
        ):
            with self.assertRaises(RuntimeError):
                download_data.query_page(0)

    def test_missing_features_raises(self):
        payload = {"not_features": []}
        with mock.patch.object(
            download_data.urllib.request,
            "urlopen",
            return_value=_fake_response(payload),
        ):
            with self.assertRaises(RuntimeError):
                download_data.query_page(0)


class TestDownload(unittest.TestCase):
    def test_duplicate_objectid_raises(self):
        rows = [
            {"OBJECTID": 1, "EVENT_UNIQUE_ID": "a"},
            {"OBJECTID": 1, "EVENT_UNIQUE_ID": "b"},
        ]
        with mock.patch.object(download_data, "fetch_all", return_value=(rows, [1, 1])):
            with tempfile.TemporaryDirectory() as d:
                out = os.path.join(d, "raw.csv")
                with mock.patch.object(sys, "argv", ["download_data.py", out]):
                    with self.assertRaises(RuntimeError):
                        download_data.main()
                # No file should be left behind on failure.
                self.assertFalse(os.path.exists(out))

    def test_creates_output_directory(self):
        rows = [
            {"OBJECTID": 1, "EVENT_UNIQUE_ID": "a"},
            {"OBJECTID": 2, "EVENT_UNIQUE_ID": "b"},
        ]
        with mock.patch.object(
            download_data, "fetch_all", return_value=(rows, [1, 2])
        ):
            with tempfile.TemporaryDirectory() as d:
                out = os.path.join(d, "nested", "dir", "raw.csv")
                with mock.patch.object(sys, "argv", ["download_data.py", out]):
                    download_data.main()
                self.assertTrue(os.path.exists(out))


if __name__ == "__main__":
    unittest.main()
