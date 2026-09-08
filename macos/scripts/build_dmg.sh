#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/BossHelperMac.app"
STAGING_DIR="$BUILD_DIR/dmg-staging"

if [ ! -d "$APP_DIR" ]; then
  echo "App not found: $APP_DIR"
  echo "Run ./scripts/build_app.sh first."
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist")"
DMG_PATH="$BUILD_DIR/BossHelper-${VERSION}-arm64.dmg"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/安装说明.txt" <<EOF
BossHelper ${VERSION} 安装说明

系统要求：
- Apple Silicon（M 系列）Mac
- macOS 14 或更高版本（Apple Silicon）

安装步骤：
1. 双击打开本 DMG；
2. 把 BossHelper.app 拖入“应用程序”文件夹；
3. 首次打开时，右键 BossHelper.app → 选择“打开”。

若仍提示“无法验证开发者”：
在“终端”中执行：
  xattr -cr /Applications/BossHelper.app
然后再双击打开。

使用前请安装配套的浏览器插件，并在 BOSS 直聘网页登录。
EOF

rm -f "$DMG_PATH"
hdiutil create \
  -volname "BossHelper" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "Built DMG: $DMG_PATH"
