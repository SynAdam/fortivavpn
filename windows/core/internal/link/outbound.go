package link

import (
	"bytes"
	"encoding/json"
	"regexp"
	"slices"
	"strings"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/xray"
)

// userLevel is the level Android gives every user and inbound. No policy
// level is configured for it, so it gets the core's defaults; keeping the
// number the same keeps the two platforms' configurations comparable.
const userLevel = 8

// httpHeaderRequest is the request a tcp door with headerType=http sends.
// Android sends a phone's browser; a PC sends a PC's.
func httpHeaderRequest(paths, hosts []string) *xray.TCPRequest {
	if len(paths) == 0 {
		paths = []string{"/"}
	}
	headers := map[string]any{
		"User-Agent":      []string{"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"},
		"Accept-Encoding": []string{"gzip, deflate"},
		"Connection":      []string{"keep-alive"},
		"Pragma":          "no-cache",
	}
	if len(hosts) > 0 {
		headers["Host"] = hosts
	}
	return &xray.TCPRequest{Version: "1.1", Method: "GET", Path: paths, Headers: headers}
}

// Outbound returns the Xray outbound for the link, tagged tag.
func (l *Link) Outbound(tag string) (*xray.Outbound, error) {
	stream := &xray.StreamSettings{}
	host, path := l.params["host"], l.params["path"]

	network := l.params["type"]
	if network == "" {
		network = "tcp"
	}
	// sniExt is the transport's own idea of the server name, which TLS falls
	// back to when the link names none (populateTransportSettings).
	var sniExt string
	switch network {
	case "tcp", "raw":
		stream.Network = "tcp"
		if l.params["headerType"] == "http" {
			hosts := splitList(host)
			stream.TCPSettings = &xray.TCPSettings{Header: xray.TCPHeader{
				Type:    "http",
				Request: httpHeaderRequest(splitList(path), hosts),
			}}
			if len(hosts) > 0 {
				sniExt = hosts[0]
			}
		} else {
			stream.TCPSettings = &xray.TCPSettings{Header: xray.TCPHeader{Type: "none"}}
			sniExt = host
		}
	case "kcp", "mkcp":
		stream.Network = "kcp"
		headerType := l.params["headerType"]
		if headerType == "" {
			headerType = "none"
		}
		stream.KCPSettings = &xray.KCPSettings{
			Header: xray.KCPHeader{Type: headerType, Domain: host},
			Seed:   l.params["seed"],
		}
	case "ws", "websocket":
		stream.Network = "ws"
		ws := &xray.WSSettings{Path: orSlash(path)}
		if host != "" {
			ws.Headers = map[string]string{"Host": host}
		}
		stream.WSSettings = ws
		sniExt = host
	case "httpupgrade":
		stream.Network = "httpupgrade"
		stream.HTTPUpgradeSettings = &xray.HTTPUpgradeSettings{Path: orSlash(path), Host: host}
		sniExt = host
	case "xhttp", "splithttp":
		stream.Network = "xhttp"
		extra, err := xhttpExtra(l.params["extra"])
		if err != nil {
			return nil, err
		}
		stream.XHTTPSettings = &xray.XHTTPSettings{
			Path:  orSlash(path),
			Host:  host,
			Mode:  l.params["mode"],
			Extra: extra,
		}
		sniExt = host
	case "grpc":
		stream.Network = "grpc"
		stream.GRPCSettings = &xray.GRPCSettings{
			ServiceName:        l.params["serviceName"],
			Authority:          l.params["authority"],
			MultiMode:          l.params["mode"] == "multi",
			IdleTimeout:        60,
			HealthCheckTimeout: 20,
		}
		sniExt = l.params["authority"]
	case "h2", "http", "h3", "quic":
		// Android passes these through and the core then refuses the
		// whole configuration at connect.
		return nil, invalid("transport %q was removed from Xray-core", network)
	default:
		return nil, invalid("unknown transport %q", network)
	}

	switch security := l.params["security"]; security {
	case "tls", "reality":
		sni := l.params["sni"]
		if sni == "" {
			switch {
			case isDomainName(sniExt):
				sni = sniExt
			case isDomainName(l.Address):
				sni = l.Address
			default:
				sni = sniExt
			}
		}
		fingerprint := l.params["fp"]
		stream.Security = security
		if security == "reality" {
			if l.params["pbk"] == "" {
				return nil, invalid("reality without a public key")
			}
			stream.RealitySettings = &xray.RealitySettings{
				ServerName:  sni,
				Fingerprint: fingerprint,
				PublicKey:   l.params["pbk"],
				ShortID:     l.params["sid"],
				SpiderX:     l.params["spx"],
			}
			break
		}
		alpn := splitList(l.params["alpn"])
		if stream.Network == "ws" {
			// An h2 ALPN breaks the WebSocket upgrade, which needs HTTP/1.1.
			alpn = slices.DeleteFunc(alpn, func(p string) bool { return p == "h2" })
		}
		if l.params["allowInsecure"] == "1" {
			// The core refuses the whole configuration over this setting
			// ("removed and migrated to pinnedPeerCertSha256"), on Android
			// too. Refused here, a standby door is left out instead.
			return nil, invalid("allowInsecure=1 is no longer accepted by Xray-core")
		}
		stream.TLSSettings = &xray.TLSSettings{
			ServerName:  sni,
			Fingerprint: fingerprint,
			ALPN:        alpn,
			// Encrypted Client Hello hides the server name inside the hello,
			// for a filter that no longer passes split hellos.
			ECHConfigList: strings.TrimSpace(l.params["ech"]),
			// The channels' "F&F" for Irancell: Go's own TLS (fingerprint
			// "unsafe") offering these suites, its hello cut by the
			// finalmask below.
			CipherSuites: strings.TrimSpace(l.params["cs"]),
		}
		if fm := l.params["fm"]; fm != "" {
			mask, err := finalMask(fm)
			if err != nil {
				return nil, err
			}
			stream.FinalMask = mask
		} else if split := fragmentMask(l.params["fragment"]); split != nil {
			// A finalmask already cuts the hello its own way, so only a link
			// without one is split here.
			stream.FinalMask = split
		}
	}

	user := xray.VLESSUser{ID: l.ID, Encryption: l.Encryption, Flow: l.Flow, Level: userLevel}
	out := &xray.Outbound{
		Tag:      tag,
		Protocol: "vless",
		Settings: xray.VLESSSettings{Vnext: []xray.VLESSServer{{
			Address: l.Address,
			Port:    l.Port,
			Users:   []xray.VLESSUser{user},
		}}},
		StreamSettings: stream,
	}
	return out, nil
}

func orSlash(path string) string {
	if path == "" {
		return "/"
	}
	return path
}

var fragmentRange = regexp.MustCompile(`^\d{1,4}(-\d{1,4})?$`)

// fragmentMask reads a link's fragment parameter, "tlshello,<lengths>,
// <gaps>" such as "tlshello,10-20,1-2" (TlsFragment.parse on Android), and
// returns the finalmask that splits the door's TLS hello that way. Anything
// else, "off" included, means no split.
//
// Android splits the hello in a separate freedom outbound that the door
// dials through (sockopt.dialerProxy). The core looks a dialerProxy up in a
// table shared by the whole process, which the instance started last owns;
// on Windows the tunnel and the door checks share a process, so after a
// check the tunnel's doors would dial through the check's splitter, closed by
// then. The finalmask "fragment" mask is the same splitter
// (proxy/freedom.FragmentWriter, generalised), applied below TLS to the
// door's own connection, and needs no table.
func fragmentMask(value string) json.RawMessage {
	if value == "" {
		return nil
	}
	parts := strings.Split(value, ",")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	if len(parts) != 3 || parts[0] != "tlshello" ||
		!fragmentRange.MatchString(parts[1]) || !fragmentRange.MatchString(parts[2]) {
		return nil
	}
	mask, _ := json.Marshal(map[string]any{"tcp": []any{map[string]any{
		"type": "fragment",
		"settings": map[string]string{
			"packets": "tlshello",
			"length":  parts[1],
			"delay":   parts[2],
		},
	}}})
	return mask
}

// finalMask checks a link's fm parameter. Fortiva sends exactly one kind:
// TCP masks of type "fragment" (the F&F in lib/utils/tls_fragment.dart and
// the backend's door experiments). Anything else is refused rather than
// handed to a core that runs as SYSTEM: the finalmask types include raw ICMP
// and DNS transports that have no business in a door.
func finalMask(raw string) (json.RawMessage, error) {
	var mask struct {
		TCP []struct {
			Type     string          `json:"type"`
			Settings json.RawMessage `json:"settings"`
		} `json:"tcp"`
	}
	if err := strictUnmarshal([]byte(raw), &mask); err != nil {
		return nil, invalid("fm: %v", err)
	}
	if len(mask.TCP) == 0 {
		return nil, invalid("fm: no tcp masks")
	}
	for i, m := range mask.TCP {
		if m.Type != "fragment" {
			return nil, invalid("fm: mask %d has type %q, only fragment is allowed", i, m.Type)
		}
		var settings struct {
			Packets  string          `json:"packets"`
			Length   json.RawMessage `json:"length"`
			Delay    json.RawMessage `json:"delay"`
			Lengths  json.RawMessage `json:"lengths"`
			Delays   json.RawMessage `json:"delays"`
			MaxSplit json.RawMessage `json:"maxSplit"`
		}
		if err := strictUnmarshal(m.Settings, &settings); err != nil {
			return nil, invalid("fm: mask %d: %v", i, err)
		}
	}
	return json.RawMessage(raw), nil
}

// xhttpAllowed lists what an xhttp door's extra may set: the transport's own
// shaping fields, and a downloadSettings stream for a split download path.
// Anything else, TLS key logs and certificate files in particular, is a file
// path a core running as SYSTEM would open on the link's say-so.
var xhttpAllowed = map[string]bool{
	"host": true, "path": true, "mode": true, "headers": true,
	"xPaddingBytes": true, "xPaddingObfsMode": true, "xPaddingKey": true,
	"xPaddingHeader": true, "xPaddingPlacement": true, "xPaddingMethod": true,
	"uplinkHTTPMethod": true, "sessionIDPlacement": true, "sessionIDKey": true,
	"sessionIDTable": true, "sessionIDLength": true, "seqPlacement": true,
	"seqKey": true, "uplinkDataPlacement": true, "uplinkDataKey": true,
	"uplinkChunkSize": true, "noGRPCHeader": true, "noSSEHeader": true,
	"scMaxEachPostBytes": true, "scMinPostsIntervalMs": true,
	"scMaxBufferedPosts": true, "scStreamUpServerSecs": true, "xmux": true,
	"downloadSettings": true,
}

// downloadAllowed lists what downloadSettings may hold, and tlsAllowed and
// realityAllowed what its security settings may.
var (
	downloadAllowed = map[string]bool{
		"address": true, "port": true, "network": true, "security": true,
		"tlsSettings": true, "realitySettings": true, "xhttpSettings": true,
		"splithttpSettings": true,
	}
	tlsAllowed = map[string]bool{
		"serverName": true, "alpn": true, "fingerprint": true,
		"allowInsecure": true, "echConfigList": true, "cipherSuites": true,
	}
	realityAllowed = map[string]bool{
		"serverName": true, "fingerprint": true, "publicKey": true,
		"password": true, "shortId": true, "spiderX": true,
	}
)

// xhttpExtra checks an xhttp door's extra parameter. Android drops extra
// that is not a JSON object; here it is refused, along with any key outside
// the lists above, so a bad door is reported instead of half-applied.
func xhttpExtra(raw string) (json.RawMessage, error) {
	if raw == "" {
		return nil, nil
	}
	var extra map[string]json.RawMessage
	if err := json.Unmarshal([]byte(raw), &extra); err != nil {
		return nil, invalid("extra: %v", err)
	}
	if err := checkXHTTP(extra); err != nil {
		return nil, invalid("extra: %v", err)
	}
	return json.RawMessage(raw), nil
}

func checkXHTTP(fields map[string]json.RawMessage) error {
	for key, value := range fields {
		if !xhttpAllowed[key] {
			return &keyError{key}
		}
		if key == "downloadSettings" {
			if err := checkDownload(value); err != nil {
				return err
			}
		}
	}
	return nil
}

func checkDownload(raw json.RawMessage) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return err
	}
	for key, value := range fields {
		if !downloadAllowed[key] {
			return &keyError{"downloadSettings." + key}
		}
		var allowed map[string]bool
		switch key {
		case "tlsSettings":
			allowed = tlsAllowed
		case "realitySettings":
			allowed = realityAllowed
		case "xhttpSettings", "splithttpSettings":
			var nested map[string]json.RawMessage
			if err := json.Unmarshal(value, &nested); err != nil {
				return err
			}
			if _, ok := nested["downloadSettings"]; ok {
				return &keyError{"downloadSettings." + key + ".downloadSettings"}
			}
			if err := checkXHTTP(nested); err != nil {
				return err
			}
			continue
		default:
			continue
		}
		var nested map[string]json.RawMessage
		if err := json.Unmarshal(value, &nested); err != nil {
			return err
		}
		for k := range nested {
			if !allowed[k] {
				return &keyError{"downloadSettings." + key + "." + k}
			}
		}
	}
	return nil
}

type keyError struct{ key string }

func (e *keyError) Error() string { return "key " + e.key + " is not allowed" }

func strictUnmarshal(data []byte, v any) error {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	return dec.Decode(v)
}
