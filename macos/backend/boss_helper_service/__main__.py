from __future__ import annotations

import argparse
import signal
import sys
from pathlib import Path

from .config import DEFAULT_HOST, DEFAULT_PORT, default_data_dir
from .crawler import CrawlerManager
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
    args = parser.parse_args(argv)

    data_dir = Path(args.data_dir).expanduser() if args.data_dir else default_data_dir()
    store = SQLiteStore(data_dir)
    crawler = CrawlerManager(store)

    try:
        server = create_server(store, crawler, args.host, args.port)
    except OSError as exc:
        print(f"无法监听 {args.host}:{args.port}: {exc}", file=sys.stderr)
        return 1

    def shutdown(_signum: int, _frame: object) -> None:
        crawler.stop()
        server.shutdown()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    print(
        f"BossHelper backend listening on http://{args.host}:{args.port} "
        f"(data: {data_dir})",
        flush=True,
    )
    try:
        server.serve_forever()
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
