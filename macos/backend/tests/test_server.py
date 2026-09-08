import csv
import json
import os
import tempfile
import threading
import time
import unittest
import urllib.request
from datetime import date
from pathlib import Path

from boss_helper_service.crawler import CrawlerManager
from boss_helper_service.server import create_server
from boss_helper_service.store import SQLiteStore


class ServerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.old_csv_dir = os.environ.get("BOSS_HELPER_CSV_DIR")
        os.environ["BOSS_HELPER_CSV_DIR"] = str(Path(self.tmp.name) / "csv")
        self.store = SQLiteStore(Path(self.tmp.name))
        self.crawler = CrawlerManager(self.store)
        self.server = create_server(self.store, self.crawler, "127.0.0.1", 0)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        if self.old_csv_dir is None:
            os.environ.pop("BOSS_HELPER_CSV_DIR", None)
        else:
            os.environ["BOSS_HELPER_CSV_DIR"] = self.old_csv_dir
        self.tmp.cleanup()

    def request_json(self, method: str, path: str, payload=None):
        data = None
        headers = {}
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(
            f"http://127.0.0.1:{self.port}{path}",
            data=data,
            headers=headers,
            method=method,
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status, json.loads(response.read().decode("utf-8"))

    def test_health_and_save_job_metrics(self) -> None:
        status, health = self.request_json("GET", "/health")
        self.assertEqual(status, 200)
        self.assertEqual(health["status"], "ok")

        status, saved = self.request_json(
            "POST",
            "/api/save_job",
            {
                "encryptJobId": "server-job",
                "jobName": "产品经理",
                "brandName": "公司",
                "salaryDesc": "15-25K",
                "status": {"status": "success", "msg": "投递成功"},
            },
        )
        self.assertEqual(status, 200)
        self.assertEqual(saved["job_id"], "server-job")

        status, metrics = self.request_json("GET", "/api/metrics/today")
        self.assertEqual(status, 200)
        self.assertEqual(metrics["total"], 1)
        self.assertEqual(metrics["success"], 1)
        self.assertIn("active_seconds", metrics)
        self.assertIn("pause_count", metrics)
        self.assertIn("speed_per_hour", metrics)
        self.assertIn("success_per_hour", metrics)

        status, series = self.request_json("GET", "/api/metrics/speed?days=3")
        self.assertEqual(status, 200)
        self.assertIsInstance(series, list)
        self.assertEqual(len(series), 3)
        self.assertIn("date", series[0])
        self.assertIn("total", series[0])
        self.assertIn("active_seconds", series[0])
        self.assertIn("pause_count", series[0])
        self.assertIn("speed_per_hour", series[0])
        self.assertIn("success_per_hour", series[0])

        status, config = self.request_json(
            "POST",
            "/api/save_config",
            {"deliveryLimit": {"value": 135}},
        )
        self.assertEqual(status, 200)
        self.assertEqual(config["delivery_limit"], 135)

        status, latest = self.request_json("GET", "/api/config/latest")
        self.assertEqual(status, 200)
        self.assertEqual(latest["config"]["delivery_limit"], 135)

        today = date.today()
        csv_path = (
            Path(self.tmp.name)
            / "csv"
            / today.strftime("%Y-%m")
            / f"week_{today.isocalendar()[1]:02d}.csv"
        )
        # CSV 导出在后台线程执行，轮询等待其落盘
        for _ in range(40):
            if csv_path.exists():
                break
            time.sleep(0.05)
        self.assertTrue(csv_path.exists())
        with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["job_id"], "server-job")


if __name__ == "__main__":
    unittest.main()
