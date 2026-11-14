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
SHA=$(shasum -a 256 build/Bento.zip | cut -d' ' -f1)
echo "Bento $VERSION: $(pwd)/build/Bento.zip"
echo "sha256: $SHA"

# Homebrew cask in the tap clone (github.com/Amabeusz/homebrew-bento).
# The zip is not reproducible, so the cask must point at exactly this build:
# upload build/Bento.zip as-is and don't rebuild after this step.
TAP_DIR="${BENTO_TAP:-../homebrew-bento}"
CASK="$TAP_DIR/Casks/bento.rb"
if [ ! -f "$CASK" ]; then
    echo "WARNING: $CASK not found, cask not updated (set BENTO_TAP to the tap clone)." >&2
    exit 0
fi
if command -v gh >/dev/null && gh release view "v$VERSION" >/dev/null 2>&1; then
    echo "WARNING: release v$VERSION already exists, cask not updated." >&2
    echo "WARNING: bump CFBundleShortVersionString in scripts/Info.plist to release a new version." >&2
    exit 0
fi

sed -i '' -E \
    -e "s/^(  version \")[^\"]*(\")$/\1$VERSION\2/" \
    -e "s/^(  sha256 \")[^\"]*(\")$/\1$SHA\2/" \
    "$CASK"
grep -q "^  version \"$VERSION\"$" "$CASK" && grep -q "^  sha256 \"$SHA\"$" "$CASK" || {
    echo "ERROR: could not update version/sha256 in $CASK." >&2
    exit 1
}

echo "Cask updated: $CASK"
echo
echo "Next:"
echo "  gh release create v$VERSION build/Bento.zip --title \"Bento $VERSION\""
echo "  git -C \"$TAP_DIR\" commit -am \"bento $VERSION\" && git -C \"$TAP_DIR\" push"
