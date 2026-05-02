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

# Ad-hoc sign so Gatekeeper does not mark the bundle as malformed.
codesign --force --deep --sign - "$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$APP_NAME"

echo "Built $ROOT/$APP_NAME"
