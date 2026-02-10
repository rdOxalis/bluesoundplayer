BlueSound Controller - Linux Desktop App
=========================================

Multi-room audio controller for BluOS and Sonos devices.

Requirements
------------
- Linux x86_64 with a graphical desktop (GNOME, KDE, XFCE, etc.)
- GTK 3 (pre-installed on all common Linux desktops)

Installation
------------
  tar xzf BlueSoundController-linux-x64.tar.gz
  sudo ./install.sh

This installs to /opt/bluesound-controller/ and creates:
- Command:    bluesound-controller
- App menu:   "BlueSound Controller"

Run without installing
----------------------
  tar xzf BlueSoundController-linux-x64.tar.gz
  ./bluesoundplayer_flutter

Uninstall
---------
  sudo rm -rf /opt/bluesound-controller
  sudo rm -f /usr/local/bin/bluesound-controller
  sudo rm -f /usr/share/applications/bluesound-controller.desktop
