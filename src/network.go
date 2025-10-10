package main

import (
	"encoding/xml"
	"fmt"
	"io"
	"net"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	BluesoundPort = "11000"
	SonosPort     = "1400"
	ScanTimeout   = 3 * time.Second
)

// Network interface info
type NetworkInterface struct {
	Name   string
	IP     string
	Subnet string
}

// Enhanced network scanner that scans all available interfaces
func scanForPlayers() ([]PlayerInfo, error) {
	fmt.Println(getText("scanning"))

	// Get all network interfaces
	interfaces, err := getAllNetworkInterfaces()
	if err != nil {
		return nil, fmt.Errorf(getText("could_not_determine_ip"), err)
	}

	if len(interfaces) == 0 {
		return nil, fmt.Errorf("no network interfaces found")
	}

	fmt.Printf(getText("scanning_interfaces")+"\n", len(interfaces))

	var players []PlayerInfo
	var mu sync.Mutex
	var wg sync.WaitGroup

	// Scan each network interface
	for _, iface := range interfaces {
		fmt.Printf(getText("scanning_interface")+"\n", iface.Name, iface.Subnet)

		// Scan all IPs in this subnet in parallel
		for i := 1; i < 255; i++ {
			wg.Add(1)
			go func(ip string) {
				defer wg.Done()

				// Check for BluOS player
				if player, found := checkForBluOSPlayer(ip); found {
					mu.Lock()
					// Check if we already found this player on another interface
					exists := false
					for _, existingPlayer := range players {
						if existingPlayer.IP == player.IP {
							exists = true
							break
						}
					}
					if !exists {
						players = append(players, player)
						fmt.Printf(getText("found_player")+"\n", player.Name, player.Model, player.IP)
					}
					mu.Unlock()
				}

				// Check for Sonos player
				if player, found := checkForSonosPlayer(ip); found {
					mu.Lock()
					// Check if we already found this player on another interface
					exists := false
					for _, existingPlayer := range players {
						if existingPlayer.IP == player.IP {
							exists = true
							break
						}
					}
					if !exists {
						players = append(players, player)
						fmt.Printf(getText("found_player")+"\n", player.Name, player.Model, player.IP)
					}
					mu.Unlock()
				}
			}(fmt.Sprintf("%s.%d", iface.Subnet, i))
		}
	}

	wg.Wait()
	
	// Sort players by IP address for consistent ordering
	sort.Slice(players, func(i, j int) bool {
		return ipToInt(players[i].IP) < ipToInt(players[j].IP)
	})
	
	fmt.Printf(getText("completed_scan")+"\n", len(interfaces))
	return players, nil
}

// Convert IP address to integer for sorting
func ipToInt(ip string) uint32 {
	parts := strings.Split(ip, ".")
	if len(parts) != 4 {
		return 0
	}
	var result uint32
	for i := 0; i < 4; i++ {
		var octet uint32
		fmt.Sscanf(parts[i], "%d", &octet)
		result = result<<8 | octet
	}
	return result
}

// Get all network interfaces with their subnets
func getAllNetworkInterfaces() ([]NetworkInterface, error) {
	var interfaces []NetworkInterface

	// Get all network interfaces
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}

	for _, iface := range ifaces {
		// Skip down interfaces and loopback
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		// Get addresses for this interface
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			// Only process IPv4 addresses
			if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
				if ipnet.IP.To4() != nil {
					subnet := getSubnet(ipnet.IP.String())

					// Skip common virtual/internal networks unless they're the only option
					ipStr := ipnet.IP.String()
					if !isUsefulNetwork(ipStr) {
						continue
					}

					interfaces = append(interfaces, NetworkInterface{
						Name:   iface.Name,
						IP:     ipStr,
						Subnet: subnet,
					})
				}
			}
		}
	}

	// If no "useful" networks found, include all IPv4 networks
	if len(interfaces) == 0 {
		for _, iface := range ifaces {
			if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
				continue
			}

			addrs, err := iface.Addrs()
			if err != nil {
				continue
			}

			for _, addr := range addrs {
				if ipnet, ok := addr.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
					if ipnet.IP.To4() != nil {
						subnet := getSubnet(ipnet.IP.String())
						interfaces = append(interfaces, NetworkInterface{
							Name:   iface.Name,
							IP:     ipnet.IP.String(),
							Subnet: subnet,
						})
					}
				}
			}
		}
	}

	return interfaces, nil
}

// Check if this is a "useful" network (not VirtualBox NAT, etc.)
func isUsefulNetwork(ip string) bool {
	// Common home/office networks
	if strings.HasPrefix(ip, "192.168.") {
		return true
	}
	if strings.HasPrefix(ip, "10.0.0.") || strings.HasPrefix(ip, "10.0.1.") {
		return true
	}
	if strings.HasPrefix(ip, "172.16.") || strings.HasPrefix(ip, "172.17.") {
		return true
	}

	// VirtualBox NAT network (usually not where real devices are)
	if strings.HasPrefix(ip, "10.0.2.") {
		return false
	}

	// Docker networks
	if strings.HasPrefix(ip, "172.17.") {
		return false
	}

	return true
}

func getSubnet(ip string) string {
	parts := strings.Split(ip, ".")
	return strings.Join(parts[:3], ".")
}

func checkForBluOSPlayer(ip string) (PlayerInfo, bool) {
	client := &http.Client{Timeout: ScanTimeout}
	url := fmt.Sprintf("http://%s:%s/SyncStatus", ip, BluesoundPort)

	resp, err := client.Get(url)
	if err != nil {
		return PlayerInfo{}, false
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return PlayerInfo{}, false
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return PlayerInfo{}, false
	}

	var syncStatus SyncStatus
	if err := xml.Unmarshal(body, &syncStatus); err != nil {
		return PlayerInfo{}, false
	}

	return PlayerInfo{
		IP:    ip,
		Name:  syncStatus.Name,
		Brand: syncStatus.Brand,
		Model: syncStatus.Model,
		Type:  DeviceTypeBluOS,
	}, true
}

func checkForSonosPlayer(ip string) (PlayerInfo, bool) {
	client := &http.Client{Timeout: ScanTimeout}

	// Try to get device description from Sonos
	url := fmt.Sprintf("http://%s:%s/xml/device_description.xml", ip, SonosPort)
	resp, err := client.Get(url)
	if err != nil {
		return PlayerInfo{}, false
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return PlayerInfo{}, false
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return PlayerInfo{}, false
	}

	bodyStr := string(body)

	// Check if this is actually a Sonos device
	if !strings.Contains(bodyStr, "Sonos") && !strings.Contains(bodyStr, "RINCON") {
		return PlayerInfo{}, false
	}

	// Extract device name and model using regex
	name := "Sonos Player"
	model := "Sonos"

	// Try to extract friendly name
	if re := regexp.MustCompile(`<friendlyName>(.*?)</friendlyName>`); re != nil {
		if matches := re.FindStringSubmatch(bodyStr); len(matches) > 1 {
			name = strings.TrimSpace(matches[1])
			// Clean up the name - remove IP and RINCON part if present
			if idx := strings.Index(name, " - RINCON"); idx != -1 {
				name = strings.TrimSpace(name[:idx])
			}
			// Remove IP addresses from the name
			ipRegex := regexp.MustCompile(`\d+\.\d+\.\d+\.\d+\s*-?\s*`)
			name = ipRegex.ReplaceAllString(name, "")
			name = strings.TrimSpace(name)
		}
	}

	// Try to extract model name
	if re := regexp.MustCompile(`<modelName>(.*?)</modelName>`); re != nil {
		if matches := re.FindStringSubmatch(bodyStr); len(matches) > 1 {
			model = strings.TrimSpace(matches[1])
		}
	}

	// If name is still too complex or contains IP, use model name
	if len(name) > 50 || strings.Contains(name, ".") || name == "" {
		if model != "Sonos" && model != "" {
			name = model
		} else {
			name = fmt.Sprintf("Sonos-%s", ip[strings.LastIndex(ip, ".")+1:])
		}
	}

	return PlayerInfo{
		IP:    ip,
		Name:  name,
		Brand: "Sonos",
		Model: model,
		Type:  DeviceTypeSonos,
	}, true
}