package main

import (
	"encoding/xml"
	"fmt"
	"html"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Structures for Sonos XML parsing
type SonosGetPositionInfoResponse struct {
	XMLName xml.Name  `xml:"Envelope"`
	Body    SonosBody `xml:"Body"`
}

type SonosBody struct {
	XMLName           xml.Name                  `xml:"Body"`
	GetPositionInfo   SonosGetPositionInfoBody  `xml:"GetPositionInfoResponse"`
	GetTransportInfo  SonosGetTransportInfoBody `xml:"GetTransportInfoResponse"`
	GetVolumeResponse SonosGetVolumeBody        `xml:"GetVolumeResponse"`
	Browse            SonosBrowseBody           `xml:"BrowseResponse"`
}

type SonosGetPositionInfoBody struct {
	XMLName       xml.Name `xml:"GetPositionInfoResponse"`
	Track         string   `xml:"Track"`
	TrackMetaData string   `xml:"TrackMetaData"`
}

type SonosGetTransportInfoBody struct {
	XMLName               xml.Name `xml:"GetTransportInfoResponse"`
	CurrentTransportState string   `xml:"CurrentTransportState"`
}

type SonosGetVolumeBody struct {
	XMLName       xml.Name `xml:"GetVolumeResponse"`
	CurrentVolume string   `xml:"CurrentVolume"`
}

type SonosBrowseBody struct {
	XMLName xml.Name `xml:"BrowseResponse"`
	Result  string   `xml:"Result"`
}

// Sonos favorite item structure
type SonosFavorite struct {
	ID   int
	Name string
	URI  string
	Meta string
}

// Sonos API Client
type SonosClient struct {
	baseURL   string
	client    *http.Client
	favorites []SonosFavorite
}

func NewSonosClient(ip string) *SonosClient {
	return &SonosClient{
		baseURL: fmt.Sprintf("http://%s:%s", ip, SonosPort),
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		favorites: make([]SonosFavorite, 0),
	}
}

// Sonos API methods
func (sc *SonosClient) makeSoapRequest(action, service, body string) ([]byte, error) {
	soapEnvelope := fmt.Sprintf(`<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>%s</s:Body>
</s:Envelope>`, body)

	url := fmt.Sprintf("%s/MediaRenderer/%s/Control", sc.baseURL, service)
	req, err := http.NewRequest("POST", url, strings.NewReader(soapEnvelope))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "text/xml; charset=utf-8")
	req.Header.Set("SOAPAction", fmt.Sprintf(`"urn:schemas-upnp-org:service:%s:1#%s"`, service, action))
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(soapEnvelope)))

	resp, err := sc.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("SOAP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("SOAP request failed with status %d: %s", resp.StatusCode, string(bodyBytes))
	}

	return io.ReadAll(resp.Body)
}

func (sc *SonosClient) loadFavorites() error {
	if len(sc.favorites) > 0 {
		return nil // Already loaded
	}

	// Force clear cache to reload
	sc.favorites = nil

	// First, try to get Sonos Radio favorites (R:0/0)
	radioFavorites := sc.browseSonosRadioStations()

	if len(radioFavorites) > 0 {
		sc.favorites = radioFavorites
		return nil
	}

	// If no radio favorites found, create informative entry
	sc.favorites = []SonosFavorite{
		{ID: 1, Name: "[INFO] No Sonos Radio favorites found", URI: "", Meta: ""},
		{ID: 2, Name: "[INFO] Add radio stations in the Sonos app", URI: "", Meta: ""},
	}

	return nil
}

func (sc *SonosClient) browseSonosRadioStations() []SonosFavorite {
	var allRadioFavorites []SonosFavorite

	// Try different ObjectIDs for Sonos Radio stations
	radioObjectIDs := []struct {
		id   string
		name string
	}{
		{"R:0/0", "Sonos Radio"},
		{"R:0/1", "Radio Stations"},
		{"FV:2", "Favorites"}, // Sometimes radio stations are in general favorites
		{"A:RADIO", "Radio"},
		{"SQ:", "Sonos Favorites"},
	}

	for _, obj := range radioObjectIDs {
		favorites := sc.browseForRadioContent(obj.id)

		// Filter to only include radio stations
		for _, fav := range favorites {
			if sc.isRadioStation(fav) {
				// Check if not already in the list
				isDuplicate := false
				for _, existing := range allRadioFavorites {
					if existing.URI == fav.URI || existing.Name == fav.Name {
						isDuplicate = true
						break
					}
				}
				if !isDuplicate {
					allRadioFavorites = append(allRadioFavorites, fav)
				}
			}
		}
	}

	// Re-number the favorites
	for i := range allRadioFavorites {
		allRadioFavorites[i].ID = i + 1
	}

	return allRadioFavorites
}

func (sc *SonosClient) browseForRadioContent(objectID string) []SonosFavorite {
	body := fmt.Sprintf(`<u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
		<ObjectID>%s</ObjectID>
		<BrowseFlag>BrowseDirectChildren</BrowseFlag>
		<Filter>*</Filter>
		<StartingIndex>0</StartingIndex>
		<RequestedCount>100</RequestedCount>
		<SortCriteria></SortCriteria>
	</u:Browse>`, objectID)

	soapEnvelope := fmt.Sprintf(`<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>%s</s:Body>
</s:Envelope>`, body)

	// Try MediaServer path
	url := fmt.Sprintf("%s/MediaServer/ContentDirectory/Control", sc.baseURL)
	req, err := http.NewRequest("POST", url, strings.NewReader(soapEnvelope))
	if err != nil {
		return []SonosFavorite{}
	}

	req.Header.Set("Content-Type", "text/xml; charset=utf-8")
	req.Header.Set("SOAPAction", `"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"`)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(soapEnvelope)))

	resp, err := sc.client.Do(req)
	if err != nil {
		return []SonosFavorite{}
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return []SonosFavorite{}
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return []SonosFavorite{}
	}

	return sc.parseFavoritesFromResponse(string(data))
}

func (sc *SonosClient) isRadioStation(fav SonosFavorite) bool {
	// Check URI patterns that indicate radio stations
	radioPatterns := []string{
		"x-sonosapi-stream:",
		"x-sonosapi-radio:",
		"x-rincon-mp3radio:",
		"http://", // Many radio stations use direct HTTP streams
		"https://",
		"mms://",
		"rtsp://",
		"x-sonos-http:",
	}

	for _, pattern := range radioPatterns {
		if strings.HasPrefix(fav.URI, pattern) {
			return true
		}
	}

	// Check metadata for radio-related classes
	if strings.Contains(fav.Meta, "object.item.audioItem.audioBroadcast") ||
		strings.Contains(fav.Meta, "object.item.audioItem.radio") ||
		strings.Contains(fav.Meta, "radioBroadcast") {
		return true
	}

	// Check if the name suggests it's a radio station
	radioNamePatterns := []string{
		"Radio",
		"FM",
		"AM",
		"Stream",
		"Live",
	}

	nameLower := strings.ToLower(fav.Name)
	for _, pattern := range radioNamePatterns {
		if strings.Contains(nameLower, strings.ToLower(pattern)) {
			return true
		}
	}

	return false
}

func (sc *SonosClient) parseFavoritesFromResponse(xmlResponse string) []SonosFavorite {
	var favorites []SonosFavorite

	// Look for the Result element in the SOAP response
	resultRegex := regexp.MustCompile(`<Result>(.*?)</Result>`)
	resultMatch := resultRegex.FindStringSubmatch(xmlResponse)

	if len(resultMatch) < 2 {
		return favorites
	}

	// Decode the DIDL-Lite content
	didlContent := html.UnescapeString(resultMatch[1])

	// Parse items from DIDL-Lite - capture the full item element
	// Use (?s) flag to make . match newlines
	itemRegex := regexp.MustCompile(`(?s)(<item[^>]*>.*?</item>)`)
	titleRegex := regexp.MustCompile(`<dc:title[^>]*>(.*?)</dc:title>`)
	resRegex := regexp.MustCompile(`<res[^>]*>(.*?)</res>`)

	items := itemRegex.FindAllStringSubmatch(didlContent, -1)

	for i, item := range items {
		if len(item) > 1 {
			fullItemXml := item[1]

			var title, uri string

			if titleMatch := titleRegex.FindStringSubmatch(fullItemXml); len(titleMatch) > 1 {
				title = html.UnescapeString(titleMatch[1])
			}

			if resMatch := resRegex.FindStringSubmatch(fullItemXml); len(resMatch) > 1 {
				uri = html.UnescapeString(resMatch[1])
			}

			if title != "" {
				favorites = append(favorites, SonosFavorite{
					ID:   i + 1,
					Name: strings.TrimSpace(title),
					URI:  uri,
					Meta: fullItemXml, // Store full item XML for use in SetAVTransportURI
				})
			}
		}
	}

	return favorites
}

func (sc *SonosClient) GetPresets() ([]Preset, error) {
	if err := sc.loadFavorites(); err != nil {
		return nil, err
	}

	var presets []Preset
	for _, fav := range sc.favorites {
		presets = append(presets, Preset{
			ID:   fav.ID,
			Name: fav.Name,
			URL:  fav.URI,
		})
	}

	return presets, nil
}

func (sc *SonosClient) GetStatus() (*Status, error) {
	// Get transport state
	transportBody := `<u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:GetTransportInfo>`

	transportData, err := sc.makeSoapRequest("GetTransportInfo", "AVTransport", transportBody)
	if err != nil {
		return &Status{
			State:  "stopped",
			Song:   "",
			Artist: "",
			Album:  "",
			Volume: 0,
		}, nil
	}

	var transportResponse SonosGetPositionInfoResponse
	if err := xml.Unmarshal(transportData, &transportResponse); err != nil {
		return &Status{
			State:  "stopped",
			Song:   "",
			Artist: "",
			Album:  "",
			Volume: 0,
		}, nil
	}

	state := strings.ToLower(transportResponse.Body.GetTransportInfo.CurrentTransportState)

	// Get position info (current track)
	positionBody := `<u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:GetPositionInfo>`

	positionData, err := sc.makeSoapRequest("GetPositionInfo", "AVTransport", positionBody)
	if err != nil {
		// Continue with basic state info
		return &Status{
			State:  state,
			Song:   "",
			Artist: "",
			Album:  "",
			Volume: 0,
		}, nil
	}

	var positionResponse SonosGetPositionInfoResponse
	if err := xml.Unmarshal(positionData, &positionResponse); err != nil {
		return &Status{
			State:  state,
			Song:   "",
			Artist: "",
			Album:  "",
			Volume: 0,
		}, nil
	}

	// Parse track metadata to extract song, artist, album
	metadata := positionResponse.Body.GetPositionInfo.TrackMetaData
	song, artist, album := parseSonosMetadata(metadata)

	// Get volume
	volumeBody := `<u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
		<InstanceID>0</InstanceID>
		<Channel>Master</Channel>
	</u:GetVolume>`

	volume := 0
	volumeData, err := sc.makeSoapRequest("GetVolume", "RenderingControl", volumeBody)
	if err == nil {
		var volumeResponse SonosGetPositionInfoResponse
		if err := xml.Unmarshal(volumeData, &volumeResponse); err == nil {
			volume, _ = strconv.Atoi(volumeResponse.Body.GetVolumeResponse.CurrentVolume)
		}
	}

	return &Status{
		State:  state,
		Song:   song,
		Artist: artist,
		Album:  album,
		Volume: volume,
	}, nil
}

func parseSonosMetadata(metadata string) (song, artist, album string) {
	titleRegex := regexp.MustCompile(`<dc:title[^>]*>(.*?)</dc:title>`)
	creatorRegex := regexp.MustCompile(`<dc:creator[^>]*>(.*?)</dc:creator>`)
	albumRegex := regexp.MustCompile(`<upnp:album[^>]*>(.*?)</upnp:album>`)

	if match := titleRegex.FindStringSubmatch(metadata); len(match) > 1 {
		song = html.UnescapeString(match[1])
	}
	if match := creatorRegex.FindStringSubmatch(metadata); len(match) > 1 {
		artist = html.UnescapeString(match[1])
	}
	if match := albumRegex.FindStringSubmatch(metadata); len(match) > 1 {
		album = html.UnescapeString(match[1])
	}

	return song, artist, album
}

func (sc *SonosClient) PlayPreset(id int) error {
	if err := sc.loadFavorites(); err != nil {
		return err
	}

	// Find the favorite
	var favorite *SonosFavorite
	for _, fav := range sc.favorites {
		if fav.ID == id {
			favorite = &fav
			break
		}
	}

	if favorite == nil {
		return fmt.Errorf("favorite not found")
	}

	// Skip INFO entries
	if strings.HasPrefix(favorite.Name, "[INFO]") {
		return fmt.Errorf("this is an info entry, not playable")
	}

	if favorite.URI == "" {
		return fmt.Errorf("no URI available for this favorite")
	}

	// Extract r:resMD from the item metadata if present - this contains the proper playback metadata
	var metadata string
	resMDRegex := regexp.MustCompile(`<r:resMD>(.*?)</r:resMD>`)

	if resMDMatch := resMDRegex.FindStringSubmatch(favorite.Meta); len(resMDMatch) > 1 {
		// Use the resMD content directly - it's already escaped DIDL-Lite, just needs to stay escaped
		metadata = resMDMatch[1]
	} else if favorite.Meta != "" {
		// No resMD found, wrap the item in DIDL-Lite
		fullDidl := fmt.Sprintf(`<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">%s</DIDL-Lite>`, favorite.Meta)
		metadata = escapeXmlForSoap(fullDidl)
	} else {
		// Fallback: minimal metadata with TuneIn service
		fullDidl := fmt.Sprintf(`<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="R:0/0/0" parentID="R:0/0" restricted="true"><dc:title>%s</dc:title><upnp:class>object.item.audioItem.audioBroadcast</upnp:class><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON65031_</desc></item></DIDL-Lite>`, html.EscapeString(favorite.Name))
		metadata = escapeXmlForSoap(fullDidl)
	}

	// Use SetAVTransportURI with proper metadata for radio streams
	body := fmt.Sprintf(`<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
		<CurrentURI>%s</CurrentURI>
		<CurrentURIMetaData>%s</CurrentURIMetaData>
	</u:SetAVTransportURI>`, html.EscapeString(favorite.URI), metadata)

	_, err := sc.makeSoapRequest("SetAVTransportURI", "AVTransport", body)
	if err != nil {
		return fmt.Errorf("SetAVTransportURI failed: %w", err)
	}

	// Start playback
	return sc.Play()
}

func (sc *SonosClient) Play() error {
	body := `<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
		<Speed>1</Speed>
	</u:Play>`

	_, err := sc.makeSoapRequest("Play", "AVTransport", body)
	return err
}

func (sc *SonosClient) Pause() error {
	body := `<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:Pause>`

	_, err := sc.makeSoapRequest("Pause", "AVTransport", body)
	return err
}

func (sc *SonosClient) Stop() error {
	body := `<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:Stop>`

	_, err := sc.makeSoapRequest("Stop", "AVTransport", body)
	return err
}

func (sc *SonosClient) SetVolume(level int) error {
	if level < 0 || level > 100 {
		return fmt.Errorf("volume must be between 0 and 100")
	}

	body := fmt.Sprintf(`<u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
		<InstanceID>0</InstanceID>
		<Channel>Master</Channel>
		<DesiredVolume>%d</DesiredVolume>
	</u:SetVolume>`, level)

	_, err := sc.makeSoapRequest("SetVolume", "RenderingControl", body)
	return err
}

func (sc *SonosClient) Next() error {
	body := `<u:Next xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:Next>`

	_, err := sc.makeSoapRequest("Next", "AVTransport", body)
	return err
}

func (sc *SonosClient) Previous() error {
	body := `<u:Previous xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:Previous>`

	_, err := sc.makeSoapRequest("Previous", "AVTransport", body)
	return err
}

func (sc *SonosClient) AddSlave(slaveIP string) error {
	// Sonos grouping is more complex - for now, return not implemented
	return fmt.Errorf("Sonos grouping not yet implemented")
}

func (sc *SonosClient) RemoveSlave(slaveIP string) error {
	return fmt.Errorf("Sonos grouping not yet implemented")
}

func (sc *SonosClient) RemoveAllSlaves() error {
	return fmt.Errorf("Sonos grouping not yet implemented")
}

func (sc *SonosClient) LeaveGroup() error {
	return fmt.Errorf("Sonos grouping not yet implemented")
}

func (sc *SonosClient) GetDeviceType() DeviceType {
	return DeviceTypeSonos
}

// escapeXmlForSoap escapes XML content for embedding in SOAP requests
func escapeXmlForSoap(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, "\"", "&quot;")
	s = strings.ReplaceAll(s, "'", "&apos;")
	return s
}

func (sc *SonosClient) DebugAPI() string {
	// Test basic HTTP connectivity first
	resp, err := sc.client.Get(sc.baseURL + "/xml/device_description.xml")
	if err != nil {
		return fmt.Sprintf("Sonos Debug: Device not reachable: %v", err)
	}
	resp.Body.Close()

	// Test SOAP services with correct actions
	var results []string

	// Test AVTransport
	if sc.testAVTransport() {
		results = append(results, "AVTransport: ✅")
	} else {
		results = append(results, "AVTransport: ❌")
	}

	// Test RenderingControl
	if sc.testRenderingControl() {
		results = append(results, "RenderingControl: ✅")
	} else {
		results = append(results, "RenderingControl: ❌")
	}

	// Test ContentDirectory
	if sc.testContentDirectory() {
		results = append(results, "ContentDirectory: ✅")
	} else {
		results = append(results, "ContentDirectory: ❌")
	}

	// Add favorite discovery debug info
	sc.favorites = nil // Clear cache to force reload
	sc.loadFavorites()
	results = append(results, fmt.Sprintf("Radio Favorites: %d found", len(sc.favorites)))

	return fmt.Sprintf("Sonos Debug: %s", strings.Join(results, " | "))
}

func (sc *SonosClient) testAVTransport() bool {
	body := `<u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:GetTransportInfo>`

	_, err := sc.makeSoapRequest("GetTransportInfo", "AVTransport", body)
	return err == nil
}

func (sc *SonosClient) testRenderingControl() bool {
	body := `<u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">
		<InstanceID>0</InstanceID>
		<Channel>Master</Channel>
	</u:GetVolume>`

	_, err := sc.makeSoapRequest("GetVolume", "RenderingControl", body)
	return err == nil
}

func (sc *SonosClient) testContentDirectory() bool {
	// Try MediaServer path first
	body := `<u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
		<ObjectID>0</ObjectID>
		<BrowseFlag>BrowseMetadata</BrowseFlag>
		<Filter>*</Filter>
		<StartingIndex>0</StartingIndex>
		<RequestedCount>1</RequestedCount>
		<SortCriteria></SortCriteria>
	</u:Browse>`

	soapEnvelope := fmt.Sprintf(`<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>%s</s:Body>
</s:Envelope>`, body)

	url := fmt.Sprintf("%s/MediaServer/ContentDirectory/Control", sc.baseURL)
	req, err := http.NewRequest("POST", url, strings.NewReader(soapEnvelope))
	if err != nil {
		return false
	}

	req.Header.Set("Content-Type", "text/xml; charset=utf-8")
	req.Header.Set("SOAPAction", `"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"`)
	req.Header.Set("Content-Length", fmt.Sprintf("%d", len(soapEnvelope)))

	resp, err := sc.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}
