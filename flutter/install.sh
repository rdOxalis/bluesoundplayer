#!/bin/bash
#
# BlueSound Controller - Install from source (developer convenience)
#
# Builds the app (if needed) and installs for the current user.
# For distributable packages, use: ./package-linux.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR/build/linux/x64/release/bundle"

# Build if bundle doesn't exist
if [ ! -f "$BUNDLE_DIR/bluesoundplayer_flutter" ]; then
    echo "Building Flutter app..."
    cd "$SCRIPT_DIR"
    flutter build linux --release
fi

# Clean up any previous installations (old naming)
rm -f "$HOME/.local/share/applications/bluesoundplayer.desktop"
rm -rf "$HOME/.local/share/bluesoundplayer"
find "$HOME/.local/share/icons" -name "bluesoundplayer.*" -delete 2>/dev/null || true

# Use the linux-install script logic
INSTALL_DIR="$HOME/.local/share/bluesound-controller"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_BASE="$HOME/.local/share/icons/hicolor"
ICON_SRC="$SCRIPT_DIR/assets/icon/app_icon.png"
# Must match APPLICATION_ID in linux/CMakeLists.txt: Wayland compositors
# (e.g. KWin) resolve a running window's icon by matching its app_id against
# a desktop file of the same name, not via gtk_window_set_icon_from_file
# (X11-only). Keeping this in sync keeps the Alt+Tab/window-switcher icon
# correct.
APP_ID="com.bluesound.bluesoundplayer_flutter"

echo "Installing BlueSound Controller..."

# Remove previous installation
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/bluesound-controller"
rm -f "$DESKTOP_DIR/bluesound-controller.desktop"
rm -f "$DESKTOP_DIR/$APP_ID.desktop"
find "$HOME/.local/share/icons" -name "bluesound-controller.*" -delete 2>/dev/null || true

# Copy app bundle
mkdir -p "$INSTALL_DIR"
cp -r "$BUNDLE_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bluesoundplayer_flutter"

# Create bin symlink
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bluesoundplayer_flutter" "$BIN_DIR/bluesound-controller"

# Install icons
if [ -f "$ICON_SRC" ]; then
    if command -v convert &>/dev/null; then
        for size in 16 24 32 48 64 128 256; do
            ICON_DIR="$ICON_BASE/${size}x${size}/apps"
            mkdir -p "$ICON_DIR"
            convert "$ICON_SRC" -resize ${size}x${size} "$ICON_DIR/bluesound-controller.png"
        done
    else
        mkdir -p "$ICON_BASE/256x256/apps"
        cp "$ICON_SRC" "$ICON_BASE/256x256/apps/bluesound-controller.png"
    fi
    gtk-update-icon-cache -f -t "$ICON_BASE" 2>/dev/null || true
fi

# Create .desktop file. Filename must equal the app_id for Wayland icon
# matching (see APP_ID comment above).
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/$APP_ID.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=BlueSound Controller
Comment=Multi-room audio controller for BluOS and Sonos
Exec=$INSTALL_DIR/bluesoundplayer_flutter
Icon=bluesound-controller
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupWMClass=$APP_ID
Keywords=audio;music;sonos;bluos;multiroom;speaker;
DESKTOP

update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

echo ""
echo "Installed to $INSTALL_DIR"
echo "Run with: bluesound-controller"
echo "Or find 'BlueSound Controller' in your application menu."
echo ""
