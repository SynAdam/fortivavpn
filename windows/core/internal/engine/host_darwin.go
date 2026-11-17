//go:build darwin

package engine

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
)

// MacStateFile is where MacHost writes down what it changed, before it
// changes it, so that a core killed with the tunnel up puts the Mac back
// when launchd starts it again. The DNS settings it changes outlive a
// restart of the Mac; the routes do not.
const MacStateFile = "/Library/Application Support/Fortiva VPN/tunnel-state.json"

// macIPv6Halves are refused in the routing table while the tunnel is up,
// as the router does (ipv6_linux.go): more specific than any default route,
// so no IPv6 goes around the tunnel, and a refusal before any connection,
// so a browser falls back to IPv4 at once. Routing IPv6 into the tunnel
// instead made the core answer every IPv6 connection with an HTTP 403 on
// the router.
var macIPv6Halves = []string{"::/1", "8000::/1"}

// MacHost is the macOS Host. The core's utun inbound adds the interface and
// the IPv4 routes, and leaves the rest to the system:
//
//   - The resolvers. macOS asks the network's own (the router's, an Iranian
//     ISP's), which are on the local network and so never reach the
//     tunnel's routes: the lookups would leave the tunnel and filtered names
//     would get the filter's answers. Each network service with a device
//     (Wi-Fi, Ethernet, an iPhone over USB) is pointed at the tunnel's
//     resolvers, whose packets the first routing rule sends through the
//     tunnel, as Windows does with the adapter's.
//   - IPv6, refused (macIPv6Halves).
type MacHost struct {
	mu    sync.Mutex
	path  string
	run   func(name string, args ...string) (string, error)
	saved *macSaved
}

// macSaved is what Up changed and Down puts back.
type macSaved struct {
	// DNS holds each network service's resolvers from before the tunnel, by
	// its name. An empty list is the network's own.
	DNS map[string][]string `json:"dns"`
	// IPv6 is whether the refusing routes went in.
	IPv6 bool `json:"ipv6"`
}

// NewHost returns the macOS Host, which reads what a killed run left in
// MacStateFile.
func NewHost() Host { return NewMacHost(MacStateFile, runTool) }

// NewMacHost is NewHost with the state kept at path and the system's tools
// run by run. Tests pass their own.
func NewMacHost(path string, run func(name string, args ...string) (string, error)) *MacHost {
	h := &MacHost{path: path, run: run}
	if raw, err := os.ReadFile(path); err == nil {
		var s macSaved
		if json.Unmarshal(raw, &s) == nil {
			if s.DNS == nil {
				s.DNS = map[string][]string{}
			}
			h.saved = &s
		}
	}
	return h
}

const (
	networksetup = "/usr/sbin/networksetup"
	routeTool    = "/sbin/route"
)

// Up implements Host.
func (h *MacHost) Up(dns []string) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if len(dns) == 0 {
		dns = []string{config.DefaultDNS}
	}
	if h.saved == nil {
		h.saved = &macSaved{DNS: map[string][]string{}}
	}
	var errs []error

	if !h.saved.IPv6 {
		h.saved.IPv6 = true
		if err := h.save(); err != nil {
			return err
		}
		for _, half := range macIPv6Halves {
			out, err := h.run(routeTool, "-n", "add", "-inet6", "-net", half, "::1", "-reject")
			if err != nil && !strings.Contains(out, "File exists") {
				errs = append(errs, fmt.Errorf("refuse IPv6 %s: %w", half, err))
			}
		}
	}

	out, err := h.run(networksetup, "-listnetworkserviceorder")
	if err != nil {
		return errors.Join(append(errs, fmt.Errorf("list network services: %w", err))...)
	}
	for _, svc := range parseServiceOrder(out) {
		if !svc.Enabled || svc.Device == "" {
			continue
		}
		if _, known := h.saved.DNS[svc.Name]; !known {
			out, err := h.run(networksetup, "-getdnsservers", svc.Name)
			if err != nil {
				errs = append(errs, fmt.Errorf("read the resolvers of %q: %w", svc.Name, err))
				continue
			}
			h.saved.DNS[svc.Name] = parseDNSServers(out)
			// Written down before it is changed, so a kill in between
			// still puts it back.
			if err := h.save(); err != nil {
				return errors.Join(append(errs, err)...)
			}
		}
		args := append([]string{"-setdnsservers", svc.Name}, dns...)
		if _, err := h.run(networksetup, args...); err != nil {
			errs = append(errs, fmt.Errorf("point %q at the tunnel: %w", svc.Name, err))
		}
	}
	h.flushCache()
	return errors.Join(errs...)
}

// Down implements Host. A service that is gone by now is skipped: there is
// nothing left of it to put back.
func (h *MacHost) Down() error {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.saved == nil {
		return nil
	}
	var errs []error
	for name, servers := range h.saved.DNS {
		args := []string{"-setdnsservers", name}
		if len(servers) == 0 {
			args = append(args, "Empty") // back to the network's own
		} else {
			args = append(args, servers...)
		}
		if _, err := h.run(networksetup, args...); err != nil {
			errs = append(errs, fmt.Errorf("restore the resolvers of %q: %w", name, err))
		}
	}
	if h.saved.IPv6 {
		for _, half := range macIPv6Halves {
			out, err := h.run(routeTool, "-n", "delete", "-inet6", "-net", half)
			if err != nil && !strings.Contains(out, "not in table") {
				errs = append(errs, fmt.Errorf("stop refusing IPv6 %s: %w", half, err))
			}
		}
	}
	h.flushCache()
	h.saved = nil
	if err := os.Remove(h.path); err != nil && !errors.Is(err, os.ErrNotExist) {
		errs = append(errs, err)
	}
	return errors.Join(errs...)
}

// flushCache drops the answers the system kept from before the change: a
// name the filter answered for stays broken until it expires otherwise.
func (h *MacHost) flushCache() {
	_, _ = h.run("/usr/bin/dscacheutil", "-flushcache")
	_, _ = h.run("/usr/bin/killall", "-HUP", "mDNSResponder")
}

func (h *MacHost) save() error {
	raw, err := json.Marshal(h.saved)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(h.path), 0o755); err != nil {
		return err
	}
	tmp := h.path + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, h.path)
}

// runTool runs one of the system's tools and returns what it printed.
// networksetup reports some failures on its output with a zero exit.
func runTool(name string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).CombinedOutput()
	text := string(out)
	if err == nil && strings.Contains(text, "** Error") {
		err = errors.New(strings.TrimSpace(text))
	}
	if err != nil {
		return text, fmt.Errorf("%s: %w (%s)", filepath.Base(name), err, strings.TrimSpace(text))
	}
	return text, nil
}

// hardwarePorts maps each device to its network kind, from the hardware
// ports networksetup lists; empty when it cannot be read.
func hardwarePorts() map[string]string {
	out, err := runTool(networksetup, "-listallhardwareports")
	if err != nil {
		return map[string]string{}
	}
	return parseHardwarePorts(out)
}
