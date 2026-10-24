package config

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/netip"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/xtls/xray-core/infra/conf"
	"github.com/xtls/xray-core/infra/conf/serial"
	_ "github.com/xtls/xray-core/main/distro/all"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/xray"
)

// The routing rules name geoip: and geosite: lists, which the core resolves
// out of the staged databases when it builds a configuration.
func TestMain(m *testing.M) {
	assets, err := filepath.Abs("../../.assets")
	if err != nil {
		panic(err)
	}
	if _, err := os.Stat(filepath.Join(assets, "geosite.dat")); err != nil {
		fmt.Fprintln(os.Stderr, "run windows/core/stage.sh first: it stages the routing data these tests build against")
		os.Exit(1)
	}
	os.Setenv("XRAY_LOCATION_ASSET", assets)
	os.Exit(m.Run())
}

const (
	wsTLS = "vless://11111111-2222-3333-4444-555555555555@198.51.100.215:443" +
		"?type=ws&security=tls&encryption=none&sni=cdn-11.example.com&fp=chrome" +
		"&path=%2Fws&host=cdn-11.example.com&fragment=tlshello,10-20,1-2#Fortiva%20FI%20Helsinki"
	tcpReality = "vless://11111111-2222-3333-4444-555555555555@fi1.example.net:443" +
		"?type=tcp&security=reality&encryption=none&sni=www.sony.com&fp=chrome" +
		"&pbk=SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc&sid=6ba85179e30d4fc2&spx=%2F&flow=xtls-rprx-vision#door"
	xhttpReality = "vless://11111111-2222-3333-4444-555555555555@198.51.100.202:8443" +
		"?type=xhttp&security=reality&encryption=none&sni=www.sony.com&fp=chrome" +
		"&pbk=SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc&sid=6ba85179e30d4fc2" +
		"&path=%2Fx&host=www.sony.com&mode=auto&extra=%7B%22xPaddingBytes%22%3A%22100-1000%22%7D#door"
)

func fakeResolver(answers map[string][]string) Resolver {
	return func(_ context.Context, host string) ([]netip.Addr, error) {
		list, ok := answers[host]
		if !ok {
			return nil, errors.New("no such host")
		}
		var out []netip.Addr
		for _, a := range list {
			out = append(out, netip.MustParseAddr(a))
		}
		return out, nil
	}
}

var noLookups Resolver = func(_ context.Context, host string) ([]netip.Addr, error) {
	return nil, fmt.Errorf("unexpected lookup of %s", host)
}

// loadStrict runs v through the core's own JSON loader, refusing unknown
// fields, and builds it: what the core does at connect, so a field the core
// does not know or a value it refuses fails here instead.
func loadStrict(t *testing.T, v *xray.Config) {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := serial.DecodeJSONConfigStrict(bytes.NewReader(raw))
	if err != nil {
		t.Fatalf("core refuses the JSON: %v\n%s", err, raw)
	}
	if _, err := cfg.Build(); err != nil {
		t.Fatalf("core refuses the configuration: %v\n%s", err, raw)
	}
}

func loadInbound(t *testing.T, in xray.Inbound) {
	t.Helper()
	raw, err := json.Marshal(in)
	if err != nil {
		t.Fatal(err)
	}
	var detour conf.InboundDetourConfig
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&detour); err != nil {
		t.Fatalf("core refuses the inbound JSON: %v\n%s", err, raw)
	}
	if _, err := detour.Build(); err != nil {
		t.Fatalf("core refuses the inbound: %v\n%s", err, raw)
	}
}

func outbound(t *testing.T, c *xray.Config, tag string) xray.Outbound {
	t.Helper()
	for _, o := range c.Outbounds {
		if o.Tag == tag {
			return o
		}
	}
	t.Fatalf("no outbound %q", tag)
	return xray.Outbound{}
}

func TestSingleDoor(t *testing.T) {
	built, err := Build(context.Background(), Request{Link: wsTLS}, noLookups)
	if err != nil {
		t.Fatal(err)
	}
	loadStrict(t, built.Config)
	loadInbound(t, built.Tun)

	var tags []string
	for _, o := range built.Config.Outbounds {
		tags = append(tags, o.Tag)
	}
	if want := []string{"proxy", "direct", "block"}; !reflect.DeepEqual(tags, want) {
		t.Errorf("outbounds %v, want %v", tags, want)
	}
	if !reflect.DeepEqual(built.Doors, []string{"proxy"}) {
		t.Errorf("doors %v", built.Doors)
	}

	proxy := outbound(t, built.Config, "proxy")
	s := proxy.StreamSettings
	if s.Network != "ws" || s.Security != "tls" {
		t.Errorf("network %q security %q", s.Network, s.Security)
	}
	if s.WSSettings.Path != "/ws" || s.WSSettings.Headers["Host"] != "cdn-11.example.com" {
		t.Errorf("ws settings %+v", s.WSSettings)
	}
	if s.TLSSettings.ServerName != "cdn-11.example.com" || s.TLSSettings.Fingerprint != "chrome" {
		t.Errorf("tls settings %+v", s.TLSSettings)
	}
	// The link's fragment=tlshello,10-20,1-2 splits the hello in the door's
	// own stream, with the same sizes and gaps.
	var mask struct {
		TCP []struct {
			Type     string            `json:"type"`
			Settings map[string]string `json:"settings"`
		} `json:"tcp"`
	}
	if err := json.Unmarshal(s.FinalMask, &mask); err != nil || len(mask.TCP) != 1 {
		t.Fatalf("finalmask %s: %v", s.FinalMask, err)
	}
	if want := map[string]string{"packets": "tlshello", "length": "10-20", "delay": "1-2"}; mask.TCP[0].Type != "fragment" || !reflect.DeepEqual(mask.TCP[0].Settings, want) {
		t.Errorf("split %+v, want fragment %v", mask.TCP[0], want)
	}

	rules := built.Config.Routing.Rules
	if rules[0].Port != "53" || !reflect.DeepEqual(rules[0].IP, []string{DefaultDNS}) || rules[0].OutboundTag != "proxy" {
		t.Errorf("first rule should send lookups through the tunnel: %+v", rules[0])
	}
	if last := rules[len(rules)-1]; !reflect.DeepEqual(last.IP, []string{"::/0"}) || last.OutboundTag != "block" {
		t.Errorf("last rule should refuse IPv6: %+v", last)
	}

	tun := built.Tun.Settings.(xray.TunSettings)
	if tun.AutoOutboundsInterface == nil || *tun.AutoOutboundsInterface != "" {
		t.Error("the core must not pick the outbound interface itself")
	}
	if !reflect.DeepEqual(tun.DNS, []string{DefaultDNS}) {
		t.Errorf("adapter DNS %v", tun.DNS)
	}
	if !built.Tun.Sniffing.RouteOnly {
		t.Error("sniffing must be route-only")
	}
}

func TestGroupOfDoors(t *testing.T) {
	built, err := Build(context.Background(), Request{
		Link:       wsTLS,
		Alternates: []string{tcpReality, xhttpReality},
		Exits:      []string{"10", "10", " "},
		Penalties:  []int64{0, 1500, -5},
	}, fakeResolver(map[string][]string{"fi1.example.net": {"2001:db8:f21::1", "203.0.113.223"}}))
	if err != nil {
		t.Fatal(err)
	}
	loadStrict(t, built.Config)

	if want := []string{"proxy@0", "proxy@1", "proxy@2"}; !reflect.DeepEqual(built.Doors, want) {
		t.Errorf("doors %v, want %v", built.Doors, want)
	}
	group := outbound(t, built.Config, "proxy")
	if group.Protocol != "autoselect" {
		t.Fatalf("proxy is %q, want the autoselect group", group.Protocol)
	}
	settings := group.Settings.(xray.AutoSelectSettings)
	if settings.Initial != "proxy@0" || settings.MinDwell != "10m" || settings.ProbeURL != ProbeURL {
		t.Errorf("group settings %+v", settings)
	}
	if want := map[string]string{"proxy@0": "10", "proxy@1": "10"}; !reflect.DeepEqual(settings.Exits, want) {
		t.Errorf("exits %v, want %v (a blank exit is unknown, not a server)", settings.Exits, want)
	}
	if want := map[string]int32{"proxy@1": 1500}; !reflect.DeepEqual(settings.Penalties, want) {
		t.Errorf("penalties %v, want %v (0 or less is no penalty)", settings.Penalties, want)
	}

	// A door that dials a name has it looked up now, and dials the IPv4
	// address it got: once the tunnel is up, a lookup would go through the
	// tunnel the door is meant to carry.
	if got := outbound(t, built.Config, "proxy@1").Settings.(xray.VLESSSettings).Vnext[0].Address; got != "203.0.113.223" {
		t.Errorf("door dials %q, want 203.0.113.223", got)
	}
	reality := outbound(t, built.Config, "proxy@1").StreamSettings
	if reality.RealitySettings.ServerName != "www.sony.com" {
		t.Errorf("the name the door presents must stay the link's: %+v", reality.RealitySettings)
	}
	if reality.RealitySettings.PublicKey == "" || reality.RealitySettings.SpiderX != "/" {
		t.Errorf("reality settings %+v", reality.RealitySettings)
	}
	user := outbound(t, built.Config, "proxy@1").Settings.(xray.VLESSSettings).Vnext[0].Users[0]
	if user.Flow != "xtls-rprx-vision" {
		t.Errorf("flow %q", user.Flow)
	}
	xhttp := outbound(t, built.Config, "proxy@2").StreamSettings.XHTTPSettings
	if xhttp.Mode != "auto" || string(xhttp.Extra) != `{"xPaddingBytes":"100-1000"}` {
		t.Errorf("xhttp settings %+v extra %s", xhttp, xhttp.Extra)
	}
}

func TestBadAlternateIsSkipped(t *testing.T) {
	built, err := Build(context.Background(), Request{
		Link:       wsTLS,
		Alternates: []string{"vmess://abc", tcpReality},
		Exits:      []string{"10", "11", "12"},
		Penalties:  []int64{0, 800, 900},
	}, fakeResolver(nil))
	if err != nil {
		t.Fatal(err)
	}
	loadStrict(t, built.Config)
	// The vmess link is refused and fi1.example.net does not resolve.
	if want := []string{"proxy@0"}; !reflect.DeepEqual(built.Doors, want) {
		t.Errorf("doors %v, want %v", built.Doors, want)
	}
	if len(built.Skipped) != 2 || !strings.Contains(built.Skipped[2], "resolve fi1.example.net") {
		t.Errorf("skipped %v", built.Skipped)
	}
	if exits := outbound(t, built.Config, "proxy").Settings.(xray.AutoSelectSettings).Exits; !reflect.DeepEqual(exits, map[string]string{"proxy@0": "10"}) {
		t.Errorf("exits of doors that were left out must go too: %v", exits)
	}
	if penalties := outbound(t, built.Config, "proxy").Settings.(xray.AutoSelectSettings).Penalties; penalties != nil {
		t.Errorf("penalties of doors that were left out must go too: %v", penalties)
	}
}

func TestBadLinkIsRefused(t *testing.T) {
	for _, raw := range []string{
		"",
		"vmess://abc",
		"vless://id@host:443",        // no parameters
		"vless://id@host:0?type=tcp", // no port
		"vless://id@host:443?type=h2&security=tls",      // removed from the core
		"vless://id@host:443?type=tcp&security=reality", // no public key
		"vless://id@host:443?type=quic",                 // removed from the core
		"vless://id@host:443?type=carrier-pigeon",       // unknown
		"vless://id@1.2.3.4:443?type=xhttp&extra=%7B%22downloadSettings%22%3A%7B%22tlsSettings%22%3A%7B%22masterKeyLog%22%3A%22C%3A%5C%5Cx%22%7D%7D%7D",
		"vless://id@1.2.3.4:443?type=tcp&security=tls&fm=%7B%22udp%22%3A%5B%5D%7D",
		"vless://id@1.2.3.4:443?type=tcp&security=tls&fm=%7B%22tcp%22%3A%5B%7B%22type%22%3A%22xicmp%22%7D%5D%7D",
	} {
		if _, err := Build(context.Background(), Request{Link: raw}, noLookups); !errors.Is(err, ErrNoDoor) {
			t.Errorf("%q: got %v, want ErrNoDoor", raw, err)
		}
	}
}

func TestFinalMaskDoor(t *testing.T) {
	// The F&F test points use: a finalmask, Go's own TLS and its suites.
	fm := `{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["0","104","1"],"delays":["0"],"maxSplit":"0"}},` +
		`{"type":"fragment","settings":{"packets":"1-1","lengths":["114","1"],"delays":["1"],"maxSplit":"11"}}]}`
	raw := "vless://11111111-2222-3333-4444-555555555555@198.51.100.215:443?type=ws&security=tls" +
		"&sni=cdn-11.example.com&host=cdn-11.example.com&path=%2Fws&fp=unsafe&fragment=off" +
		"&cs=TLS_AES_256_GCM_SHA384%3ATLS_AES_128_GCM_SHA256&fm=" + urlEscape(fm)
	built, err := Build(context.Background(), Request{Link: raw}, noLookups)
	if err != nil {
		t.Fatal(err)
	}
	loadStrict(t, built.Config)
	s := outbound(t, built.Config, "proxy").StreamSettings
	if string(s.FinalMask) != fm {
		t.Errorf("finalmask %s, want the link's own; fragment=off must not add a split", s.FinalMask)
	}
	if s.TLSSettings.CipherSuites != "TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256" {
		t.Errorf("cipher suites %q", s.TLSSettings.CipherSuites)
	}
}

func TestDNSFromTheApp(t *testing.T) {
	built, err := Build(context.Background(), Request{Link: wsTLS, DNS: []string{"8.8.8.8", " 9.9.9.9", "8.8.8.8"}}, noLookups)
	if err != nil {
		t.Fatal(err)
	}
	loadStrict(t, built.Config)
	want := []string{"8.8.8.8", "9.9.9.9"}
	if got := built.Tun.Settings.(xray.TunSettings).DNS; !reflect.DeepEqual(got, want) {
		t.Errorf("adapter DNS %v, want %v", got, want)
	}
	if got := built.Config.Routing.Rules[0].IP; !reflect.DeepEqual(got, want) {
		t.Errorf("port-53 rule %v, want %v", got, want)
	}

	if _, err := Build(context.Background(), Request{Link: wsTLS, DNS: []string{"2606:4700::1111"}}, noLookups); err == nil {
		t.Error("an IPv6 resolver must be refused: the adapter's IPv6 goes nowhere")
	}
}

func TestPingConfig(t *testing.T) {
	cfg, err := Ping(wsTLS)
	if err != nil {
		t.Fatal(err)
	}
	loadStrict(t, cfg)
	if len(cfg.Inbounds) != 0 || cfg.Routing != nil {
		t.Error("a door check must hold only the door")
	}
	if len(cfg.Outbounds) != 1 || cfg.Outbounds[0].Tag != "proxy" || cfg.Outbounds[0].StreamSettings.FinalMask == nil {
		t.Errorf("a check must hold the door alone, split as the tunnel splits it: %+v", cfg.Outbounds)
	}
}

func TestMemberTags(t *testing.T) {
	for i := range 5 {
		if got, ok := MemberIndex(MemberTag(i)); !ok || got != i {
			t.Errorf("MemberIndex(MemberTag(%d)) = %d, %v", i, got, ok)
		}
	}
	for _, tag := range []string{"proxy", "direct", "proxy@", "proxy@x", "proxy@-1"} {
		if _, ok := MemberIndex(tag); ok {
			t.Errorf("MemberIndex(%q) should fail", tag)
		}
	}
}

func urlEscape(s string) string {
	var b strings.Builder
	for _, c := range []byte(s) {
		if c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '-' || c == '_' || c == '.' {
			b.WriteByte(c)
		} else {
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}
