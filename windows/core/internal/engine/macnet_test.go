package engine

import (
	"reflect"
	"testing"
)

// Printed by networksetup on a Mac with two USB Ethernet adapters, Wi-Fi,
// an iPhone over USB and three other VPNs (2026-11-16).
const (
	hardwarePortsOut = `
Hardware Port: Ethernet Adapter (en3)
Device: en3
Ethernet Address: fa:73:dc:7e:00:28

Hardware Port: Thunderbolt Bridge
Device: bridge0
Ethernet Address: 36:04:10:de:cf:c0

Hardware Port: Wi-Fi
Device: en0
Ethernet Address: 1c:f6:4c:96:9a:35

Hardware Port: Thunderbolt 1
Device: en1
Ethernet Address: 36:04:10:de:cf:c0

Hardware Port: USB 10/100/1000 LAN
Device: en5
Ethernet Address: 00:e0:4c:68:00:01

Hardware Port: iPhone USB
Device: en6
Ethernet Address: 00:00:00:00:00:00

VLAN Configurations
===================
`
	serviceOrderOut = `An asterisk (*) denotes that a network service is disabled.
(1) USB 10/100/1000 LAN
(Hardware Port: USB 10/100/1000 LAN, Device: en5)

(2) Thunderbolt Bridge
(Hardware Port: Thunderbolt Bridge, Device: bridge0)

(3) Wi-Fi
(Hardware Port: Wi-Fi, Device: en0)

(4) iPhone USB
(Hardware Port: iPhone USB, Device: en6)

(*) Old Ethernet
(Hardware Port: Ethernet Adapter (en3), Device: en3)

(5) FoXray
(Hardware Port: dev.yiguo.FoXray, Device: )

(6) peer-1
(Hardware Port: com.wireguard.macos, Device: )
`
)

func TestParseHardwarePorts(t *testing.T) {
	got := parseHardwarePorts(hardwarePortsOut)
	want := map[string]string{
		"en3":     "ethernet",
		"bridge0": "other",
		"en0":     "wifi",
		"en1":     "other",
		"en5":     "ethernet",
		"en6":     "mobile",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseHardwarePorts = %v, want %v", got, want)
	}
}

func TestParseServiceOrder(t *testing.T) {
	got := parseServiceOrder(serviceOrderOut)
	want := []macService{
		{Name: "USB 10/100/1000 LAN", Device: "en5", Enabled: true},
		{Name: "Thunderbolt Bridge", Device: "bridge0", Enabled: true},
		{Name: "Wi-Fi", Device: "en0", Enabled: true},
		{Name: "iPhone USB", Device: "en6", Enabled: true},
		{Name: "Old Ethernet", Device: "en3", Enabled: false},
		{Name: "FoXray", Device: "", Enabled: true},
		{Name: "peer-1", Device: "", Enabled: true},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseServiceOrder =\n%#v\nwant\n%#v", got, want)
	}
}

func TestParseDNSServers(t *testing.T) {
	if got := parseDNSServers("There aren't any DNS Servers set on Wi-Fi.\n"); got != nil {
		t.Fatalf("no servers parsed as %v", got)
	}
	got := parseDNSServers("8.8.8.8\n8.8.4.4\n2001:4860:4860::8888\n")
	want := []string{"8.8.8.8", "8.8.4.4", "2001:4860:4860::8888"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseDNSServers = %v, want %v", got, want)
	}
}

func TestFreeUtun(t *testing.T) {
	if got := freeUtun(map[string]bool{"utun0": true, "utun4": true}); got != "utun10" {
		t.Fatalf("freeUtun = %s, want utun10", got)
	}
	if got := freeUtun(map[string]bool{"utun10": true, "utun11": true}); got != "utun12" {
		t.Fatalf("freeUtun = %s, want utun12", got)
	}
}
