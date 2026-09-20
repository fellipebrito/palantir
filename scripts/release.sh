#!/usr/bin/env bash
# Build, sign, notarize, staple, and package Palantír as a DMG.
#
# Everything here is automatic EXCEPT the certificate, which Apple will only let
# the Account Holder create. See README, "The certificate".
#
#   ./scripts/release.sh               signed + notarized (needs the cert and ASC key)
#   ./scripts/release.sh --no-notarize signed, not notarized (no ASC key needed)
#   ./scripts/release.sh --unsigned    ad-hoc, for local testing only
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APPDIR="$HERE/../app"
DIST="$HERE/../dist"
# The team id is public by nature: it is embedded in every signed binary. The
# App Store Connect key id and issuer are not, and neither is the .p8 itself,
# which stays at ~/.appstoreconnect/private_keys/ and never enters this repo.
TEAM="AR7DXKP4VP"

MODE="release"
case "${1:-}" in
  --unsigned)    MODE="unsigned" ;;
  --no-notarize) MODE="signed" ;;
  "")            MODE="release" ;;
  *) echo "unknown flag: $1" >&2; exit 2 ;;
esac

# Checked before the build rather than after it, so a missing key costs a second
# instead of a full compile and a signature.
if [ "$MODE" = "release" ]; then
  : "${ASC_KEY_ID:?set ASC_KEY_ID to the App Store Connect key id (or pass --no-notarize)}"
  : "${ASC_ISSUER:?set ASC_ISSUER to the App Store Connect issuer id (or pass --no-notarize)}"
  P8="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
  [ -f "$P8" ] || { echo "no private key at $P8" >&2; exit 1; }
fi

rm -rf "$DIST"; mkdir -p "$DIST"
cd "$APPDIR"
xcodegen generate >/dev/null

if [ "$MODE" = "unsigned" ]; then
  xcodebuild -project Palantir.xcodeproj -scheme Palantir -configuration Release \
    -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build >/dev/null
else
  xcodebuild -project Palantir.xcodeproj -scheme Palantir -configuration Release \
    -derivedDataPath build/dd \
    CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM" build >/dev/null
fi

APP="$(find build/dd/Build/Products/Release -maxdepth 1 -name 'Palantir.app' | head -1)"
[ -n "$APP" ] || { echo "no app built" >&2; exit 1; }
cp -R "$APP" "$DIST/Palantir.app"

# Read back from the bundle rather than from project.yml: the version that goes
# in the DMG name is then the version that is actually inside it.
PLIST="$DIST/Palantir.app/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
DMG="$DIST/Palantir-$VERSION.dmg"

if [ "$MODE" != "unsigned" ]; then
  # Hardened runtime is required for notarization and is set in project.yml.
  codesign --force --options runtime --timestamp \
    --sign "Developer ID Application" "$DIST/Palantir.app"
  codesign --verify --strict --verbose=2 "$DIST/Palantir.app"
fi

# A DMG rather than a zip: people get the drag-to-Applications gesture, and the
# notarization ticket can be stapled to the DMG itself. Imaged from a staging
# folder so nothing else in dist/ ends up inside the image.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$DIST/Palantir.app" "$STAGE/Palantir.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Palantír" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [ "$MODE" = "release" ]; then
  codesign --force --sign "Developer ID Application" "$DMG"
  xcrun notarytool submit "$DMG" \
    --key "$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8" \
    --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER" --wait
  # Stapling is what lets it open on a Mac with no network.
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo
  echo "  Signed and notarized: $DMG  ($VERSION build $BUILD)"
  echo "  Verify the way someone else's Mac will:"
  echo "    spctl -a -vvv -t install $DMG"
  echo "  Then publish:"
  echo "    gh release create v$VERSION $DMG --title \"Palantír $VERSION\" --notes \"...\""
elif [ "$MODE" = "signed" ]; then
  codesign --force --sign "Developer ID Application" "$DMG"
  echo
  echo "  Signed, NOT notarized: $DMG  ($VERSION build $BUILD)"
  echo "  Gatekeeper will warn on a Mac that has never seen it. Re-run without"
  echo "  --no-notarize once ASC_KEY_ID and ASC_ISSUER are set."
else
  echo
  echo "  UNSIGNED build: $DMG  ($VERSION build $BUILD)"
  echo "  Gatekeeper will block it. Local testing only."
fi
