#!/bin/bash
#
# BlueSound Controller - Package for Linux distribution
#
# Creates a self-contained tar.gz that users can extract and install with:
#   tar xzf BlueSoundController-linux-x64.tar.gz
#   cd BlueSoundController-linux-x64
#   ./install.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR/build/linux/x64/release/bundle"
RELEASE_DIR="$SCRIPT_DIR/../release"
PKG_NAME="BlueSoundController-linux-x64"
STAGING_DIR="$SCRIPT_DIR/build/$PKG_NAME"

# Build
echo "Building Flutter app..."
cd "$SCRIPT_DIR"
flutter build linux --release

if [ ! -f "$BUNDLE_DIR/bluesoundplayer_flutter" ]; then
    echo "Error: Build failed, no binary found."
    exit 1
fi

# Stage package contents
echo "Packaging..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy bundle (binary, libs, data)
cp -r "$BUNDLE_DIR"/* "$STAGING_DIR/"

# Copy install script and README from linux-install template
cp "$SCRIPT_DIR/linux-install/install.sh" "$STAGING_DIR/"
cp "$SCRIPT_DIR/linux-install/README.txt" "$STAGING_DIR/"

# Create tar.gz
mkdir -p "$RELEASE_DIR"
tar czf "$RELEASE_DIR/$PKG_NAME.tar.gz" -C "$SCRIPT_DIR/build" "$PKG_NAME"

# Cleanup
rm -rf "$STAGING_DIR"

SIZE=$(du -h "$RELEASE_DIR/$PKG_NAME.tar.gz" | cut -f1)
echo ""
echo "Package created: release/$PKG_NAME.tar.gz ($SIZE)"
echo ""
echo "User installs with:"
echo "  tar xzf $PKG_NAME.tar.gz"
echo "  cd $PKG_NAME"
echo "  ./install.sh"
