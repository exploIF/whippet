#!/usr/bin/env bash
# Builds Whippet in Release mode and installs it into /Applications.
#
# Usage: scripts/install.sh [--no-open]
#   --no-open   Don't launch Whippet after installing.

set -euo pipefail

APP_NAME="Whippet"
DEST_DIR="/Applications"
DEST="$DEST_DIR/$APP_NAME.app"

open_after=true
for arg in "$@"; do
    case "$arg" in
        --no-open) open_after=false ;;
        -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v xcodebuild >/dev/null; then
    echo "xcodebuild not found. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app" >&2
    exit 1
fi

# Keep build products in a folder Spotlight doesn't index (".noindex"), so only the copy in
# /Applications shows up in Spotlight and Launchpad. Xcode only honours this as a per-user
# workspace setting, so set it once unless you've already chosen a build location.
DERIVED_DATA="build/DerivedData.noindex"
user_settings="$APP_NAME.xcodeproj/project.xcworkspace/xcuserdata/$(whoami).xcuserdatad/WorkspaceSettings.xcsettings"
if [[ ! -f "$user_settings" ]]; then
    mkdir -p "$(dirname "$user_settings")"
    cat >"$user_settings" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BuildLocationStyle</key>
	<string>UseAppPreferences</string>
	<key>CustomBuildLocationType</key>
	<string>RelativeToDerivedData</string>
	<key>DerivedDataCustomLocation</key>
	<string>$DERIVED_DATA</string>
	<key>DerivedDataLocationStyle</key>
	<string>WorkspaceRelativePath</string>
</dict>
</plist>
PLIST
    echo "==> Xcode will now build this project into $DERIVED_DATA (not indexed by Spotlight)."
elif ! /usr/libexec/PlistBuddy -c "Print :DerivedDataLocationStyle" "$user_settings" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy \
        -c "Add :DerivedDataLocationStyle string WorkspaceRelativePath" \
        -c "Add :DerivedDataCustomLocation string $DERIVED_DATA" \
        "$user_settings" >/dev/null
    echo "==> Xcode will now build this project into $DERIVED_DATA (not indexed by Spotlight)."
fi

echo "==> Building $APP_NAME (Release)…"
build_log="$(mktemp -t whippet-build)"
if ! xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
        -derivedDataPath "$DERIVED_DATA/$APP_NAME" build >"$build_log" 2>&1; then
    grep -E "error:" "$build_log" >&2 || tail -n 30 "$build_log" >&2
    echo "Build failed. Full log: $build_log" >&2
    exit 1
fi
rm -f "$build_log"

built_app="$DERIVED_DATA/$APP_NAME/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$built_app" ]]; then
    echo "Build succeeded but $built_app is missing." >&2
    exit 1
fi

if pgrep -x "$APP_NAME" >/dev/null; then
    echo "==> Quitting running ${APP_NAME}…"
    osascript -e "tell application id \"com.exploif.whippet\" to quit" >/dev/null 2>&1 || true
    for _ in {1..20}; do
        pgrep -x "$APP_NAME" >/dev/null || break
        sleep 0.25
    done
    pkill -x "$APP_NAME" 2>/dev/null || true
fi

echo "==> Installing to ${DEST}…"
if [[ -w "$DEST_DIR" ]]; then
    rm -rf "$DEST"
    ditto "$built_app" "$DEST"
else
    sudo rm -rf "$DEST"
    sudo ditto "$built_app" "$DEST"
fi

echo "==> Installed $APP_NAME $(defaults read "$DEST/Contents/Info" CFBundleShortVersionString 2>/dev/null || true)"

if $open_after; then
    open "$DEST"
    echo "==> $APP_NAME is running — look for it in the menu bar."
fi
