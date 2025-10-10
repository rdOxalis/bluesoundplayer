package main

import (
	"flag"
	"fmt"
	"strings"
	"time"
)

// CLI flags
type CLIFlags struct {
	nonInteractive bool
	playerIP       string
	playerIndex    int
	command        string
	presetID       int
	volume         int
	listPlayers    bool
	listPresets    bool
	status         bool
	deviceType     string
	help           bool
}

var cliFlags CLIFlags

// Initialize CLI flags
func initCLIFlags() {
	flag.BoolVar(&cliFlags.nonInteractive, "c", false, "Non-interactive command mode")
	flag.BoolVar(&cliFlags.nonInteractive, "command", false, "Non-interactive command mode")
	flag.StringVar(&cliFlags.playerIP, "ip", "", "Player IP address (e.g., 192.168.1.100)")
	flag.IntVar(&cliFlags.playerIndex, "player", 0, "Player index from scan (1-N)")
	flag.StringVar(&cliFlags.command, "cmd", "", "Command: play|pause|stop|next|prev|status|presets|list")
	flag.IntVar(&cliFlags.presetID, "preset", 0, "Preset/Favorite ID to play")
	flag.IntVar(&cliFlags.volume, "volume", -1, "Set volume (0-100)")
	flag.BoolVar(&cliFlags.listPlayers, "list", false, "List available players")
	flag.BoolVar(&cliFlags.listPresets, "presets", false, "List available presets/favorites")
	flag.BoolVar(&cliFlags.status, "status", false, "Show player status")
	flag.StringVar(&cliFlags.deviceType, "type", "", "Device type filter: bluos|sonos")
	flag.BoolVar(&cliFlags.help, "help", false, "Show help message")
}

// Handle non-interactive CLI mode
func handleCLIMode() error {
	// Show help if requested
	if cliFlags.help {
		showCLIHelp()
		return nil
	}

	// List players and exit
	if cliFlags.listPlayers {
		return listPlayersCmd()
	}

	// Scan for players
	players, err := scanForPlayers()
	if err != nil {
		return fmt.Errorf("failed to scan for players: %w", err)
	}

	if len(players) == 0 {
		return fmt.Errorf("no players found on network")
	}

	// Filter by device type if specified
	if cliFlags.deviceType != "" {
		var filtered []PlayerInfo
		deviceType := DeviceType(strings.ToLower(cliFlags.deviceType))
		for _, p := range players {
			if p.Type == deviceType {
				filtered = append(filtered, p)
			}
		}
		players = filtered
		if len(players) == 0 {
			return fmt.Errorf("no %s players found", cliFlags.deviceType)
		}
	}

	// Select player
	var selectedPlayer PlayerInfo
	if cliFlags.playerIP != "" {
		// Find by IP
		found := false
		for _, p := range players {
			if p.IP == cliFlags.playerIP {
				selectedPlayer = p
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("player with IP %s not found", cliFlags.playerIP)
		}
	} else if cliFlags.playerIndex > 0 && cliFlags.playerIndex <= len(players) {
		// Find by index
		selectedPlayer = players[cliFlags.playerIndex-1]
	} else {
		// Use first player if no selection criteria given
		selectedPlayer = players[0]
		fmt.Printf("No player specified, using: %s (%s)\n", selectedPlayer.Name, selectedPlayer.IP)
	}

	// Create client
	var client AudioClient
	switch selectedPlayer.Type {
	case DeviceTypeBluOS:
		client = NewBluesoundClient(selectedPlayer.IP)
	case DeviceTypeSonos:
		client = NewSonosClient(selectedPlayer.IP)
	default:
		return fmt.Errorf("unsupported device type: %s", selectedPlayer.Type)
	}

	// Execute command
	return executeCLICommand(client, &selectedPlayer)
}

// Execute the CLI command
func executeCLICommand(client AudioClient, player *PlayerInfo) error {
	// Handle status flag
	if cliFlags.status {
		return showStatusCmd(client, player)
	}

	// Handle presets flag
	if cliFlags.listPresets {
		return showPresetsCmd(client, player)
	}

	// Handle volume change
	if cliFlags.volume >= 0 {
		if err := client.SetVolume(cliFlags.volume); err != nil {
			return fmt.Errorf("failed to set volume: %w", err)
		}
		fmt.Printf("✓ Volume set to %d%%\n", cliFlags.volume)
		return nil
	}

	// Handle preset playback
	if cliFlags.presetID > 0 {
		if err := client.PlayPreset(cliFlags.presetID); err != nil {
			return fmt.Errorf("failed to play preset %d: %w", cliFlags.presetID, err)
		}
		fmt.Printf("✓ Playing preset %d\n", cliFlags.presetID)
		time.Sleep(500 * time.Millisecond)
		return showStatusCmd(client, player)
	}

	// Handle command string
	switch strings.ToLower(cliFlags.command) {
	case "play":
		if err := client.Play(); err != nil {
			return fmt.Errorf("failed to play: %w", err)
		}
		fmt.Println("▶️  Playback started")
		time.Sleep(500 * time.Millisecond)
		return showStatusCmd(client, player)

	case "pause":
		if err := client.Pause(); err != nil {
			return fmt.Errorf("failed to pause: %w", err)
		}
		fmt.Println("⏸️  Paused")
		return showStatusCmd(client, player)

	case "stop":
		if err := client.Stop(); err != nil {
			return fmt.Errorf("failed to stop: %w", err)
		}
		fmt.Println("⏹️  Stopped")
		return showStatusCmd(client, player)

	case "next":
		if err := client.Next(); err != nil {
			return fmt.Errorf("failed to skip: %w", err)
		}
		fmt.Println("⏭️  Next track")
		time.Sleep(500 * time.Millisecond)
		return showStatusCmd(client, player)

	case "prev", "previous":
		if err := client.Previous(); err != nil {
			return fmt.Errorf("failed to go back: %w", err)
		}
		fmt.Println("⏮️  Previous track")
		time.Sleep(500 * time.Millisecond)
		return showStatusCmd(client, player)

	case "status":
		return showStatusCmd(client, player)

	case "presets", "favorites":
		return showPresetsCmd(client, player)

	case "list":
		return listPlayersCmd()

	case "":
		return fmt.Errorf("no command specified (use -cmd or -help)")

	default:
		return fmt.Errorf("unknown command: %s", cliFlags.command)
	}
}

// List all available players
func listPlayersCmd() error {
	players, err := scanForPlayers()
	if err != nil {
		return fmt.Errorf("failed to scan: %w", err)
	}

	if len(players) == 0 {
		fmt.Println("No players found")
		return nil
	}

	fmt.Println("\n📱 Available Players:")
	fmt.Println(strings.Repeat("=", 70))
	for i, p := range players {
		typeStr := ""
		switch p.Type {
		case DeviceTypeBluOS:
			typeStr = "[BluOS]"
		case DeviceTypeSonos:
			typeStr = "[Sonos]"
		}
		fmt.Printf("[%d] %s (%s %s)\n", i+1, p.Name, p.Brand, p.Model)
		fmt.Printf("    IP: %s %s\n", p.IP, typeStr)
		if i < len(players)-1 {
			fmt.Println()
		}
	}
	fmt.Println(strings.Repeat("=", 70))
	return nil
}

// Show player status
func showStatusCmd(client AudioClient, player *PlayerInfo) error {
	status, err := client.GetStatus()
	if err != nil {
		return fmt.Errorf("failed to get status: %w", err)
	}

	typeStr := ""
	switch player.Type {
	case DeviceTypeBluOS:
		typeStr = "[BluOS]"
	case DeviceTypeSonos:
		typeStr = "[Sonos]"
	}

	fmt.Println("\n📊 Player Status")
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("Player:  %s (%s) %s\n", player.Name, player.IP, typeStr)
	fmt.Printf("State:   %s\n", status.State)
	fmt.Printf("Volume:  %d%%\n", status.Volume)

	if status.Song != "" {
		fmt.Printf("Song:    %s\n", status.Song)
		if status.Artist != "" {
			fmt.Printf("Artist:  %s\n", status.Artist)
		}
		if status.Album != "" {
			fmt.Printf("Album:   %s\n", status.Album)
		}
	} else {
		fmt.Println("Song:    No song playing")
	}
	fmt.Println(strings.Repeat("=", 70))
	return nil
}

// Show presets/favorites
func showPresetsCmd(client AudioClient, player *PlayerInfo) error {
	presets, err := client.GetPresets()
	if err != nil {
		return fmt.Errorf("failed to get presets: %w", err)
	}

	typeStr := ""
	switch player.Type {
	case DeviceTypeBluOS:
		typeStr = "[BluOS]"
	case DeviceTypeSonos:
		typeStr = "[Sonos]"
	}

	fmt.Println("\n📋 Presets/Favorites")
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("Player: %s (%s) %s\n", player.Name, player.IP, typeStr)
	fmt.Println()

	if len(presets) == 0 {
		fmt.Println("No presets/favorites found")
	} else {
		for _, preset := range presets {
			fmt.Printf("[%d] %s\n", preset.ID, preset.Name)
		}
	}
	fmt.Println(strings.Repeat("=", 70))
	return nil
}

// Show CLI help
func showCLIHelp() {
	fmt.Println(`
🎵 Multi-Room Audio Controller - CLI Mode
=============================================

USAGE:
  bluesoundplayer -c -ip <IP> -cmd <command>
  bluesoundplayer -c -player <N> -preset <ID>
  bluesoundplayer -list

PLAYER SELECTION:
  -ip <address>     Select player by IP address (e.g., 192.168.1.100)
  -player <N>       Select player by index from scan (1-N)
  -type <type>      Filter by device type: bluos|sonos
  (If neither specified, first player found is used)

COMMANDS:
  -cmd play         Start/resume playback
  -cmd pause        Pause playback
  -cmd stop         Stop playback
  -cmd next         Skip to next track
  -cmd prev         Go to previous track
  -cmd status       Show player status
  -cmd presets      List available presets/favorites
  -cmd list         List all players

  -preset <ID>      Play preset/favorite by ID
  -volume <0-100>   Set volume level
  -status           Show player status (shortcut)
  -presets          List presets (shortcut)
  -list             List all players (shortcut)

OPTIONS:
  -c, -command      Enable non-interactive command mode
  -help             Show this help message

EXAMPLES:
  # List all players
  bluesoundplayer -list

  # Show status of first player
  bluesoundplayer -c -status

  # Play preset 3 on player with IP 192.168.1.100
  bluesoundplayer -c -ip 192.168.1.100 -preset 3

  # Set volume to 50% on second player from scan
  bluesoundplayer -c -player 2 -volume 50

  # Pause playback on specific player
  bluesoundplayer -c -ip 192.168.1.100 -cmd pause

  # Show presets for BluOS devices only
  bluesoundplayer -c -type bluos -presets

  # Next track on first Sonos player
  bluesoundplayer -c -type sonos -cmd next

INTERACTIVE MODE:
  Run without -c flag to enter interactive mode:
  bluesoundplayer
`)
}