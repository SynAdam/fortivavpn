// Package agent is the router build's stand-in for the app: it registers the
// router with the backend, fetches the router's own doors, picks one, keeps
// the tunnel up and reports what happened, the calls the Flutter app makes
// on a phone. The tunnel itself is the engine the Windows build runs.
package agent

import (
	"bytes"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// DefaultBase is the backend, as ApiConfig.baseUrl in lib/api/api_client.dart.
const DefaultBase = "https://api.fortivavpn.com"

// relayServerName is the name put in the TLS hello to a relay, as
// relayServerName in lib/api/api_routes.dart says why: a hello naming an
// address, or nothing, was cut on one Iranian network. The pin decides.
const relayServerName = "www.samsung.com"

// callTimeout bounds one route of one call, as ApiConfig.timeout.
const callTimeout = 10 * time.Second

// builtinRelays is set at build time from lib/api/built_in.dart (router
// build.sh), as a JSON list of {url, pin}. Empty in the public copy, whose
// built_in.dart has none, and in tests.
var builtinRelays string

// Relay is an API relay: an https URL dialled by address, whose
// certificate is accepted only when the SHA-256 of its DER bytes is Pin.
type Relay struct {
	URL string `json:"url"`
	Pin string `json:"pin"`
}

// BuiltinRelays are the relays compiled in.
func BuiltinRelays() []Relay {
	var out []Relay
	if builtinRelays == "" {
		return nil
	}
	if err := json.Unmarshal([]byte(builtinRelays), &out); err != nil {
		return nil
	}
	return validRelays(out)
}

func validRelays(in []Relay) []Relay {
	var out []Relay
	for _, r := range in {
		u, err := url.Parse(r.URL)
		pin := strings.ToLower(r.Pin)
		if err != nil || u.Scheme != "https" || u.Host == "" || len(pin) != 64 {
			continue
		}
		if _, err := hex.DecodeString(pin); err != nil {
			continue
		}
		out = append(out, Relay{URL: strings.TrimRight(r.URL, "/"), Pin: pin})
	}
	return out
}

// APIError is an answer the backend gave with a status other than 2xx. It
// is not a reason to try another route: the backend was reached.
type APIError struct {
	Status int
	Body   string
}

func (e *APIError) Error() string { return fmt.Sprintf("backend answered %d: %s", e.Status, e.Body) }

// API calls the backend. Every call goes direct first, then through each
// relay; with Through set and a tunnel up, the default route goes through
// the tunnel, which is how a phone's calls go once it is connected.
type API struct {
	Base     string
	Version  string
	Platform string
	// Bind, when set, keeps a socket on the WAN, around the tunnel.
	Bind func(network, address string, c syscall.RawConn) error
	// TunnelUp says whether a tunnel is up, so a call can go through it.
	TunnelUp func() bool

	mu     sync.Mutex
	relays []Relay
	// route is how the last call that worked was sent, for the reports.
	route string
	// The clients of the routes, made at the first call and kept, so their
	// connections are reused instead of a new one for every call.
	tunnel, direct *http.Client
	relayClients   map[Relay]*http.Client
}

// SetRelays replaces the relays tried after the direct route. The
// backend's list (/app/config api_relays) replaces the built-in one.
func (a *API) SetRelays(relays []Relay) {
	a.mu.Lock()
	a.relays = validRelays(relays)
	keep := map[Relay]bool{}
	for _, r := range a.relays {
		keep[r] = true
	}
	for r, c := range a.relayClients {
		if !keep[r] {
			c.CloseIdleConnections()
			delete(a.relayClients, r)
		}
	}
	a.mu.Unlock()
}

// clients returns the client of the tunnel route, of the direct route and of
// each relay, making the ones not made yet.
func (a *API) clients(relays []Relay) (tunnel, direct *http.Client, byRelay []*http.Client) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.tunnel == nil {
		// Unbound, so it follows the routes into the tunnel.
		a.tunnel = plainClient(nil)
		a.direct = plainClient(a.Bind)
		a.relayClients = map[Relay]*http.Client{}
	}
	for _, r := range relays {
		c := a.relayClients[r]
		if c == nil {
			c = relayClient(r, a.Bind)
			a.relayClients[r] = c
		}
		byRelay = append(byRelay, c)
	}
	return a.tunnel, a.direct, byRelay
}

// Route says how the last call that worked was sent: "direct", "tunnel" or
// "relay".
func (a *API) Route() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.route
}

// Post sends body to path and decodes the answer into out. aroundTunnel
// sends it on the WAN even while a tunnel is up, so the backend sees the
// router's own network, as the app's via_tunnel=false calls do.
func (a *API) Post(ctx context.Context, path string, body, out any, aroundTunnel bool) error {
	raw, err := json.Marshal(body)
	if err != nil {
		return err
	}
	return a.do(ctx, http.MethodPost, path, raw, out, aroundTunnel)
}

// Get fetches path and decodes the answer into out.
func (a *API) Get(ctx context.Context, path string, out any, aroundTunnel bool) error {
	return a.do(ctx, http.MethodGet, path, nil, out, aroundTunnel)
}

func (a *API) do(ctx context.Context, method, path string, body []byte, out any, aroundTunnel bool) error {
	base := a.Base
	if base == "" {
		base = DefaultBase
	}
	type route struct {
		name   string
		base   string
		client *http.Client
	}
	// The relays forward to Fortiva's own backend, so a router pointed at
	// another one (a test, or development) gets none, as an app build with
	// another base URL gets none (ApiConfig.baseOverridden).
	var relays []Relay
	if base == DefaultBase {
		a.mu.Lock()
		relays = append(relays, a.relays...)
		a.mu.Unlock()
		if len(relays) == 0 {
			relays = BuiltinRelays()
		}
	}
	tunnel, direct, relayClients := a.clients(relays)
	routes := []route{}
	if !aroundTunnel && a.TunnelUp != nil && a.TunnelUp() {
		routes = append(routes, route{"tunnel", base, tunnel})
	}
	routes = append(routes, route{"direct", base, direct})
	for i, r := range relays {
		routes = append(routes, route{"relay " + strconv.Itoa(i+1), r.URL, relayClients[i]})
	}

	var errs []error
	for _, r := range routes {
		err := a.once(ctx, r.client, method, r.base+path, body, out)
		if err == nil {
			a.mu.Lock()
			a.route, _, _ = strings.Cut(r.name, " ")
			a.mu.Unlock()
			return nil
		}
		var apiErr *APIError
		if errors.As(err, &apiErr) {
			if strings.HasPrefix(r.name, "relay") {
				// The backend's own answer, which holds no address of the
				// relay, kept as an *APIError so the caller can read it.
				return fmt.Errorf("%s: %w", r.name, apiErr)
			}
			return err
		}
		if ctx.Err() != nil {
			if strings.HasPrefix(r.name, "relay") {
				return fmt.Errorf("%s: %s", r.name, describe(err))
			}
			return err
		}
		// A connection the route kept may have died with the network or the
		// tunnel it went over; the next call dials a new one.
		r.client.CloseIdleConnections()
		if strings.HasPrefix(r.name, "relay") {
			// A relay's address is kept out of logs and reports, as it is
			// kept out of every file but lib/api/built_in.dart.
			errs = append(errs, fmt.Errorf("%s: %s", r.name, describe(err)))
			continue
		}
		errs = append(errs, fmt.Errorf("%s: %w", r.name, err))
	}
	return errors.Join(errs...)
}

// describe says why a call failed without naming what it dialled.
func describe(err error) string {
	var apiErr *APIError
	var netErr net.Error
	switch {
	case errors.As(err, &apiErr):
		return "answered " + strconv.Itoa(apiErr.Status)
	case errors.Is(err, context.DeadlineExceeded), errors.As(err, &netErr) && netErr.Timeout():
		return "timed out"
	case errors.Is(err, syscall.ECONNREFUSED):
		return "refused"
	case errors.Is(err, syscall.ENETUNREACH), errors.Is(err, syscall.EHOSTUNREACH):
		return "unreachable"
	case errors.Is(err, syscall.ECONNRESET), errors.Is(err, io.EOF), errors.Is(err, io.ErrUnexpectedEOF):
		return "connection closed"
	case strings.Contains(err.Error(), "pin"):
		return "certificate does not match its pin"
	case strings.Contains(err.Error(), "tls"):
		return "TLS failed"
	default:
		return "failed"
	}
}

func (a *API) once(ctx context.Context, client *http.Client, method, target string, body []byte, out any) error {
	ctx, cancel := context.WithTimeout(ctx, callTimeout)
	defer cancel()
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}
	req, err := http.NewRequestWithContext(ctx, method, target, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	// The headers every app call carries (ApiClient in api_client.dart).
	if a.Version != "" {
		req.Header.Set("X-App-Version", a.Version)
	}
	if a.Platform != "" {
		req.Header.Set("X-App-Platform", a.Platform)
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		text := string(data)
		if len(text) > 300 {
			text = text[:300]
		}
		return &APIError{Status: resp.StatusCode, Body: text}
	}
	if out == nil || len(data) == 0 {
		return nil
	}
	return json.Unmarshal(data, out)
}

func plainClient(bind func(network, address string, c syscall.RawConn) error) *http.Client {
	dialer := &net.Dialer{Timeout: callTimeout, Control: bind}
	return &http.Client{
		Transport: &http.Transport{
			Proxy:               nil,
			DialContext:         dialer.DialContext,
			TLSHandshakeTimeout: callTimeout,
			ForceAttemptHTTP2:   true,
			MaxIdleConns:        2,
			IdleConnTimeout:     30 * time.Second,
		},
	}
}

// relayClient trusts only the relay's own certificate, by its pin, and no
// public authority: one issued for the relay's address, or for the name in
// the hello, must not be accepted without the pin (relayClient in
// api_routes.dart).
func relayClient(r Relay, bind func(network, address string, c syscall.RawConn) error) *http.Client {
	dialer := &net.Dialer{Timeout: callTimeout, Control: bind}
	pin := r.Pin
	return &http.Client{
		Transport: &http.Transport{
			Proxy:       nil,
			DialContext: dialer.DialContext,
			TLSClientConfig: &tls.Config{
				ServerName:         relayServerName,
				InsecureSkipVerify: true, // the pin below is the whole check
				VerifyPeerCertificate: func(rawCerts [][]byte, _ [][]*x509.Certificate) error {
					if len(rawCerts) == 0 {
						return errors.New("relay sent no certificate")
					}
					sum := sha256.Sum256(rawCerts[0])
					if hex.EncodeToString(sum[:]) != pin {
						return errors.New("relay certificate does not match its pin")
					}
					return nil
				},
			},
			TLSHandshakeTimeout: callTimeout,
			MaxIdleConns:        1,
			IdleConnTimeout:     30 * time.Second,
		},
	}
}
