package main

import (
	"bufio"
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// dashboardCommands and groupsPageCommands list the commands shown in
// their respective screens' footer, wrapped to the terminal width by
// WrapCommandList instead of breaking at fixed points.
var dashboardCommands = []string{
	"play <id>", "play", "pause", "stop", "next", "prev", "vol <0-100>",
	"output <id>", "group <id1+id2>", "ungroup", "g (groups)",
	"lang <en|de|sw>", "quit",
}

var groupsPageCommands = []string{"group <id1+id2>", "ungroup", "g (back)", "quit"}

// Global state for TUI
type TUIState struct {
	client           AudioClient
	playerName       string
	status           *Status
	presets          []Preset
	presetsPage      int  // 0-indexed, see renderPresetsSection
	showGroups       bool // true: render the group-combinations page instead of the dashboard
	lastAction       string
	statusError      string
	presetsError     string
	availablePlayers []PlayerInfo
}

// lineCountingWriter wraps a writer and counts newlines written through
// it, so renderTUI can measure exactly how many terminal rows its fixed
// sections (header/players/status, commands/footer) use before deciding
// how many preset lines fit in what's left of the screen.
type lineCountingWriter struct {
	w     io.Writer
	lines int
}

func (lw *lineCountingWriter) Write(p []byte) (int, error) {
	lw.lines += bytes.Count(p, []byte("\n"))
	return lw.w.Write(p)
}

var tuiState = &TUIState{}

// Clear screen and move cursor to top
func clearScreen() {
	fmt.Print("\033[2J\033[H")
}

// enterAltScreen switches to the terminal's alternate screen buffer (the
// same mechanism vim/less/htop use), so the dashboard redraws in place
// without ever scrolling the shell's normal screen/scrollback, and
// without leaving redraw history behind once the app exits.
func enterAltScreen() {
	fmt.Print("\033[?1049h")
}

// exitAltScreen restores the shell's normal screen buffer, revealing
// whatever was on screen before enterAltScreen. Must be called before any
// message meant to remain visible after the app exits (goodbye, fatal
// errors), since text drawn while the alt screen is active disappears the
// moment it's left.
func exitAltScreen() {
	fmt.Print("\033[?1049l")
}

// installExitHandler ensures the alternate screen buffer is left cleanly
// even on Ctrl+C/SIGTERM - without this, an interrupted session would
// leave the terminal stuck showing the last redrawn frame (or blank)
// after the process is gone.
func installExitHandler() {
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigCh
		exitAltScreen()
		os.Exit(0)
	}()
}

// Update TUI state
func updateStatus() {
	status, err := tuiState.client.GetStatus()
	if err != nil {
		tuiState.statusError = getText("error_retrieving_status")
		tuiState.status = nil
	} else {
		tuiState.status = status
		tuiState.statusError = ""
	}
}

func updatePresets() {
	presets, err := tuiState.client.GetPresets()
	if err != nil {
		tuiState.presetsError = getText("error_loading_presets")
		tuiState.presets = nil
	} else {
		tuiState.presets = presets
		tuiState.presetsError = ""
	}
	tuiState.presetsPage = 0
}

// Render the complete TUI. The header/players/status section and the
// commands/footer section are always shown in full; only the presets
// section is paginated (via the "n"/"p" commands), sized to whatever
// terminal rows are left after those fixed sections - see
// renderPresetsSection. Group combinations have their own page (the "g"
// command, see renderGroupsPage) instead of always occupying header space,
// since that list grows quadratically with the number of players.
func renderTUI() {
	if tuiState.showGroups {
		renderGroupsPage()
		return
	}

	clearScreen()

	// lw counts the rows the fixed top section (header/players/status)
	// actually takes, since that varies with player count.
	lw := &lineCountingWriter{w: os.Stdout}

	// Header
	fmt.Fprintln(lw, getText("title"))
	fmt.Fprintln(lw, strings.Repeat("=", 70))
	deviceTypeIndicator := ""
	if tuiState.client != nil {
		switch tuiState.client.GetDeviceType() {
		case DeviceTypeBluOS:
			deviceTypeIndicator = " [BluOS]"
		case DeviceTypeSonos:
			deviceTypeIndicator = " [Sonos]"
		}
	}
	fmt.Fprintf(lw, "🔗 %s %s%s\n", getText("current_player"), tuiState.playerName, deviceTypeIndicator)
	fmt.Fprintln(lw)

	// Available Players Section
	if len(tuiState.availablePlayers) > 1 {
		fmt.Fprintln(lw, getText("available_outputs"))
		for i, player := range tuiState.availablePlayers {
			activeMarker := ""
			if player.Name == tuiState.playerName {
				activeMarker = " ✅"
			}
			typeIndicator := ""
			switch player.Type {
			case DeviceTypeBluOS:
				typeIndicator = " [BluOS]"
			case DeviceTypeSonos:
				typeIndicator = " [Sonos]"
			}
			fmt.Fprintf(lw, "  [%d] %s (%s)%s%s\n", i+1, player.Name, player.IP, typeIndicator, activeMarker)
		}
		fmt.Fprintln(lw)
	}

	// Status Section
	if tuiState.statusError != "" {
		fmt.Fprintln(lw, tuiState.statusError)
	} else if tuiState.status != nil {
		volumeStr := getText("volume_unknown")
		if tuiState.status.Volume >= 0 {
			volumeStr = fmt.Sprintf("%d%%", tuiState.status.Volume)
		}
		fmt.Fprintf(lw, getText("status_volume")+"\n", tuiState.status.State, volumeStr)
		if tuiState.status.Song != "" {
			fmt.Fprintf(lw, "🎵 %s", tuiState.status.Song)
			if tuiState.status.Artist != "" {
				fmt.Fprintf(lw, " - %s", tuiState.status.Artist)
			}
			fmt.Fprintln(lw)
		} else {
			fmt.Fprintf(lw, "🎵 %s\n", getText("no_song_playing"))
		}
	}
	fmt.Fprintln(lw)

	// Commands/footer section is built (but not printed yet) so its exact
	// row count is known before deciding how many preset lines fit.
	commandWidth, ok := TerminalWidth()
	if !ok {
		commandWidth = 70
	}
	var footer bytes.Buffer
	fmt.Fprintln(&footer, getText("available_commands"))
	for _, line := range WrapCommandList(dashboardCommands, "  ", commandWidth) {
		fmt.Fprintln(&footer, line)
	}
	fmt.Fprintln(&footer)
	if tuiState.lastAction != "" {
		fmt.Fprintf(&footer, "%s %s\n", getText("last_action"), tuiState.lastAction)
		fmt.Fprintln(&footer)
	}
	footerLines := bytes.Count(footer.Bytes(), []byte("\n"))

	// Presets Section
	fmt.Println(getText("available_presets"))
	if tuiState.presetsError != "" {
		fmt.Println(tuiState.presetsError)
	} else if tuiState.presets != nil {
		renderPresetsSection(lw.lines, footerLines)
	}
	fmt.Println()

	os.Stdout.Write(footer.Bytes())
}

// renderGroupsPage shows the grouping page (all valid master+slave
// combinations for the currently discovered players), reached via the "g"
// command. It's a separate page rather than part of the main dashboard
// because the combination list grows quadratically with the player count.
func renderGroupsPage() {
	clearScreen()

	fmt.Println(getText("title"))
	fmt.Println(strings.Repeat("=", 70))
	deviceTypeIndicator := ""
	if tuiState.client != nil {
		switch tuiState.client.GetDeviceType() {
		case DeviceTypeBluOS:
			deviceTypeIndicator = " [BluOS]"
		case DeviceTypeSonos:
			deviceTypeIndicator = " [Sonos]"
		}
	}
	fmt.Printf("🔗 %s %s%s\n", getText("current_player"), tuiState.playerName, deviceTypeIndicator)
	fmt.Println()

	fmt.Println(getText("group_combinations"))
	printedAny := false
	for i, master := range tuiState.availablePlayers {
		for j, slave := range tuiState.availablePlayers {
			if i != j && master.Type == slave.Type {
				fmt.Printf("  group %d+%d - %s + %s\n", i+1, j+1, master.Name, slave.Name)
				printedAny = true
			}
		}
	}
	if !printedAny {
		fmt.Println("  " + getText("no_group_combinations"))
	}
	fmt.Println()

	fmt.Println(getText("available_commands"))
	groupsWidth, ok := TerminalWidth()
	if !ok {
		groupsWidth = 70
	}
	for _, line := range WrapCommandList(groupsPageCommands, "  ", groupsWidth) {
		fmt.Println(line)
	}
	fmt.Println()

	if tuiState.lastAction != "" {
		fmt.Printf("%s %s\n", getText("last_action"), tuiState.lastAction)
		fmt.Println()
	}
}

// renderPresetsSection prints one page of tuiState.presets, sized to fit
// whatever terminal rows remain after the given number of already-used
// header and footer rows (plus the prompt line printed after renderTUI
// returns, and this section's own header/page-indicator lines). Falls
// back to printing everything unpaginated when the terminal size can't be
// determined (e.g. piped output).
func renderPresetsSection(headerLines, footerLines int) {
	allLines := BuildPresetLines(tuiState.presets, "  ")

	height, ok := TerminalHeight()
	if !ok {
		for _, l := range allLines {
			fmt.Println(l)
		}
		return
	}

	// Reserve: header section + footer section + this section's own
	// "Available Presets" header (already printed by the caller) + the
	// page indicator line shown below + the trailing blank line before
	// the footer + the 3-row prompt box printed after renderTUI returns
	// (see printPromptBox, whose last line prints without a trailing
	// newline so filling the terminal exactly doesn't force a scroll).
	const presetsSectionOwnLines = 3 // "Available Presets" header + page indicator + trailing blank line
	const promptBoxLines = 3
	available := height - headerLines - footerLines - presetsSectionOwnLines - promptBoxLines
	if available < 1 {
		available = 1
	}

	pageCount := (len(allLines) + available - 1) / available
	if pageCount < 1 {
		pageCount = 1
	}
	if tuiState.presetsPage >= pageCount {
		tuiState.presetsPage = pageCount - 1
	}
	if tuiState.presetsPage < 0 {
		tuiState.presetsPage = 0
	}

	start := tuiState.presetsPage * available
	end := start + available
	if end > len(allLines) {
		end = len(allLines)
	}
	for _, l := range allLines[start:end] {
		fmt.Println(l)
	}

	if pageCount > 1 {
		fmt.Printf(getText("presets_page")+"\n", tuiState.presetsPage+1, pageCount)
	}
}

// Player selection
func selectPlayer() (AudioClient, string, []PlayerInfo, error) {
	// Enable verbose output for interactive mode
	quietMode = false
	
	players, err := scanForPlayers()
	if err != nil {
		return nil, "", nil, err
	}

	if len(players) == 0 {
		return nil, "", nil, fmt.Errorf(getText("no_players"))
	}

	fmt.Println("\n" + getText("available_players"))
	for i, player := range players {
		typeIndicator := ""
		switch player.Type {
		case DeviceTypeBluOS:
			typeIndicator = " [BluOS]"
		case DeviceTypeSonos:
			typeIndicator = " [Sonos]"
		}
		fmt.Printf("  [%d] %s (%s %s) - %s%s\n", i+1, player.Name, player.Brand, player.Model, player.IP, typeIndicator)
	}

	reader := bufio.NewReader(os.Stdin)
	for {
		fmt.Printf("\n"+getText("select_player"), len(players))
		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		choice, err := strconv.Atoi(input)
		if err != nil || choice < 1 || choice > len(players) {
			fmt.Println(getText("invalid_selection"))
			continue
		}

		selectedPlayer := players[choice-1]
		fmt.Printf(getText("connected_to")+"\n", selectedPlayer.Name, selectedPlayer.IP)

		var client AudioClient
		switch selectedPlayer.Type {
		case DeviceTypeBluOS:
			client = NewBluesoundClient(selectedPlayer.IP)
		case DeviceTypeSonos:
			client = NewSonosClient(selectedPlayer.IP)
		default:
			return nil, "", nil, fmt.Errorf("unsupported device type")
		}

		return client, selectedPlayer.Name, players, nil
	}
}

// Switch to different player
func switchToPlayer(playerID int) {
	if playerID < 1 || playerID > len(tuiState.availablePlayers) {
		tuiState.lastAction = getText("invalid_player_id")
		return
	}

	selectedPlayer := tuiState.availablePlayers[playerID-1]

	switch selectedPlayer.Type {
	case DeviceTypeBluOS:
		tuiState.client = NewBluesoundClient(selectedPlayer.IP)
	case DeviceTypeSonos:
		tuiState.client = NewSonosClient(selectedPlayer.IP)
	default:
		tuiState.lastAction = getText("error_switching_player")
		return
	}

	tuiState.playerName = selectedPlayer.Name
	tuiState.lastAction = fmt.Sprintf(getText("switched_to_player"), playerID, selectedPlayer.Name)

	// Update status and presets for new player
	updateStatus()
	updatePresets()
}

// Group players (only works for BluOS devices)
func groupPlayers(groupSpec string) {
	parts := strings.Split(groupSpec, "+")
	if len(parts) != 2 {
		tuiState.lastAction = getText("invalid_group_format")
		return
	}

	masterID, err1 := strconv.Atoi(parts[0])
	slaveID, err2 := strconv.Atoi(parts[1])

	if err1 != nil || err2 != nil || masterID < 1 || slaveID < 1 ||
		masterID > len(tuiState.availablePlayers) || slaveID > len(tuiState.availablePlayers) {
		tuiState.lastAction = getText("invalid_group_format")
		return
	}

	if masterID == slaveID {
		tuiState.lastAction = getText("invalid_group_format")
		return
	}

	masterPlayer := tuiState.availablePlayers[masterID-1]
	slavePlayer := tuiState.availablePlayers[slaveID-1]

	// Check if both are the same device type
	if masterPlayer.Type != slavePlayer.Type {
		tuiState.lastAction = "❌ Cannot group different device types"
		return
	}

	// Switch to master player
	switch masterPlayer.Type {
	case DeviceTypeBluOS:
		tuiState.client = NewBluesoundClient(masterPlayer.IP)
	case DeviceTypeSonos:
		tuiState.client = NewSonosClient(masterPlayer.IP)
	}
	tuiState.playerName = masterPlayer.Name

	// Add slave to master
	if err := tuiState.client.AddSlave(slavePlayer.IP); err != nil {
		tuiState.lastAction = fmt.Sprintf("%s: %v", getText("error_grouping"), err)
		return
	}

	tuiState.lastAction = fmt.Sprintf(getText("grouped_players"), masterPlayer.Name)
	updateStatus()
}

// Debug function to test API endpoints
func debugAPI() {
	if tuiState.client != nil {
		tuiState.lastAction = tuiState.client.DebugAPI()
	} else {
		tuiState.lastAction = "No client connected"
	}
}

// Ungroup all players
func ungroupAll() {
	if tuiState.client == nil {
		tuiState.lastAction = "No client connected"
		return
	}

	// For Sonos: use the built-in RemoveAllSlaves which queries zone topology
	if tuiState.client.GetDeviceType() == DeviceTypeSonos {
		if err := tuiState.client.RemoveAllSlaves(); err != nil {
			tuiState.lastAction = fmt.Sprintf("%s: %v", getText("error_ungrouping"), err)
		} else {
			tuiState.lastAction = getText("ungrouped_all")
		}
		updateStatus()
		return
	}

	var successCount int

	// Try removing slaves one by one using RemoveSlave
	for _, player := range tuiState.availablePlayers {
		if player.Name != tuiState.playerName && player.Type == DeviceTypeBluOS {
			if _, err := tuiState.client.(*BluesoundClient).makeRequest(fmt.Sprintf("/RemoveSlave?slave=%s", player.IP)); err == nil {
				successCount++
			}

			// Also try the reverse
			otherClient := NewBluesoundClient(player.IP)
			currentPlayerIP := strings.Split(tuiState.client.(*BluesoundClient).baseURL, "://")[1]
			currentPlayerIP = strings.Split(currentPlayerIP, ":")[0]

			if _, err := otherClient.makeRequest(fmt.Sprintf("/RemoveSlave?slave=%s", currentPlayerIP)); err == nil {
				successCount++
			}
		}
	}

	// Try various standalone/reset approaches on all BluOS players
	for _, player := range tuiState.availablePlayers {
		if player.Type == DeviceTypeBluOS {
			client := NewBluesoundClient(player.IP)

			// Try various standalone/reset approaches
			standaloneMethods := []string{
				"/Standalone",
				"/Reset",
				"/ClearSlaves",
			}

			for _, method := range standaloneMethods {
				if _, err := client.makeRequest(method); err == nil {
					successCount++
					break
				}
			}
		}
	}

	if successCount > 0 {
		tuiState.lastAction = getText("ungrouped_all")
	} else {
		tuiState.lastAction = fmt.Sprintf("%s (RemoveSlave approach failed)", getText("error_ungrouping"))
	}

	updateStatus()
}

// Change language
func changeLanguage(lang string) {
	switch strings.ToLower(lang) {
	case "en", "english":
		currentLanguage = LangEnglish
		tuiState.lastAction = getText("language_changed") + " English"
	case "de", "german", "deutsch":
		currentLanguage = LangGerman
		tuiState.lastAction = getText("language_changed") + " Deutsch"
	case "sw", "swahili", "kiswahili":
		currentLanguage = LangSwahili
		tuiState.lastAction = getText("language_changed") + " Kiswahili"
	default:
		tuiState.lastAction = getText("invalid_language")
	}
}

// printPromptBox draws a bordered input line below the current screen -
// styled after Claude Code's own CLI prompt - and leaves the cursor
// positioned right after the "❯" glyph, ready for typing.
func printPromptBox() {
	width, ok := TerminalWidth()
	if !ok {
		width = 70
	}
	border := strings.Repeat("─", width)

	fmt.Println(border)
	fmt.Println() // reserved input row, filled in below
	fmt.Print(border) // no trailing newline: this is the last row of the
	// screen when the dashboard fills the terminal exactly, and a
	// newline here would push the cursor past it, forcing the terminal
	// to scroll by one and leave a wasted blank row at the bottom.
	fmt.Print("\033[1A\r") // back up to the input row, column 1
	fmt.Print("❯ ")
}

// Interactive loop
func interactiveMode() {
	reader := bufio.NewReader(os.Stdin)

	// Initial data load
	updateStatus()
	updatePresets()

	for {
		renderTUI()
		printPromptBox()

		input, _ := reader.ReadString('\n')
		input = strings.TrimSpace(input)

		if input == "" {
			continue
		}

		parts := strings.Fields(input)
		command := strings.ToLower(parts[0])

		switch command {
		case "play":
			if len(parts) > 1 {
				// Play preset/favorite
				presetID, err := strconv.Atoi(parts[1])
				if err != nil {
					tuiState.lastAction = getText("invalid_preset_id")
					continue
				}
				if err := tuiState.client.PlayPreset(presetID); err != nil {
					tuiState.lastAction = fmt.Sprintf("%s: %v", getText("error_playing_preset"), err)
				} else {
					tuiState.lastAction = fmt.Sprintf(getText("playing_preset"), presetID)
					time.Sleep(500 * time.Millisecond)
					updateStatus()
				}
			} else {
				// Start playback
				if err := tuiState.client.Play(); err != nil {
					tuiState.lastAction = getText("error_starting_playback")
				} else {
					tuiState.lastAction = getText("playback_started")
					time.Sleep(500 * time.Millisecond)
					updateStatus()
				}
			}

		case "pause":
			if err := tuiState.client.Pause(); err != nil {
				tuiState.lastAction = getText("error_pausing")
			} else {
				tuiState.lastAction = getText("paused")
				updateStatus()
			}

		case "stop":
			if err := tuiState.client.Stop(); err != nil {
				tuiState.lastAction = getText("error_stopping")
			} else {
				tuiState.lastAction = getText("stopped")
				updateStatus()
			}

		case "next":
			if err := tuiState.client.Next(); err != nil {
				tuiState.lastAction = getText("error_next_track")
			} else {
				tuiState.lastAction = getText("next_track")
				time.Sleep(500 * time.Millisecond)
				updateStatus()
			}

		case "prev", "previous":
			if err := tuiState.client.Previous(); err != nil {
				tuiState.lastAction = getText("error_prev_track")
			} else {
				tuiState.lastAction = getText("prev_track")
				time.Sleep(500 * time.Millisecond)
				updateStatus()
			}

		case "vol", "volume":
			if len(parts) < 2 {
				tuiState.lastAction = getText("volume_missing")
				continue
			}
			volume, err := strconv.Atoi(parts[1])
			if err != nil {
				tuiState.lastAction = getText("invalid_volume")
				continue
			}
			if err := tuiState.client.SetVolume(volume); err != nil {
				tuiState.lastAction = getText("error_setting_volume")
			} else {
				tuiState.lastAction = fmt.Sprintf(getText("volume_set"), volume)
				updateStatus()
			}

		case "status":
			updateStatus()
			tuiState.lastAction = "Status refreshed"

		case "presets":
			updatePresets()
			tuiState.lastAction = "Presets/Favorites refreshed"

		case "n":
			tuiState.presetsPage++

		case "p":
			if tuiState.presetsPage > 0 {
				tuiState.presetsPage--
			}

		case "g":
			tuiState.showGroups = !tuiState.showGroups

		case "help":
			tuiState.lastAction = "Help displayed above"

		case "output":
			if len(parts) < 2 {
				tuiState.lastAction = getText("invalid_player_id")
				continue
			}
			playerID, err := strconv.Atoi(parts[1])
			if err != nil {
				tuiState.lastAction = getText("invalid_player_id")
				continue
			}
			switchToPlayer(playerID)

		case "group":
			if len(parts) < 2 {
				tuiState.lastAction = getText("invalid_group_format")
				continue
			}
			groupPlayers(parts[1])

		case "ungroup":
			ungroupAll()

		case "debug":
			debugAPI()

		case "lang", "language":
			if len(parts) < 2 {
				tuiState.lastAction = getText("invalid_language")
				continue
			}
			changeLanguage(parts[1])

		case "quit", "exit":
			exitAltScreen()
			fmt.Println(getText("goodbye"))
			return

		default:
			tuiState.lastAction = fmt.Sprintf(getText("unknown_command"), command)
		}
	}
}

func main() {
	// Initialize CLI flags
	initCLIFlags()
	flag.Parse()

	// Check if user provided CLI flags but forgot -c
	if !cliFlags.nonInteractive && !cliFlags.listPlayers && !cliFlags.status && 
		!cliFlags.listPresets && !cliFlags.help {
		// Check if any command-line options were provided
		hasOptions := cliFlags.playerIP != "" || 
			cliFlags.playerIndex > 0 || 
			cliFlags.command != "" || 
			cliFlags.presetID > 0 || 
			cliFlags.volume >= 0 || 
			cliFlags.deviceType != ""
		
		if hasOptions {
			fmt.Println("❌ Error: Command-line options provided without enabling CLI mode")
			fmt.Println()
			fmt.Println("To use non-interactive mode, add the -c flag:")
			fmt.Println()
			fmt.Println("Examples:")
			fmt.Println("  ./bluesoundplayer -c -ip 192.168.1.100 -cmd play")
			fmt.Println("  ./bluesoundplayer -c -player 1 -preset 3")
			fmt.Println()
			fmt.Println("For help, use: ./bluesoundplayer -help")
			fmt.Println("For interactive mode, run without any flags: ./bluesoundplayer")
			os.Exit(1)
		}
	}

	// Handle non-interactive CLI mode
	if cliFlags.nonInteractive || cliFlags.listPlayers || cliFlags.status || cliFlags.listPresets || cliFlags.help {
		if err := handleCLIMode(); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		return
	}

	// Interactive mode (original behavior). Enter the alternate screen
	// buffer immediately so scanning/player-selection output and the
	// dashboard all render in place without scrolling the shell.
	installExitHandler()
	enterAltScreen()

	fmt.Println(getText("title"))
	fmt.Println(strings.Repeat("=", 70))

	// Select player
	client, playerName, availablePlayers, err := selectPlayer()
	if err != nil {
		exitAltScreen()
		log.Fatalf(getText("error_selecting_player"), err)
	}

	// Initialize TUI state
	tuiState.client = client
	tuiState.playerName = playerName
	tuiState.availablePlayers = availablePlayers

	// Start interactive mode
	interactiveMode()
}