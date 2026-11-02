#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/hyprmac"

APP=build/hyprmac.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/hyprmac"
cp scripts/Info.plist "$APP/Contents/Info.plist"

if security find-identity -p codesigning | grep -q "hyprmac-dev"; then
    codesign --force --sign "hyprmac-dev" "$APP"
else
    echo "WARNING: 'hyprmac-dev' signing identity not found (see docs/SETUP.md)." >&2
    echo "WARNING: signing ad-hoc; macOS will re-request permissions after each build." >&2
    codesign --force --sign - "$APP"
fi

echo "$(pwd)/$APP"
