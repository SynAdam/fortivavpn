//go:build darwin

package engine

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

// fakeTools answers MacHost's commands the way macOS does and records the
// ones that change something.
type fakeTools struct {
	dns     map[string][]string // a service's resolvers now
	changes []string
}

func newFakeTools() *fakeTools {
	return &fakeTools{dns: map[string][]string{
		"USB 10/100/1000 LAN": nil,
		"Wi-Fi":               nil,
		"iPhone USB":          {"8.8.8.8", "8.8.4.4"},
		"Thunderbolt Bridge":  nil,
	}}
}

func (f *fakeTools) run(name string, args ...string) (string, error) {
	line := filepath.Base(name) + " " + strings.Join(args, " ")
	switch {
	case strings.HasSuffix(name, "networksetup") && args[0] == "-listnetworkserviceorder":
		return serviceOrderOut, nil
	case strings.HasSuffix(name, "networksetup") && args[0] == "-getdnsservers":
		servers := f.dns[args[1]]
		if len(servers) == 0 {
			return "There aren't any DNS Servers set on " + args[1] + ".\n", nil
		}
		return strings.Join(servers, "\n") + "\n", nil
	case strings.HasSuffix(name, "networksetup") && args[0] == "-setdnsservers":
		if args[2] == "Empty" {
			f.dns[args[1]] = nil
		} else {
			f.dns[args[1]] = append([]string(nil), args[2:]...)
		}
	case strings.HasSuffix(name, "dscacheutil"), strings.HasSuffix(name, "killall"):
		return "", nil
	}
	f.changes = append(f.changes, line)
	return "", nil
}

func TestMacHostUpAndDown(t *testing.T) {
	tools := newFakeTools()
	path := filepath.Join(t.TempDir(), "state.json")
	h := NewMacHost(path, tools.run)

	if err := h.Up([]string{"1.1.1.1", "1.0.0.1"}); err != nil {
		t.Fatal(err)
	}
	tunnel := []string{"1.1.1.1", "1.0.0.1"}
	for _, svc := range []string{"USB 10/100/1000 LAN", "Wi-Fi", "iPhone USB", "Thunderbolt Bridge"} {
		if !reflect.DeepEqual(tools.dns[svc], tunnel) {
			t.Errorf("%s points at %v while the tunnel is up, want %v", svc, tools.dns[svc], tunnel)
		}
	}
	for _, other := range []string{"FoXray", "peer-1", "Old Ethernet"} {
		for _, c := range tools.changes {
			if strings.Contains(c, other) {
				t.Errorf("changed %q, another VPN or a disabled service: %s", other, c)
			}
		}
	}
	wantRoutes := []string{
		"route -n add -inet6 -net ::/1 ::1 -reject",
		"route -n add -inet6 -net 8000::/1 ::1 -reject",
	}
	if !reflect.DeepEqual(tools.changes[:2], wantRoutes) {
		t.Errorf("first changes %v, want the IPv6 refusals %v", tools.changes[:2], wantRoutes)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("no state written while the tunnel is up: %v", err)
	}

	// A second Up, as after a network change, keeps what was there first.
	tools.changes = nil
	if err := h.Up([]string{"9.9.9.9"}); err != nil {
		t.Fatal(err)
	}
	for _, c := range tools.changes {
		if strings.HasPrefix(c, "route") {
			t.Errorf("IPv6 refused twice: %s", c)
		}
	}

	if err := h.Down(); err != nil {
		t.Fatal(err)
	}
	if tools.dns["Wi-Fi"] != nil || tools.dns["USB 10/100/1000 LAN"] != nil {
		t.Errorf("Wi-Fi %v, USB LAN %v after the tunnel, want the network's own", tools.dns["Wi-Fi"], tools.dns["USB 10/100/1000 LAN"])
	}
	if !reflect.DeepEqual(tools.dns["iPhone USB"], []string{"8.8.8.8", "8.8.4.4"}) {
		t.Errorf("iPhone USB %v after the tunnel, want its own 8.8.8.8 8.8.4.4", tools.dns["iPhone USB"])
	}
	last := tools.changes[len(tools.changes)-2:]
	wantDel := []string{"route -n delete -inet6 -net ::/1", "route -n delete -inet6 -net 8000::/1"}
	if !reflect.DeepEqual(last, wantDel) {
		t.Errorf("last changes %v, want %v", last, wantDel)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Errorf("state left after Down: %v", err)
	}

	tools.changes = nil
	if err := h.Down(); err != nil || len(tools.changes) != 0 {
		t.Errorf("a second Down changed %v (%v), want nothing", tools.changes, err)
	}
}

// A core killed with the tunnel up is started again by launchd, and puts
// back what the killed one wrote down.
func TestMacHostPutsBackAfterAKill(t *testing.T) {
	tools := newFakeTools()
	path := filepath.Join(t.TempDir(), "state.json")
	if err := NewMacHost(path, tools.run).Up(nil); err != nil {
		t.Fatal(err)
	}
	if got := tools.dns["Wi-Fi"]; !reflect.DeepEqual(got, []string{"1.1.1.1"}) {
		t.Fatalf("Wi-Fi %v with no resolvers asked for, want the default 1.1.1.1", got)
	}

	if err := NewMacHost(path, tools.run).Down(); err != nil {
		t.Fatal(err)
	}
	if tools.dns["Wi-Fi"] != nil || !reflect.DeepEqual(tools.dns["iPhone USB"], []string{"8.8.8.8", "8.8.4.4"}) {
		t.Errorf("after the restart Wi-Fi %v, iPhone USB %v", tools.dns["Wi-Fi"], tools.dns["iPhone USB"])
	}
}
