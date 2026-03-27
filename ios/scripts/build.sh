#!/usr/bin/env bash
# =============================================================================
# build.sh - Build the app from the command line (no Xcode GUI needed)
# Usage: bash scripts/build.sh [debug|adhoc|release]
# =============================================================================

set -euo pipefail

BUILD_TYPE="${1:-debug}"
PROJECT="DeskBoard.xcodeproj"
SCHEME="DeskBoard"

# Ensure Xcode project exists
if [ ! -d "$PROJECT" ]; then
    echo "🔧 Generating Xcode project..."
    mint run xcodegen generate --spec project.yml
fi

case "$BUILD_TYPE" in
    debug)
        echo "🏗 Building Debug (development)..."
        bundle exec fastlane build_debug
        ;;
    adhoc)
        echo "🏗 Building AdHoc distribution..."
        bundle exec fastlane build_adhoc
        ;;
    release)
        echo "🏗 Building Release (App Store)..."
        bundle exec fastlane build_release
        ;;
    *)
        echo "❌ Unknown build type: $BUILD_TYPE"
        echo "Usage: $0 [debug|adhoc|release]"
        exit 1
        ;;
esac

echo "✅ Build complete. Output: build/"