#!/bin/bash
# Standalone Intel DMG builder. Runs on a macOS x86_64 runner; no Homebrew.
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/AIMP Monterey.app"
DMG="$DIST/AIMP-Monterey-Intel-Standalone.dmg"

WINE_VERSION="11.0_1"
WINE_ASSET="wine-stable-${WINE_VERSION}-osx64.tar.xz"
WINE_URL="https://github.com/Gcenx/macOS_Wine_builds/releases/download/${WINE_VERSION}/${WINE_ASSET}"
GST_VERSION="1.28.6"
GST_ASSET="gstreamer-1.0-${GST_VERSION}-universal.pkg"
GST_BASE="https://gstreamer.freedesktop.org/data/pkg/osx/${GST_VERSION}"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
say() { printf '[standalone] %s\n' "$*"; }

[[ "$(uname -s)" == Darwin ]] || fail 'Must run on macOS'
[[ "$(uname -m)" == x86_64 ]] || fail 'Must run on Intel macOS'
for cmd in swiftc tar pkgutil ditto hdiutil curl shasum codesign file otool; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing $cmd"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aimp-standalone.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$DIST"
rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

say 'Downloading the prebuilt WineHQ x86_64 runtime...'
curl --fail --location --retry 3 --connect-timeout 20 --proto '=https' --proto-redir '=https' \
  "$WINE_URL" --output "$WORK/$WINE_ASSET"
tar -xJf "$WORK/$WINE_ASSET" -C "$WORK"
WINE_APP="$(find "$WORK" -type d -name 'Wine Stable.app' -print -quit)"
[[ -n "$WINE_APP" ]] || fail 'Wine release does not contain Wine Stable.app'
[[ -x "$WINE_APP/Contents/Resources/wine/bin/wine" ]] || fail 'Wine binary not found in release'
ditto "$WINE_APP" "$APP/Contents/Resources/Wine"
[[ -x "$APP/Contents/Resources/Wine/Contents/Resources/wine/bin/wine" ]] || fail 'Bundled Wine missing'
say 'Embedded Wine is in app Resources/Wine'

say 'Downloading and verifying the GStreamer runtime...'
curl --fail --location --retry 3 --connect-timeout 20 --proto '=https' --proto-redir '=https' \
  "$GST_BASE/$GST_ASSET" --output "$WORK/$GST_ASSET"
curl --fail --location --proto '=https' --proto-redir '=https' \
  "$GST_BASE/$GST_ASSET.sha256sum" --output "$WORK/$GST_ASSET.sha256sum"
EXPECTED="$(awk '{print $1}' "$WORK/$GST_ASSET.sha256sum" | head -n1)"
ACTUAL="$(shasum -a 256 "$WORK/$GST_ASSET" | awk '{print $1}')"
[[ "$EXPECTED" == "$ACTUAL" ]] || fail 'GStreamer SHA256 mismatch'

# The official pkg installs the framework under /Library/Frameworks.
# On an ephemeral GitHub-hosted macOS runner we may use sudo during BUILD
# (never required on the end-user's Mac) and copy the installed framework.
say 'Installing GStreamer into ephemeral build runner only...'
sudo /usr/sbin/installer -pkg "$WORK/$GST_ASSET" -target / >/dev/null
GSTREAMER_FRAMEWORK='/Library/Frameworks/GStreamer.framework'
[[ -d "$GSTREAMER_FRAMEWORK" ]] || fail 'GStreamer installer did not create the expected framework'
ditto "$GSTREAMER_FRAMEWORK" "$APP/Contents/Resources/GStreamer.framework"
[[ -e "$APP/Contents/Resources/GStreamer.framework/Versions/Current" ]] || fail 'GStreamer framework incomplete'

say 'Checking that embedded Wine can start without a separately installed Wine package...'
WINE_TEST="$APP/Contents/Resources/Wine/Contents/Resources/wine/bin/wine"
WINE_TEST_VERSION="$(DYLD_FRAMEWORK_PATH="$APP/Contents/Resources" \
  DYLD_FALLBACK_FRAMEWORK_PATH="$APP/Contents/Resources" \
  "$WINE_TEST" --version 2>&1)" || fail "Bundled Wine smoke check failed: $WINE_TEST_VERSION"
say "Bundled Wine responds: $WINE_TEST_VERSION"

say 'Compiling native Finder entry point with a Monterey 12.0 deployment target...'
xcrun swiftc -parse-as-library -O -target x86_64-apple-macos12.0 \
  "$ROOT/app/MacLauncher.swift" -o "$APP/Contents/MacOS/AIMP"
chmod 755 "$APP/Contents/MacOS/AIMP"
cp "$ROOT/app/launch-standalone.sh" "$APP/Contents/Resources/launch-standalone.sh"
chmod 755 "$APP/Contents/Resources/launch-standalone.sh"
cp "$ROOT/app/find-official-aimp.sh" "$APP/Contents/Resources/find-official-aimp.sh"
chmod 755 "$APP/Contents/Resources/find-official-aimp.sh"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
/usr/bin/plutil -lint "$APP/Contents/Info.plist"
[[ "$(file "$APP/Contents/MacOS/AIMP")" == *x86_64* ]] || fail 'Launcher executable is not Intel'

# We do not embed proprietary AIMP files in public artifacts.
[[ ! -e "$APP/Contents/Resources/AIMP-original.zip" ]] || fail 'Unexpected bundled AIMP archive'
[[ ! -e "$APP/Contents/Resources/AIMP/AIMP.exe" ]] || fail 'Unexpected bundled AIMP.exe'

# Recursively ad-hoc signing is NOT notarization. Gatekeeper may still block the app.
say 'Applying ad-hoc signature (Apple Developer ID/notarization not available)...'
codesign --force --deep --sign - "$APP" || fail 'Signing failed'
# Ad-hoc verification of the outer bundle is mandatory. The original Wine
# vendor bundle contains nested binary assets not yet normalized for Apple
# Developer ID signing; deep/strict verification is diagnostic only here.
codesign --verify --verbose=4 "$APP" || fail 'Outer app signature verification failed'
if ! codesign --verify --deep --strict --verbose=4 "$APP"; then
  say 'WARNING: deep strict signature verification failed on bundled third-party runtime.'
  say 'This is an UNNOTARIZED TEST BUILD, not a verified release.'
fi

STAGE="$WORK/dmg-stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/AIMP Monterey.app"
ln -s /Applications "$STAGE/Applications"
say 'Creating standalone DMG...'
hdiutil create -ov -format UDZO -fs HFS+ -volname 'AIMP Monterey' \
  -srcfolder "$STAGE" "$DMG" >/dev/null
shasum -a 256 "$DMG" > "$DMG.sha256"
say "Created: $DMG"
say 'IMPORTANT: Untested on actual Monterey and not notarized.'
