#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release

APP_NAME="Livepal.app"
BIN=".build/arm64-apple-macosx/release/Livepal"
if [[ ! -f "$BIN" ]]; then
  BIN=".build/release/Livepal"
fi

rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp "$BIN" "$APP_NAME/Contents/MacOS/Livepal"
cp "$ROOT/Supporting/Info.plist" "$APP_NAME/Contents/Info.plist"

echo "APPL????" > "$APP_NAME/Contents/PkgInfo"

chmod +x "$APP_NAME/Contents/MacOS/Livepal"

echo "Built $ROOT/$APP_NAME"
