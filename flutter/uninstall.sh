#!/bin/bash
#
# BlueSound Controller - Linux Uninstallation Script
#
# Usage:
#   ./uninstall.sh          - Uninstall user installation
#   sudo ./uninstall.sh -s  - Uninstall system-wide installation
#

set -e

APP_NAME="bluesoundplayer"
APP_DISPLAY_NAME="BlueSound Controller"

# Determine installation type
SYSTEM_WIDE=false
if [ "$1" = "-s" ] || [ "$1" = "--system" ]; then
    SYSTEM_WIDE=true
fi

if [ "$SYSTEM_WIDE" = true ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Error: System-wide uninstallation requires root privileges."
        echo "Please run: sudo $0 -s"
        exit 1
    fi
    INSTALL_DIR="/opt/$APP_NAME"
    DESKTOP_DIR="/usr/share/applications"
    ICON_DIR="/usr/share/icons/hicolor"
    echo "Uninstalling system-wide installation..."
else
    INSTALL_DIR="$HOME/.local/share/$APP_NAME"
    DESKTOP_DIR="$HOME/.local/share/applications"
    ICON_DIR="$HOME/.local/share/icons/hicolor"
    echo "Uninstalling user installation..."
fi

# Remove application files
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing application files from $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
else
    echo "Application directory not found: $INSTALL_DIR"
fi

# Remove desktop entry
DESKTOP_FILE="$DESKTOP_DIR/$APP_NAME.desktop"
if [ -f "$DESKTOP_FILE" ]; then
    echo "Removing desktop entry..."
    rm -f "$DESKTOP_FILE"
else
    echo "Desktop entry not found: $DESKTOP_FILE"
fi

# Remove icons
echo "Removing icons..."
for SIZE in 16 24 32 48 64 128 256 512; do
    ICON_FILE="$ICON_DIR/${SIZE}x${SIZE}/apps/$APP_NAME.png"
    if [ -f "$ICON_FILE" ]; then
        rm -f "$ICON_FILE"
    fi
done

# Update icon cache
if [ "$SYSTEM_WIDE" = true ]; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
else
    gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true
fi

# Update desktop database
if [ "$SYSTEM_WIDE" = true ]; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
else
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo ""
echo "=========================================="
echo " Uninstallation complete!"
echo "=========================================="
echo ""
echo " '$APP_DISPLAY_NAME' has been removed from your system."
echo ""
