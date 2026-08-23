from __future__ import annotations

import fcntl
import os
import sys
from pathlib import Path

_FILE_HANDLE: object | None = None


def setup_logging(data_dir: Path) -> None:
    """Write the authoritative log to data-dir/backend.log, while keeping
    stdout/stderr output non-blocking so a full or closed pipe can never
    stall a request thread."""
    global _FILE_HANDLE
    try:
        _FILE_HANDLE = open(Path(data_dir) / "backend.log", "a", encoding="utf-8")
    except OSError:
        _FILE_HANDLE = None

    for stream in (sys.stdout, sys.stderr):
        try:
            fd = stream.fileno()
            flags = fcntl.fcntl(fd, fcntl.F_GETFL)
            fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
        except (OSError, ValueError, AttributeError):
            pass


def log(message: str) -> None:
    line = f"{message}\n"
    if _FILE_HANDLE is not None:
        try:
            _FILE_HANDLE.write(line)
            _FILE_HANDLE.flush()
        except OSError:
            pass
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.write(line)
            stream.flush()
        except (BrokenPipeError, BlockingIOError, OSError):
            pass
