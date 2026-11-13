package engine

import (
	"errors"
	"strings"
	"syscall"
	"testing"
)

func TestTheDefaultRouteWithTheLowestMetricIsTheWAN(t *testing.T) {
	table := `Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
br-lan	0001A8C0	00000000	0001	0	0	0	00FFFFFF	0	0	0
wwan0	00000000	0100000A	0003	0	0	20	00000000	0	0	0
pppoe-wan	00000000	01020304	0003	0	0	0	00000000	0	0	0
fortiva0	00000000	00000000	0001	0	0	0	00000000	0	0	0
eth1	00000000	0101A8C0	0002	0	0	0	00000000	0	0	0
`
	if got := parseDefaultRoute(strings.NewReader(table), "fortiva0"); got != "pppoe-wan" {
		// eth1's route is down (no RTF_UP), and fortiva0 is the tunnel.
		t.Fatalf("WAN is %q, want pppoe-wan", got)
	}
	if got := parseDefaultRoute(strings.NewReader("Iface\tDestination\n"), ""); got != "" {
		t.Fatalf("a table with no default route gave %q", got)
	}
}

func TestTheWANsKindComesFromItsName(t *testing.T) {
	for device, want := range map[string]string{
		"pppoe-wan": "ethernet", "eth1": "ethernet", "wan": "ethernet",
		"wwan0": "mobile", "usb0": "mobile", "3g-wan": "mobile",
		"phy0-sta0": "wifi", "wlan0": "wifi", "": "",
	} {
		if got := networkOf(device); got != want {
			t.Errorf("networkOf(%q) = %q, want %q", device, got, want)
		}
	}
}

func TestTheWANGoingAndComingBackAreBothChanges(t *testing.T) {
	var w wanDevice
	for i, step := range []struct {
		device  string
		changed bool
	}{
		{"pppoe-wan", true}, {"pppoe-wan", false}, {"", true}, {"", false}, {"pppoe-wan", true}, {"eth1", true},
	} {
		if got := w.set(step.device); got != step.changed {
			t.Fatalf("step %d to %q: changed %v, want %v", i, step.device, got, step.changed)
		}
	}
}

func TestASocketIsRefusedWhileTheTunnelIsUpAndNoWANIsKnown(t *testing.T) {
	// 192.0.2.0/24 is for documentation.
	for _, c := range []struct {
		active          bool
		device, address string
		want            string
		refused         bool
	}{
		{false, "", "192.0.2.7:443", "", false},
		{false, "eth1", "192.0.2.7:443", "", false},
		{true, "eth1", "192.0.2.7:443", "eth1", false},
		{true, "", "192.0.2.7:443", "", true},
		{true, "", "127.0.0.1:10808", "", false},
		{true, "eth1", "[::1]:53", "", false},
	} {
		got, err := bindDevice(c.active, c.device, c.address)
		if got != c.want || (err != nil) != c.refused || (err != nil && !errors.Is(err, syscall.ENETUNREACH)) {
			t.Errorf("bindDevice(%v, %q, %q) = %q, %v", c.active, c.device, c.address, got, err)
		}
	}
}

func TestTheRouterAdapterCarriesIPv4Alone(t *testing.T) {
	// IPv6 is refused in the routing table while the tunnel is up
	// (ipv6_linux.go), never routed into it: the core would answer it with
	// an HTTP 403.
	a := RouterAdapter()
	if strings.Join(a.Routes, " ") != "0.0.0.0/1 128.0.0.0/1" {
		t.Errorf("routes %v, want the two IPv4 halves", a.Routes)
	}
	for _, addr := range a.Address {
		if strings.Contains(addr, ":") {
			t.Errorf("an IPv6 address %s", addr)
		}
	}
	if a.Name != "fortiva0" {
		t.Errorf("name %q", a.Name)
	}
}
