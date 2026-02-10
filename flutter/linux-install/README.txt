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
  ./install.sh

No sudo required. Installs to ~/.local/ and creates:
- Command:    bluesound-controller  (in ~/.local/bin/)
- App menu:   "BlueSound Controller"

Run without installing
----------------------
  tar xzf BlueSoundController-linux-x64.tar.gz
  ./bluesoundplayer_flutter

Uninstall
---------
  rm -rf ~/.local/share/bluesound-controller
  rm -f ~/.local/bin/bluesound-controller
  rm -f ~/.local/share/applications/bluesound-controller.desktop
  rm -f ~/.local/share/icons/hicolor/256x256/apps/bluesound-controller.png
