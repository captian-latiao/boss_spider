import csv
import os
import threading
from datetime import date
from pathlib import Path
from typing import Any


CSV_FIELDNAMES = [
    "job_id",
    "main_category",
    "sub_category",
    "job_name",
    "job_area",
    "job_company",
    "job_industry",
    "job_finance",
    "job_scale",
    "job_welfare",
    "salary_range",
    "salary_type",
    "job_experience",
    "job_tag_list",
    "post_description",
    "deliver_status",
    "filter_reason",
    "filter_detail",
    "address_detail",
    "boss_active",
    "create_time",
]


def _default_csv_dir() -> Path:
    override = os.environ.get("BOSS_HELPER_CSV_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Documents" / "BossHelperData"


class CsvExporter:
    def __init__(self, csv_dir: str | Path | None = None):
        self.csv_dir = Path(csv_dir).expanduser() if csv_dir else _default_csv_dir()
        self._lock = threading.Lock()

    def _weekly_csv_path(self) -> Path:
        today = date.today()
        month_dir = self.csv_dir / today.strftime("%Y-%m")
        month_dir.mkdir(parents=True, exist_ok=True)
        week_number = today.isocalendar()[1]
        return month_dir / f"week_{week_number:02d}.csv"

    def export_job(self, job: dict[str, Any]) -> Path | None:
        job_id = str(job.get("job_id") or "").strip()
        if not job_id:
            return None

        path = self._weekly_csv_path()
        new_row = {
            field: str(job.get(field, "") or "")
            for field in CSV_FIELDNAMES
        }

        with self._lock:
            rows: dict[str, dict[str, str]] = {}
            if path.exists():
                with path.open("r", encoding="utf-8-sig", newline="") as handle:
                    for row in csv.DictReader(handle):
                        existing_id = str(row.get("job_id") or "").strip()
                        if existing_id:
                            rows[existing_id] = {
                                field: str(row.get(field, "") or "")
                                for field in CSV_FIELDNAMES
                            }

            rows[job_id] = new_row

            with path.open("w", encoding="utf-8-sig", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=CSV_FIELDNAMES)
                writer.writeheader()
                for row in rows.values():
                    writer.writerow(row)

        return path
