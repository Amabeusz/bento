#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! security find-identity -p codesigning | grep -q "bento-dev"; then
    echo "ERROR: 'bento-dev' signing identity not found (see docs/SETUP.md)." >&2
    echo "ERROR: a release signed ad-hoc would make users grant permissions again after every update." >&2
    exit 1
fi

scripts/build-app.sh

STAGE=build/release
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R build/bento.app "$STAGE/Bento.app"
codesign --verify --deep --strict "$STAGE/Bento.app"
ditto -c -k --keepParent "$STAGE/Bento.app" build/Bento.zip

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" scripts/Info.plist)
echo "Bento $VERSION: $(pwd)/build/Bento.zip"
