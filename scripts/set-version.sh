#!/bin/bash
set -euo pipefail

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

echo "Setting version to $VERSION"

# Update MARKETING_VERSION in project.pbxproj
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" MacPing.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION (build number), which Sparkle compares to decide what is newer.
# AIDEV-NOTE: must be monotonic across semver; the old "strip the dots" scheme made 2.0.0 (200) < 1.10.0 (1100).
IFS=. read -r MAJOR MINOR PATCH <<< "${VERSION%%[-+]*}"
BUILD_NUMBER=$(( 10#${MAJOR:-0} * 1000000 + 10#${MINOR:-0} * 1000 + 10#${PATCH:-0} ))
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" MacPing.xcodeproj/project.pbxproj

echo "Version set to $VERSION (build $BUILD_NUMBER)"
