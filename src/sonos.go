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
	TrackURI      string   `xml:"TrackURI"`
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
	ID          int
	Name        string
	URI         string
	Meta        string
	Category    PresetCategory
	IsContainer bool // playlists/albums: needs queue-based playback, see playContainer
}

// Sonos API Client
type SonosClient struct {
	baseURL   string
	client    *http.Client
	favorites []SonosFavorite
	uuid      string // cached RINCON UUID, see deviceUUID()
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

	favorites := sc.browseFavorites()

	if len(favorites) > 0 {
		sc.favorites = favorites
		return nil
	}

	// If no favorites found, create informative entry
	sc.favorites = []SonosFavorite{
		{ID: 1, Name: "[INFO] No Sonos favorites found", Category: CategoryStation},
		{ID: 2, Name: "[INFO] Add favorites in the Sonos app", Category: CategoryStation},
	}

	return nil
}

// browseFavorites browses all known favorite/library containers and merges
// the results into a single deduplicated, categorized list (radio
// stations, playlists, albums, songs). Category filtering itself happens
// per-item in parseFavoritesFromResponse via categorizeFavorite.
func (sc *SonosClient) browseFavorites() []SonosFavorite {
	var allFavorites []SonosFavorite

	// Try different ObjectIDs for Sonos favorites/library content
	objectIDs := []string{
		"R:0/0",   // Sonos Radio
		"R:0/1",   // Radio Stations
		"FV:2",    // Sonos Favorites (radio, playlists, albums, songs)
		"A:RADIO", // Radio
		"SQ:",     // Sonos Playlists
	}

	for _, objectID := range objectIDs {
		favorites := sc.browseContainer(objectID)

		for _, fav := range favorites {
			// Check if not already in the list
			isDuplicate := false
			for _, existing := range allFavorites {
				if existing.URI == fav.URI || existing.Name == fav.Name {
					isDuplicate = true
					break
				}
			}
			if !isDuplicate {
				allFavorites = append(allFavorites, fav)
			}
		}
	}

	// Re-number the favorites
	for i := range allFavorites {
		allFavorites[i].ID = i + 1
	}

	return allFavorites
}

func (sc *SonosClient) browseContainer(objectID string) []SonosFavorite {
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

// categorizeFavorite maps a Sonos DIDL-Lite upnp:class and URI to a preset
// category, mirroring the Flutter app's _categorize() so both apps show
// the same favorites in the same buckets. ok is false for types that
// shouldn't be shown at all (e.g. meta-container "album list" nodes).
func categorizeFavorite(upnpClass, uri string) (category PresetCategory, ok bool) {
	cls := strings.ToLower(upnpClass)
	lowerURI := strings.ToLower(uri)

	// Album lists (meta-containers, not directly playable)
	if strings.Contains(cls, "albumlist") {
		return "", false
	}

	// Radio / audio broadcast
	if strings.Contains(cls, "audiobroadcast") || strings.Contains(cls, "radio") {
		return CategoryStation, true
	}
	// Music track / generic audio item
	if strings.Contains(cls, "musictrack") || (strings.Contains(cls, "audioitem") && !strings.Contains(cls, "broadcast")) {
		if strings.Contains(lowerURI, "x-sonosapi-stream:") ||
			strings.Contains(lowerURI, "x-sonosapi-radio:") ||
			strings.Contains(lowerURI, "x-rincon-mp3radio:") {
			return CategoryStation, true
		}
		if strings.Contains(cls, "musictrack") {
			return CategorySong, true
		}
	}
	// Album
	if strings.Contains(cls, "musicalbum") || strings.Contains(cls, "album") {
		return CategoryAlbum, true
	}
	// Playlist container
	if strings.Contains(cls, "playlistcontainer") || strings.Contains(cls, "playlist") {
		return CategoryPlaylist, true
	}
	// StorageFolder or generic container → playlist
	if strings.Contains(cls, "container") || strings.Contains(cls, "storagefolder") {
		return CategoryPlaylist, true
	}

	// URI-based fallback for items without a clear class
	switch {
	case strings.Contains(lowerURI, "x-sonosapi-stream:"),
		strings.Contains(lowerURI, "x-sonosapi-radio:"),
		strings.Contains(lowerURI, "x-rincon-mp3radio:"),
		strings.Contains(lowerURI, "mms://"),
		strings.Contains(lowerURI, "rtsp://"):
		return CategoryStation, true
	case strings.Contains(lowerURI, "x-sonosapi-hls:"),
		strings.Contains(lowerURI, "x-sonos-spotify:"),
		strings.Contains(lowerURI, "x-sonos-http:"):
		return CategoryPlaylist, true
	case strings.HasPrefix(lowerURI, "http://"), strings.HasPrefix(lowerURI, "https://"):
		return CategoryStation, true
	}

	return "", false
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

	// Parse both <item> (stations, songs) and <container> (playlists,
	// albums) elements from DIDL-Lite - capture the full element.
	// Use (?s) flag to make . match newlines.
	elementRegex := regexp.MustCompile(`(?s)<(item|container)\b[^>]*>.*?</(?:item|container)>`)
	titleRegex := regexp.MustCompile(`<dc:title[^>]*>(.*?)</dc:title>`)
	resRegex := regexp.MustCompile(`<res[^>]*>(.*?)</res>`)
	classRegex := regexp.MustCompile(`<upnp:class[^>]*>(.*?)</upnp:class>`)
	idAttrRegex := regexp.MustCompile(`\bid="([^"]*)"`)

	elements := elementRegex.FindAllString(didlContent, -1)

	for _, el := range elements {
		isContainerTag := strings.HasPrefix(el, "<container")

		var title, uri, class, itemID string

		if m := titleRegex.FindStringSubmatch(el); len(m) > 1 {
			title = html.UnescapeString(m[1])
		}
		if m := resRegex.FindStringSubmatch(el); len(m) > 1 {
			uri = html.UnescapeString(m[1])
		}
		if m := classRegex.FindStringSubmatch(el); len(m) > 1 {
			class = m[1]
		}
		if m := idAttrRegex.FindStringSubmatch(el); len(m) > 1 {
			itemID = m[1]
		}

		if title == "" {
			continue
		}

		category, ok := categorizeFavorite(class, uri)
		if !ok {
			continue
		}

		isContainer := isContainerTag ||
			strings.Contains(strings.ToLower(class), "container") ||
			strings.Contains(strings.ToLower(class), "album")

		// Items without a <res> URI (browse-only container references)
		// always need queue-based playback.
		if uri == "" && itemID != "" {
			uri = "x-rincon-cpcontainer:" + itemID
			isContainer = true
		}

		favorites = append(favorites, SonosFavorite{
			Name:        strings.TrimSpace(title),
			URI:         uri,
			Meta:        el, // Store full element XML for use in SetAVTransportURI/AddURIToQueue
			Category:    category,
			IsContainer: isContainer,
		})
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
			ID:       fav.ID,
			Name:     fav.Name,
			URL:      fav.URI,
			Category: fav.Category,
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
	song, artist, album, streamContent := parseSonosMetadata(metadata)

	// For radio streams, <r:streamContent> carries the current program
	// info; use it as artist when the metadata itself has none.
	if streamContent != "" && artist == "" {
		artist = streamContent
	}

	// Some services (e.g. TuneIn via aggregator) report the raw stream
	// URI as <dc:title> until real ICY metadata arrives - replace it with
	// the matching favorite's name (if known), or the stream's program
	// info, rather than showing a URL as the "song".
	if looksLikeStreamURI(song) {
		trackURI := positionResponse.Body.GetPositionInfo.TrackURI
		if favName := sc.findFavoriteNameByURI(trackURI); favName != "" {
			song = favName
		} else if streamContent != "" {
			song = streamContent
			artist = "" // avoid showing streamContent twice
		} else {
			song = ""
		}
	}

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

func parseSonosMetadata(metadata string) (song, artist, album, streamContent string) {
	titleRegex := regexp.MustCompile(`<dc:title[^>]*>(.*?)</dc:title>`)
	creatorRegex := regexp.MustCompile(`<dc:creator[^>]*>(.*?)</dc:creator>`)
	albumRegex := regexp.MustCompile(`<upnp:album[^>]*>(.*?)</upnp:album>`)
	// <r:streamContent> carries the current program info for radio
	// streams (e.g. artist - title), separate from the static station
	// <dc:title>.
	streamContentRegex := regexp.MustCompile(`<r:streamContent[^>]*>(.*?)</r:streamContent>`)

	if match := titleRegex.FindStringSubmatch(metadata); len(match) > 1 {
		song = html.UnescapeString(match[1])
	}
	if match := creatorRegex.FindStringSubmatch(metadata); len(match) > 1 {
		artist = html.UnescapeString(match[1])
	}
	if match := albumRegex.FindStringSubmatch(metadata); len(match) > 1 {
		album = html.UnescapeString(match[1])
	}
	if match := streamContentRegex.FindStringSubmatch(metadata); len(match) > 1 {
		streamContent = html.UnescapeString(match[1])
	}

	return song, artist, album, streamContent
}

// looksLikeStreamURI reports whether s is a raw stream URI/filename
// rather than a real title - some radio services (e.g. TuneIn via
// aggregator services) report the stream URL itself as <dc:title> until
// the station's actual ICY metadata arrives.
func looksLikeStreamURI(s string) bool {
	if s == "" {
		return false
	}
	if strings.HasPrefix(s, "http://") ||
		strings.HasPrefix(s, "https://") ||
		strings.HasPrefix(s, "x-") ||
		strings.HasPrefix(s, "aac://") ||
		strings.HasPrefix(s, "mms://") ||
		strings.Contains(s, "stream.") ||
		strings.Contains(s, "?aggregator=") {
		return true
	}
	// General fallback: some streaming services report an opaque
	// filename/query string as <dc:title> in a shape the prefix checks
	// above don't cover (e.g. "regc-80s80ssoul...?sABC=...&amsparams=
	// playerid:...;skey=..."). Real titles virtually always contain a
	// space; a single long, space-free token full of query/tracking
	// punctuation does not.
	if !strings.Contains(s, " ") && len(s) > 20 && strings.ContainsAny(s, "?&=#;") {
		return true
	}
	return false
}

// findFavoriteNameByURI returns the cached favorite's name matching uri,
// or "" if no favorites are loaded yet or none match.
func (sc *SonosClient) findFavoriteNameByURI(uri string) string {
	if uri == "" {
		return ""
	}
	for _, fav := range sc.favorites {
		if fav.URI == uri {
			return fav.Name
		}
	}
	return ""
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

	// Container types (playlists, albums) need queue-based playback.
	// Direct URIs (stations, songs) use SetAVTransportURI.
	if favorite.IsContainer {
		return sc.playContainer(favorite)
	}
	return sc.playItem(favorite)
}

// playItem plays a directly-playable favorite (radio stations, songs) via
// SetAVTransportURI.
func (sc *SonosClient) playItem(favorite *SonosFavorite) error {
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

// playContainer plays a playlist/album favorite by replacing the queue
// with its contents and switching transport to the queue - a direct
// SetAVTransportURI to a container URI does not start playback, unlike
// stations/songs handled by playItem.
func (sc *SonosClient) playContainer(favorite *SonosFavorite) error {
	var metadata string
	if favorite.Meta != "" {
		fullDidl := fmt.Sprintf(`<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:r="urn:schemas-rinconnetworks-com:metadata-1-0/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">%s</DIDL-Lite>`, favorite.Meta)
		metadata = escapeXmlForSoap(fullDidl)
	}

	// 1. Clear queue
	if _, err := sc.makeSoapRequest("RemoveAllTracksFromQueue", "AVTransport",
		`<u:RemoveAllTracksFromQueue xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:RemoveAllTracksFromQueue>`); err != nil {
		return fmt.Errorf("RemoveAllTracksFromQueue failed: %w", err)
	}

	// 2. Add container to queue
	addBody := fmt.Sprintf(`<u:AddURIToQueue xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
		<EnqueuedURI>%s</EnqueuedURI>
		<EnqueuedURIMetaData>%s</EnqueuedURIMetaData>
		<DesiredFirstTrackNumberEnqueued>0</DesiredFirstTrackNumberEnqueued>
		<EnqueueAsNext>1</EnqueueAsNext>
	</u:AddURIToQueue>`, html.EscapeString(favorite.URI), metadata)
	if _, err := sc.makeSoapRequest("AddURIToQueue", "AVTransport", addBody); err != nil {
		return fmt.Errorf("AddURIToQueue failed: %w", err)
	}

	// 3. Switch transport to the queue
	if uuid, err := sc.deviceUUID(); err == nil && uuid != "" {
		queueBody := fmt.Sprintf(`<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
			<InstanceID>0</InstanceID>
			<CurrentURI>x-rincon-queue:%s#0</CurrentURI>
			<CurrentURIMetaData></CurrentURIMetaData>
		</u:SetAVTransportURI>`, uuid)
		if _, err := sc.makeSoapRequest("SetAVTransportURI", "AVTransport", queueBody); err != nil {
			return fmt.Errorf("SetAVTransportURI (queue) failed: %w", err)
		}
	}

	// 4. Play
	return sc.Play()
}

// deviceUUID returns this player's RINCON UUID, needed to address its own
// queue as a playback source (x-rincon-queue:<uuid>#0).
func (sc *SonosClient) deviceUUID() (string, error) {
	if sc.uuid != "" {
		return sc.uuid, nil
	}

	resp, err := sc.client.Get(sc.baseURL + "/xml/device_description.xml")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	udnRegex := regexp.MustCompile(`<UDN>uuid:(RINCON_[A-Za-z0-9]+)</UDN>`)
	match := udnRegex.FindSubmatch(body)
	if len(match) < 2 {
		return "", fmt.Errorf("UDN not found in device description")
	}

	sc.uuid = string(match[1])
	return sc.uuid, nil
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

// makeSoapRequestPath sends a SOAP request to an arbitrary path (not just /MediaRenderer/...)
func (sc *SonosClient) makeSoapRequestPath(path, service, action, body string) ([]byte, error) {
	soapEnvelope := fmt.Sprintf(`<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
<s:Body>
  <u:%s xmlns:u="urn:schemas-upnp-org:service:%s:1">
    %s
  </u:%s>
</s:Body>
</s:Envelope>`, action, service, body, action)

	url := sc.baseURL + path
	req, err := http.NewRequest("POST", url, strings.NewReader(soapEnvelope))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "text/xml; charset=utf-8")
	req.Header.Set("SOAPAction", fmt.Sprintf(`"urn:schemas-upnp-org:service:%s:1#%s"`, service, action))

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

func (sc *SonosClient) AddSlave(slaveIP string) error {
	// Sonos grouping: we need the master's RINCON UUID.
	// Look up the UUID from the available players list.
	masterUUID := ""
	masterIP := strings.TrimPrefix(sc.baseURL, "http://")
	masterIP = strings.TrimSuffix(masterIP, ":"+SonosPort)

	for _, player := range tuiState.availablePlayers {
		if player.IP == masterIP && player.UUID != "" {
			masterUUID = player.UUID
			break
		}
	}

	if masterUUID == "" {
		return fmt.Errorf("cannot group: master RINCON UUID not found (IP: %s)", masterIP)
	}

	// Call SetAVTransportURI on the SLAVE with x-rincon:<master-UUID>
	slaveClient := NewSonosClient(slaveIP)
	body := fmt.Sprintf(`<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
		<CurrentURI>x-rincon:%s</CurrentURI>
		<CurrentURIMetaData></CurrentURIMetaData>
	</u:SetAVTransportURI>`, masterUUID)

	_, err := slaveClient.makeSoapRequest("SetAVTransportURI", "AVTransport", body)
	if err != nil {
		return fmt.Errorf("failed to group Sonos speakers: %w", err)
	}
	return nil
}

func (sc *SonosClient) RemoveSlave(slaveIP string) error {
	// Call BecomeCoordinatorOfStandaloneGroup on the slave
	slaveClient := NewSonosClient(slaveIP)
	body := `<u:BecomeCoordinatorOfStandaloneGroup xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:BecomeCoordinatorOfStandaloneGroup>`

	_, err := slaveClient.makeSoapRequest("BecomeCoordinatorOfStandaloneGroup", "AVTransport", body)
	if err != nil {
		return fmt.Errorf("failed to ungroup Sonos speaker: %w", err)
	}
	return nil
}

func (sc *SonosClient) RemoveAllSlaves() error {
	// Get zone group topology to find all members
	members, err := sc.getGroupMemberIPs()
	if err != nil {
		return fmt.Errorf("failed to get group members: %w", err)
	}

	masterIP := strings.TrimPrefix(sc.baseURL, "http://")
	masterIP = strings.TrimSuffix(masterIP, ":"+SonosPort)

	var lastErr error
	for _, memberIP := range members {
		if memberIP != masterIP {
			if err := sc.RemoveSlave(memberIP); err != nil {
				lastErr = err
			}
		}
	}
	return lastErr
}

func (sc *SonosClient) LeaveGroup() error {
	// This player leaves its current group
	body := `<u:BecomeCoordinatorOfStandaloneGroup xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
		<InstanceID>0</InstanceID>
	</u:BecomeCoordinatorOfStandaloneGroup>`
	_, err := sc.makeSoapRequest("BecomeCoordinatorOfStandaloneGroup", "AVTransport", body)
	if err != nil {
		return fmt.Errorf("failed to leave group: %w", err)
	}
	return nil
}

// getGroupMemberIPs returns the IPs of all members in this player's zone group.
func (sc *SonosClient) getGroupMemberIPs() ([]string, error) {
	data, err := sc.makeSoapRequestPath(
		"/ZoneGroupTopology/Control",
		"ZoneGroupTopology",
		"GetZoneGroupState",
		"",
	)
	if err != nil {
		return nil, err
	}

	// Extract the ZoneGroupState from the SOAP response
	stateRegex := regexp.MustCompile(`<ZoneGroupState>(.*?)</ZoneGroupState>`)
	stateMatch := stateRegex.FindStringSubmatch(string(data))
	if len(stateMatch) < 2 {
		return nil, fmt.Errorf("ZoneGroupState not found in response")
	}

	decoded := html.UnescapeString(stateMatch[1])

	masterIP := strings.TrimPrefix(sc.baseURL, "http://")
	masterIP = strings.TrimSuffix(masterIP, ":"+SonosPort)

	// Find the group containing this player's IP
	locationRegex := regexp.MustCompile(`Location="http://([^:]+):`)
	groupRegex := regexp.MustCompile(`(?s)<ZoneGroup[^>]*>.*?</ZoneGroup>`)

	groups := groupRegex.FindAllString(decoded, -1)
	for _, group := range groups {
		locations := locationRegex.FindAllStringSubmatch(group, -1)
		var ips []string
		containsThis := false

		for _, loc := range locations {
			if len(loc) > 1 {
				ip := loc[1]
				ips = append(ips, ip)
				if ip == masterIP {
					containsThis = true
				}
			}
		}

		if containsThis {
			return ips, nil
		}
	}

	return []string{masterIP}, nil
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
