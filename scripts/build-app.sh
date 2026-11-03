#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/hyprmac"

APP=build/hyprmac.app
if pgrep -x hyprmac >/dev/null; then
    echo "Stopping the running hyprmac before replacing its bundle (it restores parked windows)." >&2
    pkill -TERM -x hyprmac || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x hyprmac >/dev/null || break
        sleep 0.5
    done
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/hyprmac"
cp scripts/Info.plist "$APP/Contents/Info.plist"

if security find-identity -p codesigning | grep -q "hyprmac-dev"; then
    codesign --force --sign "hyprmac-dev" "$APP"
else
    echo "WARNING: 'hyprmac-dev' signing identity not found (see docs/SETUP.md)." >&2
    echo "WARNING: signing ad-hoc; macOS will re-request permissions after each build." >&2
    echo "WARNING: if System Settings shows hyprmac enabled but it reports missing permissions, reset the stale entries and grant again:" >&2
    echo "    tccutil reset Accessibility pl.amadeusz.hyprmac" >&2
    echo "    tccutil reset ScreenCapture pl.amadeusz.hyprmac" >&2
    codesign --force --sign - "$APP"
fi

echo "$(pwd)/$APP"
