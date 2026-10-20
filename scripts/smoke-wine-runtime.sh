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

# Never allow an interactive dialog or broken Windows bootstrap to stall CI.
python3 - "$WINE" "$PREFIX" "$LOG" <<'PY'
import os, subprocess, sys
wine, prefix, logfile = sys.argv[1:]
env = dict(os.environ)
steps = [
    ("wineboot init", [wine, "wineboot", "--init"], 150),
    ("wine cmd", [wine, "cmd", "/c", "echo", "AIMP_WINE_OK"], 90),
]
with open(logfile, "w", encoding="utf-8") as log:
    for name, command, timeout in steps:
        print(f"[smoke] Running {name} (max {timeout}s)", flush=True)
        try:
            proc = subprocess.run(command, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True, errors="replace",
                                  timeout=timeout)
            log.write(f"=== {name} status={proc.returncode} ===\n{proc.stdout}\n")
            log.flush()
            print(proc.stdout[-3500:], flush=True)
            if proc.returncode:
                print(f"[smoke] FAIL: {name}, exit={proc.returncode}", file=sys.stderr)
                sys.exit(2)
            if name == "wine cmd" and "AIMP_WINE_OK" not in proc.stdout:
                print("[smoke] FAIL: cmd output marker missing", file=sys.stderr)
                sys.exit(3)
        except subprocess.TimeoutExpired as exc:
            log.write(f"=== {name} TIMEOUT ===\n{exc.output}\n")
            print(f"[smoke] FAIL: {name} timed out", file=sys.stderr)
            sys.exit(4)
print("[smoke] PASS: Wine booted and executed Windows cmd.exe")
PY
