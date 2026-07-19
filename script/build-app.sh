#!/bin/bash
# Builds Renamatic.app into build/ from the SwiftPM executable.
#
#   script/build-app.sh              debug/dev build, ad-hoc signed
#   script/build-app.sh release      release build, ad-hoc signed
#   script/build-app.sh --release    release build, Developer ID + notarized + stapled
#
# --release expects:
#   DEV_ID_IDENTITY   env var, e.g. "Developer ID Application: Your Name (TEAMID)"
#                     (put it in a gitignored .env at the repo root, or export it yourself)
#   a notarytool keychain profile named "renamatic-notary"
#   (create once with: xcrun notarytool store-credentials renamatic-notary)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

NOTARY_PROFILE="renamatic-notary"

NOTARIZE=0
CONFIG="${1:-release}"
if [ "$CONFIG" = "--release" ]; then
  NOTARIZE=1
  CONFIG="release"
  : "${DEV_ID_IDENTITY:?Set DEV_ID_IDENTITY to your Developer ID Application identity, e.g. export DEV_ID_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\"}"
fi

swift build -c "$CONFIG"

APP="build/Renamatic.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp ".build/$CONFIG/Renamatic" "$APP/Contents/MacOS/Renamatic"
cp Resources/Info.plist "$APP/Contents/"
if [ -f Icon/AppIcon.icns ]; then
  cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Sparkle ships as a dynamic framework (with its own bundled XPC helpers for
# installing updates) — it has to be embedded in Contents/Frameworks, not
# statically linked. Package.swift adds the matching @executable_path rpath.
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
cp -R ".build/$CONFIG/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

if [ "$NOTARIZE" = "1" ]; then
  # --deep re-signs Sparkle's bundled helpers under our identity too, which
  # notarization requires (hardened runtime + timestamp on every nested binary).
  codesign --force --deep --options runtime --timestamp \
    --sign "$DEV_ID_IDENTITY" "$APP"
  echo "Signed with: $DEV_ID_IDENTITY"

  ZIP="build/Renamatic.zip"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Submitting to Apple notary service (waits for the result)…"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"

  # re-zip the stapled app as the distributable artifact
  ditto -c -k --keepParent "$APP" "build/Renamatic-$(defaults read "$PWD/$APP/Contents/Info" CFBundleShortVersionString).zip"
  spctl --assess --type execute "$APP" && echo "Gatekeeper: accepted"
else
  codesign --force --deep --sign - "$APP"
fi

echo "Built $APP"
