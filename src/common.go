package main

import (
	"encoding/xml"
)

// Device type enumeration
type DeviceType string

const (
	DeviceTypeBluOS DeviceType = "bluos"
	DeviceTypeSonos DeviceType = "sonos"
)

// Common structures
type Presets struct {
	XMLName xml.Name `xml:"presets"`
	Presets []Preset `xml:"preset"`
}

type Preset struct {
	ID    int    `xml:"id,attr"`
	Name  string `xml:"name,attr"`
	URL   string `xml:"url,attr"`
	Image string `xml:"image,attr"`
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
