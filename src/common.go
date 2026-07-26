package main

import (
	"encoding/xml"
	"fmt"
	"os"

	"golang.org/x/term"
)

// Device type enumeration
type DeviceType string

const (
	DeviceTypeBluOS DeviceType = "bluos"
	DeviceTypeSonos DeviceType = "sonos"
)

// PresetCategory groups a preset/favorite for display. Values mirror the
// Flutter app's PresetCategory enum so both apps categorize and show
// presets the same way.
type PresetCategory string

const (
	CategoryStation  PresetCategory = "station"
	CategoryPlaylist PresetCategory = "playlist"
	CategoryAlbum    PresetCategory = "album"
	CategorySong     PresetCategory = "song"
)

// categoryDisplayOrder is the order categories are shown in, matching the
// Flutter app's presets screen (Stations, Playlists, Albums, Songs).
var categoryDisplayOrder = []PresetCategory{CategoryStation, CategoryPlaylist, CategoryAlbum, CategorySong}

// Common structures
type Presets struct {
	XMLName xml.Name `xml:"presets"`
	Presets []Preset `xml:"preset"`
}

type Preset struct {
	ID       int            `xml:"id,attr"`
	Name     string         `xml:"name,attr"`
	URL      string         `xml:"url,attr"`
	Image    string         `xml:"image,attr"`
	Category PresetCategory `xml:"-"`
}

// BuildPresetLines renders presets grouped by category (Stations,
// Playlists, Albums, Songs) into display lines, with a localized,
// icon-prefixed header per group, instead of one flat list mixing radio
// stations, playlists, albums and songs together. indent is prepended to
// every line (e.g. "  " for the indented interactive TUI, "" for one-shot
// CLI output). Presets with no category default to Stations.
func BuildPresetLines(presets []Preset, indent string) []string {
	groups := make(map[PresetCategory][]Preset)
	for _, p := range presets {
		cat := p.Category
		if cat == "" {
			cat = CategoryStation
		}
		groups[cat] = append(groups[cat], p)
	}

	var lines []string
	printedAny := false
	for _, cat := range categoryDisplayOrder {
		items := groups[cat]
		if len(items) == 0 {
			continue
		}
		if printedAny {
			lines = append(lines, "")
		}
		printedAny = true
		lines = append(lines, indent+categoryLabel(cat))
		for _, p := range items {
			lines = append(lines, fmt.Sprintf("%s  [%d] %s", indent, p.ID, p.Name))
		}
	}

	return lines
}

// PrintPresetsGrouped prints all presets at once (no pagination), for
// one-shot CLI output where there's no follow-up prompt to page through.
func PrintPresetsGrouped(presets []Preset, indent string) {
	for _, l := range BuildPresetLines(presets, indent) {
		fmt.Println(l)
	}
}

// TerminalHeight returns the current terminal's row count. ok is false
// when stdout isn't an interactive terminal (piped/redirected output) or
// its size can't be determined.
func TerminalHeight() (height int, ok bool) {
	fd := int(os.Stdout.Fd())
	if !term.IsTerminal(fd) {
		return 0, false
	}
	_, h, err := term.GetSize(fd)
	if err != nil || h <= 0 {
		return 0, false
	}
	return h, true
}

// TerminalWidth returns the current terminal's column count. ok is false
// when stdout isn't an interactive terminal or its size can't be
// determined.
func TerminalWidth() (width int, ok bool) {
	fd := int(os.Stdout.Fd())
	if !term.IsTerminal(fd) {
		return 0, false
	}
	w, _, err := term.GetSize(fd)
	if err != nil || w <= 0 {
		return 0, false
	}
	return w, true
}

// WrapCommandList greedily packs items onto as few "indent + item | item |
// ..." lines as fit within width, instead of breaking at fixed points
// that might be too narrow (wrapping/truncating unpredictably in the
// terminal) or too wide (wasting space) for a given window size.
func WrapCommandList(items []string, indent string, width int) []string {
	if width <= 0 {
		width = 70
	}

	var lines []string
	line := ""
	for _, item := range items {
		if line == "" {
			line = indent + item
			continue
		}
		candidate := line + " | " + item
		if len(candidate) > width {
			lines = append(lines, line)
			line = indent + item
			continue
		}
		line = candidate
	}
	if line != "" {
		lines = append(lines, line)
	}
	return lines
}

type Status struct {
	XMLName xml.Name `xml:"status"`
	State   string   `xml:"state"`
	Song    string   `xml:"song"`
	Artist  string   `xml:"artist"`
	Album   string   `xml:"album"`
	Volume  int      `xml:"volume"`
}

// Player info for scan results
type PlayerInfo struct {
	IP    string
	Name  string
	Brand string
	Model string
	Type  DeviceType
	UUID  string // Sonos RINCON ID, e.g. "RINCON_000E5872AA6801400"
}

// Generic client interface
type AudioClient interface {
	GetPresets() ([]Preset, error)
	GetStatus() (*Status, error)
	PlayPreset(id int) error
	Play() error
	Pause() error
	Stop() error
	SetVolume(level int) error
	Next() error
	Previous() error
	AddSlave(slaveIP string) error
	RemoveSlave(slaveIP string) error
	RemoveAllSlaves() error
	LeaveGroup() error
	GetDeviceType() DeviceType
	DebugAPI() string
}
