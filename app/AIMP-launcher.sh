#!/bin/bash
# Invoked by macOS LaunchServices from AIMP Monterey.app.
set -euo pipefail
IFS=$'\n\t'

CONTENTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXE="$CONTENTS/Resources/AIMP/AIMP.exe"
PREFIX="$HOME/Library/Application Support/AIMP Monterey/prefix"
LOGDIR="$HOME/Library/Logs/AIMP Monterey"
mkdir -p "$LOGDIR" "$PREFIX"
LOGFILE="$LOGDIR/launcher.log"

msg() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"
}
alert() {
  msg "ERROR: $1"
  if command -v osascript >/dev/null 2>&1; then
    /usr/bin/osascript -e 'display dialog "'"$(printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g')"'" with title "AIMP Monterey" buttons {"OK"} default button 1 with icon caution' >/dev/null 2>&1 || true
  fi
  exit 1
}

if [[ ! -f "$EXE" ]]; then alert 'Файл AIMP.exe не найден. Собери приложение заново.'; fi

export PATH="/opt/local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
export WINEPREFIX="$PREFIX"
export WINEARCH='win64'
export WINEDEBUG="${WINEDEBUG:--all}"

WINE=''
if [[ -n "${AIMP_WINE_BIN:-}" ]]; then
  [[ -x "$AIMP_WINE_BIN" ]] || alert 'Указан AIMP_WINE_BIN, но файл Wine не найден.'
  WINE="$AIMP_WINE_BIN"
else
  for candidate in \
    /opt/local/bin/wine \
    /usr/local/bin/wine \
    '/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine' \
    '/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine' \
    '/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine' \
    /opt/homebrew/bin/wine; do
    if [[ -x "$candidate" ]]; then WINE="$candidate"; break; fi
  done
  if [[ -z "$WINE" ]] && command -v wine >/dev/null 2>&1; then
    WINE="$(command -v wine)"
  fi
fi
[[ -n "$WINE" ]] || alert 'Wine не установлен. Нужен совместимый Wine 8+ для Intel macOS 12. См. README.'

if VERSION="$("$WINE" --version 2>/dev/null)"; then
  msg "Wine runtime: $VERSION"
  if [[ "$VERSION" =~ wine-([0-9]+) ]] && [[ "${BASH_REMATCH[1]}" -lt 8 ]]; then
    alert 'Обнаружен устаревший Wine. Установи Wine 8 или новее.'
  fi
fi

args=()
if [[ $# -gt 0 ]]; then
  for item in "$@"; do
    if [[ -e "$item" ]]; then
      WINEPATH="$(dirname "$WINE")/winepath"
      if [[ -x "$WINEPATH" ]]; then
        converted="$("$WINEPATH" -w "$item" 2>/dev/null || true)"
        [[ -n "$converted" ]] && item="$converted"
      fi
    fi
    args+=("$item")
  done
fi

cd "$(dirname "$EXE")"
msg "Launching AIMP; args count: ${#args[@]}"
exec "$WINE" "$EXE" "${args[@]}" >> "$LOGFILE" 2>&1
