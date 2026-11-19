#!/bin/bash
# Fetch Sparkle's command-line tools (sign_update, generate_keys) into build/sparkle-tools,
# pinned by version and SHA-256, and print the bin directory.
# AIDEV-NOTE: keep SPARKLE_VERSION in step with the Sparkle package version in project.pbxproj.
set -euo pipefail
cd "$(dirname "$0")/../.."
SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
DIR="build/sparkle-tools/$SPARKLE_VERSION"
if [[ ! -x "$DIR/bin/sign_update" ]]; then
  mkdir -p "$DIR"
  TARBALL="$DIR/Sparkle-$SPARKLE_VERSION.tar.xz"
  curl -fsSL -o "$TARBALL" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
  echo "$SPARKLE_SHA256  $TARBALL" | shasum -a 256 -c - >/dev/null || { echo "Sparkle tools checksum mismatch" >&2; exit 1; }
  tar -xJf "$TARBALL" -C "$DIR" bin
fi
echo "$PWD/$DIR/bin"
