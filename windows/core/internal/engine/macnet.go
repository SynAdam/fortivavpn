package engine

import (
	"fmt"
	"net/netip"
	"regexp"
	"strings"
)

// What the macOS build reads from networksetup, and the utun it takes. It
// has no build tag, so its tests run wherever the module's tests do.

// portKind names a hardware port's medium the way the app's diagnostics
// do. An iPhone over USB or Bluetooth is a phone's mobile data.
func portKind(port string) string {
	p := strings.ToLower(port)
	switch {
	case p == "wi-fi" || p == "airport":
		return "wifi"
	case strings.Contains(p, "iphone") || strings.Contains(p, "ipad") ||
		strings.Contains(p, "bluetooth pan") || strings.Contains(p, "modem"):
		return "mobile"
	case strings.Contains(p, "thunderbolt bridge") || strings.HasPrefix(p, "thunderbolt "):
		return "other"
	case strings.Contains(p, "ethernet") || strings.Contains(p, "lan"):
		return "ethernet"
	default:
		return "other"
	}
}

// parseHardwarePorts reads "networksetup -listallhardwareports": a
// "Hardware Port:" line, then its "Device:" line, for each port. The result
// maps a device ("en0") to its kind.
func parseHardwarePorts(out string) map[string]string {
	ports := map[string]string{}
	port := ""
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if v, ok := strings.CutPrefix(line, "Hardware Port:"); ok {
			port = strings.TrimSpace(v)
			continue
		}
		if v, ok := strings.CutPrefix(line, "Device:"); ok && port != "" {
			if dev := strings.TrimSpace(v); dev != "" {
				ports[dev] = portKind(port)
			}
			port = ""
		}
	}
	return ports
}

// macService is one network service, as the Network settings list it.
type macService struct {
	Name    string
	Device  string
	Enabled bool
}

var (
	serviceLine = regexp.MustCompile(`^\((\d+|\*)\)\s+(.+)$`)
	portLine    = regexp.MustCompile(`^\(Hardware Port: (.*), Device: (.*)\)$`)
)

// parseServiceOrder reads "networksetup -listnetworkserviceorder": "(1)
// Name", or "(*) Name" for a disabled service, then its "(Hardware Port: …,
// Device: …)" line. Another VPN's service has no device.
func parseServiceOrder(out string) []macService {
	var services []macService
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if m := serviceLine.FindStringSubmatch(line); m != nil {
			services = append(services, macService{Name: m[2], Enabled: m[1] != "*"})
			continue
		}
		if m := portLine.FindStringSubmatch(line); m != nil && len(services) > 0 {
			services[len(services)-1].Device = strings.TrimSpace(m[2])
		}
	}
	return services
}

// parseDNSServers reads "networksetup -getdnsservers": an address a line,
// or a sentence when the service uses its network's own resolvers, which
// is no address.
func parseDNSServers(out string) []string {
	var servers []string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if _, err := netip.ParseAddr(line); err == nil {
			servers = append(servers, line)
		}
	}
	return servers
}

// firstUtun is the lowest utun number the tunnel takes. macOS and other
// VPNs take the low ones (iCloud Private Relay, Back to My Mac, Tailscale
// and the like start at utun0), and the core refuses a name that is taken.
const firstUtun = 10

// freeUtun is the first utun name from firstUtun on that is not taken.
func freeUtun(taken map[string]bool) string {
	for n := firstUtun; ; n++ {
		if name := fmt.Sprintf("utun%d", n); !taken[name] {
			return name
		}
	}
}
