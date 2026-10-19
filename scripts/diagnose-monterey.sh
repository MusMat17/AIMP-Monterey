#!/bin/bash
set -u
IFS=$'\n\t'
printf '%s\n' '=== AIMP Monterey diagnostics ==='
printf 'OS: '; sw_vers -productVersion 2>/dev/null || uname -s
printf 'Architecture: '; uname -m
printf 'Wine in PATH: '; command -v wine || echo '(none)'
printf 'Wine version: '; wine --version 2>&1 || true
for bin in '/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine' '/Applications/Wine Staging.app/Contents/Resources/wine/bin/wine'; do
  if [[ -x "$bin" ]]; then printf '%s -> %s\n' "$bin" "$("$bin" --version 2>&1)"; fi
done
printf 'Built app: '
[[ -d "$(dirname "$0")/../dist/AIMP Monterey.app" ]] && echo yes || echo no
printf 'Prefix present: '
[[ -d "$HOME/Library/Application Support/AIMP Monterey/prefix" ]] && echo yes || echo no
printf 'Logs: ~/Library/Logs/AIMP Monterey/launcher.log\n'
