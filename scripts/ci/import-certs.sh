#!/bin/bash
# CI: load the Developer ID Application certificate (base64 .p12 secret) into a throwaway
# keychain, validate the notary API key, and export settings for build-release.sh.
# AIDEV-NOTE: adapted from murmur/scripts/ci/import-certs.sh; MacPing ships no PKG, so no Installer cert.
set -euo pipefail
: "${RUNNER_TEMP:?}" "${DEVELOPER_ID_APP_P12:?missing secret}" "${DEVELOPER_ID_APP_PASSWORD:?missing secret}"
: "${ASC_API_KEY_P8:?missing secret}" "${ASC_API_KEY_ID:?missing secret}" "${ASC_API_ISSUER_ID:?missing secret}"

KC="$RUNNER_TEMP/macping-signing.keychain-db"
KC_PASS=$(uuidgen)
security create-keychain -p "$KC_PASS" "$KC"
security set-keychain-settings -lut 21600 "$KC"
security unlock-keychain -p "$KC_PASS" "$KC"

# Apple's Developer ID intermediates: without them `find-identity -v` silently drops the identity.
for ca in DeveloperIDG2CA DeveloperIDCA; do
  curl -fsSL "https://www.apple.com/certificateauthority/$ca.cer" -o "$RUNNER_TEMP/$ca.cer" \
    && security import "$RUNNER_TEMP/$ca.cer" -k "$KC" >/dev/null 2>&1 || true
done

P12="$RUNNER_TEMP/cert-$RANDOM.p12"
echo "$DEVELOPER_ID_APP_P12" | base64 --decode > "$P12"
security import "$P12" -k "$KC" -P "$DEVELOPER_ID_APP_PASSWORD" -T /usr/bin/codesign
rm -f "$P12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PASS" "$KC" >/dev/null
# shellcheck disable=SC2046
security list-keychains -d user -s "$KC" $(security list-keychains -d user | tr -d '"')

APP_ID=$(security find-identity -v -p codesigning "$KC" | awk -F'"' '/Developer ID Application/ {print $2; exit}')
if [[ -z "$APP_ID" ]]; then
  security find-identity "$KC"
  echo "::error title=No valid Developer ID Application identity::Check DEVELOPER_ID_APP_P12 / DEVELOPER_ID_APP_PASSWORD"
  exit 1
fi
echo "MACPING_SIGN_IDENTITY=$APP_ID" >> "$GITHUB_ENV"

# Accept the .p8 as pasted text or base64 of the file.
KEY="$RUNNER_TEMP/AuthKey.p8"
if [[ "$ASC_API_KEY_P8" == *"BEGIN PRIVATE KEY"* ]]; then
  printf '%s\n' "$ASC_API_KEY_P8" > "$KEY"
else
  echo "$ASC_API_KEY_P8" | base64 --decode > "$KEY" 2>/dev/null || printf '%s\n' "$ASC_API_KEY_P8" > "$KEY"
fi
# Validate now so a bad key (or an unsigned Apple agreement, HTTP 403) fails here, legibly.
if ! CHECK=$(xcrun notarytool history --key "$KEY" --key-id "$ASC_API_KEY_ID" --issuer "$ASC_API_ISSUER_ID" 2>&1 | tail -5); then
  echo "$CHECK"
  echo "::error title=Notary API key rejected::${CHECK//$'\n'/%0A}"
  exit 1
fi
{ echo "NOTARY_KEY_PATH=$KEY"; echo "NOTARY_KEY_ID=$ASC_API_KEY_ID"; echo "NOTARY_ISSUER=$ASC_API_ISSUER_ID"; } >> "$GITHUB_ENV"
echo "::notice title=Signing setup::Identity: $APP_ID · notary key validated"
