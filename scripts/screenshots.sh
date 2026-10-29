#!/bin/bash
# Captures the README screenshots from the scripted demo (fixed seed, a window, no lock).
#   ./build.sh && scripts/screenshots.sh   → docs/screenshots/day.png, night.png, gate.png
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="build/Peekaboo Keys.app/Contents/MacOS/PeekabooKeys"
mkdir -p docs/screenshots
for mode in day night gate; do
    log=$(mktemp)
    "$BIN" --demo "$mode" >"$log" 2>&1 &
    pid=$!
    id=""
    for _ in $(seq 100); do
        id=$(sed -n 's/^WINDOW //p' "$log" | head -1)
        [ -n "$id" ] && break
        sleep 0.1
    done
    [ -n "$id" ] || { echo "✗ $mode: no window"; kill "$pid" 2>/dev/null; exit 1; }
    # The demo prints its window number once every scripted key has landed.
    sleep 0.3
    screencapture -o -x -l "$id" "docs/screenshots/$mode.png"
    wait "$pid" 2>/dev/null || true
    rm -f "$log"
    echo "✓ docs/screenshots/$mode.png"
done
