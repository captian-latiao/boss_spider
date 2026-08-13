import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse

from . import __version__
from .crawler import CrawlerManager
from .delivery import record_delivery
from .importer import import_paths
from .store import SQLiteStore, serialize_json


class BossHelperHandler(BaseHTTPRequestHandler):
    server_version = "BossHelperBackend/0.1"
    store: SQLiteStore
    crawler: CrawlerManager
    shutdown_callback: Any = None

    def _cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header(
            "Access-Control-Allow-Headers", "Content-Type,Authorization"
        )
        self.send_header(
            "Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS"
        )

    def _send_json(self, status: int, payload: Any) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> Any:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/health":
            self._send_json(
                200,
                {
                    "status": "ok",
                    "version": __version__,
                    "pid": os.getpid(),
                },
            )
        elif path == "/api/metrics/today":
            self._send_json(200, self.store.get_today_metrics())
        elif path == "/api/crawl/status":
            self._send_json(200, self.crawler.full_status())
        elif path == "/api/config/latest":
            config = self.store.get_latest_config()
            if config is None:
                self._send_json(
                    200,
                    {"code": 200, "config": None},
                )
            else:
                self._send_json(200, {"code": 200, "config": config})
        else:
            self._send_json(404, {"code": 404, "message": "Not Found"})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        try:
            if path == "/api/save_job":
                payload = self._read_json()
                job = record_delivery(self.store, payload)
                print(
                    f"[delivery] job_id={job['job_id']} "
                    f"status={job['deliver_status']} "
                    f"company={job.get('job_company', '')} "
                    f"job_name={job.get('job_name', '')}",
                    flush=True,
                )
                self._send_json(
                    200,
                    {
                        "code": 200,
                        "message": "Success",
                        "job_id": job["job_id"],
                    },
                )
            elif path == "/api/crawl/start":
                self._send_json(200, self.crawler.start())
            elif path == "/api/crawl/stop":
                self._send_json(200, self.crawler.stop())
            elif path == "/api/import":
                payload = self._read_json()
                paths = payload.get("paths", [])
                if not isinstance(paths, list) or not paths:
                    self._send_json(
                        400,
                        {"code": 400, "message": "paths 必须是非空数组"},
                    )
                    return
                result = import_paths(self.store, paths)
                self._send_json(200, {"code": 200, **result})
            elif path == "/api/save_config":
                payload = self._read_json()
                config_type = payload.get("config_type", "formData")
                result = self.store.save_config(
                    payload,
                    config_type=str(config_type),
                )
                print(
                    f"[config] config_type={result['config_type']} "
                    f"delivery_limit={result['delivery_limit']}",
                    flush=True,
                )
                self._send_json(200, {"code": 200, **result})
            elif path == "/api/shutdown":
                self._send_json(
                    200,
                    {"code": 200, "message": "Shutting down"},
                )
                self.wfile.flush()
                if self.shutdown_callback is not None:
                    threading.Timer(0.2, self.shutdown_callback).start()
            else:
                self._send_json(404, {"code": 404, "message": "Not Found"})
        except json.JSONDecodeError:
            self._send_json(
                400, {"code": 400, "message": "请求体不是合法 JSON"}
            )
        except ValueError as exc:
            self._send_json(400, {"code": 400, "message": str(exc)})
        except Exception as exc:
            self._send_json(
                500, {"code": 500, "message": f"服务异常: {exc}"}
            )

    def log_message(self, format: str, *args: Any) -> None:
        print(
            f"[backend] {self.address_string()} - {format % args}",
            flush=True,
        )


def create_server(
    store: SQLiteStore,
    crawler: CrawlerManager,
    host: str,
    port: int,
) -> ThreadingHTTPServer:
    handler = type(
        "BoundBossHelperHandler",
        (BossHelperHandler,),
        {"store": store, "crawler": crawler},
    )
    server = ThreadingHTTPServer((host, port), handler)
    server.daemon_threads = True
    handler.shutdown_callback = server.shutdown
    return server
