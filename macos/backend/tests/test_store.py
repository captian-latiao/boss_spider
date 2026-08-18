import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

from boss_helper_service.store import SQLiteStore, compute_speed_stats


class StoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.store = SQLiteStore(Path(self.tmp.name))

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def test_upsert_job_deduplicates_and_merges_non_empty_values(self) -> None:
        first = {
            "job_id": "job-1",
            "job_name": "产品经理",
            "salary_range": "15-25K",
            "deliver_status": "success",
            "source": "delivery",
        }
        second = {
            "job_id": "job-1",
            "job_name": "",
            "salary_range": "",
            "deliver_status": "warning",
            "source": "delivery",
        }

        self.store.upsert_job(first, source="delivery")
        self.store.upsert_job(second, source="delivery")

        self.assertEqual(self.store.get_all_job_ids(), {"job-1"})
        with self.store._connect() as conn:
            row = conn.execute(
                "SELECT job_name, salary_range, deliver_status, source "
                "FROM jobs WHERE job_id = ?",
                ("job-1",),
            ).fetchone()
        self.assertEqual(row["job_name"], "产品经理")
        self.assertEqual(row["salary_range"], "15-25K")
        self.assertEqual(row["deliver_status"], "warning")
        self.assertEqual(row["source"], "delivery")

    def test_today_metrics_classify_statuses(self) -> None:
        for status in ["success", "danger", "warning", "success"]:
            self.store.insert_delivery_event(
                job_id=f"job-{status}",
                deliver_status=status,
                filter_reason="test",
                raw_json="{}",
            )

        metrics = self.store.get_today_metrics()
        self.assertEqual(metrics["total"], 4)
        self.assertEqual(metrics["success"], 2)
        self.assertEqual(metrics["danger"], 1)
        self.assertEqual(metrics["warning"], 1)
        self.assertIsNone(metrics["delivery_limit"])

    def test_speed_stats_single_event_all_zero(self) -> None:
        self.store.insert_delivery_event(
            job_id="job-1",
            deliver_status="success",
            event_time="2026-08-19T09:00:00",
        )
        metrics = self.store.get_today_metrics(today="2026-08-19")
        self.assertEqual(metrics["total"], 1)
        self.assertEqual(metrics["active_seconds"], 0)
        self.assertEqual(metrics["pause_count"], 0)
        self.assertEqual(metrics["pause_seconds"], 0)
        self.assertEqual(metrics["speed_per_hour"], 0)

    def test_speed_stats_within_threshold(self) -> None:
        self.store.insert_delivery_event(
            job_id="job-1",
            deliver_status="success",
            event_time="2026-08-19T09:00:00",
        )
        self.store.insert_delivery_event(
            job_id="job-2",
            deliver_status="success",
            event_time="2026-08-19T09:03:00",
        )
        metrics = self.store.get_today_metrics(today="2026-08-19")
        self.assertEqual(metrics["total"], 2)
        self.assertEqual(metrics["active_seconds"], 180)
        self.assertEqual(metrics["pause_count"], 0)
        self.assertEqual(metrics["pause_seconds"], 0)
        self.assertAlmostEqual(metrics["speed_per_hour"], 40.0)

    def test_speed_stats_pause_excluded(self) -> None:
        self.store.insert_delivery_event(
            job_id="job-1",
            deliver_status="success",
            event_time="2026-08-19T09:00:00",
        )
        self.store.insert_delivery_event(
            job_id="job-2",
            deliver_status="success",
            event_time="2026-08-19T09:10:00",
        )
        metrics = self.store.get_today_metrics(today="2026-08-19")
        self.assertEqual(metrics["total"], 2)
        self.assertEqual(metrics["active_seconds"], 0)
        self.assertEqual(metrics["pause_count"], 1)
        self.assertEqual(metrics["pause_seconds"], 600)
        self.assertEqual(metrics["speed_per_hour"], 0)

    def test_speed_stats_mixed_gaps(self) -> None:
        for time in [
            "2026-08-19T09:00:00",
            "2026-08-19T09:03:00",
            "2026-08-19T09:20:00",
            "2026-08-19T09:22:00",
        ]:
            self.store.insert_delivery_event(
                job_id=f"job-{time}",
                deliver_status="success",
                event_time=time,
            )
        metrics = self.store.get_today_metrics(today="2026-08-19")
        self.assertEqual(metrics["total"], 4)
        self.assertEqual(metrics["active_seconds"], 300)
        self.assertEqual(metrics["pause_count"], 1)
        self.assertEqual(metrics["pause_seconds"], 1020)
        self.assertAlmostEqual(metrics["speed_per_hour"], 48.0)

    def test_compute_speed_stats_unparseable_ignored(self) -> None:
        stats = compute_speed_stats(
            ["not-a-date", "2026-08-19T09:00:00", "2026-08-19T09:02:00"]
        )
        self.assertEqual(stats["active_seconds"], 120)
        self.assertEqual(stats["pause_count"], 0)

    def test_daily_speed_series_fills_zero_days(self) -> None:
        now = datetime.now()
        day_a = (now - timedelta(days=2)).strftime("%Y-%m-%d")
        day_b = now.strftime("%Y-%m-%d")
        self.store.insert_delivery_event(
            job_id="job-1",
            deliver_status="success",
            event_time=f"{day_a}T09:00:00",
        )
        self.store.insert_delivery_event(
            job_id="job-2",
            deliver_status="success",
            event_time=f"{day_a}T09:02:00",
        )
        self.store.insert_delivery_event(
            job_id="job-3",
            deliver_status="success",
            event_time=f"{day_b}T10:00:00",
        )

        series = self.store.get_daily_speed(days=7)
        self.assertEqual(len(series), 7)
        self.assertEqual([item["date"] for item in series], sorted(item["date"] for item in series))
        self.assertEqual(series[-1]["date"], day_b)

        day_a_item = next(item for item in series if item["date"] == day_a)
        self.assertEqual(day_a_item["total"], 2)
        self.assertEqual(day_a_item["active_seconds"], 120)

        today_item = series[-1]
        self.assertEqual(today_item["total"], 1)
        self.assertEqual(today_item["active_seconds"], 0)

    def test_crawl_status_and_log_tail(self) -> None:
        run_id = self.store.create_crawl_run()
        self.store.add_crawl_event(run_id, "info", "first")
        self.store.add_crawl_event(run_id, "info", "second")
        self.store.update_crawl_run(
            run_id,
            state="running",
            current_keyword="安全",
            current_page=2,
            scraped_count=3,
        )

        status = self.store.get_latest_crawl_status()
        self.assertEqual(status["run_id"], run_id)
        self.assertEqual(status["state"], "running")
        self.assertEqual(status["current_keyword"], "安全")
        self.assertEqual(status["current_page"], 2)
        self.assertEqual(status["scraped_count"], 3)
        self.assertEqual(
            [item["message"] for item in status["log_tail"]],
            ["first", "second"],
        )

    def test_app_config_save_and_delivery_limit(self) -> None:
        result = self.store.save_config(
            {
                "deliveryLimit": {"value": 140},
                "apiKey": "secret-key",
                "nested": {"token": "secret-token", "jobTitle": "产品"},
            },
            config_type="formData",
        )

        self.assertEqual(result["delivery_limit"], 140)
        metrics = self.store.get_today_metrics()
        self.assertEqual(metrics["delivery_limit"], 140)

        latest = self.store.get_latest_config()
        self.assertIsNotNone(latest)
        self.assertEqual(latest["redacted_payload"]["apiKey"], "***")
        self.assertEqual(
            latest["redacted_payload"]["nested"]["token"],
            "***",
        )
        self.assertEqual(
            latest["redacted_payload"]["nested"]["jobTitle"],
            "产品",
        )

    def test_app_config_upsert(self) -> None:
        self.store.save_config({"deliveryLimit": {"value": 100}})
        self.store.save_config({"deliveryLimit": {"value": 150}})

        latest = self.store.get_latest_config()
        self.assertEqual(latest["delivery_limit"], 150)


if __name__ == "__main__":
    unittest.main()
