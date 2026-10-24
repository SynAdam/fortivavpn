// Package xray holds the part of Xray-core's JSON configuration that the
// Windows core writes. It is deliberately a subset: the service builds every
// configuration itself from checked input, and a field it never sets cannot
// be smuggled in.
package xray

import "encoding/json"

// Config is a whole Xray configuration.
type Config struct {
	Log       *Log       `json:"log,omitempty"`
	Stats     *Empty     `json:"stats,omitempty"`
	Policy    *Policy    `json:"policy,omitempty"`
	Inbounds  []Inbound  `json:"inbounds,omitempty"`
	Outbounds []Outbound `json:"outbounds"`
	Routing   *Routing   `json:"routing,omitempty"`
}

// Empty is a JSON object with nothing in it, for sections whose presence is
// the setting ("stats": {}).
type Empty struct{}

type Log struct {
	LogLevel string `json:"loglevel"`
	Access   string `json:"access,omitempty"`
}

type Policy struct {
	System PolicySystem `json:"system"`
}

type PolicySystem struct {
	StatsOutboundUplink   bool `json:"statsOutboundUplink"`
	StatsOutboundDownlink bool `json:"statsOutboundDownlink"`
}

type Inbound struct {
	Tag      string    `json:"tag"`
	Protocol string    `json:"protocol"`
	Listen   string    `json:"listen,omitempty"`
	Port     int       `json:"port"`
	Settings any       `json:"settings,omitempty"`
	Sniffing *Sniffing `json:"sniffing,omitempty"`
}

type Sniffing struct {
	Enabled      bool     `json:"enabled"`
	DestOverride []string `json:"destOverride,omitempty"`
	RouteOnly    bool     `json:"routeOnly"`
}

// TunSettings configures the "tun" inbound (proxy/tun in the core).
type TunSettings struct {
	Name                   string   `json:"name"`
	Desc                   string   `json:"desc,omitempty"`
	MTU                    uint32   `json:"mtu"`
	Gateway                []string `json:"gateway,omitempty"`
	DNS                    []string `json:"dns,omitempty"`
	AutoSystemRoutingTable []string `json:"autoSystemRoutingTable,omitempty"`
	// AutoOutboundsInterface is a pointer because the core treats "absent"
	// and "empty" differently: absent with routes means "auto", which picks
	// the physical interface by its name and address, and empty means the
	// core binds nothing and leaves it to us.
	AutoOutboundsInterface *string `json:"autoOutboundsInterface,omitempty"`
}

type SocksSettings struct {
	Auth      string `json:"auth"`
	UDP       bool   `json:"udp"`
	UserLevel int    `json:"userLevel"`
}

type Outbound struct {
	Tag            string          `json:"tag"`
	Protocol       string          `json:"protocol"`
	Settings       any             `json:"settings,omitempty"`
	StreamSettings *StreamSettings `json:"streamSettings,omitempty"`
	Mux            *Mux            `json:"mux,omitempty"`
}

type VLESSSettings struct {
	Vnext []VLESSServer `json:"vnext"`
}

type VLESSServer struct {
	Address string      `json:"address"`
	Port    int         `json:"port"`
	Users   []VLESSUser `json:"users"`
}

type VLESSUser struct {
	ID         string `json:"id"`
	Encryption string `json:"encryption"`
	Flow       string `json:"flow,omitempty"`
	Level      int    `json:"level"`
}

// FreedomSettings is empty: "direct" dials the address it is given.
type FreedomSettings struct{}

type BlackholeSettings struct {
	Response *BlackholeResponse `json:"response,omitempty"`
}

type BlackholeResponse struct {
	Type string `json:"type"`
}

// AutoSelectSettings configures the "autoselect" outbound that
// android/core/patches/xray-autoselect.patch adds to the core.
type AutoSelectSettings struct {
	Outbounds        []string          `json:"outbounds"`
	ProbeURL         string            `json:"probeURL,omitempty"`
	FallbackProbeURL string            `json:"fallbackProbeURL,omitempty"`
	Initial          string            `json:"initial,omitempty"`
	MinDwell         string            `json:"minDwell,omitempty"`
	Exits            map[string]string `json:"exits,omitempty"`
	Penalties        map[string]int32  `json:"penalties,omitempty"`
}

type Mux struct {
	Enabled     bool `json:"enabled"`
	Concurrency int  `json:"concurrency"`
}

type StreamSettings struct {
	Network             string               `json:"network,omitempty"`
	Security            string               `json:"security,omitempty"`
	TCPSettings         *TCPSettings         `json:"tcpSettings,omitempty"`
	KCPSettings         *KCPSettings         `json:"kcpSettings,omitempty"`
	WSSettings          *WSSettings          `json:"wsSettings,omitempty"`
	HTTPUpgradeSettings *HTTPUpgradeSettings `json:"httpupgradeSettings,omitempty"`
	XHTTPSettings       *XHTTPSettings       `json:"xhttpSettings,omitempty"`
	GRPCSettings        *GRPCSettings        `json:"grpcSettings,omitempty"`
	TLSSettings         *TLSSettings         `json:"tlsSettings,omitempty"`
	RealitySettings     *RealitySettings     `json:"realitySettings,omitempty"`
	FinalMask           json.RawMessage      `json:"finalmask,omitempty"`
}

type TCPSettings struct {
	Header TCPHeader `json:"header"`
}

type TCPHeader struct {
	Type    string      `json:"type"`
	Request *TCPRequest `json:"request,omitempty"`
}

type TCPRequest struct {
	Version string         `json:"version"`
	Method  string         `json:"method"`
	Path    []string       `json:"path"`
	Headers map[string]any `json:"headers"`
}

type KCPSettings struct {
	Header KCPHeader `json:"header"`
	Seed   string    `json:"seed,omitempty"`
}

type KCPHeader struct {
	Type   string `json:"type"`
	Domain string `json:"domain,omitempty"`
}

type WSSettings struct {
	Path    string            `json:"path"`
	Headers map[string]string `json:"headers,omitempty"`
}

type HTTPUpgradeSettings struct {
	Path string `json:"path"`
	Host string `json:"host,omitempty"`
}

type XHTTPSettings struct {
	Path  string          `json:"path"`
	Host  string          `json:"host,omitempty"`
	Mode  string          `json:"mode,omitempty"`
	Extra json.RawMessage `json:"extra,omitempty"`
}

type GRPCSettings struct {
	ServiceName        string `json:"serviceName"`
	Authority          string `json:"authority,omitempty"`
	MultiMode          bool   `json:"multiMode"`
	IdleTimeout        int    `json:"idle_timeout"`
	HealthCheckTimeout int    `json:"health_check_timeout"`
}

type TLSSettings struct {
	ServerName    string   `json:"serverName,omitempty"`
	Fingerprint   string   `json:"fingerprint,omitempty"`
	ALPN          []string `json:"alpn,omitempty"`
	ECHConfigList string   `json:"echConfigList,omitempty"`
	CipherSuites  string   `json:"cipherSuites,omitempty"`
}

type RealitySettings struct {
	ServerName  string `json:"serverName,omitempty"`
	Fingerprint string `json:"fingerprint,omitempty"`
	PublicKey   string `json:"publicKey,omitempty"`
	ShortID     string `json:"shortId,omitempty"`
	SpiderX     string `json:"spiderX,omitempty"`
}

type Routing struct {
	DomainStrategy string `json:"domainStrategy"`
	Rules          []Rule `json:"rules"`
}

type Rule struct {
	Type        string   `json:"type"`
	OutboundTag string   `json:"outboundTag"`
	Domain      []string `json:"domain,omitempty"`
	IP          []string `json:"ip,omitempty"`
	Port        string   `json:"port,omitempty"`
	Network     string   `json:"network,omitempty"`
	InboundTag  []string `json:"inboundTag,omitempty"`
}
