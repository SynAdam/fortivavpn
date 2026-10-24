// Package config builds the Xray configuration the Windows tunnel runs.
//
// It is the configuration the Android app builds (V2rayConfigManager, with
// the default settings, which are the only ones Android ever uses), with
// these differences:
//
//   - Android's SOCKS inbound and tun2socks are replaced by the core's own
//     TUN inbound on a Wintun adapter. No local proxy port is opened, so no
//     other program on the PC can find or use the tunnel through one.
//   - IPv6 is captured and refused. Android routes only IPv4 into its tunnel
//     and the system blocks IPv6 for tunnelled apps; Windows does neither, so
//     a PC with native IPv6 would send it around the tunnel.
//   - Nothing depends on the two tables the core keeps for the whole
//     process: the resolver dialers use for a host name, and the outbounds a
//     dialerProxy is looked up in. Each instance overwrites both when it
//     starts, and here the tunnel and the door checks share one process. So a
//     door's host name is looked up before the tunnel starts and its address
//     written into the door, where Android keeps the name and a hosts entry;
//     a door's TLS hello is split in its own stream (link.fragmentMask),
//     where Android chains a splitter outbound; and "direct" dials the
//     address it is given, which with route-only sniffing is always an
//     address. Android runs its door checks in another process than its
//     tunnel and does not meet this.
//
// The TUN inbound is returned apart from the rest, so the engine can check
// that a door carries traffic before it captures the PC's traffic, as Android
// does with its proxy-only start.
package config

import (
	"context"
	"errors"
	"fmt"
	"math"
	"net/netip"
	"strconv"
	"strings"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/link"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/xray"
)

// Tags the routing rules and the engine refer to.
const (
	ProxyTag  = "proxy"
	DirectTag = "direct"
	BlockTag  = "block"
	TunTag    = "tun"
)

// MaxAlternates is how many standby doors are held next to the chosen one.
// Android keeps the first four the app sends.
const MaxAlternates = 4

// DefaultDNS is the resolver the tunnel hands to Windows and asks through
// the tunnel, when the app sends none (AppConfig.DNS_PROXY on Android).
const DefaultDNS = "1.1.1.1"

// Probe URLs of the autoselect group, the same as Android's.
const (
	ProbeURL         = "https://www.gstatic.com/generate_204"
	FallbackProbeURL = "https://www.google.com/generate_204"
)

// Adapter is how the Wintun adapter is named and addressed. The addresses
// are only there so routes have an interface to point at; nothing is
// addressed to them. The IPv4 one is Android's tunnel address. The IPv6 one
// is a unique local address, which also makes Windows prefer IPv4 for
// everything while the tunnel is up (RFC 6724 rule 5: a ULA source does not
// match a global destination's label).
var Adapter = struct {
	Name    string
	Desc    string
	MTU     uint32
	Address []string
	Routes  []string
}{
	Name:    "Fortiva",
	Desc:    "Fortiva Tunnel",
	MTU:     1500,
	Address: []string{"10.10.14.1/30", "fd66:6f72:7469:7661::1/126"},
	// Halves rather than default routes: being more specific, they win over
	// any other default route whatever its metric, and they leave the
	// physical interface's own default route alone for the core to use.
	Routes: []string{"0.0.0.0/1", "128.0.0.0/1", "::/1", "8000::/1"},
}

// Request is what the app asks to connect to.
type Request struct {
	// Link is the door to connect through.
	Link string `json:"link"`
	// Alternates are other doors held next to it. With any, the doors form
	// an autoselect group that moves to a working door when one fails.
	Alternates []string `json:"alternates,omitempty"`
	// Exits names the server each door sends traffic out from, Link first.
	// Failover prefers a door on the same server, so the user's address
	// changes less. Blank entries are unknown.
	Exits []string `json:"exits,omitempty"`
	// Penalties is milliseconds the group adds to each door's score, Link
	// first: the backend's measure of how often the door fails in the middle
	// of a session, which the group's probes cannot see. 0 or less is none.
	Penalties []int64 `json:"penalties,omitempty"`
	// DNS is the resolvers the app's DNS screen chose, IPv4 only. Empty
	// means DefaultDNS.
	DNS []string `json:"dns,omitempty"`
}

// Resolver looks a door's host name up before the tunnel exists. Android
// does the same (resolveOutboundDomainsToHosts): once the tunnel is up the
// core's resolver asks through the tunnel, which for the door itself would
// be asking through a connection that does not exist yet.
type Resolver func(ctx context.Context, host string) ([]netip.Addr, error)

// Built is a configuration ready to start.
type Built struct {
	// Config has no inbounds: it can dial through its doors, which is how the
	// engine checks them, and captures nothing.
	Config *xray.Config
	// Tun is the inbound that captures the PC's traffic, added once a door
	// has been seen to work.
	Tun xray.Inbound
	// Doors are the outbound tags of the doors that made it in, the chosen
	// door first. More than one means Config's proxy is an autoselect group.
	Doors []string
	// Skipped says why each door that did not make it in was left out, by
	// its position in the request (0 is Link).
	Skipped map[int]string
}

// ErrNoDoor is returned when not even the chosen door could be used.
var ErrNoDoor = errors.New("no usable door")

// Build turns a request into a configuration. Alternates that cannot be
// used are left out and listed in Skipped; the chosen link must be usable.
func Build(ctx context.Context, req Request, resolve Resolver) (*Built, error) {
	dns, err := dnsServers(req.DNS)
	if err != nil {
		return nil, err
	}

	links := append([]string{req.Link}, req.Alternates...)
	if len(links) > 1+MaxAlternates {
		links = links[:1+MaxAlternates]
	}
	group := len(links) > 1

	built := &Built{Skipped: map[int]string{}}
	resolved := map[string]netip.Addr{}
	var doors []xray.Outbound
	for i, raw := range links {
		tag := ProxyTag
		if group {
			tag = MemberTag(i)
		}
		out, err := door(ctx, raw, tag, resolved, resolve)
		if err != nil {
			if i == 0 {
				return nil, fmt.Errorf("%w: %w", ErrNoDoor, err)
			}
			built.Skipped[i] = err.Error()
			continue
		}
		doors = append(doors, *out)
		built.Doors = append(built.Doors, tag)
	}

	var outbounds []xray.Outbound
	if group {
		exits := map[string]string{}
		for i, exit := range req.Exits {
			if exit = strings.TrimSpace(exit); exit != "" && i < len(links) {
				exits[MemberTag(i)] = exit
			}
		}
		for tag := range exits {
			if !contains(built.Doors, tag) {
				delete(exits, tag)
			}
		}
		if len(exits) == 0 {
			exits = nil
		}
		// Only the doors that made it in, as with the exits. The core holds a
		// penalty as a 32-bit number.
		var penalties map[string]int32
		for i, p := range req.Penalties {
			if tag := MemberTag(i); p > 0 && contains(built.Doors, tag) {
				if penalties == nil {
					penalties = map[string]int32{}
				}
				penalties[tag] = int32(min(p, math.MaxInt32))
			}
		}
		outbounds = append(outbounds, xray.Outbound{
			Tag:      ProxyTag,
			Protocol: "autoselect",
			Settings: xray.AutoSelectSettings{
				Outbounds:        built.Doors,
				ProbeURL:         ProbeURL,
				FallbackProbeURL: FallbackProbeURL,
				Initial:          built.Doors[0],
				// Cloudflare and direct doors kept trading places on Iranian
				// mobile networks with a shorter dwell (2026-10-02).
				MinDwell:  "10m",
				Exits:     exits,
				Penalties: penalties,
			},
		})
	}
	outbounds = append(outbounds, doors...)
	outbounds = append(outbounds,
		xray.Outbound{Tag: DirectTag, Protocol: "freedom", Settings: xray.FreedomSettings{}},
		xray.Outbound{Tag: BlockTag, Protocol: "blackhole", Settings: xray.BlackholeSettings{Response: &xray.BlackholeResponse{Type: "http"}}},
	)

	built.Config = &xray.Config{
		// Info is what puts "sniffed domain" in the log, which is where the
		// sites the heartbeat reports come from (SiteStats on Android).
		Log:   &xray.Log{LogLevel: "info", Access: "none"},
		Stats: &xray.Empty{},
		Policy: &xray.Policy{System: xray.PolicySystem{
			StatsOutboundUplink:   true,
			StatsOutboundDownlink: true,
		}},
		// No "dns" section: Windows asks the adapter's resolvers, whose
		// packets the first routing rule sends through the tunnel, and
		// nothing in this configuration resolves a name itself. Android's
		// section holds the door hosts and a "domestic" resolver that is the
		// same address, asked through the tunnel too.
		Outbounds: outbounds,
		Routing:   routing(dns),
	}

	empty := ""
	built.Tun = xray.Inbound{
		Tag:      TunTag,
		Protocol: "tun",
		Settings: xray.TunSettings{
			Name:                   Adapter.Name,
			Desc:                   Adapter.Desc,
			MTU:                    Adapter.MTU,
			Gateway:                Adapter.Address,
			DNS:                    dns,
			AutoSystemRoutingTable: Adapter.Routes,
			// Empty, not absent: the engine binds the core's own sockets to
			// the interface that holds the real default route. The core's
			// "auto" guesses that interface from its name and address and
			// can pick a virtual machine's host-only adapter.
			AutoOutboundsInterface: &empty,
		},
		// routeOnly: the sniffed name decides the route but the connection
		// still goes to the address the app asked for. A Telegram fake-TLS
		// proxy presents a name that is not its own. The sinkhole patch
		// makes the one exception, for addresses Iran's filter hands out.
		Sniffing: &xray.Sniffing{Enabled: true, DestOverride: []string{"http", "tls"}, RouteOnly: true},
	}
	return built, nil
}

// MemberTag is the tag of the door at position i of the request in a group:
// "proxy@<i>", as Android tags them, so tunnelStats can say which door is in
// use by its position in the list the app sent.
func MemberTag(i int) string { return ProxyTag + "@" + strconv.Itoa(i) }

// MemberIndex reverses MemberTag. It reports false for any other tag.
func MemberIndex(tag string) (int, bool) {
	rest, ok := strings.CutPrefix(tag, ProxyTag+"@")
	if !ok {
		return 0, false
	}
	i, err := strconv.Atoi(rest)
	return i, err == nil && i >= 0
}

// door builds one door's outbound. A door that dials a name has it looked up
// now and gets the address instead (see the package comment). resolved holds
// the names looked up so far, so doors on one server are looked up once.
func door(ctx context.Context, raw, tag string, resolved map[string]netip.Addr, resolve Resolver) (*xray.Outbound, error) {
	l, err := link.Parse(raw)
	if err != nil {
		return nil, err
	}
	out, err := l.Outbound(tag)
	if err != nil {
		return nil, err
	}
	if l.IsIP() {
		return out, nil
	}
	addr, ok := resolved[l.Address]
	if !ok {
		addrs, err := resolve(ctx, l.Address)
		if err != nil {
			return nil, fmt.Errorf("resolve %s: %w", l.Address, err)
		}
		if addr, ok = pick(addrs); !ok {
			return nil, fmt.Errorf("resolve %s: no addresses", l.Address)
		}
		resolved[l.Address] = addr
	}
	settings := out.Settings.(xray.VLESSSettings)
	settings.Vnext[0].Address = addr.String()
	out.Settings = settings
	return out, nil
}

// pick prefers an IPv4 address: the doors' servers answer on IPv4, and an
// IPv6 path from a PC in Iran is the rarer and less tested one.
func pick(addrs []netip.Addr) (netip.Addr, bool) {
	for _, a := range addrs {
		if a = a.Unmap(); a.Is4() {
			return a, true
		}
	}
	for _, a := range addrs {
		if a.IsValid() {
			return a, true
		}
	}
	return netip.Addr{}, false
}

func dnsServers(requested []string) ([]string, error) {
	var out []string
	for _, s := range requested {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		addr, err := netip.ParseAddr(s)
		if err != nil || !addr.Is4() {
			return nil, fmt.Errorf("dns server %q is not an IPv4 address", s)
		}
		if !contains(out, addr.String()) {
			out = append(out, addr.String())
		}
	}
	if len(out) == 0 {
		out = []string{DefaultDNS}
	}
	return out, nil
}

// routing is Android's rules with its default "white_iran" preset, in its
// order, and one rule of our own at the end.
func routing(dns []string) *xray.Routing {
	return &xray.Routing{
		DomainStrategy: "AsIs",
		Rules: []xray.Rule{
			// Windows sends every lookup to the adapter's resolvers, and
			// those go through the tunnel.
			{Type: "field", IP: dns, Port: "53", OutboundTag: ProxyTag},
			// QUIC is refused, so browsers fall back to TCP, which the
			// sniffer can read and the doors carry well.
			{Type: "field", Network: "udp", Port: "443", OutboundTag: BlockTag},
			{Type: "field", IP: []string{"geoip:private"}, OutboundTag: DirectTag},
			{Type: "field", Domain: []string{"geosite:private"}, OutboundTag: DirectTag},
			// Iranian sites go direct: they work without the tunnel, often
			// refuse foreign addresses, and should not use the allowance.
			{Type: "field", Domain: []string{"domain:ir", "geosite:category-ir"}, OutboundTag: DirectTag},
			{Type: "field", IP: []string{"geoip:ir"}, OutboundTag: DirectTag},
			// IPv6 that reaches the tunnel is refused rather than sent to a
			// door: the servers have no IPv6 to send it out from. Windows
			// prefers IPv4 while the tunnel is up, so this is only what an
			// app forces, and refusing it at once is what makes the app fall
			// back to IPv4 instead of waiting.
			{Type: "field", IP: []string{"::/0"}, OutboundTag: BlockTag},
		},
	}
}

// Ping is the configuration a door check runs: the door alone, tagged
// "proxy". Android checks doors the same way (measureOutboundDelay on a
// configuration of only outbounds). A door that dials a name keeps it here:
// the check runs while the PC's own resolver can answer, and the door alone
// does not loop through a tunnel.
func Ping(raw string) (*xray.Config, error) {
	l, err := link.Parse(raw)
	if err != nil {
		return nil, err
	}
	out, err := l.Outbound(ProxyTag)
	if err != nil {
		return nil, err
	}
	return &xray.Config{Log: &xray.Log{LogLevel: "none", Access: "none"}, Outbounds: []xray.Outbound{*out}}, nil
}

func contains(list []string, s string) bool {
	for _, item := range list {
		if item == s {
			return true
		}
	}
	return false
}
