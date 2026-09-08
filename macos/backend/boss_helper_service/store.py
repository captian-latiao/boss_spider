from __future__ import annotations

import json
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Iterable

from .config import ensure_data_dir


JOB_COLUMNS = [
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
    "job_education",
    "job_tag_list",
    "search_keyword",
    "post_description",
    "deliver_status",
    "filter_reason",
    "filter_detail",
    "ai_score",
    "ai_reason",
    "longitude",
    "latitude",
    "address_detail",
    "boss_name",
    "boss_title",
    "boss_active",
    "create_time",
    "source",
    "ingested_at",
]


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _now_minus(minutes: int) -> str:
    return (datetime.now() - timedelta(minutes=minutes)).isoformat(timespec="seconds")


PAUSE_THRESHOLD_SECONDS = 300


def compute_speed_stats(
    event_times: Iterable[str],
    success_times: Iterable[str] | None = None,
) -> dict[str, Any]:
    """Pause-aware delivery speed stats from ISO event timestamps.

    Gaps between consecutive events that exceed PAUSE_THRESHOLD_SECONDS are
    treated as pauses: the whole gap is excluded from active time. Speed is
    total deliveries divided by active time in hours. When success_times is
    provided, success_per_hour is the successful-delivery count divided by
    the same active time.
    """
    parsed: list[datetime] = []
    for raw in event_times:
        try:
            parsed.append(datetime.fromisoformat(raw))
        except ValueError:
            continue

    parsed_success: list[datetime] = []
    for raw in success_times or ():
        try:
            parsed_success.append(datetime.fromisoformat(raw))
        except ValueError:
            continue

    if len(parsed) < 2:
        return {
            "active_seconds": 0,
            "pause_count": 0,
            "pause_seconds": 0,
            "speed_per_hour": 0,
            "success_per_hour": 0,
        }

    parsed.sort()
    active_seconds = 0
    pause_count = 0
    pause_seconds = 0
    for prev, curr in zip(parsed, parsed[1:]):
        gap = max(0, int((curr - prev).total_seconds()))
        if gap > PAUSE_THRESHOLD_SECONDS:
            pause_count += 1
            pause_seconds += gap
        else:
            active_seconds += gap

    speed_per_hour = 0
    success_per_hour = 0
    if active_seconds > 0:
        active_hours = active_seconds / 3600
        speed_per_hour = len(parsed) / active_hours
        success_per_hour = len(parsed_success) / active_hours

    return {
        "active_seconds": active_seconds,
        "pause_count": pause_count,
        "pause_seconds": pause_seconds,
        "speed_per_hour": round(speed_per_hour, 2),
        "success_per_hour": round(success_per_hour, 2),
    }


class SQLiteStore:
    def __init__(self, data_dir: str | Path):
        self.data_dir = Path(ensure_data_dir(data_dir))
        self.db_path = self.data_dir / "boss_helper.db"
        self._lock = threading.RLock()
        self._conn = self._connect()
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA foreign_keys=ON")
        self.init_schema()

    def _connect(self) -> sqlite3.Connection:
        # All access is serialized by self._lock, so a single shared connection
        # is safe to use from worker threads via check_same_thread=False.
        conn = sqlite3.connect(self.db_path, timeout=15, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        return conn

    @contextmanager
    def _connection(self):
        # Reuse the shared connection; callers must hold self._lock.
        with self._conn:
            yield self._conn

    def init_schema(self) -> None:
        jobs_columns = ", ".join(
            [
                f"{column} TEXT"
                for column in JOB_COLUMNS
                if column != "job_id"
            ]
        )
        with self._lock, self._connection() as conn:
            conn.execute(
                f"""
                CREATE TABLE IF NOT EXISTS jobs (
                    job_id TEXT PRIMARY KEY,
                    {jobs_columns}
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS delivery_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    job_id TEXT NOT NULL,
                    deliver_status TEXT NOT NULL,
                    filter_reason TEXT,
                    filter_detail TEXT,
                    event_time TEXT NOT NULL,
                    raw_json TEXT
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_delivery_events_time "
                "ON delivery_events(event_time)"
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS crawl_runs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    state TEXT NOT NULL,
                    started_at TEXT NOT NULL,
                    finished_at TEXT,
                    current_keyword TEXT,
                    current_page INTEGER DEFAULT 0,
                    scraped_count INTEGER DEFAULT 0,
                    error_count INTEGER DEFAULT 0,
                    last_message TEXT
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS crawl_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id INTEGER NOT NULL,
                    event_time TEXT NOT NULL,
                    level TEXT NOT NULL,
                    message TEXT NOT NULL
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_crawl_events_run "
                "ON crawl_events(run_id, id)"
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS app_config (
                    config_type TEXT PRIMARY KEY,
                    payload_json TEXT NOT NULL,
                    delivery_limit INTEGER NOT NULL DEFAULT 120,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
                """
            )

    def upsert_job(self, job: dict[str, Any], source: str) -> str | None:
        job_id = str(job.get("job_id") or "").strip()
        if not job_id:
            return None

        values = {
            column: job.get(column, "")
            for column in JOB_COLUMNS
            if column != "job_id"
        }
        values["source"] = source
        values["ingested_at"] = _now()

        insert_columns = ["job_id", *values.keys()]
        placeholders = ", ".join(["?" for _ in insert_columns])
        update_assignments = []
        for column in values:
            if column in {"source", "ingested_at"}:
                update_assignments.append(f"{column} = excluded.{column}")
            else:
                update_assignments.append(
                    f"{column} = COALESCE(NULLIF(excluded.{column}, ''), jobs.{column})"
                )

        sql = (
            f"INSERT INTO jobs ({', '.join(insert_columns)}) "
            f"VALUES ({placeholders}) "
            f"ON CONFLICT(job_id) DO UPDATE SET {', '.join(update_assignments)}"
        )
        args = [job_id, *[values[column] for column in values]]
        with self._lock, self._connection() as conn:
            conn.execute(sql, args)
        return job_id

    def insert_delivery_event(
        self,
        job_id: str,
        deliver_status: str,
        filter_reason: str = "",
        filter_detail: str = "",
        raw_json: str | None = None,
        event_time: str | None = None,
    ) -> None:
        with self._lock, self._connection() as conn:
            status = deliver_status or "pending"
            reason = filter_reason or ""
            detail = filter_detail or ""
            ts = event_time or _now()
            # 重试队列可能重推同一事件：30 分钟内相同 job/状态/原因视为重复，跳过
            duplicate = conn.execute(
                """
                SELECT 1 FROM delivery_events
                WHERE job_id = ? AND deliver_status = ?
                  AND filter_reason = ? AND filter_detail = ?
                  AND event_time >= ?
                LIMIT 1
                """,
                (job_id, status, reason, detail, _now_minus(30)),
            ).fetchone()
            if duplicate:
                return
            conn.execute(
                """
                INSERT INTO delivery_events (
                    job_id, deliver_status, filter_reason, filter_detail,
                    event_time, raw_json
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    job_id,
                    status,
                    reason,
                    detail,
                    ts,
                    raw_json or "",
                ),
            )

    def get_today_metrics(self, today: str | None = None) -> dict[str, Any]:
        date_key = today or datetime.now().strftime("%Y-%m-%d")
        with self._lock, self._connection() as conn:
            row = conn.execute(
                """
                SELECT
                    COUNT(*) AS total,
                    SUM(CASE WHEN deliver_status = 'success' THEN 1 ELSE 0 END) AS success,
                    SUM(CASE WHEN deliver_status = 'danger' THEN 1 ELSE 0 END) AS danger,
                    SUM(CASE WHEN deliver_status = 'warning' THEN 1 ELSE 0 END) AS warning,
                    MIN(event_time) AS first_event_at,
                    MAX(event_time) AS last_event_at
                FROM delivery_events
                WHERE substr(event_time, 1, 10) = ?
                """,
                (date_key,),
            ).fetchone()

            config_row = conn.execute(
                "SELECT delivery_limit FROM app_config "
                "ORDER BY updated_at DESC LIMIT 1"
            ).fetchone()

            event_rows = conn.execute(
                "SELECT event_time, deliver_status FROM delivery_events "
                "WHERE substr(event_time, 1, 10) = ?",
                (date_key,),
            ).fetchall()

        first = row["first_event_at"] if row else None
        last = row["last_event_at"] if row else None
        elapsed_seconds = 0
        if first and last and first != last:
            try:
                first_dt = datetime.fromisoformat(first)
                last_dt = datetime.fromisoformat(last)
                elapsed_seconds = max(0, int((last_dt - first_dt).total_seconds()))
            except ValueError:
                elapsed_seconds = 0

        all_times = [row["event_time"] for row in event_rows]
        success_times = [
            row["event_time"]
            for row in event_rows
            if row["deliver_status"] == "success"
        ]
        speed_stats = compute_speed_stats(all_times, success_times)

        return {
            "date": date_key,
            "total": int(row["total"] or 0) if row else 0,
            "success": int(row["success"] or 0) if row else 0,
            "danger": int(row["danger"] or 0) if row else 0,
            "warning": int(row["warning"] or 0) if row else 0,
            "elapsed_seconds": elapsed_seconds,
            "first_event_at": first,
            "last_event_at": last,
            "delivery_limit": int(config_row["delivery_limit"])
            if config_row
            else None,
            **speed_stats,
        }

    def get_daily_speed(self, days: int = 7) -> list[dict[str, Any]]:
        days = max(1, min(days, 90))
        now = datetime.now()
        start = (now - timedelta(days=days - 1)).strftime("%Y-%m-%d")

        with self._lock, self._connection() as conn:
            rows = conn.execute(
                """
                SELECT event_time, deliver_status FROM delivery_events
                WHERE event_time >= ?
                ORDER BY event_time
                """,
                (start,),
            ).fetchall()

        by_date: dict[str, list[str]] = {}
        success_by_date: dict[str, list[str]] = {}
        for row in rows:
            date_key = row["event_time"][:10]
            if date_key >= start:
                by_date.setdefault(date_key, []).append(row["event_time"])
                if row["deliver_status"] == "success":
                    success_by_date.setdefault(date_key, []).append(
                        row["event_time"]
                    )

        result: list[dict[str, Any]] = []
        for offset in range(days):
            date_key = (now - timedelta(days=days - 1 - offset)).strftime(
                "%Y-%m-%d"
            )
            stats = compute_speed_stats(
                by_date.get(date_key, []),
                success_by_date.get(date_key, []),
            )
            result.append(
                {
                    "date": date_key,
                    "total": len(by_date.get(date_key, [])),
                    "active_seconds": stats["active_seconds"],
                    "pause_count": stats["pause_count"],
                    "speed_per_hour": stats["speed_per_hour"],
                    "success_per_hour": stats["success_per_hour"],
                }
            )
        return result

    def save_config(
        self,
        payload: dict[str, Any],
        config_type: str = "formData",
    ) -> dict[str, Any]:
        delivery_limit_value = payload.get("deliveryLimit")
        if isinstance(delivery_limit_value, dict):
            delivery_limit = int(
                delivery_limit_value.get("value", 120) or 120
            )
        else:
            delivery_limit = 120

        payload_json = serialize_json(payload)
        now = _now()
        with self._lock, self._connection() as conn:
            conn.execute(
                """
                INSERT INTO app_config (
                    config_type, payload_json, delivery_limit,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(config_type) DO UPDATE SET
                    payload_json = excluded.payload_json,
                    delivery_limit = excluded.delivery_limit,
                    updated_at = excluded.updated_at
                """,
                (config_type, payload_json, delivery_limit, now, now),
            )

        return {
            "config_type": config_type,
            "delivery_limit": delivery_limit,
            "updated_at": now,
        }

    def get_latest_config(self) -> dict[str, Any] | None:
        with self._lock, self._connection() as conn:
            row = conn.execute(
                """
                SELECT config_type, payload_json, delivery_limit, updated_at
                FROM app_config
                ORDER BY updated_at DESC
                LIMIT 1
                """
            ).fetchone()

        if row is None:
            return None

        try:
            payload = json.loads(row["payload_json"])
        except json.JSONDecodeError:
            payload = {}

        return {
            "config_type": row["config_type"],
            "delivery_limit": int(row["delivery_limit"] or 120),
            "updated_at": row["updated_at"],
            "redacted_payload": _redact_sensitive(payload),
        }

    def create_crawl_run(self) -> int:
        with self._lock, self._connection() as conn:
            cursor = conn.execute(
                "INSERT INTO crawl_runs (state, started_at) VALUES (?, ?)",
                ("starting", _now()),
            )
            return int(cursor.lastrowid)

    def update_crawl_run(self, run_id: int, **fields: Any) -> None:
        if not fields:
            return
        columns = [key for key in fields if key != "id"]
        assignments = ", ".join(f"{column} = ?" for column in columns)
        args = [fields[column] for column in columns]
        with self._lock, self._connection() as conn:
            conn.execute(
                f"UPDATE crawl_runs SET {assignments} WHERE id = ?",
                [*args, run_id],
            )

    def add_crawl_event(self, run_id: int, level: str, message: str) -> None:
        with self._lock, self._connection() as conn:
            conn.execute(
                """
                INSERT INTO crawl_events (run_id, event_time, level, message)
                VALUES (?, ?, ?, ?)
                """,
                (run_id, _now(), level, message),
            )

    def get_latest_crawl_status(self) -> dict[str, Any]:
        with self._lock, self._connection() as conn:
            run = conn.execute(
                "SELECT * FROM crawl_runs ORDER BY id DESC LIMIT 1"
            ).fetchone()
            if run is None:
                return {
                    "state": "idle",
                    "run_id": None,
                    "current_keyword": "",
                    "current_page": 0,
                    "scraped_count": 0,
                    "error_count": 0,
                    "last_message": "",
                    "started_at": None,
                    "finished_at": None,
                    "log_tail": [],
                }

            logs = conn.execute(
                """
                SELECT level, message FROM crawl_events
                WHERE run_id = ?
                ORDER BY id DESC
                LIMIT 50
                """,
                (run["id"],),
            ).fetchall()

        return {
            "state": run["state"],
            "run_id": int(run["id"]),
            "current_keyword": run["current_keyword"] or "",
            "current_page": int(run["current_page"] or 0),
            "scraped_count": int(run["scraped_count"] or 0),
            "error_count": int(run["error_count"] or 0),
            "last_message": run["last_message"] or "",
            "started_at": run["started_at"],
            "finished_at": run["finished_at"],
            "log_tail": [
                {"level": item["level"], "message": item["message"]}
                for item in reversed(logs)
            ],
        }

    def get_all_job_ids(self) -> set[str]:
        with self._lock, self._connection() as conn:
            rows = conn.execute("SELECT job_id FROM jobs").fetchall()
        return {row["job_id"] for row in rows}

    def get_recent_events(self, limit: int = 50) -> list[dict[str, Any]]:
        with self._lock, self._connection() as conn:
            rows = conn.execute(
                """
                SELECT
                    e.id,
                    e.job_id,
                    e.deliver_status,
                    e.filter_reason,
                    e.filter_detail,
                    e.event_time,
                    COALESCE(j.job_name, '') AS job_name,
                    COALESCE(j.job_company, '') AS job_company,
                    COALESCE(j.job_area, '') AS job_area,
                    COALESCE(j.salary_range, '') AS salary_range,
                    COALESCE(j.boss_name, '') AS boss_name,
                    COALESCE(j.boss_title, '') AS boss_title
                FROM delivery_events e
                LEFT JOIN jobs j ON e.job_id = j.job_id
                ORDER BY e.id DESC
                LIMIT ?
                """,
                (max(1, min(limit, 200)),),
            ).fetchall()
        return [dict(row) for row in rows]

    def get_jobs(
        self,
        limit: int = 100,
        status: str | None = None,
        keyword: str | None = None,
    ) -> list[dict[str, Any]]:
        query = "SELECT * FROM jobs WHERE 1=1"
        params: list[Any] = []
        if status and status != "all":
            if status in {"filter", "warning", "filtered"}:
                query += " AND deliver_status IN ('warning', 'filter', 'filtered')"
            elif status in {"danger", "error", "failed"}:
                query += " AND deliver_status IN ('danger', 'error', 'failed')"
            elif status in {"success", "delivered"}:
                query += " AND deliver_status IN ('success', 'delivered')"
            else:
                query += " AND deliver_status = ?"
                params.append(status)
        if keyword:
            query += (
                " AND (job_name LIKE ? OR job_company LIKE ?"
                " OR post_description LIKE ? OR job_area LIKE ?"
                " OR filter_reason LIKE ? OR filter_detail LIKE ?)"
            )
            kw = f"%{keyword}%"
            params.extend([kw, kw, kw, kw, kw, kw])
        query += " ORDER BY ingested_at DESC LIMIT ?"
        params.append(max(1, min(limit, 500)))

        with self._lock, self._connection() as conn:
            rows = conn.execute(query, params).fetchall()
        return [dict(row) for row in rows]




def serialize_json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False, default=str)


def _redact_sensitive(value: Any) -> Any:
    if isinstance(value, dict):
        redacted = {}
        for key, item in value.items():
            lower_key = str(key).lower()
            if any(
                token in lower_key
                for token in ("key", "token", "secret", "password")
            ):
                redacted[key] = "***"
            else:
                redacted[key] = _redact_sensitive(item)
        return redacted
    if isinstance(value, list):
        return [_redact_sensitive(item) for item in value]
    return value
