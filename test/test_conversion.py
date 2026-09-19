import csv
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/"scripts"))
import convert_data as c
import download_data as d

class ConversionTests(unittest.TestCase):
    def fixture(self, root):
        src=root/"raw.csv"
        row={"OBJECTID":"1","EVENT_UNIQUE_ID":"same", "OCC_DATE":"2025-12-30",
             "REPORT_DATE":"2026-01-03","NEIGHBOURHOOD_140":"A", "LONG_WGS84":"-79",
             "LAT_WGS84":"43", "OCC_HOUR":"0", "PREMISES_TYPE":"Outside"}
        with src.open("w") as f:
            w=csv.DictWriter(f,fieldnames=row);w.writeheader();w.writerow(row)
            w.writerow(dict(row,OBJECTID="2",REPORT_DATE=""))
        return src

    def test_dates_ids_and_midnight_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); src=self.fixture(root)
            with mock.patch.multiple(c,SRC=src,DST_LEGACY=root/"new/a.csv",DST_ENHANCED=root/"new/b.csv"):
                c.main()
            with (root/"new/b.csv").open() as f: rows=list(csv.DictReader(f))
            self.assertEqual(rows[0]["report_date"],"2026-01-03")
            self.assertEqual(rows[0]["hour"],"0")
            self.assertEqual(rows[1]["report_date"],"")
            self.assertEqual(len(rows),2)

    def test_second_replace_failure_rolls_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);src=self.fixture(root);a=root/"a.csv";b=root/"b.csv"
            a.write_text("old-a");b.write_text("old-b")
            real=c.os.replace
            def replace(source,target):
                if Path(target)==b: raise OSError("simulated interruption")
                return real(source,target)
            with mock.patch.multiple(c,SRC=src,DST_LEGACY=a,DST_ENHANCED=b), mock.patch.object(c.os,"replace",side_effect=replace):
                with self.assertRaises(OSError):c.main()
            self.assertEqual(a.read_text(),"old-a");self.assertEqual(b.read_text(),"old-b")

    def test_schema_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            src=Path(tmp)/"bad.csv";src.write_text("OCC_DATE\n2025-01-01\n")
            with mock.patch.object(c,"SRC",src):
                with self.assertRaises(ValueError):c.main()

class DownloadCompletenessTests(unittest.TestCase):
    def test_early_page_is_not_success(self):
        page={"features":[{"attributes":{"OBJECTID":1}}],"exceededTransferLimit":False}
        with mock.patch.object(d,"query_ids",return_value={1,2}),mock.patch.object(d,"query_page",return_value=page):
            with self.assertRaises(RuntimeError):d.fetch_all()

    def test_changed_id_manifest_rejected(self):
        page={"features":[{"attributes":{"OBJECTID":1}}]}
        with mock.patch.object(d,"query_ids",side_effect=[{1},{1,2}]),mock.patch.object(d,"query_page",return_value=page):
            with self.assertRaises(RuntimeError):d.fetch_all()

    def test_matching_manifest_succeeds(self):
        page={"features":[{"attributes":{"OBJECTID":1}}]}
        with mock.patch.object(d,"query_ids",return_value={1}),mock.patch.object(d,"query_page",return_value=page):
            self.assertEqual(d.fetch_all()[1],[1])

if __name__=="__main__":unittest.main()
