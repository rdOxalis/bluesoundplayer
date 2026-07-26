#!/bin/bash
#
# BlueSound Controller - Uninstall
#

set -e

echo "Uninstalling BlueSound Controller..."

# Remove app files
rm -rf "$HOME/.local/share/bluesound-controller"
rm -rf "$HOME/.local/share/bluesoundplayer"

# Remove bin symlink
rm -f "$HOME/.local/bin/bluesound-controller"

# Remove desktop entries (old and new naming)
rm -f "$HOME/.local/share/applications/com.bluesound.bluesoundplayer_flutter.desktop"
rm -f "$HOME/.local/share/applications/bluesound-controller.desktop"
rm -f "$HOME/.local/share/applications/bluesoundplayer.desktop"

# Remove icons (both old and new naming)
ICON_BASE="$HOME/.local/share/icons/hicolor"
for size in 16 24 32 48 64 128 256 512; do
    rm -f "$ICON_BASE/${size}x${size}/apps/bluesound-controller.png"
    rm -f "$ICON_BASE/${size}x${size}/apps/bluesoundplayer.png"
done
gtk-update-icon-cache -f -t "$ICON_BASE" 2>/dev/null || true

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "BlueSound Controller has been removed."
