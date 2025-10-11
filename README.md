# 🎵 Multi-Room Player for Bluesound and Sonos Devices

A Multi-Room audio controller with **interactive and non-interactive modes**, multi-language support, and automatic network scanning for BlueOS and Sonos devices.

## ✨ Features

- 🔍 **Automatic Network Scanning** - Finds all BluOS and Sonos players on your network
- 🌍 **Multi-Language Support** - English, German, and Swahili
- 🎮 **Two Control Modes** - Interactive TUI and CLI command mode
- 📱 **Multiple Player Support** - Control different players easily
- 🎵 **Full Playback Control** - Play, pause, stop, volume, and preset management
- 🔗 **Player Grouping** - Group BluOS players for synchronized playback
- 🔄 **Consistent Player Ordering** - Players always appear in the same order (sorted by IP)

## 📦 Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone <repository-url>
cd bluesoundplayer

# Build for your platform
cd src
go build -o ../bluesoundplayer *.go
```

### Option 2: Build for Multiple Platforms

```bash
# Using Makefile
make all              # Build for all platforms
make linux            # Linux AMD64
make windows          # Windows AMD64
make raspberry        # All Raspberry Pi variants
make apple            # macOS (Intel and Apple Silicon)

# Or using build script
./build_execs.sh
```

## 🚀 Usage Modes

### Interactive Mode (TUI)

Start without any flags to enter the **interactive mode**:

```bash
./bluesoundplayer
```

The app will:
1. Scan your network for all players
2. Let you select a player interactively
3. Display a live interface with status, presets, and commands

### Non-Interactive Mode (CLI)

Use the `-c` flag for **single command execution**:

```bash
./bluesoundplayer -c [options] [command]
```

**Important:** Most command-line options require the `-c` flag to enable CLI mode!

## 📋 Command Line Reference

### Quick Access Flags (No `-c` Required)

These flags work directly without `-c`:

| Flag | Description | Example |
|------|-------------|---------|
| `-list` | List all available players | `./bluesoundplayer -list` |
| `-help` | Show help message | `./bluesoundplayer -help` |
| `-status` | Show status of first player | `./bluesoundplayer -status` |
| `-presets` | Show presets of first player | `./bluesoundplayer -presets` |

**Note:** `-status` and `-presets` operate on the **first discovered player** (lowest IP address).

### Player Selection (Requires `-c`)

Choose which player to control:

| Flag | Description | Example |
|------|-------------|---------|
| `-ip <address>` | Select by IP address | `-c -ip 192.168.1.100` |
| `-player <N>` | Select by index (1-N) | `-c -player 2` |
| `-type <type>` | Filter by device type | `-c -type bluos` |

**Player Selection Priority:**
1. If `-ip` is specified → Uses that specific player
2. If `-player` is specified → Uses player at that index
3. If neither → Uses **first player found** (sorted by IP)

**Device Types:**
- `bluos` - BluOS devices (Bluesound, NAD, etc.)
- `sonos` - Sonos devices

### Playback Commands (Requires `-c`)

| Flag | Description | Example |
|------|-------------|---------|
| `-cmd play` | Start/resume playback | `-c -ip 192.168.1.100 -cmd play` |
| `-cmd pause` | Pause playback | `-c -player 1 -cmd pause` |
| `-cmd stop` | Stop playback | `-c -ip 192.168.1.100 -cmd stop` |
| `-cmd next` | Skip to next track | `-c -player 2 -cmd next` |
| `-cmd prev` | Previous track | `-c -ip 192.168.1.100 -cmd prev` |

### Direct Actions (Requires `-c`)

| Flag | Description | Example |
|------|-------------|---------|
| `-preset <ID>` | Play specific preset | `-c -ip 192.168.1.100 -preset 3` |
| `-volume <0-100>` | Set volume level | `-c -player 1 -volume 50` |

### Information Commands

| Flag | Description | Requires `-c` |
|------|-------------|---------------|
| `-cmd status` | Show player status | Yes |
| `-cmd presets` | List presets | Yes |
| `-cmd list` | List all players | Yes |
| `-status` | Show first player status | **No** |
| `-presets` | Show first player presets | **No** |
| `-list` | List all players | **No** |

## 💡 Practical Examples

### Discovery & Information

```bash
# List all players on network (sorted by IP)
./bluesoundplayer -list

# List only BluOS devices
./bluesoundplayer -c -type bluos -list

# List only Sonos devices
./bluesoundplayer -c -type sonos -list

# Quick status check of first player
./bluesoundplayer -status

# Detailed status of specific player
./bluesoundplayer -c -ip 192.168.1.100 -cmd status

# Show presets of second player
./bluesoundplayer -c -player 2 -cmd presets
```

### Playback Control

```bash
# Play preset 5 on first player
./bluesoundplayer -c -preset 5

# Play preset on specific player by IP
./bluesoundplayer -c -ip 192.168.1.100 -preset 3

# Play preset on second player from list
./bluesoundplayer -c -player 2 -preset 1

# Resume playback on specific player
./bluesoundplayer -c -ip 192.168.1.100 -cmd play

# Pause all Sonos devices (using scripting)
for ip in $(./bluesoundplayer -c -type sonos -list | grep "IP:" | awk '{print $2}'); do
    ./bluesoundplayer -c -ip $ip -cmd pause
done

# Skip to next track
./bluesoundplayer -c -ip 192.168.1.100 -cmd next
```

### Volume Control

```bash
# Set volume to 50% on specific player
./bluesoundplayer -c -ip 192.168.1.100 -volume 50

# Set volume on second player from list
./bluesoundplayer -c -player 2 -volume 75

# Set volume and show updated status
./bluesoundplayer -c -ip 192.168.1.100 -volume 40 && \
./bluesoundplayer -c -ip 192.168.1.100 -cmd status

# Quiet mode for all BluOS devices
./bluesoundplayer -c -type bluos -volume 20
```

### Workflow Examples

```bash
# Morning routine: Start radio at comfortable volume
./bluesoundplayer -c -ip 192.168.1.100 -volume 30
./bluesoundplayer -c -ip 192.168.1.100 -preset 1

# Evening: Fade to quiet and stop
./bluesoundplayer -c -ip 192.168.1.100 -volume 10
sleep 60
./bluesoundplayer -c -ip 192.168.1.100 -cmd stop

# Party mode: Start same preset on all players
PRESET=3
for ip in $(./bluesoundplayer -list | grep "IP:" | awk '{print $2}'); do
    ./bluesoundplayer -c -ip $ip -preset $PRESET
done
```

### Common Mistakes & Solutions

❌ **Wrong:**
```bash
# Forgot -c flag with command options
./bluesoundplayer -ip 192.168.1.100 -cmd play
```
**Error:** "Command-line options provided without enabling CLI mode"

✅ **Correct:**
```bash
# Use -c flag for CLI mode
./bluesoundplayer -c -ip 192.168.1.100 -cmd play
```

---

❌ **Wrong:**
```bash
# Using player index from old scan
./bluesoundplayer -list          # Player 2 is Kitchen
# ... time passes, players turn on/off ...
./bluesoundplayer -c -player 2   # Might be different now!
```

✅ **Correct:**
```bash
# Always use IP address for specific player
./bluesoundplayer -c -ip 192.168.1.101 -cmd play
```

---

❌ **Wrong:**
```bash
# Trying to use -type in interactive mode
./bluesoundplayer -type bluos
# Still shows all devices
```

✅ **Correct:**
```bash
# Use -type with -c and commands
./bluesoundplayer -c -type bluos -list
# Or just use interactive without filters
./bluesoundplayer
```

## 🎮 Interactive Mode Commands

Once in interactive mode, use these commands:

| Command | Description |
|---------|-------------|
| `play <id>` | Play preset by ID |
| `play` | Start/resume playback |
| `pause` | Pause playback |
| `stop` | Stop playback |
| `next` | Skip to next track |
| `prev` | Go to previous track |
| `vol <0-100>` | Set volume level |
| `status` | Refresh status |
| `presets` | Refresh presets list |
| `output <id>` | Switch to different player |
| `group <id1+id2>` | Group players (BluOS only) |
| `ungroup` | Ungroup all players |
| `lang <en\|de\|sw>` | Change language |
| `debug` | Show API diagnostics |
| `help` | Show help |
| `quit` / `exit` | Exit program |

### Interactive Mode Example Session

```
🎵 Multi-Room Audio Controller
======================================================================
🔍 Scanning network for audio players...
   ✅ Found: Kitchen (Node 2i) at 192.168.1.100 [BluOS]
   ✅ Found: Living Room (Play:3) at 192.168.1.101 [Sonos]

📱 Available Players:
  [1] Kitchen (Bluesound Node 2i) - 192.168.1.100 [BluOS]
  [2] Living Room (Sonos Play:3) - 192.168.1.101 [Sonos]

Select a player (1-2): 1
✅ Connected to: Kitchen (192.168.1.100)

🎵 Multi-Room Audio Controller - Interactive Mode
======================================================================
🔗 Current Player: Kitchen [BluOS]

📱 Available Players:
  [1] Kitchen (192.168.1.100) [BluOS] ✅
  [2] Living Room (192.168.1.101) [Sonos]

📊 Status: stop | Volume: 50%
🎵 No song playing

📋 Available Presets/Favorites:
  [1] Spotify Daily Mix
  [2] Radio Paradise
  [3] Classical WQXR

🎮 Available Commands:
  play <id> | play | pause | stop | next | prev | vol <0-100>
  output <id> | group <id1+id2> | ungroup | lang <en|de|sw> | quit

======================================================================
Command> play 2
✅ Playing preset 2

📊 Status: stream | Volume: 50%
🎵 World Music - Radio Paradise

Command> vol 35
🔊 Volume set to 35%

Command> output 2
🔄 Switched to player 2: Living Room

Command> quit
👋 Goodbye!
```

## 🌍 Multi-Language Support

Switch languages in interactive mode:

| Command | Language | UI Example |
|---------|----------|------------|
| `lang en` | 🇺🇸 English | "✅ Connected to: Living Room" |
| `lang de` | 🇩🇪 Deutsch | "✅ Verbunden mit: Wohnzimmer" |
| `lang sw` | 🇹🇿 Kiswahili | "✅ Imeunganishwa na: Sebule" |

## 🏠 Home Automation Integration

### Cron Jobs

```bash
# /etc/crontab - Morning radio weekdays at 7 AM
0 7 * * 1-5 pi /home/pi/bluesoundplayer -c -ip 192.168.1.100 -preset 1 -volume 30

# Stop music at midnight
0 0 * * * pi /home/pi/bluesoundplayer -c -ip 192.168.1.100 -cmd stop

# Volume down every 5 minutes from 22:00 to 23:00
*/5 22 * * * pi /home/pi/bluesoundplayer -c -ip 192.168.1.100 -volume 20
55 22 * * * pi /home/pi/bluesoundplayer -c -ip 192.168.1.100 -volume 10
0 23 * * * pi /home/pi/bluesoundplayer -c -ip 192.168.1.100 -cmd stop
```

### Bash Scripts

```bash
#!/bin/bash
# morning-radio.sh - Start morning radio routine

PLAYER_IP="192.168.1.100"
RADIO_PRESET=3
VOLUME=40

echo "Starting morning radio..."
/home/pi/bluesoundplayer -c -ip $PLAYER_IP -volume $VOLUME
/home/pi/bluesoundplayer -c -ip $PLAYER_IP -preset $RADIO_PRESET
echo "✓ Radio started at volume $VOLUME%"
```

```bash
#!/bin/bash
# goodnight.sh - Fade out and stop all players

echo "Starting goodnight routine..."

# Get all player IPs
PLAYERS=$(/home/pi/bluesoundplayer -list | grep "IP:" | awk '{print $2}')

# Fade to 20%
for IP in $PLAYERS; do
    /home/pi/bluesoundplayer -c -ip $IP -volume 20
done
sleep 30

# Fade to 10%
for IP in $PLAYERS; do
    /home/pi/bluesoundplayer -c -ip $IP -volume 10
done
sleep 30

# Stop all
for IP in $PLAYERS; do
    /home/pi/bluesoundplayer -c -ip $IP -cmd stop
    echo "✓ Stopped player: $IP"
done

echo "Goodnight!"
```

### Home Assistant

```yaml
# configuration.yaml
shell_command:
  play_radio: "/usr/local/bin/bluesoundplayer -c -ip 192.168.1.100 -preset 3"
  stop_music: "/usr/local/bin/bluesoundplayer -c -ip 192.168.1.100 -cmd stop"
  set_volume: "/usr/local/bin/bluesoundplayer -c -ip 192.168.1.100 -volume {{ volume }}"

# automations.yaml
- alias: "Morning Music"
  trigger:
    platform: time
    at: "07:00:00"
  condition:
    condition: state
    entity_id: binary_sensor.workday
    state: 'on'
  action:
    service: shell_command.play_radio

- alias: "Volume Down at Night"
  trigger:
    platform: time
    at: "22:00:00"
  action:
    service: shell_command.set_volume
    data:
      volume: 20
```

### Node-RED Flow

```json
[
    {
        "id": "morning_radio",
        "type": "exec",
        "command": "/usr/local/bin/bluesoundplayer -c -ip 192.168.1.100 -preset 1 -volume 30",
        "name": "Morning Radio"
    },
    {
        "id": "stop_music",
        "type": "exec",
        "command": "/usr/local/bin/bluesoundplayer -c -ip 192.168.1.100 -cmd stop",
        "name": "Stop Music"
    }
]
```

## 🔧 Building for Multiple Platforms

### Using Makefile

```bash
# Build for all platforms
make all

# Build for specific platforms
make linux          # Linux AMD64
make windows        # Windows AMD64
make raspberry      # All Raspberry Pi variants
make apple          # macOS (Intel and Apple Silicon)

# Individual targets
make rpi-armv6      # Raspberry Pi 1/Zero/Zero W
make rpi-armv7      # Raspberry Pi 2/3/4/Zero 2 W
make rpi-arm64      # Raspberry Pi 4/5 (64-bit)
make apple-arm64    # Apple Silicon (M1/M2/M3/M4)
make apple-amd64    # Intel Macs

# Utility commands
make clean          # Clean build artifacts
make test           # Test if project builds
make run            # Run locally for development
make list           # List built executables
make fmt            # Format Go code
```

### Using Build Script

```bash
# Build all platforms
./build_execs.sh

# Executables will be in release/ directory
ls release/
```

## 🔍 Troubleshooting

### No Players Found

```bash
# Check network connectivity
ping 192.168.1.100

# Verify players are on same network
ip addr show

# Test BluOS player manually
curl http://192.168.1.100:11000/SyncStatus

# Test Sonos player manually
curl http://192.168.1.101:1400/xml/device_description.xml

# Check firewall settings
sudo ufw status
```

### Player Index Changes

**Problem:** Player indices change between scans

**Solution:** Always use IP addresses for scripts:
```bash
# ✅ Good - Uses stable IP
./bluesoundplayer -c -ip 192.168.1.100 -preset 3

# ❌ Bad - Index might change
./bluesoundplayer -c -player 2 -preset 3
```

### Permission Errors

```bash
# Make executable
chmod +x bluesoundplayer

# Install system-wide
sudo cp bluesoundplayer /usr/local/bin/

# Check permissions
ls -la /usr/local/bin/bluesoundplayer
```

### Debugging

```bash
# Test connectivity in interactive mode
./bluesoundplayer
Command> debug

# Check API endpoints via CLI
./bluesoundplayer -c -ip 192.168.1.100 -cmd status

# Verbose network scan
./bluesoundplayer -list
```

## 🔗 Technical Details

### Supported Devices

**BluOS Devices (Port 11000):**
- Bluesound (Node, Powernode, Pulse, Vault, etc.)
- NAD (C 658, C 368, M10, etc.)
- DALI
- And other BluOS-compatible devices

**Sonos Devices (Port 1400):**
- All Sonos speakers and components
- Uses SOAP/UPnP protocol

### API Protocols

**BluOS:**
- Protocol: HTTP REST API
- Port: 11000
- Format: XML responses
- Examples: `/Status`, `/Presets`, `/Play`, `/Volume?level=50`

**Sonos:**
- Protocol: SOAP/UPnP
- Port: 1400
- Services: AVTransport, RenderingControl, ContentDirectory

### Player Discovery

- Scans all network interfaces automatically
- Checks each IP in subnet (x.x.x.1-254)
- Results sorted by IP address for consistency
- Deduplicates players found on multiple interfaces

## 📄 License

This project is open source. Check the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit:
- Bug reports
- Feature requests
- Pull requests
- Documentation improvements

## 🙏 Acknowledgments

- BluOS API documentation
- Sonos UPnP/SOAP protocol specifications
- Go community for excellent networking libraries