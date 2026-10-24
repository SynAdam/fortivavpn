// Package link reads the vless:// links the app connects with and turns each
// into the Xray outbound the Android app builds from the same link
// (android/.../fmt/VlessFmt.kt, FmtBase.kt and V2rayConfigManager's
// populateTransportSettings and populateTlsSettings), so that a door behaves
// the same on every platform. Where Android passes something through that
// the core then rejects, this package refuses the link instead, so the app
// hears which link was wrong rather than seeing the whole tunnel fail.
package link

import (
	"errors"
	"fmt"
	"net/netip"
	"net/url"
	"strconv"
	"strings"

	"golang.org/x/net/idna"
)

// Link is one parsed vless:// link.
type Link struct {
	// Remarks is the link's #name, decoded. Only logs use it.
	Remarks string
	// Address is the server: a domain in ASCII form, or an IP address
	// without brackets.
	Address    string
	Port       int
	ID         string
	Encryption string
	Flow       string

	params map[string]string
}

// ErrInvalid wraps every reason a link is refused.
var ErrInvalid = errors.New("invalid link")

func invalid(format string, args ...any) error {
	return fmt.Errorf("%w: %s", ErrInvalid, fmt.Sprintf(format, args...))
}

// Parse reads a vless:// link the way the Android app does: the query is
// split on "&" and each part on its first "=", values are percent-decoded
// with "+" read as a space (java.net.URLDecoder), keys are taken as they are
// and the last of a repeated key wins.
func Parse(raw string) (*Link, error) {
	s := strings.TrimSpace(raw)
	// Utils.fixIllegalUrl on Android: two characters that some panels leave
	// unescaped and that a strict URL parser refuses.
	s = strings.ReplaceAll(s, " ", "%20")
	s = strings.ReplaceAll(s, "|", "%7C")
	// Links that went through an HTML page arrive with their ampersands
	// escaped, and the query then silently loses every parameter after the
	// first (README, "Config links arriving with &amp;").
	s = strings.ReplaceAll(s, "&amp;", "&")

	u, err := url.Parse(s)
	if err != nil {
		return nil, invalid("%v", err)
	}
	if !strings.EqualFold(u.Scheme, "vless") {
		return nil, invalid("scheme %q is not vless", u.Scheme)
	}
	if u.RawQuery == "" {
		// VlessFmt.parse refuses these too: a link with no parameters is
		// almost always one that was cut short.
		return nil, invalid("no parameters")
	}
	if u.User == nil || u.User.Username() == "" {
		return nil, invalid("no user id")
	}

	host := u.Hostname()
	if host == "" {
		return nil, invalid("no server")
	}
	if !isASCII(host) {
		// Only an internationalised name is converted: the lookup profile
		// also refuses ASCII names with underscores, which some CDN host
		// names have and which dial fine.
		ascii, err := idna.Lookup.ToASCII(host)
		if err != nil {
			return nil, invalid("server %q: %v", host, err)
		}
		host = ascii
	}

	port, err := strconv.Atoi(u.Port())
	if err != nil || port < 1 || port > 65535 {
		return nil, invalid("port %q", u.Port())
	}

	params := parseQuery(u.RawQuery)
	l := &Link{
		Remarks:    u.Fragment,
		Address:    host,
		Port:       port,
		ID:         u.User.Username(),
		Encryption: params["encryption"],
		Flow:       params["flow"],
		params:     params,
	}
	if l.Encryption == "" {
		l.Encryption = "none"
	}
	return l, nil
}

func parseQuery(raw string) map[string]string {
	params := make(map[string]string)
	for _, part := range strings.Split(raw, "&") {
		key, value, _ := strings.Cut(part, "=")
		if decoded, err := url.QueryUnescape(value); err == nil {
			value = decoded
		}
		params[key] = value
	}
	return params
}

// Param returns a query parameter, or "" when the link does not have it.
func (l *Link) Param(key string) string { return l.params[key] }

// IsIP reports whether the link dials an address rather than a name.
func (l *Link) IsIP() bool {
	_, err := netip.ParseAddr(l.Address)
	return err == nil
}

// isDomainName approximates Utils.isDomainName on Android: not an IP
// address, and shaped like a host name.
func isDomainName(s string) bool {
	if s == "" {
		return false
	}
	if _, err := netip.ParseAddr(s); err == nil {
		return false
	}
	if len(s) > 253 || !strings.Contains(s, ".") {
		return false
	}
	for _, label := range strings.Split(strings.TrimSuffix(s, "."), ".") {
		if label == "" || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return false
		}
		for _, r := range label {
			if !(r == '-' || r == '_' || r >= '0' && r <= '9' || r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z') {
				return false
			}
		}
	}
	return true
}

func isASCII(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] >= 0x80 {
			return false
		}
	}
	return true
}

// splitList splits a comma-separated parameter, trimming each item and
// dropping empty ones, as the Kotlin layer does for host, path and alpn.
func splitList(s string) []string {
	var out []string
	for _, item := range strings.Split(s, ",") {
		if item = strings.TrimSpace(item); item != "" {
			out = append(out, item)
		}
	}
	return out
}
