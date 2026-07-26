package main

import (
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// BluOS specific structures
type SyncStatus struct {
	XMLName xml.Name `xml:"SyncStatus"`
	Name    string   `xml:"name,attr"`
	Brand   string   `xml:"brand,attr"`
	Model   string   `xml:"model,attr"`
}

// BluOS API Client
type BluesoundClient struct {
	baseURL string
	client  *http.Client
}

func NewBluesoundClient(ip string) *BluesoundClient {
	return &BluesoundClient{
		baseURL: fmt.Sprintf("http://%s:%s", ip, BluesoundPort),
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// BluOS API methods
func (bc *BluesoundClient) makeRequest(endpoint string) ([]byte, error) {
	url := bc.baseURL + endpoint
	resp, err := bc.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	return body, nil
}

func (bc *BluesoundClient) GetPresets() ([]Preset, error) {
	data, err := bc.makeRequest("/Presets")
	if err != nil {
		return nil, err
	}

	var presets Presets
	if err := xml.Unmarshal(data, &presets); err != nil {
		return nil, fmt.Errorf("failed to parse presets XML: %w", err)
	}

	for i := range presets.Presets {
		presets.Presets[i].Category = categorizeBluOSPreset(presets.Presets[i].URL)
	}

	return presets.Presets, nil
}

// categorizeBluOSPreset mirrors the Flutter app's _categorizePreset so both
// apps group BluOS presets the same way: presets backed by a streaming
// service ("/load?service=...", e.g. a saved Spotify/TuneIn playlist) are
// shown as playlists, everything else (internet radio stations, AirPlay,
// etc.) as stations.
func categorizeBluOSPreset(url string) PresetCategory {
	if strings.HasPrefix(strings.ToLower(url), "/load?service=") {
		return CategoryPlaylist
	}
	return CategoryStation
}

func (bc *BluesoundClient) GetStatus() (*Status, error) {
	data, err := bc.makeRequest("/Status")
	if err != nil {
		return nil, err
	}

	var status Status
	if err := xml.Unmarshal(data, &status); err != nil {
		return nil, fmt.Errorf("failed to parse status XML: %w", err)
	}

	return &status, nil
}

func (bc *BluesoundClient) PlayPreset(id int) error {
	endpoint := fmt.Sprintf("/Preset?id=%d", id)
	_, err := bc.makeRequest(endpoint)
	return err
}

func (bc *BluesoundClient) Play() error {
	_, err := bc.makeRequest("/Play")
	return err
}

func (bc *BluesoundClient) Pause() error {
	_, err := bc.makeRequest("/Pause")
	return err
}

func (bc *BluesoundClient) Stop() error {
	_, err := bc.makeRequest("/Stop")
	return err
}

func (bc *BluesoundClient) SetVolume(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("volume must be between 0 and 100")
	}
	endpoint := fmt.Sprintf("/Volume?level=%d", level)
	_, err := bc.makeRequest(endpoint)
	return err
}

func (bc *BluesoundClient) Next() error {
	_, err := bc.makeRequest("/Skip")
	return err
}

func (bc *BluesoundClient) Previous() error {
	_, err := bc.makeRequest("/Back")
	return err
}

func (bc *BluesoundClient) AddSlave(slaveIP string) error {
	endpoint := fmt.Sprintf("/AddSlave?slave=%s", slaveIP)
	_, err := bc.makeRequest(endpoint)
	return err
}

func (bc *BluesoundClient) RemoveSlave(slaveIP string) error {
	endpoint := fmt.Sprintf("/RemoveSlave?slave=%s", slaveIP)
	_, err := bc.makeRequest(endpoint)
	return err
}

func (bc *BluesoundClient) RemoveAllSlaves() error {
	_, err := bc.makeRequest("/RemoveAllSlaves")
	return err
}

func (bc *BluesoundClient) LeaveGroup() error {
	_, err := bc.makeRequest("/LeaveGroup")
	return err
}

func (bc *BluesoundClient) GetDeviceType() DeviceType {
	return DeviceTypeBluOS
}

func (bc *BluesoundClient) DebugAPI() string {
	endpoints := []string{"/Status", "/SyncStatus", "/Presets", "/RemoveSlave", "/AddSlave", "/Slaves"}
	var results []string
	for _, endpoint := range endpoints {
		_, err := bc.makeRequest(endpoint)
		if err != nil {
			results = append(results, fmt.Sprintf("%s: ❌", endpoint))
		} else {
			results = append(results, fmt.Sprintf("%s: ✅", endpoint))
		}
	}
	return fmt.Sprintf("BluOS API Test: %s", strings.Join(results, " | "))
}
