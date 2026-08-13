from __future__ import annotations

import os
from pathlib import Path

APP_NAME = "BossHelper"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 5005
DB_FILENAME = "boss_helper.db"


def default_data_dir() -> Path:
    override = os.environ.get("BOSS_HELPER_DATA_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Library" / "Application Support" / APP_NAME


def ensure_data_dir(data_dir: str | os.PathLike[str] | None = None) -> Path:
    path = Path(data_dir).expanduser() if data_dir else default_data_dir()
    path.mkdir(parents=True, exist_ok=True)
    return path


def db_path(data_dir: str | os.PathLike[str] | None = None) -> Path:
    return ensure_data_dir(data_dir) / DB_FILENAME
