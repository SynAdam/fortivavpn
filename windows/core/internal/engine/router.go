package engine

import (
	"bufio"
	"io"
	"net"
	"net/netip"
	"os"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
)

// RouterWAN is the WAN device the router build binds the core's sockets to,
// from its settings (cmd/fortiva-router). Empty follows the default route.
// Only Linux reads it (bind_linux.go).
var RouterWAN string

// RouterAdapterName is the router's TUN interface, which is never the WAN.
var RouterAdapterName = "fortiva0"

// ipv6Setting says whether a new interface gets IPv6. Writing
// net.ipv6.conf.all.disable_ipv6 also writes this one. Tests replace it.
var ipv6Setting = "/proc/sys/net/ipv6/conf/default/disable_ipv6"

// RouterAdapter is config.RouterAdapter, without its IPv6 address and
// routes when new interfaces get no IPv6 or the kernel has none. The engine
// asks at each connect, so turning IPv6 on or off needs no restart.
func RouterAdapter() config.AdapterSpec {
	if ipv6Off() {
		return config.RouterAdapter.WithoutIPv6()
	}
	return config.RouterAdapter
}

func ipv6Off() bool {
	data, err := os.ReadFile(ipv6Setting)
	// No file: a kernel without IPv6.
	return err != nil || strings.TrimSpace(string(data)) != "0"
}

// networkOf names the kind of network a WAN device is. A router's WAN is a
// cable most of the time; a cellular modem or a Wi-Fi uplink is told apart
// by the device's name.
func networkOf(device string) string {
	switch {
	case device == "":
		return ""
	case strings.HasPrefix(device, "wwan"), strings.HasPrefix(device, "usb"),
		strings.HasPrefix(device, "rmnet"), strings.HasPrefix(device, "3g-"),
		strings.HasPrefix(device, "qmi"), strings.HasPrefix(device, "mbim"):
		return "mobile"
	case strings.HasPrefix(device, "wlan"), strings.HasPrefix(device, "phy"),
		strings.HasPrefix(device, "apcli"), strings.HasPrefix(device, "sta"):
		return "wifi"
	default:
		return "ethernet"
	}
}

// parseDefaultRoute reads /proc/net/route: a header line, then one route a
// line, with the destination, flags, metric and mask in hex.
func parseDefaultRoute(r io.Reader, skip string) string {
	const rtfUp = 0x1
	best, bestMetric := "", int64(-1)
	sc := bufio.NewScanner(r)
	first := true
	for sc.Scan() {
		if first {
			first = false
			continue
		}
		f := strings.Fields(sc.Text())
		if len(f) < 8 {
			continue
		}
		iface, dest, flagsHex, metricText, mask := f[0], f[1], f[3], f[6], f[7]
		if iface == skip || dest != "00000000" || mask != "00000000" {
			continue
		}
		flags, err := strconv.ParseInt(flagsHex, 16, 64)
		if err != nil || flags&rtfUp == 0 {
			continue
		}
		metric, err := strconv.ParseInt(metricText, 10, 64)
		if err != nil {
			continue
		}
		if bestMetric < 0 || metric < bestMetric {
			best, bestMetric = iface, metric
		}
	}
	return best
}

// wanDevice is the WAN device a binder last saw.
type wanDevice struct {
	mu     sync.RWMutex
	device string
}

func (w *wanDevice) get() string {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return w.device
}

// set records device and says whether it changed, to or from "" (no WAN)
// included: the door group is measured again when the WAN goes and when it
// comes back.
func (w *wanDevice) set(device string) bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	changed := device != w.device
	w.device = device
	return changed
}

// bindDevice is the device a socket to address is bound to, or "" to leave
// it alone. Loopback is left alone, as on Windows. While binding is active
// and no WAN is known the socket is refused: unbound, it would follow the
// tunnel's routes into the tunnel it carries.
func bindDevice(active bool, device, address string) (string, error) {
	if !active {
		return "", nil
	}
	if host, _, err := net.SplitHostPort(address); err == nil {
		if ip, err := netip.ParseAddr(host); err == nil && ip.IsLoopback() {
			return "", nil
		}
	}
	if device == "" {
		return "", syscall.ENETUNREACH
	}
	return device, nil
}
