from __future__ import annotations

import argparse
import os
import signal
import threading
import time
from pathlib import Path

from .config import DEFAULT_HOST, DEFAULT_PORT, default_data_dir, ensure_data_dir
from .crawler import CrawlerManager
from .logging_utils import log, setup_logging
from .server import create_server
from .store import SQLiteStore


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="BossHelper macOS backend")
    parser.add_argument(
        "--data-dir",
        default=None,
        help="本地数据目录，默认 ~/Library/Application Support/BossHelper",
    )
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--parent-pid",
        type=int,
        default=None,
        help="App 进程 PID；父进程退出后本进程自动退出，防止孤儿",
    )
    args = parser.parse_args(argv)

    data_dir = Path(args.data_dir).expanduser() if args.data_dir else default_data_dir()
    setup_logging(data_dir)
    store = SQLiteStore(data_dir)
    crawler = CrawlerManager(store)

    try:
        server = create_server(store, crawler, args.host, args.port)
    except OSError as exc:
        log(f"无法监听 {args.host}:{args.port}: {exc}")
        return 1

    try:
        (ensure_data_dir(data_dir) / "backend.pid").write_text(
            str(os.getpid()), encoding="utf-8"
        )
    except OSError:
        pass

    if args.parent_pid is not None:

        def watch_parent() -> None:
            while True:
                time.sleep(2)
                try:
                    os.kill(args.parent_pid, 0)
                except ProcessLookupError:
                    os._exit(0)
                except OSError:
                    pass

        threading.Thread(target=watch_parent, daemon=True).start()

    def shutdown(_signum: int, _frame: object) -> None:
        threading.Thread(target=_shutdown_async, daemon=True).start()
        threading.Thread(target=force_exit, daemon=True).start()

    def _shutdown_async() -> None:
        crawler.stop()
        server.shutdown()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    def force_exit() -> None:
        time.sleep(2)
        os._exit(0)

    log(
        f"BossHelper backend listening on http://{args.host}:{args.port} "
        f"(data: {data_dir})"
    )
    try:
        server.serve_forever()
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
