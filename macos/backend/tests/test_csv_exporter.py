import csv
import tempfile
import unittest
from datetime import date
from pathlib import Path

from boss_helper_service.csv_exporter import CSV_FIELDNAMES, CsvExporter


class CsvExporterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.exporter = CsvExporter(Path(self.tmp.name))

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _weekly_path(self) -> Path:
        today = date.today()
        return (
            self.exporter.csv_dir
            / today.strftime("%Y-%m")
            / f"week_{today.isocalendar()[1]:02d}.csv"
        )

    def _read_rows(self):
        path = self._weekly_path()
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            return list(reader), reader.fieldnames

    def test_first_export_creates_old_21_field_header(self) -> None:
        self.exporter.export_job(
            {
                "job_id": "job-1",
                "job_name": "产品经理",
                "salary_range": "15-25K",
                "deliver_status": "success",
            }
        )

        rows, fieldnames = self._read_rows()
        self.assertEqual(fieldnames, CSV_FIELDNAMES)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["job_name"], "产品经理")

    def test_same_job_updates_row_instead_of_duplicating(self) -> None:
        self.exporter.export_job(
            {"job_id": "job-1", "job_name": "旧名称", "deliver_status": "warning"}
        )
        self.exporter.export_job(
            {"job_id": "job-1", "job_name": "新名称", "deliver_status": "success"}
        )

        rows, _ = self._read_rows()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["job_name"], "新名称")
        self.assertEqual(rows[0]["deliver_status"], "success")

    def test_different_jobs_append_rows(self) -> None:
        self.exporter.export_job({"job_id": "job-1", "job_name": "A"})
        self.exporter.export_job({"job_id": "job-2", "job_name": "B"})

        rows, _ = self._read_rows()
        self.assertEqual(len(rows), 2)
        self.assertEqual({row["job_id"] for row in rows}, {"job-1", "job-2"})


if __name__ == "__main__":
    unittest.main()
