#!/bin/bash
set -e

APP_NAME="BlueSound Controller"
INSTALL_DIR="/opt/bluesound-controller"
BIN_LINK="/usr/local/bin/bluesound-controller"
DESKTOP_FILE="/usr/share/applications/bluesound-controller.desktop"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo ./install.sh"
  exit 1
fi

echo "Installing $APP_NAME..."

# Remove previous installation
rm -rf "$INSTALL_DIR"
rm -f "$BIN_LINK"
rm -f "$DESKTOP_FILE"

# Copy app bundle
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR"/bluesoundplayer_flutter "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR"/lib "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR"/data "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/bluesoundplayer_flutter"

# Create symlink
ln -sf "$INSTALL_DIR/bluesoundplayer_flutter" "$BIN_LINK"

# Create .desktop file
cat > "$DESKTOP_FILE" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=BlueSound Controller
Comment=Multi-room audio controller for BluOS and Sonos
Exec=/opt/bluesound-controller/bluesoundplayer_flutter
Icon=audio-speakers
Terminal=false
Categories=AudioVideo;Audio;
DESKTOP

echo "Installed to $INSTALL_DIR"
echo "Run with: bluesound-controller"
echo "Or find '$APP_NAME' in your application menu."
