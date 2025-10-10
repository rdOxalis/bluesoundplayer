# 🎵 Multi-Room Player for Bluesound and Sonos Devices

A Multi-Room preset player for the command line with **interactive and non-interactive modes**, multi-language support, and automatic network scanning.

## ✨ Features

- 🔍 **Automatic Network Scanning** - Finds all BluOS and Sonos players on your network
- 🌍 **Multi-Language Support** - English, German, and Swahili
- 🎮 **Two Control Modes** - Interactive TUI and CLI command mode
- 📱 **Multiple Player Support** - Control different players easily
- 🎵 **Full Playback Control** - Play, pause, stop, volume, and preset management
- 🔗 **Player Grouping** - Group BluOS players for synchronized playback

## 📦 Installation

1. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd bluesoundplayer
   ```

2. **Build the application:**
   ```bash
   # Build for your current platform
   cd src && go build -o ../bluesoundplayer *.go
   
   # Or use the Makefile for multiple platforms
   make all
   ```

## 🚀 Usage

### Interactive Mode (TUI)

Start the application without flags to enter interactive mode:

```bash
./bluesoundplayer
```

The app will:
1. Scan your network for players
2. Let you select a player
3. Enter an interactive interface with real-time status updates

### Non-Interactive Mode (CLI)

Use the `-c` flag for single commands:

```bash
# List all available players
./bluesoundplayer -list

# Show status of first player
./bluesoundplayer -c -status

# Play preset 3 on specific player
./bluesoundplayer -c -ip 192.168.1.100 -preset 3

# Set volume to 75%
./bluesoundplayer -c -player 2 -volume 75

# Control playback
./bluesoundplayer -c -ip 192.168.1.100 -cmd play
./bluesoundplayer -c -ip 192.168.1.100 -cmd pause
./bluesoundplayer -c -ip 192.168.1.100 -cmd next
```

## 📋 Command Line Options

### Player Selection
- `-ip <address>` - Select player by IP address (e.g., 192.168.1.100)
- `-player <N>` - Select player by index from scan (1-N)
- `-type <bluos|sonos>` - Filter by device type

### Commands
- `-cmd play` - Start/resume playback
- `-cmd pause` - Pause playback
- `-cmd stop` - Stop playback
- `-cmd next` - Skip to next track
- `-cmd prev` - Go to previous track
- `-cmd status` - Show player status
- `-cmd presets` - List available presets/favorites

### Direct Actions
- `-preset <ID>` - Play preset/favorite by ID
- `-volume <0-100>` - Set volume level
- `-status` - Show player status (shortcut flag)
- `-presets` - List presets (shortcut flag)
- `-list` - List all players (shortcut flag)

### Options
- `-c` or `-command` - Enable non-interactive command mode
- `-help` - Show help message

## 💡 CLI Examples

### Discovery and Information

```bash
# List all players on the network
./bluesoundplayer -list

# Show detailed status of first player
./bluesoundplayer -c -status

# List presets for specific player
./bluesoundplayer -c -ip 192.168.1.100 -presets

# Find only BluOS devices
./bluesoundplayer -c -type bluos -list
```

### Playback Control

```bash
# Play preset 5 on first player
./bluesoundplayer -c -preset 5

# Play preset on specific player by IP
./bluesoundplayer -