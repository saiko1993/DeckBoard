#!/usr/bin/env bash
# =============================================================================
# setup.sh - One-time project bootstrap script
# Run this after cloning the repo to set up the development environment.
# Usage: bash scripts/setup.sh
# =============================================================================

set -euo pipefail

echo "🚀 Setting up DeskBoard development environment..."

# 1. Check for Homebrew
if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew is required. Install from https://brew.sh"
    exit 1
fi

# 2. Install Mint (Swift tool manager)
if ! command -v mint &>/dev/null; then
    echo "📦 Installing Mint..."
    brew install mint
fi

# 3. Install Ruby tool versions (rbenv recommended)
if ! command -v rbenv &>/dev/null; then
    echo "📦 Installing rbenv..."
    brew install rbenv
    rbenv init
fi

# 4. Bootstrap Mint tools (XcodeGen, SwiftLint, SwiftFormat)
echo "🔧 Bootstrapping Mint tools..."
mint bootstrap

# 5. Install Ruby gems (Fastlane)
echo "💎 Installing Ruby gems..."
if ! command -v bundle &>/dev/null; then
    gem install bundler --no-document
fi
bundle install

# 6. Generate Xcode project
echo "📱 Generating Xcode project..."
mint run xcodegen generate --spec project.yml

# 7. Copy .env.example if .env doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "⚠️  Created .env from .env.example — please fill in your credentials!"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Fill in .env with your Apple Developer credentials"
echo "  2. Run 'bundle exec fastlane sync_dev_certs' to sync certificates"
echo "  3. Open DeskBoard.xcodeproj in Xcode to develop"
echo "  4. Or run 'bundle exec fastlane build_debug' to build from command line"