import os
import tempfile
import unittest
from pathlib import Path

from boss_helper_service.delivery import record_delivery
from boss_helper_service.store import SQLiteStore


class DeliveryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.old_csv_dir = os.environ.get("BOSS_HELPER_CSV_DIR")
        os.environ["BOSS_HELPER_CSV_DIR"] = str(Path(self.tmp.name) / "csv")
        self.store = SQLiteStore(Path(self.tmp.name))

    def tearDown(self) -> None:
        if self.old_csv_dir is None:
            os.environ.pop("BOSS_HELPER_CSV_DIR", None)
        else:
            os.environ["BOSS_HELPER_CSV_DIR"] = self.old_csv_dir
        self.tmp.cleanup()

    def test_record_delivery_saves_job_and_metric(self) -> None:
        payload = {
            "encryptJobId": "job-1",
            "jobName": "AI 产品经理",
            "brandName": "测试公司",
            "cityName": "杭州",
            "areaDistrict": "西湖区",
            "businessDistrict": "西溪",
            "brandIndustry": "互联网",
            "brandStageName": "A轮",
            "brandScaleName": "100-499人",
            "welfareList": ["五险一金", "双休"],
            "salaryDesc": "20-30K·14薪",
            "jobExperience": "3-5年",
            "skills": ["AI", "B端"],
            "card": {
                "postDescription": "岗位描述",
                "address": "杭州西湖区",
                "activeTimeDesc": "刚刚活跃",
            },
            "status": {"status": "success", "msg": "投递成功", "detail": ""},
        }

        job = record_delivery(self.store, payload)
        self.assertEqual(job["job_id"], "job-1")
        self.assertEqual(job["salary_range"], "20-30K")
        self.assertEqual(job["salary_type"], "14薪")
        self.assertEqual(job["job_area"], "杭州·西湖区·西溪")

        metrics = self.store.get_today_metrics()
        self.assertEqual(metrics["total"], 1)
        self.assertEqual(metrics["success"], 1)
        self.assertEqual(metrics["danger"], 0)

    def test_record_delivery_requires_job_id(self) -> None:
        with self.assertRaises(ValueError):
            record_delivery(self.store, {"jobName": "没有 id"})


if __name__ == "__main__":
    unittest.main()
