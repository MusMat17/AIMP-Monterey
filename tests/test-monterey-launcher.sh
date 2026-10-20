#!/bin/bash
# Test real standalone launcher with the system's /bin/bash (3.2 on macOS 12)
# without downloading/running AIMP or launching any real Wine GUI.
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$(uname -s)" == Darwin ]] || { echo "This integration test runs on macOS" >&2; exit 1; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/aimp-shell-test.XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
RES="$TMP/Contents/Resources"
MOCK_WINE="$RES/Wine/Contents/Resources/wine/bin/wine"
MOCK_AIMP="$TMP/home/Library/Application Support/AIMP Monterey/AIMP/AIMP.exe"
mkdir -p "$(dirname "$MOCK_WINE")" "$(dirname "$MOCK_AIMP")" "$RES/GStreamer.framework"
cp "$ROOT/app/launch-standalone.sh" "$RES/launch-standalone.sh"
touch "$MOCK_AIMP"

cat > "$MOCK_WINE" <<'WINE_MOCK'
#!/bin/bash
set -euo pipefail
if [[ "${1:-}" == '--version' ]]; then
  printf 'wine-test-mock\n'
  exit 0
fi
printf '<%s>\n' "$@" > "$MOCK_WINE_ARGS"
WINE_MOCK
chmod +x "$MOCK_WINE"

# Test 1: Normal Finder double-click with NO command-line arguments.
HOME="$TMP/home" MOCK_WINE_ARGS="$TMP/wine-args" \
  /bin/bash "$RES/launch-standalone.sh"
printf '<%s>\n' "$MOCK_AIMP" > "$TMP/expected"
diff -u "$TMP/expected" "$TMP/wine-args"
echo 'PASS: zero arguments: invokes AIMP.exe without Bash nounset error'

# Test 2: Opening an audio file from Finder.
SAMPLE="$TMP/Track with spaces.mp3"
touch "$SAMPLE"
HOME="$TMP/home" MOCK_WINE_ARGS="$TMP/wine-args" \
  /bin/bash "$RES/launch-standalone.sh" "$SAMPLE"
printf '<%s>\n<%s>\n' "$MOCK_AIMP" "$SAMPLE" > "$TMP/expected"
diff -u "$TMP/expected" "$TMP/wine-args"
echo 'PASS: one audio-file argument is passed correctly'

# Test 3: log available even when mocked launcher is invoked.
test -s "$TMP/home/Library/Logs/AIMP Monterey/launcher.log"
echo 'PASS: diagnostics created'
