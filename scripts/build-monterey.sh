#!/bin/bash
# Build an AIMP x64 Wine launcher bundle and DMG on an Intel Mac.
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist"
APP="$OUT/AIMP Monterey.app"
DMG="$OUT/AIMP-Monterey-Intel-12.dmg"
OFFICIAL_URL='https://aimp.ru/?do=download.file&id=31'
VERSION='5.40.2727'

log() { printf '[AIMP Monterey] %s\n' "$*"; }
fail() { printf '[AIMP Monterey] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == 'Darwin' ]] || fail 'This build runs on macOS, not Linux/Windows.'
[[ "$(uname -m)" == 'x86_64' ]] || fail 'This build targets Intel (x86_64) Macs only.'
OS="$(sw_vers -productVersion)"
case "$OS" in
  12.*) ;;
  *) log "Warning: target is Monterey 12; detected macOS $OS. Continuing on Intel." ;;
esac

for tool in curl ditto hdiutil shasum plutil mktemp; do
  command -v "$tool" >/dev/null 2>&1 || fail "Missing macOS command: $tool"
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aimp-monterey.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT

ORIGINAL_DIR="$ROOT/vendor/AIMP"
ORIGINAL_ZIP="$ROOT/vendor/AIMP-portable-original.zip"
if [[ -f "$ORIGINAL_DIR/AIMP.exe" ]]; then
  SRC="$ORIGINAL_DIR"
  log 'Using original AIMP files provided locally in vendor/AIMP.'
else
  if [[ ! -s "$ORIGINAL_ZIP" ]]; then
    log "Downloading original AIMP $VERSION portable build from aimp.ru"
    curl --fail --location --retry 3 --connect-timeout 20 --max-time 180 \
      --proto '=https' --tlsv1.2 --output "$WORK/aimp.zip" "$OFFICIAL_URL" \
      || fail 'Download failed. Obtain the original portable ZIP from https://aimp.ru/?do=download&os=desktop and save as vendor/AIMP-portable-original.zip.'
    ORIGINAL_ZIP="$WORK/aimp.zip"
  fi
  /usr/bin/unzip -tqq "$ORIGINAL_ZIP" || fail 'Downloaded file is not a valid ZIP archive.'
  /usr/bin/unzip -Z1 "$ORIGINAL_ZIP" | while IFS= read -r entry; do
    case "$entry" in
      /*|../*|*/../*|*/..|*\\*) echo "Unsafe ZIP path: $entry" >&2; exit 2;;
    esac
  done || fail 'ZIP contains unsafe file paths.'
  mkdir -p "$WORK/unpacked"
  ditto -x -k "$ORIGINAL_ZIP" "$WORK/unpacked"
  EXES=()
  while IFS= read -r -d '' exe; do EXES+=("$exe"); done < <(find "$WORK/unpacked" -type f -iname 'AIMP.exe' -print0)
  [[ "${#EXES[@]}" -eq 1 ]] || fail "Expected one AIMP.exe, found ${#EXES[@]} in ZIP."
  SRC="$(dirname "${EXES[0]}")"
  log "Original archive SHA256: $(shasum -a 256 "$ORIGINAL_ZIP" | awk '{print $1}')"
fi

[[ -f "$SRC/AIMP.exe" ]] || fail 'Source AIMP.exe not found.'

mkdir -p "$OUT"
rm -rf "$APP" "$DMG"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/AIMP"
ditto "$SRC" "$APP/Contents/Resources/AIMP"
cp "$ROOT/app/AIMP-launcher.sh" "$APP/Contents/MacOS/AIMP"
chmod +x "$APP/Contents/MacOS/AIMP"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" || fail 'Invalid Info.plist'
shasum -a 256 "$APP/Contents/Resources/AIMP/AIMP.exe" > "$OUT/AIMP-exe.sha256"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || log 'Ad-hoc signing failed; bundle remains unsigned.'
fi

STAGE="$WORK/DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$(basename "$APP")"
ln -s /Applications "$STAGE/Applications"
log 'Creating DMG with hdiutil...'
hdiutil create -ov -format UDZO -fs HFS+ -volname 'AIMP Monterey' -srcfolder "$STAGE" "$DMG" >/dev/null
shasum -a 256 "$DMG" > "$DMG.sha256"
log "Bundle: $APP"
log "DMG:    $DMG"
log 'Done. Launching requires a separately installed compatible Wine 8+ runtime.'
