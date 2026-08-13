from __future__ import annotations

import re
import threading
import time
from datetime import datetime
from typing import Any

from .store import SQLiteStore


INDEX_URL = "https://www.zhipin.com/hangzhou/?ka=city-sites-101210100"
MAIN_CATEGORY = "产品"
SUB_CATEGORY = "产品经理"
SEARCH_KEYWORDS = ["安全", " "]
MAX_PAGES = 10
LOGIN_WAIT_SECONDS = 30


IDLE = "idle"
STARTING = "starting"
WAITING_LOGIN = "waiting_login"
RUNNING = "running"
STOPPING = "stopping"
STOPPED = "stopped"
ERROR = "error"


def _load_selenium() -> dict[str, Any]:
    from selenium import webdriver
    from selenium.common.exceptions import NoSuchElementException
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.keys import Keys
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.support.ui import WebDriverWait

    return {
        "webdriver": webdriver,
        "NoSuchElementException": NoSuchElementException,
        "By": By,
        "Keys": Keys,
        "EC": EC,
        "WebDriverWait": WebDriverWait,
    }


class CrawlerManager:
    def __init__(self, store: SQLiteStore):
        self.store = store
        self._lock = threading.RLock()
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()
        self._run_id: int | None = None
        self._state = IDLE
        self._current_keyword = ""
        self._current_page = 0
        self._scraped_count = 0
        self._error_count = 0
        self._last_message = ""

    def is_running(self) -> bool:
        return bool(self._thread and self._thread.is_alive())

    def start(self) -> dict[str, Any]:
        with self._lock:
            if self.is_running():
                return {"accepted": False, "message": "爬虫已在运行", **self.status()}

            self._stop_event.clear()
            self._run_id = self.store.create_crawl_run()
            self._state = STARTING
            self._current_keyword = ""
            self._current_page = 0
            self._scraped_count = 0
            self._error_count = 0
            self._last_message = "正在启动"
            self.store.update_crawl_run(self._run_id, state=self._state)
            self._thread = threading.Thread(
                target=self._run,
                name="boss-helper-crawler",
                daemon=True,
            )
            self._thread.start()
            return {"accepted": True, "run_id": self._run_id, **self.status()}

    def stop(self) -> dict[str, Any]:
        with self._lock:
            if not self.is_running():
                return {"accepted": False, "message": "爬虫未运行", **self.status()}
            self._state = STOPPING
            self._stop_event.set()
            self._last_message = "正在停止"
            if self._run_id:
                self.store.update_crawl_run(
                    self._run_id, state=self._state, last_message=self._last_message
                )
            return {"accepted": True, **self.status()}

    def status(self) -> dict[str, Any]:
        with self._lock:
            return {
                "state": self._state,
                "run_id": self._run_id,
                "current_keyword": self._current_keyword,
                "current_page": self._current_page,
                "scraped_count": self._scraped_count,
                "error_count": self._error_count,
                "last_message": self._last_message,
            }

    def full_status(self) -> dict[str, Any]:
        stored = self.store.get_latest_crawl_status()
        live = self.status()
        if live["run_id"] is not None and live["run_id"] == stored.get("run_id"):
            stored.update(live)
        return stored

    def _set_state(self, state: str, message: str | None = None) -> None:
        with self._lock:
            self._state = state
            if message is not None:
                self._last_message = message
            if self._run_id:
                self.store.update_crawl_run(
                    self._run_id,
                    state=self._state,
                    last_message=self._last_message,
                )

    def _log(self, level: str, message: str) -> None:
        if self._run_id is None:
            return
        self.store.add_crawl_event(self._run_id, level, message)
        with self._lock:
            self._last_message = message
            if self._run_id:
                self.store.update_crawl_run(
                    self._run_id, last_message=self._last_message
                )

    def _update_progress(self) -> None:
        if self._run_id:
            self.store.update_crawl_run(
                self._run_id,
                state=self._state,
                current_keyword=self._current_keyword,
                current_page=self._current_page,
                scraped_count=self._scraped_count,
                error_count=self._error_count,
                last_message=self._last_message,
            )

    def _run(self) -> None:
        browser = None
        try:
            sel = _load_selenium()
            self._set_state(WAITING_LOGIN, "正在启动 Chrome")
            self._log("info", "正在启动固定 Chrome 浏览器")

            options = sel["webdriver"].ChromeOptions()
            options.add_experimental_option("excludeSwitches", ["enable-automation"])
            options.add_experimental_option("useAutomationExtension", False)
            options.add_argument("--disable-blink-features=AutomationControlled")

            browser = sel["webdriver"].Chrome(options=options)
            try:
                browser.execute_cdp_cmd(
                    "Page.addScriptToEvaluateOnNewDocument",
                    {
                        "source": """
                        Object.defineProperty(navigator, 'webdriver', {
                          get: () => undefined
                        })
                        """
                    },
                )
            except Exception as exc:  # pragma: no cover - driver-specific
                self._log("warning", f"隐藏 webdriver 特征失败: {exc}")

            browser.get(INDEX_URL)
            self._set_state(
                WAITING_LOGIN,
                f"请在 {LOGIN_WAIT_SECONDS} 秒内完成登录或验证码验证",
            )
            self._log("info", "等待手动登录/验证码，完成后自动继续")
            deadline = time.monotonic() + LOGIN_WAIT_SECONDS
            while time.monotonic() < deadline:
                if self._stop_event.is_set():
                    return
                time.sleep(1)

            self._close_login_dialog(browser, sel)
            self._set_state(RUNNING, "正在选择岗位分类")
            selected = self._select_category(
                browser, sel, MAIN_CATEGORY, SUB_CATEGORY
            )
            if selected is None:
                self._set_state(ERROR, "岗位分类选择失败")
                self._log("error", "岗位分类选择失败")
                return

            time.sleep(10)

            for search_keyword in SEARCH_KEYWORDS:
                if self._stop_event.is_set():
                    break
                with self._lock:
                    self._current_keyword = search_keyword
                    self._current_page = 0
                self._log("info", f"开始搜索关键字: {search_keyword}")
                self._search_jobs(browser, sel, search_keyword)
                time.sleep(10)

                page_count = 0
                while page_count < MAX_PAGES:
                    if self._stop_event.is_set():
                        break

                    self._close_login_dialog(browser, sel)
                    self._scroll_page(browser)
                    cards = browser.find_elements(
                        sel["By"].CLASS_NAME, "job-card-wrapper"
                    )

                    for card in cards:
                        if self._stop_event.is_set():
                            break
                        try:
                            job = self._parse_job(
                                card,
                                sel,
                                MAIN_CATEGORY,
                                SUB_CATEGORY,
                                search_keyword,
                            )
                            if job and self.store.upsert_job(
                                job, source="crawler"
                            ):
                                with self._lock:
                                    self._scraped_count += 1
                        except Exception as exc:
                            with self._lock:
                                self._error_count += 1
                            self._log("warning", f"解析职位失败: {exc}")

                    page_count += 1
                    with self._lock:
                        self._current_page = page_count
                    self._update_progress()

                    if self._stop_event.is_set():
                        break
                    if not self._next_page(browser, sel):
                        self._log("info", "当前关键字已无下一页")
                        break
                    self._log("info", f"已进入第 {page_count + 1} 页")

            if self._stop_event.is_set():
                self._set_state(STOPPED, "已停止")
            else:
                self._set_state(STOPPED, "爬取完成")
                self._log("info", "爬取完成")
        except Exception as exc:
            with self._lock:
                self._error_count += 1
            self._log("error", f"爬虫异常: {exc}")
            self._set_state(ERROR, f"爬虫异常: {exc}")
        finally:
            if browser is not None:
                try:
                    browser.quit()
                except Exception:
                    pass
            if self._run_id:
                self.store.update_crawl_run(
                    self._run_id,
                    state=self._state,
                    finished_at=datetime.now().isoformat(timespec="seconds"),
                    scraped_count=self._scraped_count,
                    error_count=self._error_count,
                    last_message=self._last_message,
                )

    def _close_login_dialog(self, browser: Any, sel: dict[str, Any]) -> None:
        try:
            browser.find_element(sel["By"].CLASS_NAME, "boss-login-close").click()
            self._log("info", "已关闭登录弹窗")
        except sel["NoSuchElementException"]:
            pass
        except Exception as exc:
            self._log("warning", f"关闭登录弹窗失败: {exc}")

    def _select_category(
        self,
        browser: Any,
        sel: dict[str, Any],
        main_category: str,
        sub_category: str,
    ) -> tuple[str, str] | None:
        try:
            browser.find_element(
                sel["By"].XPATH, f'//b[text()="{main_category}"]'
            ).click()
            main = browser.find_element(
                sel["By"].XPATH,
                f'//p[@class="menu-article" and text()="{main_category}"]',
            )
            time.sleep(3)
            sub = main.find_element(
                sel["By"].XPATH,
                f'./following-sibling::ul//a[text()="{sub_category}"]',
            )
            sub.click()
            time.sleep(5)
            self._log("info", f"已选择 {main_category}-{sub_category}")
            return main_category, sub_category
        except Exception as exc:
            self._log("error", f"选择分类失败: {exc}")
            return None

    def _search_jobs(
        self, browser: Any, sel: dict[str, Any], keyword: str
    ) -> None:
        search_input = sel["WebDriverWait"](browser, 10).until(
            sel["EC"].presence_of_element_located(
                (sel["By"].XPATH, '//input[@placeholder="搜索职位、公司"]')
            )
        )
        search_input.clear()
        time.sleep(5)
        search_input.send_keys(keyword)
        time.sleep(5)
        search_input.send_keys(sel["Keys"].RETURN)
        time.sleep(10)

    def _scroll_page(self, browser: Any) -> None:
        scroll_height = max(
            0, browser.execute_script("return document.body.scrollHeight") - 1500
        )
        for index in range(5):
            browser.execute_script(
                f"window.scrollTo(0, {scroll_height * index / 5 - 300});"
            )
            time.sleep(1)
        time.sleep(5)

    def _next_page(self, browser: Any, sel: dict[str, Any]) -> bool:
        try:
            button = sel["WebDriverWait"](browser, 10).until(
                sel["EC"].element_to_be_clickable(
                    (sel["By"].CLASS_NAME, "ui-icon-arrow-right")
                )
            )
            parent_class = button.find_element(
                sel["By"].XPATH, ".."
            ).get_attribute("class")
            if "disabled" in (parent_class or ""):
                return False
            button.click()
            time.sleep(5)
            sel["WebDriverWait"](browser, 10).until(
                sel["EC"].presence_of_all_elements_located(
                    (sel["By"].CLASS_NAME, "job-card-wrapper")
                )
            )
            return True
        except Exception as exc:
            self._log("warning", f"翻页失败: {exc}")
            return False

    def _parse_job(
        self,
        job: Any,
        sel: dict[str, Any],
        main_category: str,
        sub_category: str,
        search_keyword: str,
    ) -> dict[str, Any] | None:
        By = sel["By"]

        def text(class_name: str, default: str = "") -> str:
            try:
                return job.find_element(By.CLASS_NAME, class_name).text.strip()
            except Exception:
                return default

        company_tags = [
            element.text.strip()
            for element in job.find_elements(
                By.CSS_SELECTOR, ".company-tag-list li"
            )
        ]
        basic_tags = [
            element.text.strip()
            for element in job.find_elements(
                By.CSS_SELECTOR, ".job-info .tag-list li"
            )
        ]
        skill_tags = [
            element.text.strip()
            for element in job.find_elements(
                By.CSS_SELECTOR, ".job-card-footer .tag-list li"
            )
        ]

        try:
            welfare = job.find_element(By.CLASS_NAME, "info-desc").text.strip()
        except Exception:
            welfare = "无"

        salary_element = text("salary")
        salary_range = salary_element
        salary_type = "12薪"
        match = re.search(r"(\d+-\d+K)(?:[·\s]?)?(\d+薪)?", salary_element)
        if match:
            salary_range = match.group(1)
            salary_type = match.group(2) or "12薪"

        return {
            "job_id": job.get_attribute("data-jobid")
            or job.get_attribute("data-encrypt-jobid")
            or "",
            "main_category": main_category,
            "sub_category": sub_category,
            "job_name": text("job-name"),
            "job_area": text("job-area"),
            "job_company": text("company-name"),
            "job_industry": company_tags[0] if len(company_tags) > 0 else "",
            "job_finance": company_tags[1] if len(company_tags) > 1 else "",
            "job_scale": company_tags[2] if len(company_tags) > 2 else "",
            "job_welfare": welfare,
            "salary_range": salary_range,
            "salary_type": salary_type,
            "job_experience": basic_tags[0] if len(basic_tags) > 0 else "",
            "job_education": basic_tags[1] if len(basic_tags) > 1 else "",
            "job_tag_list": ",".join(skill_tags),
            "search_keyword": search_keyword,
            "post_description": "",
            "deliver_status": "crawled",
            "filter_reason": "",
            "filter_detail": "",
            "create_time": datetime.now().strftime("%Y-%m-%d"),
        }
