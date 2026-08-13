import tempfile
import unittest
from pathlib import Path

from boss_helper_service.importer import import_paths
from boss_helper_service.store import SQLiteStore


class ImporterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.store = SQLiteStore(self.root / "data")

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_import_csv(self) -> None:
        csv_path = self.root / "jobs.csv"
        csv_path.write_text(
            "job_id,job_name,salary_range,deliver_status\n"
            "1,产品经理,15-20K,success\n"
            "2,数据分析,20-30K,warning\n",
            encoding="utf-8",
        )

        result = import_paths(self.store, [str(csv_path)])
        self.assertEqual(result["imported"], 2)
        self.assertEqual(result["files"], 1)
        self.assertEqual(self.store.get_all_job_ids(), {"1", "2"})

    def test_import_data_js_and_deduplicate(self) -> None:
        js_path = self.root / "data.js"
        js_path.write_text(
            'const jobData = [{"job_id": "1", "job_name": "旧数据", '
            '"salary_range": "10-15K"}];',
            encoding="utf-8",
        )

        result = import_paths(self.store, [str(js_path)])
        self.assertEqual(result["imported"], 1)
        self.assertEqual(self.store.get_all_job_ids(), {"1"})

    def test_import_directory(self) -> None:
        source_dir = self.root / "jobdata"
        source_dir.mkdir()
        (source_dir / "a.csv").write_text(
            "job_id,job_name\n3,爬虫岗位\n", encoding="utf-8"
        )
        (source_dir / "b.js").write_text(
            'const jobData = [{"job_id": "4", "job_name": "JS 岗位"}];',
            encoding="utf-8",
        )

        result = import_paths(self.store, [str(source_dir)])
        self.assertEqual(result["imported"], 2)
        self.assertEqual(self.store.get_all_job_ids(), {"3", "4"})


if __name__ == "__main__":
    unittest.main()
