#!/bin/bash
# Build, sign, notarize and package MacPing into release/MacPing-<v>.{zip,dmg} + SHA256SUMS.txt.
#
#   ./scripts/build-release.sh 1.2.0
#
# Env (all optional locally; required on CI, where an unsigned release is refused):
#   MACPING_SIGN_IDENTITY   "Developer ID Application: ..." (default: first one in the keychain, else ad-hoc)
#   NOTARY_KEY_PATH NOTARY_KEY_ID NOTARY_ISSUER   App Store Connect API key -> notarize + staple
#   NOTARY_PROFILE          or a local `notarytool store-credentials` profile instead of the key
# Requires: brew install create-dmg
# AIDEV-NOTE: semantic-release runs this as a *prepare* step so a signing/notarization failure aborts
# before the release commit and tag are pushed.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh

VERSION="${1:-}"
[[ -n "$VERSION" ]] || { echo "Usage: $0 <version>"; exit 1; }
echo "Building MacPing v$VERSION"

IDENTITY=${MACPING_SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}')}
if [[ -n "${GITHUB_ACTIONS:-}" && ( -z "$IDENTITY" || -z "${NOTARY_KEY_PATH:-}" ) ]]; then
  annotate error "Incomplete signing setup" "Need MACPING_SIGN_IDENTITY and NOTARY_KEY_*. Refusing to ship an unnotarized release."
  echo "Refusing to build an unsigned/unnotarized release on CI"; exit 1
fi

# Build unsigned, then sign explicitly: the project uses Automatic signing with no team set.
# A normal run takes about a minute; retry once if it stalls or a package download fails.
build_app() {
  watched "xcodebuild" "${XCODEBUILD_TIMEOUT:-300}" xcodebuild -project MacPing.xcodeproj -scheme MacPing \
    -configuration Release -derivedDataPath build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO clean build
}
build_app || { echo "xcodebuild did not succeed, retrying once"; build_app; }

APP_PATH="build/Build/Products/Release/MacPing.app"
[[ -d "$APP_PATH" ]] || { echo "Error: App not found at $APP_PATH"; exit 1; }

rm -rf release && mkdir -p release
ZIP="release/MacPing-${VERSION}.zip"
DMG="release/MacPing-${VERSION}.dmg"

# AIDEV-NOTE: sign Sparkle inside-out (XPCs, Autoupdate, Updater.app, framework) BEFORE the app; never --deep,
# which would strip Downloader.xpc's entitlements. Order/flags follow Sparkle's "Distributing outside Xcode" docs.
SIGN_AS=${IDENTITY:--}
TS=(); [[ -n "$IDENTITY" ]] && TS=(--timestamp)
SP="$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B"
[[ -d "$SP" ]] || { annotate error "Sparkle missing" "Sparkle.framework not embedded in $APP_PATH"; exit 1; }
cs() { codesign -f -s "$SIGN_AS" -o runtime ${TS[@]+"${TS[@]}"} "$@"; }   # bash 3.2-safe empty array
step "Signing Sparkle Installer.xpc" cs "$SP/XPCServices/Installer.xpc"
step "Signing Sparkle Downloader.xpc" cs --preserve-metadata=entitlements "$SP/XPCServices/Downloader.xpc"
step "Signing Sparkle Autoupdate" cs "$SP/Autoupdate"
step "Signing Sparkle Updater.app" cs "$SP/Updater.app"
step "Signing Sparkle.framework" cs "$APP_PATH/Contents/Frameworks/Sparkle.framework"
[[ -z "$IDENTITY" ]] && echo "No Developer ID identity: ad-hoc signing (local testing only)"
step "Signing MacPing.app" cs --entitlements MacPing/MacPing.entitlements "$APP_PATH"
step "Verifying signature" codesign --verify --deep --strict --verbose=2 "$APP_PATH"

NOTARIZE=""
[[ -n "$IDENTITY" && -n "${NOTARY_KEY_PATH:-}${NOTARY_PROFILE:-}" ]] && NOTARIZE=1

if [[ -n "$NOTARIZE" ]]; then
  # Notarize the app itself (submitted as a zip) and staple it, so the ZIP download works offline too.
  echo "Notarizing MacPing.app"
  ditto -c -k --keepParent "$APP_PATH" build/notarize-app.zip
  notarize build/notarize-app.zip "$APP_PATH"
  rm -f build/notarize-app.zip
fi

echo "Creating ZIP archive..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

echo "Creating DMG..."
step "create-dmg" create-dmg \
  --volname "MacPing" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MacPing.app" 150 190 \
  --hide-extension "MacPing.app" \
  --app-drop-link 450 185 \
  --no-internet-enable \
  "$DMG" "$APP_PATH"
[[ -n "$IDENTITY" ]] && step "Signing DMG" codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [[ -n "$NOTARIZE" ]]; then
  echo "Notarizing $(basename "$DMG")"
  notarize "$DMG"
  step "Gatekeeper check (app)" spctl --assess --type execute -v "$APP_PATH"
  step "Gatekeeper check (DMG)" spctl --assess --type open --context context:primary-signature -v "$DMG"
else
  echo "Skipping notarization (no Developer ID / notary key)"
fi

(cd release && shasum -a 256 ./*.zip ./*.dmg | sed 's| \./| |' > SHA256SUMS.txt)
# Read by the "Sparkle appcast" CI step, which signs the DMG after semantic-release publishes.
echo "$VERSION" > release/VERSION
echo "Release artifacts created:"
ls -la release/
