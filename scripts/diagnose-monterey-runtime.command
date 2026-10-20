#!/bin/bash
# Non-destructive Wine diagnostics for the user's Intel Mac / Monterey.
# Runs a Windows built-in command only inside an isolated temporary prefix.
# Never modifies or deletes the existing AIMP Wine prefix or downloaded AIMP.
set -u

APP="/Applications/AIMP Monterey.app"
RES="$APP/Contents/Resources"
WINE="$RES/Wine/Contents/Resources/wine/bin/wine"
GST="$RES/GStreamer.framework"
PREFIX="$HOME/Library/Application Support/AIMP Monterey/prefix"
REPORT="$HOME/Desktop/AIMP-Wine-Diagnostic-$(date '+%Y%m%d-%H%M%S').txt"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aimp-runtime-check.XXXXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT

exec > >(tee "$REPORT") 2>&1
printf '%s\n' '=== AIMP Monterey non-destructive Wine diagnostic ==='
date
sw_vers
uname -m
printf 'App: %s\nReport: %s\n' "$APP" "$REPORT"
if [[ ! -x "$WINE" ]]; then echo 'ERROR: bundled Wine binary not found'; exit 2; fi
if [[ ! -d "$GST" ]]; then echo 'ERROR: bundled GStreamer.framework not found'; exit 3; fi
"$WINE" --version
/usr/bin/file "$WINE"
echo '=== Existing prefix metadata (not modified) ==='
if [[ -d "$PREFIX" ]]; then
  ls -ld "$PREFIX"
  for p in "$PREFIX/system.reg" "$PREFIX/user.reg" "$PREFIX/drive_c/windows/system32/kernel32.dll"; do
    if [[ -e "$p" ]]; then ls -lh "$p"; else echo "MISSING: $p"; fi
  done
else
  echo "Existing prefix not present"
fi
echo '=== Bundled DLL locations ==='
find "$RES/Wine/Contents/Resources/wine" -iname kernel32.dll -print | head -n 12
echo '=== Built-in Wine executable dependencies ==='
/usr/bin/otool -L "$WINE" 2>&1 | head -n 45
echo '=== Quarantine / code signature status ==='
/usr/bin/xattr -p com.apple.quarantine "$APP" 2>&1 || true
/usr/bin/codesign --verify --verbose=2 "$APP" 2>&1 || true

echo '=== Isolated CLEAN prefix test; original user prefix remains untouched ==='
export WINEPREFIX="$TMP/prefix"
export WINEARCH=win64
export DYLD_FRAMEWORK_PATH="$RES"
export DYLD_FALLBACK_FRAMEWORK_PATH="$RES"
export GST_PLUGIN_SYSTEM_PATH_1_0="$GST/Versions/Current/lib/gstreamer-1.0"
export GST_PLUGIN_PATH_1_0="$GST_PLUGIN_SYSTEM_PATH_1_0"
export PATH="$(dirname "$WINE"):/usr/bin:/bin:/usr/sbin:/sbin"
export WINEDEBUG='err+all,warn+module'
mkdir -p "$WINEPREFIX"

/usr/bin/perl -e 'alarm 100; exec @ARGV or die $!' "$WINE" cmd /c echo AIMP_CLEAN_PREFIX_OK
RESULT=$?
echo "Clean prefix cmd exit code: $RESULT"
echo '=== Clean prefix resulting metadata ==='
for p in "$WINEPREFIX/system.reg" "$WINEPREFIX/drive_c/windows/system32/kernel32.dll"; do
  if [[ -e "$p" ]]; then ls -lh "$p"; else echo "MISSING: $p"; fi
done
if [[ "$RESULT" -eq 0 ]]; then
  echo 'PASS: Wine can start with a clean prefix; existing AIMP prefix may need repair'
else
  echo 'FAIL: Wine cannot run even with a clean prefix; likely runtime bundle or macOS compatibility'
fi
echo 'No existing AIMP data or Wine prefix was modified by this diagnostic.'
echo "Saved diagnostic report: $REPORT"
exit 0
