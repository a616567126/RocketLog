#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="${ROCKETLOG_APP_PATH:-$ROOT/RocketLog.app}"
CACHE="${ROCKETLOG_BUILD_DIR:-$ROOT/.build}"
ARCH="${ROCKETLOG_ARCH:-$(uname -m)}"

case "$ARCH" in
  arm64|x86_64) ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Install Apple Command Line Tools first: xcode-select --install" >&2
  exit 1
fi

if [[ ! -f "$ROOT/assets/RocketLog.icns" ]]; then
  echo "Missing assets/RocketLog.icns. Restore the icon from the source repository." >&2
  exit 1
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE/module-cache"

xcrun swiftc \
  -target "$ARCH-apple-macos13.0" \
  -module-cache-path "$CACHE/module-cache" \
  -O -whole-module-optimization \
  -framework AppKit -framework SwiftUI -lsqlite3 \
  "$ROOT/Sources/main.swift" \
  -o "$CACHE/RocketLog.new"

# Replace the executable atomically so an earlier launch does not retain its inode.
mv -f "$CACHE/RocketLog.new" "$APP/Contents/MacOS/RocketLog"
cp "$ROOT/assets/RocketLog.icns" "$APP/Contents/Resources/RocketLog.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>RocketLog</string>
    <key>CFBundleIdentifier</key><string>org.rocketlog.app</string>
    <key>CFBundleName</key><string>RocketLog</string>
    <key>CFBundleDisplayName</key><string>RocketLog</string>
    <key>CFBundleIconFile</key><string>RocketLog</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built: $APP"
