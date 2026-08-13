#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
BUILD_DIR="$ROOT_DIR/build/backend"
PYTHON_BIN="${PYTHON_BIN:-python3}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

"$PYTHON_BIN" -m venv "$BUILD_DIR/venv"
"$BUILD_DIR/venv/bin/python" -m pip install --upgrade pip
"$BUILD_DIR/venv/bin/pip" install -r "$BACKEND_DIR/requirements.txt" pyinstaller

"$BUILD_DIR/venv/bin/pyinstaller" \
  --clean \
  --onefile \
  --name boss-helper-backend \
  --paths "$BACKEND_DIR" \
  --distpath "$BUILD_DIR/dist" \
  --workpath "$BUILD_DIR/work" \
  --specpath "$BUILD_DIR" \
  "$BACKEND_DIR/run.py"

echo "Built backend: $BUILD_DIR/dist/boss-helper-backend"
