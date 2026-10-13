#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="DougMonitor"
BUNDLE_ID="br.com.douglasalmeida.DougMonitor"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

case "$MODE" in
  run|--build-only|--debug|--logs|--telemetry|--verify) ;;
  *) echo "Uso: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

if [[ "$MODE" != "--build-only" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

# Optimize the distributed monitor for its deliberately small CPU/RAM footprint.
swift build -c release --product "$APP_NAME"
BUILD_DIR="$(swift build -c release --show-bin-path)"
APP_BUNDLE="$ROOT_DIR/dist/Monitor.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
# Finder/iCloud metadata can invalidate a generated bundle's local signature.
# Only clear these two packaging attributes, preserving quarantine and all others.
/usr/bin/xattr -r -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/xattr -r -d com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

case "$MODE" in
  --build-only) echo "Aplicativo: $APP_BUNDLE" ;;
  run) /usr/bin/open "$APP_BUNDLE" ;;
  --debug) /usr/bin/lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs)
    /usr/bin/open "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'process == "DougMonitor"'
    ;;
  --telemetry)
    /usr/bin/open "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "br.com.douglasalmeida.DougMonitor"'
    ;;
  --verify)
    /usr/bin/open "$APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "Monitor está em execução."
    ;;
esac
