#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY="${CODE_SIGN_IDENTITY:-Cap Local Signing}"
DERIVED_DATA="$PWD/build/DerivedData"
APP="$DERIVED_DATA/Build/Products/Release/Cap.app"
DEST="/Applications/Cap.app"

osascript -e 'tell application id "dev.bruce.cap" to quit' >/dev/null 2>&1 || true
sleep 0.5

xcodebuild -project Cap.xcodeproj -scheme Cap -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
  build

codesign --verify --deep --strict "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E 'Identifier|Authority'

rm -rf "$DEST"
ditto "$APP" "$DEST"
open "$DEST"

echo "Installed: $DEST"
