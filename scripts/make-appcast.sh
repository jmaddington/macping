#!/bin/bash
# Sign a release DMG for Sparkle and write appcast.xml next to it.
#
#   SPARKLE_ED_PRIVATE_KEY=… ./scripts/make-appcast.sh release/MacPing-1.2.0.dmg
#
# Version and build number come from the built app (build/Build/Products/Release/MacPing.app), so the
# appcast always matches what users install. Sparkle compares sparkle:version to CFBundleVersion.
# AIDEV-NOTE: run only on the final, notarized + stapled DMG; re-signing it afterwards breaks the EdDSA signature.
# AIDEV-NOTE: CI runs this as its own step after semantic-release, so the key never reaches npm code.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh
DMG=${1:?usage: make-appcast.sh <dmg>}
[[ -f "$DMG" ]] || { echo "no such file: $DMG"; exit 1; }
: "${SPARKLE_ED_PRIVATE_KEY:?set SPARKLE_ED_PRIVATE_KEY}"
PLIST=build/Build/Products/Release/MacPing.app/Contents/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST")
REPO=${GITHUB_REPOSITORY:-jmaddington/macping}
BIN=$(scripts/ci/sparkle-tools.sh)

KEYFILE=$(mktemp)
chmod 600 "$KEYFILE"
trap 'rm -f "${KEYFILE:?}"' EXIT
printf '%s\n' "$SPARKLE_ED_PRIVATE_KEY" > "$KEYFILE"
SIG=$("$BIN/sign_update" --ed-key-file "$KEYFILE" "$DMG")
# sign_update prints: sparkle:edSignature="…" length="…"
[[ "$SIG" == *'sparkle:edSignature="'*'length="'* ]] || { annotate error "sign_update failed" "$SIG"; echo "$SIG"; exit 1; }

NAME=$(basename "$DMG")
URL="https://github.com/$REPO/releases/download/v$VERSION/$NAME"
NOTES="https://github.com/$REPO/releases/tag/v$VERSION"
DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")
OUT="$(dirname "$DMG")/appcast.xml"
cat > "$OUT" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MacPing</title>
    <link>https://github.com/$REPO</link>
    <item>
      <title>MacPing $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>$NOTES</sparkle:fullReleaseNotesLink>
      <description><![CDATA[<p>MacPing $VERSION is available. <a href="$NOTES">Release notes</a></p>]]></description>
      <enclosure url="$URL" type="application/octet-stream" $SIG />
    </item>
  </channel>
</rss>
XML
xmllint --noout "$OUT"
echo "Wrote $OUT (v$VERSION build $BUILD -> $URL)"
