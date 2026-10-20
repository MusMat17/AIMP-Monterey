#!/bin/bash
# Extract the original AIMP application icon from the OFFICIAL AIMP Windows ZIP.
# The public repository does not contain third-party AIMP binaries or its icon.
# Build host (not end user) must provide wrestool/icotool from icoutils.
set -euo pipefail
IFS=$'\n\t'
ZIP="${1:?Usage: build-aimp-icon.sh <original AIMP portable ZIP> <target AIMP.icns>}"
OUTPUT="${2:?Output icns path required}"
for tool in wrestool icotool iconutil sips unzip ditto; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing icon builder tool: $tool" >&2; exit 1; }
done
[[ -s "$ZIP" ]] || { echo "Official AIMP ZIP not found: $ZIP" >&2; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aimp-icon.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/original" "$WORK/ico" "$WORK/png" "$WORK/AIMP.iconset"

# Validate before extracting untrusted archives.
unzip -tqq "$ZIP"
if unzip -Z1 "$ZIP" | grep -Eq '(^/|(^|/)\.\.(/|$)|\\)'; then
  echo "Unsafe path in original ZIP" >&2
  exit 1
fi
ditto -x -k "$ZIP" "$WORK/original"
EXE="$(find "$WORK/original" -type f -iname AIMP.exe -print -quit)"
[[ -n "$EXE" ]] || { echo "Cannot locate AIMP.exe in original portable ZIP" >&2; exit 1; }

wrestool --extract --type=14 --output="$WORK/ico" "$EXE"
ICO="$(find "$WORK/ico" -maxdepth 1 -type f -iname '*.ico' | LC_ALL=C sort | head -n 1)"
[[ -n "$ICO" ]] || { echo "AIMP.exe contains no extractable group-icon" >&2; exit 1; }
icotool --extract --output="$WORK/png/" "$ICO"

# Pick the highest-resolution original embedded icon.
BEST=''
BEST_SIZE=0
while IFS= read -r -d '' png; do
  width="$(sips -g pixelWidth "$png" | awk '/pixelWidth:/ {print $2}')"
  height="$(sips -g pixelHeight "$png" | awk '/pixelHeight:/ {print $2}')"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || continue
  [[ "$width" == "$height" ]] || continue
  if (( width > BEST_SIZE )); then BEST="$png"; BEST_SIZE="$width"; fi
done < <(find "$WORK/png" -type f -iname '*.png' -print0)

[[ -n "$BEST" ]] || { echo "AIMP icon PNG extraction returned no square image" >&2; exit 1; }
echo "[icon] Using official AIMP icon embedded at ${BEST_SIZE}x${BEST_SIZE}"
for dim in 16 32 64 128 256 512 1024; do
  case "$dim" in
    16) name='icon_16x16.png';;
    32) name='icon_16x16@2x.png';;
    64) name='icon_32x32@2x.png';;
    128) name='icon_128x128.png';;
    256) name='icon_128x128@2x.png';;
    512) name='icon_256x256@2x.png';;
    1024) name='icon_512x512@2x.png';;
  esac
  sips -s format png -z "$dim" "$dim" "$BEST" \
    --out "$WORK/AIMP.iconset/$name" >/dev/null
done
# Include the traditional 32/256/512 native image slots.
cp "$WORK/AIMP.iconset/icon_16x16@2x.png" "$WORK/AIMP.iconset/icon_32x32.png"
cp "$WORK/AIMP.iconset/icon_128x128@2x.png" "$WORK/AIMP.iconset/icon_256x256.png"
cp "$WORK/AIMP.iconset/icon_256x256@2x.png" "$WORK/AIMP.iconset/icon_512x512.png"

mkdir -p "$(dirname "$OUTPUT")"
iconutil --convert icns "$WORK/AIMP.iconset" --output "$OUTPUT"
[[ -s "$OUTPUT" ]] || { echo "Could not build AIMP.icns" >&2; exit 1; }
echo "[icon] Created macOS app icon: $OUTPUT"
