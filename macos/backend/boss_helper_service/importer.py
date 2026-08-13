import csv
import json
from pathlib import Path
from typing import Any

from .store import JOB_COLUMNS, SQLiteStore


def _clean_value(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def _normalize_row(row: dict[str, Any]) -> dict[str, Any]:
    normalized: dict[str, Any] = {}
    for column in JOB_COLUMNS:
        if column in row:
            normalized[column] = _clean_value(row[column])
    if "jobId" in row and "job_id" not in normalized:
        normalized["job_id"] = _clean_value(row["jobId"])
    if "encryptJobId" in row and "job_id" not in normalized:
        normalized["job_id"] = _clean_value(row["encryptJobId"])
    return normalized


def _import_csv(store: SQLiteStore, path: Path) -> tuple[int, int]:
    imported = 0
    skipped = 0
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            normalized = _normalize_row(row)
            if not normalized.get("job_id"):
                skipped += 1
                continue
            store.upsert_job(normalized, source="import")
            imported += 1
    return imported, skipped


def _import_data_js(store: SQLiteStore, path: Path) -> tuple[int, int]:
    content = path.read_text(encoding="utf-8").strip()
    prefix = "const jobData = "
    if not content.startswith(prefix):
        raise ValueError(f"{path} 不是预期的 data.js 格式")
    json_text = content[len(prefix) :].rstrip().rstrip(";")
    rows = json.loads(json_text)
    if not isinstance(rows, list):
        raise ValueError(f"{path} 顶层内容不是数组")

    imported = 0
    skipped = 0
    for row in rows:
        normalized = _normalize_row(row)
        if not normalized.get("job_id"):
            skipped += 1
            continue
        store.upsert_job(normalized, source="import")
        imported += 1
    return imported, skipped


def _import_file(store: SQLiteStore, path: Path) -> tuple[int, int]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        return _import_csv(store, path)
    if suffix == ".js":
        return _import_data_js(store, path)
    raise ValueError(f"不支持的文件类型: {path}")


def import_paths(store: SQLiteStore, paths: list[str]) -> dict[str, int]:
    imported = 0
    skipped = 0
    files: list[Path] = []

    for raw in paths:
        path = Path(raw).expanduser()
        if path.is_dir():
            files.extend(
                item
                for item in path.rglob("*")
                if item.is_file() and item.suffix.lower() in {".csv", ".js"}
            )
        elif path.is_file():
            files.append(path)

    for file in files:
        file_imported, file_skipped = _import_file(store, file)
        imported += file_imported
        skipped += file_skipped

    return {"imported": imported, "skipped": skipped, "files": len(files)}
