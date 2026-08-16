#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="StartGGMatchExporter"
MODE="${1:-all}"
LOCAL_SIGNING_IDENTITY="StartGGMatchExporter Local Signing"

resolve_signing_identity() {
  if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$CODE_SIGN_IDENTITY"
    return
  fi

  local -a matching_identities
  matching_identities=(
    $(security find-identity -v -p codesigning | awk -v identity="$LOCAL_SIGNING_IDENTITY" '
      index($0, "\"" identity "\"") { print $2 }
    ')
  )

  if [[ ${#matching_identities[@]} -eq 0 ]]; then
    printf '%s\n' "-"
  elif [[ ${#matching_identities[@]} -eq 1 ]]; then
    printf '%s\n' "${matching_identities[0]}"
  else
    echo "Multiple code-signing identities named '$LOCAL_SIGNING_IDENTITY' were found." >&2
    return 1
  fi
}

build_one() {
  local config="$1"
  local output_dir="$ROOT_DIR/$config"
  local app_dir="$output_dir/$APP_NAME.app"
  local binary_path
  local signing_identity
  local -a codesign_args

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
  <string>2.5.10</string>
  <key>CFBundleVersion</key>
  <string>36</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  chmod +x "$app_dir/Contents/MacOS/$APP_NAME"
  signing_identity="$(resolve_signing_identity)"
  codesign_args=(--force --sign "$signing_identity")
  if [[ "$signing_identity" != "-" ]]; then
    codesign_args+=(--options runtime --timestamp=none)
  fi
  if [[ -n "${CODE_SIGN_KEYCHAIN:-}" ]]; then
    codesign_args+=(--keychain "$CODE_SIGN_KEYCHAIN")
  fi
  codesign "${codesign_args[@]}" "$app_dir"
  codesign --verify --strict --verbose=2 "$app_dir"
  (cd "$output_dir" && rm -f "$APP_NAME-macOS-$config.zip" && zip -qry "$APP_NAME-macOS-$config.zip" "$APP_NAME.app")
  echo "Built $app_dir (signed with $signing_identity)"
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
