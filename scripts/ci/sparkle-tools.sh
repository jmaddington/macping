#!/bin/bash
# Fetch Sparkle's command-line tools (sign_update, generate_keys), pinned by version and SHA-256,
# unpack them into a fresh temp directory, and print its bin directory.
# AIDEV-NOTE: keep SPARKLE_VERSION in step with the Sparkle package version in project.pbxproj.
set -euo pipefail
cd "$(dirname "$0")/../.."
SPARKLE_VERSION=2.10.1
SPARKLE_SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
CACHE="build/sparkle-tools"
TARBALL="$CACHE/Sparkle-$SPARKLE_VERSION.tar.xz"
mkdir -p "$CACHE"
[[ -f "$TARBALL" ]] || curl -fsSL -o "$TARBALL" \
  "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
# AIDEV-NOTE: verify on every call and unpack into a fresh temp dir, so a tampered cache can't be reused.
echo "$SPARKLE_SHA256  $TARBALL" | shasum -a 256 -c - >/dev/null || { echo "Sparkle tools checksum mismatch" >&2; exit 1; }
OUT=$(mktemp -d)
tar -xJf "$TARBALL" -C "$OUT" bin
echo "$OUT/bin"
