#!/bin/bash
# First-launch bootstrap: no Homebrew, Wine install, Terminal or admin password needed.
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES="$ROOT/Resources"
WINE="$RES/Wine/Contents/Resources/wine/bin/wine"
WINEPATH="$RES/Wine/Contents/Resources/wine/bin/winepath"
GST="$RES/GStreamer.framework"
APPDATA="$HOME/Library/Application Support/AIMP Monterey"
AIMPDIR="$APPDATA/AIMP"
PREFIX="$APPDATA/prefix"
LOGDIR="$HOME/Library/Logs/AIMP Monterey"
LOG="$LOGDIR/launcher.log"
mkdir -p "$APPDATA" "$LOGDIR"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
fail() { log "ERROR: $1"; echo "$1" >&2; exit 1; }

[[ "$(uname -s)" == Darwin && "$(uname -m)" == x86_64 ]] || fail "Нужен Intel Mac с macOS."
[[ -x "$WINE" ]] || fail "Не найден встроенный Wine — сборка повреждена."
[[ -d "$GST" ]] || fail "Не найдена встроенная библиотека GStreamer — сборка повреждена."

# These libraries belong to this app, not to /Library/Frameworks or Homebrew.
export DYLD_FRAMEWORK_PATH="$RES${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
export DYLD_FALLBACK_FRAMEWORK_PATH="$RES${DYLD_FALLBACK_FRAMEWORK_PATH:+:$DYLD_FALLBACK_FRAMEWORK_PATH}"
export GST_PLUGIN_PATH_1_0="$GST/Versions/Current/lib/gstreamer-1.0"
export GST_PLUGIN_SYSTEM_PATH_1_0="$GST/Versions/Current/lib/gstreamer-1.0"
export PATH="$(dirname "$WINE"):$RES/Wine/Contents/Resources/start/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export WINEARCH=win64
export WINEPREFIX="$PREFIX"
export WINEDEBUG="${WINEDEBUG:--all}"

# AIMP is proprietary: obtain its untouched original portable ZIP directly
# from the author's website, *only for this user's local installation*.
# CI and public GitHub artifacts never include AIMP.exe.
ensure_aimp() {
  [[ -f "$AIMPDIR/AIMP.exe" ]] && return 0
  log "First launch: downloading original AIMP portable distribution."

  local tmp archive source candidates entry
  tmp="$(mktemp -d "$APPDATA/.install.XXXXXXXX")"
  archive="$tmp/AIMP-original.zip"
  trap 'rm -rf "$tmp"' RETURN

  # An optional archive can be supplied for private offline builds.
  if [[ -f "$RES/AIMP-original.zip" ]]; then
    cp "$RES/AIMP-original.zip" "$archive"
  else
    /bin/bash "$RES/find-official-aimp.sh" "$archive" \
      || fail "Не удалось получить оригинальную портативную сборку AIMP x64 с aimp.ru."

  fi

  /usr/bin/unzip -tqq "$archive" || fail "Сайт AIMP не предоставил ZIP-архив. Проверь официальный адрес загрузки."
  # Reject traversal paths prior to extraction.
  /usr/bin/unzip -Z1 "$archive" | while IFS= read -r entry; do
    case "$entry" in
      /*|../*|*/../*|*/..|*\\*) exit 3;;
    esac
  done || fail "Небезопасное содержимое ZIP-архива."

  mkdir -p "$tmp/unpacked"
  /usr/bin/ditto -x -k "$archive" "$tmp/unpacked"
  candidates=()
  while IFS= read -r -d '' source; do candidates+=("$source"); done < <(find "$tmp/unpacked" -type f -iname AIMP.exe -print0)
  [[ ${#candidates[@]} -eq 1 ]] || fail "В архиве не обнаружена оригинальная программа AIMP.exe."
  source="$(dirname "${candidates[0]}")"
  [[ -f "$source/AIMP.exe" ]] || fail "AIMP.exe не найден."
  /bin/mv "$source" "$AIMPDIR" || fail "Не удалось записать AIMP в папку пользователя."
  log "AIMP installed locally from original ZIP, sha256: $(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
}
ensure_aimp

mkdir -p "$PREFIX"
args=()
for item in "$@"; do
  if [[ -e "$item" && -x "$WINEPATH" ]]; then
    converted="$("$WINEPATH" -w "$item" 2>>"$LOG" || true)"
    [[ -n "$converted" ]] && item="$converted"
  fi
  args+=("$item")
done

log "Running bundled Wine: $("$WINE" --version 2>&1); media args: ${#args[@]}"
cd "$AIMPDIR"
# macOS Monterey ships Bash 3.2. With set -u it raises "args[@]: unbound
# variable" when the array is empty, even when it was initialized with args=().
# Avoid *any* expansion of an empty array in the normal Finder-launch path.
if [[ "$#" -eq 0 ]]; then
  "$WINE" "$AIMPDIR/AIMP.exe" >> "$LOG" 2>&1
else
  "$WINE" "$AIMPDIR/AIMP.exe" "${args[@]}" >> "$LOG" 2>&1
fi
