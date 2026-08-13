import json
import re
from datetime import datetime
from typing import Any

from .csv_exporter import CsvExporter
from .store import SQLiteStore, serialize_json


def _extract_salary(salary_desc: str) -> tuple[str, str]:
    salary_range = salary_desc or ""
    salary_type = "12薪"
    if "·" in salary_desc:
        parts = salary_desc.split("·")
        salary_range = parts[0]
        salary_type = parts[1]
    elif "薪" in salary_desc:
        match = re.search(r"(\d+-\d+K)(\d+薪)?", salary_desc)
        if match:
            salary_range = match.group(1)
            salary_type = match.group(2) or "12薪"
    return salary_range, salary_type


def build_job_from_delivery_payload(data: dict[str, Any]) -> dict[str, Any]:
    job_id = data.get("encryptJobId") or data.get("job_id")
    if not job_id:
        raise ValueError("encryptJobId is required")

    city_name = data.get("cityName", "")
    area_district = data.get("areaDistrict", "")
    business_district = data.get("businessDistrict", "")
    area_parts = [
        part for part in [city_name, area_district, business_district] if part
    ]
    job_area = "·".join(area_parts) if area_parts else city_name

    welfare_list = data.get("welfareList")
    job_welfare = (
        ",".join(welfare_list)
        if isinstance(welfare_list, list)
        else (welfare_list or "")
    )

    salary_desc = data.get("salaryDesc", "")
    salary_range, salary_type = _extract_salary(salary_desc)

    skills = data.get("skills")
    job_tag_list = ",".join(skills) if isinstance(skills, list) else (skills or "")

    card = data.get("card") or {}
    status_info = data.get("status") or {}
    deliver_status = status_info.get("status", "pending")
    filter_reason = status_info.get("msg", "")
    filter_detail = status_info.get("detail", "")
    if filter_detail == filter_reason:
        filter_detail = ""

    return {
        "job_id": str(job_id),
        "main_category": data.get("main_category", "产品"),
        "sub_category": data.get("sub_category", "产品经理"),
        "job_name": data.get("jobName", ""),
        "job_area": job_area,
        "job_company": data.get("brandName", ""),
        "job_industry": data.get("brandIndustry", ""),
        "job_finance": data.get("brandStageName", ""),
        "job_scale": data.get("brandScaleName", ""),
        "job_welfare": job_welfare,
        "salary_range": salary_range,
        "salary_type": salary_type,
        "job_experience": data.get("jobExperience", ""),
        "job_education": data.get("degreeName", ""),
        "job_tag_list": job_tag_list,
        "search_keyword": data.get("search_keyword", ""),
        "post_description": card.get("postDescription", ""),
        "deliver_status": deliver_status,
        "filter_reason": filter_reason,
        "filter_detail": filter_detail,
        "address_detail": card.get("address", ""),
        "boss_name": card.get("bossName", ""),
        "boss_title": card.get("bossTitle", ""),
        "boss_active": card.get("activeTimeDesc", ""),
        "create_time": datetime.now().strftime("%Y/%m/%d"),
    }


def record_delivery(
    store: SQLiteStore,
    data: dict[str, Any],
    csv_exporter: CsvExporter | None = None,
) -> dict[str, Any]:
    job = build_job_from_delivery_payload(data)
    store.upsert_job(job, source="delivery")
    store.insert_delivery_event(
        job_id=job["job_id"],
        deliver_status=job["deliver_status"],
        filter_reason=job["filter_reason"],
        filter_detail=job["filter_detail"],
        raw_json=serialize_json(data),
    )
    (csv_exporter or CsvExporter()).export_job(job)
    return job
