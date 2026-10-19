#!/bin/bash
# Download original AIMP x64 portable ZIP from aimp.ru only, with PE64 validation.
# Output: a verbatim official ZIP. No repacking or modification.
set -euo pipefail
IFS=$'\n\t'
TARGET="${1:?Usage: find-official-aimp.sh /path/to/original.zip}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aimp-original.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
PAGE="https://aimp.ru/?do=download&os=windows"
/usr/bin/curl -fsSL --connect-timeout 20 --max-time 90 \
  --proto '=https' --proto-redir '=https' "$PAGE" -o "$TMP/index.html"

# Extract official hyperlinks from the current AIMP download page,
# not search engines or mirrors. Keep order and prefer portable links.
# The endpoint is intentionally discovered rather than hardcoding an old file ID.
/usr/bin/perl -0777 -ne '
while (/\b(?:href|data-href)\s*=\s*["\x27]([^"\x27]+)["\x27]/gi) {
  $x=$1; $x =~ s/&amp;/&/g;
  if ($x =~ /(?:download\.file|w64_no-installer\.zip)/i) { print "$x\n"; }
}
' "$TMP/index.html" > "$TMP/links"

[[ -s "$TMP/links" ]] || {
  echo "No official AIMP file links discoverable in page HTML." >&2; exit 1;
}

# Test all candidates (typically 4 stable links, plus beta links).
# An EXE installer fails ZIP validation immediately. The selected ZIP must
# contain AIMP.exe with 64-bit PE header. Never execute downloaded content here.
count=0
while IFS= read -r url; do
  case "$url" in
    https://aimp.ru/*|https://www.aimp.ru/*) ;;
    http://aimp.ru/*) url="https://${url#http://}" ;;
    /*) url="https://aimp.ru$url" ;;
    \?*) url="https://aimp.ru/$url" ;;
    *) continue ;;
  esac
  case "$url" in
    https://aimp.ru/*|https://www.aimp.ru/*) ;;
    *) continue ;;
  esac
  count=$((count+1))
  [[ "$count" -le 16 ]] || break
  if ! /usr/bin/curl --fail --location --retry 1 --connect-timeout 15 \
      --max-time 150 --proto '=https' --proto-redir '=https' \
      --referer "$PAGE" -o "$TMP/candidate.zip" "$url" 2>/dev/null; then
    continue
  fi
  /usr/bin/unzip -tqq "$TMP/candidate.zip" >/dev/null 2>&1 || continue

  # Check for traversal before using ditto to extract.
  if /usr/bin/unzip -Z1 "$TMP/candidate.zip" | /usr/bin/grep -Eq '(^/|(^|/)\.\.(/|$)|\\)'; then
    continue
  fi
  mkdir -p "$TMP/probe"
  /usr/bin/ditto -x -k "$TMP/candidate.zip" "$TMP/probe"
  found=0
  while IFS= read -r -d '' exe; do
    if /usr/bin/file "$exe" | /usr/bin/grep -Eqi 'PE32\+.*x86-64|PE32\+.*x86_64|PE32\+.*x86-64'; then
      found=1
    fi
  done < <(/usr/bin/find "$TMP/probe" -type f -iname AIMP.exe -print0)
  if [[ "$found" -eq 1 ]]; then
    /bin/cp "$TMP/candidate.zip" "$TARGET"
    echo "Selected original AIMP x64 ZIP from $url"
    exit 0
  fi
  /bin/rm -rf "$TMP/probe"
done < "$TMP/links"

echo "Official AIMP Windows x64 portable ZIP not found; page/download format may have changed." >&2
exit 1
