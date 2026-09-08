#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/BossHelperMac"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/BossHelperMac.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
BACKEND_EXE="$ROOT_DIR/build/backend/dist/boss-helper-backend"

cd "$PROJECT_DIR"
swift build -c release

"$ROOT_DIR/scripts/build_backend.sh"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$PROJECT_DIR/.build/release/BossHelperMac" "$MACOS_DIR/BossHelperMac"
cp "$BACKEND_EXE" "$MACOS_DIR/boss-helper-backend"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

# Adhoc-sign the bundle so Gatekeeper doesn't treat it as "damaged" when downloaded.
# (Not notarized, so macOS may still ask "unverified developer" — right-click → Open.)
codesign --force --deep -s - "$APP_DIR"

echo "Built app: $APP_DIR"
echo "Run it with: open $APP_DIR"
