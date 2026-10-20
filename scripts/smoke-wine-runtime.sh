#!/bin/bash
# Validate actual Win32 execution on a fresh Wine prefix (not just wine --version).
# Intended for a macOS CI runner, after the bundled Wine/GStreamer are installed.
set -euo pipefail

WINE="${1:?usage: smoke-wine-runtime.sh <wine-binary> <gstreamer-framework-dir>}"
GST="${2:?missing gstreamer framework directory}"
[[ -x "$WINE" ]] || { echo "Wine executable missing: $WINE" >&2; exit 1; }
[[ -d "$GST" ]] || { echo "GStreamer framework missing: $GST" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aimp-wine-smoke.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT
PREFIX="$WORK/prefix"
LOG="$WORK/wine-test.log"
RES="$(dirname "$GST")"
mkdir -p "$PREFIX"
export WINEPREFIX="$PREFIX"
export WINEARCH=win64
export WINEDEBUG="err+all,warn+module"
export PATH="$(dirname "$WINE"):/usr/bin:/bin:/usr/sbin:/sbin"
export DYLD_FRAMEWORK_PATH="$RES"
export DYLD_FALLBACK_FRAMEWORK_PATH="$RES"
export GST_PLUGIN_SYSTEM_PATH_1_0="$GST/Versions/Current/lib/gstreamer-1.0"
export GST_PLUGIN_PATH_1_0="$GST_PLUGIN_SYSTEM_PATH_1_0"

# Useful evidence: are the original Wine builtin DLL files present in the bundle?
RUNTIME="$(cd "$(dirname "$WINE")/.." && pwd)"
echo "[smoke] macOS: $(sw_vers -productVersion), arch: $(uname -m)"
echo "[smoke] Wine: $("$WINE" --version)"
echo "[smoke] DLL candidates (first 12):"
find "$RUNTIME" -iname kernel32.dll -print | head -n 12 || true

# Wine Mono/Gecko installation dialogs and GStreamer plugin registration can
# block in unattended prefix bootstrap. Disable these only for this smoke test
# to isolate the core Windows loader. AIMP playback is tested separately.
export WINEDLLOVERRIDES='winegstreamer,mscoree,mshtml='
echo "[smoke] Overrides: $WINEDLLOVERRIDES"
echo '[smoke] Testing Windows cmd.exe directly; creates an isolated temporary prefix.'

python3 - "$WINE" "$LOG" <<'PY'
import os, subprocess, sys, signal
wine, logfile = sys.argv[1:]
env = dict(os.environ)
cmd = [wine, "cmd", "/c", "echo", "AIMP_WINE_OK"]
with open(logfile, "w", encoding="utf-8") as log:
    proc = subprocess.Popen(
        cmd, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True
    )
    try:
        exit_code = proc.wait(timeout=65)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=5)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        log.flush()
        with open(logfile, "r", encoding="utf-8", errors="replace") as src:
            recent = src.read()[-6000:]
        print("[smoke] TIMEOUT after 65s running cmd.exe; last output:\\n"+recent, flush=True)
        sys.exit(4)
log_contents = open(logfile, encoding="utf-8", errors="replace").read()
print("[smoke] cmd.exe exit:", exit_code, flush=True)
print("[smoke] last output:\\n"+log_contents[-6000:], flush=True)
if exit_code or "AIMP_WINE_OK" not in log_contents:
    print("[smoke] FAIL: embedded Wine cannot execute cmd.exe", file=sys.stderr)
    sys.exit(3)
print("[smoke] PASS: Wine successfully executed Windows cmd.exe", flush=True)
PY
