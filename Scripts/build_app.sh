#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="StartGGMatchExporter"
MODE="${1:-all}"

build_one() {
  local config="$1"
  local output_dir="$ROOT_DIR/$config"
  local app_dir="$output_dir/$APP_NAME.app"
  local binary_path

  swift build -c "$config" --package-path "$ROOT_DIR"
  binary_path="$(swift build -c "$config" --package-path "$ROOT_DIR" --show-bin-path)/$APP_NAME"

  rm -rf "$app_dir"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$binary_path" "$app_dir/Contents/MacOS/$APP_NAME"
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"

  cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.cinestill800t.StartGGMatchExporter</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>2.3.1</string>
  <key>CFBundleVersion</key>
  <string>24</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  chmod +x "$app_dir/Contents/MacOS/$APP_NAME"
  codesign --force --deep --sign - "$app_dir"
  (cd "$output_dir" && rm -f "$APP_NAME-macOS-$config.zip" && zip -qry "$APP_NAME-macOS-$config.zip" "$APP_NAME.app")
  echo "Built $app_dir"
}

case "$MODE" in
  debug)
    build_one debug
    ;;
  release)
    build_one release
    ;;
  all)
    build_one debug
    build_one release
    ;;
  *)
    echo "Usage: $0 [debug|release|all]" >&2
    exit 1
    ;;
esac
