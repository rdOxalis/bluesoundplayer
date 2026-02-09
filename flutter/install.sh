#!/bin/bash
#
# BlueSound Controller - Linux Installation Script
#
# Usage:
#   ./install.sh          - Install for current user (recommended)
#   sudo ./install.sh -s  - Install system-wide (for all users)
#

set -e

APP_NAME="bluesoundplayer"
APP_DISPLAY_NAME="BlueSound Controller"
APP_COMMENT="Multi-Room Audio Controller for BluOS and Sonos"
APP_CATEGORIES="AudioVideo;Audio;Player;"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR/build/linux/x64/release/bundle"
ICON_SOURCE="$SCRIPT_DIR/assets/icon/app_icon.png"

# Check if bundle exists
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Error: Release bundle not found at $BUNDLE_DIR"
    echo "Please run 'flutter build linux --release' first."
    exit 1
fi

# Check if icon exists
if [ ! -f "$ICON_SOURCE" ]; then
    echo "Warning: Icon not found at $ICON_SOURCE"
    ICON_SOURCE=""
fi

# Determine installation type
SYSTEM_WIDE=false
if [ "$1" = "-s" ] || [ "$1" = "--system" ]; then
    SYSTEM_WIDE=true
fi

if [ "$SYSTEM_WIDE" = true ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Error: System-wide installation requires root privileges."
        echo "Please run: sudo $0 -s"
        exit 1
    fi
    INSTALL_DIR="/opt/$APP_NAME"
    DESKTOP_DIR="/usr/share/applications"
    ICON_DIR="/usr/share/icons/hicolor"
    echo "Installing system-wide to $INSTALL_DIR..."
else
    INSTALL_DIR="$HOME/.local/share/$APP_NAME"
    DESKTOP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor"
    echo "Installing for current user to $INSTALL_DIR..."
fi

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR"

# Copy application files
echo "Copying application files..."
cp -r "$BUNDLE_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bluesoundplayer_flutter"

# Install icon in multiple sizes
if [ -n "$ICON_SOURCE" ]; then
    echo "Installing icon..."
    for SIZE in 16 24 32 48 64 128 256 512; do
        ICON_TARGET_DIR="$ICON_DIR/${SIZE}x${SIZE}/apps"
        mkdir -p "$ICON_TARGET_DIR"

        # Check if convert (ImageMagick) is available for resizing
        if command -v convert &> /dev/null; then
            convert "$ICON_SOURCE" -resize ${SIZE}x${SIZE} "$ICON_TARGET_DIR/$APP_NAME.png"
        else
            # Just copy the original icon if ImageMagick is not available
            cp "$ICON_SOURCE" "$ICON_TARGET_DIR/$APP_NAME.png"
        fi
    done

    # Update icon cache
    if [ "$SYSTEM_WIDE" = true ]; then
        gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    else
        gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true
    fi

    ICON_NAME="$APP_NAME"
else
    ICON_NAME="audio-speakers"
fi

# Create desktop entry
echo "Creating desktop entry..."
cat > "$DESKTOP_DIR/$APP_NAME.desktop" << EOF
[Desktop Entry]
Name=$APP_DISPLAY_NAME
Comment=$APP_COMMENT
Exec=$INSTALL_DIR/bluesoundplayer_flutter
Icon=$ICON_NAME
Type=Application
Categories=$APP_CATEGORIES
Terminal=false
StartupWMClass=bluesoundplayer_flutter
Keywords=audio;music;sonos;bluos;multiroom;speaker;
EOF

# Update desktop database
echo "Updating desktop database..."
if [ "$SYSTEM_WIDE" = true ]; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
else
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo " Installation complete!"
echo "=========================================="
echo ""
echo " You can now find '$APP_DISPLAY_NAME' in your application menu"
echo " or run it directly with: $INSTALL_DIR/bluesoundplayer_flutter"
echo ""
echo " To uninstall, run: $(dirname "$0")/uninstall.sh"
echo ""
