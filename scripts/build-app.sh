#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/bento"

APP=build/bento.app
if pgrep -x bento >/dev/null; then
    echo "Stopping the running bento before replacing its bundle (it restores parked windows)." >&2
    pkill -TERM -x bento || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x bento >/dev/null || break
        sleep 0.5
    done
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/bento"
cp scripts/Info.plist "$APP/Contents/Info.plist"
cp scripts/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if security find-identity -p codesigning | grep -q "bento-dev"; then
    codesign --force --sign "bento-dev" "$APP"
else
    echo "WARNING: 'bento-dev' signing identity not found (see docs/SETUP.md)." >&2
    echo "WARNING: signing ad-hoc; macOS will re-request permissions after each build." >&2
    echo "WARNING: if System Settings shows bento enabled but it reports missing permissions, reset the stale entries and grant again:" >&2
    echo "    tccutil reset Accessibility pl.amadeusz.bento" >&2
    echo "    tccutil reset ScreenCapture pl.amadeusz.bento" >&2
    codesign --force --sign - "$APP"
fi

echo "$(pwd)/$APP"
