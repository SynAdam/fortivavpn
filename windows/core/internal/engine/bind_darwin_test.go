//go:build darwin

package engine

import (
	"net"
	"reflect"
	"strings"
	"testing"

	"golang.org/x/net/route"
	"golang.org/x/sys/unix"
)

func defaultRoute(index, flags int) *route.RouteMessage {
	addrs := make([]route.Addr, unix.RTAX_MAX)
	addrs[unix.RTAX_DST] = &route.Inet4Addr{}
	addrs[unix.RTAX_NETMASK] = &route.Inet4Addr{}
	return &route.RouteMessage{Index: index, Flags: flags, Addrs: addrs}
}

func TestPickDefaultRoute(t *testing.T) {
	const up, gw, scoped = unix.RTF_UP, unix.RTF_GATEWAY, unix.RTF_IFSCOPE
	half := defaultRoute(30, up|gw)
	half.Addrs[unix.RTAX_DST] = &route.Inet4Addr{IP: [4]byte{128}}
	half.Addrs[unix.RTAX_NETMASK] = &route.Inet4Addr{IP: [4]byte{128}}

	cases := []struct {
		name string
		msgs []route.Message
		want int
	}{
		{"the primary network", []route.Message{defaultRoute(11, up|gw|scoped), defaultRoute(4, up|gw), defaultRoute(11, up|gw)}, 4},
		// What this Mac had with FoXray connected: its default route is an
		// interface route on utun4, Wi-Fi's is scoped.
		{"another VPN holds the default", []route.Message{defaultRoute(20, up|unix.RTF_STATIC), defaultRoute(11, up|gw|scoped)}, 11},
		{"the tunnel's own halves", []route.Message{half, defaultRoute(11, up|gw|scoped)}, 11},
		// macOS's own utuns hold scoped IPv6 defaults with gateways.
		{"a system tunnel's scoped default", []route.Message{defaultRoute(15, up|gw|scoped)}, 0},
		{"another VPN's default with a gateway", []route.Message{defaultRoute(20, up|gw), defaultRoute(11, up|gw|scoped)}, 11},
		{"down", []route.Message{defaultRoute(11, gw)}, 0},
		{"none", nil, 0},
	}
	names := map[int]string{4: "en5", 11: "en0", 15: "utun0", 20: "utun4", 30: "utun10"}
	nameOf := func(i int) string { return names[i] }
	for _, c := range cases {
		if got := pickDefaultRoute(c.msgs, nameOf); got != c.want {
			t.Errorf("%s: picked %d, want %d", c.name, got, c.want)
		}
	}
}

// What the binder picks on the Mac the tests run on, for a person reading
// the test's output; a Mac with no network picks nothing.
func TestDefaultRouteHere(t *testing.T) {
	b, err := NewDarwinBinder(nil)
	if err != nil {
		t.Fatal(err)
	}
	b.mu.RLock()
	defer b.mu.RUnlock()
	t.Logf("IPv4 index %d (%s, %s), IPv6 index %d", b.index4, b.device, b.network, b.index6)
}

func gatewayRoute(index, flags int, gw [4]byte) *route.RouteMessage {
	m := defaultRoute(index, flags)
	m.Addrs[unix.RTAX_GATEWAY] = &route.Inet4Addr{IP: gw}
	return m
}

// With Wi-Fi the only network, en0 has no scoped default route, so a
// socket bound to it finds no route once the tunnel's halves are in. The
// binder adds one while it binds, and takes it away after.
func TestPinAddsAScopedDefaultOnlyWhenNoneExists(t *testing.T) {
	lo, err := net.InterfaceByName("lo0")
	if err != nil {
		t.Skip("no lo0")
	}
	const up, gw, scoped = unix.RTF_UP, unix.RTF_GATEWAY, unix.RTF_IFSCOPE
	var ran []string
	b := &DarwinBinder{run: func(name string, args ...string) (string, error) {
		ran = append(ran, strings.Join(args, " "))
		return "", nil
	}}

	primary := []route.Message{gatewayRoute(lo.Index, up|gw, [4]byte{10, 207, 214, 39})}
	b.pin(true, "lo0", primary)
	if want := []string{"-n add -ifscope lo0 default 10.207.214.39"}; !reflect.DeepEqual(ran, want) {
		t.Fatalf("ran %v, want %v", ran, want)
	}

	// Its own route is there now: nothing more.
	ran = nil
	withOurs := append(primary, gatewayRoute(lo.Index, up|gw|scoped, [4]byte{10, 207, 214, 39}))
	b.pin(true, "lo0", withOurs)
	if len(ran) != 0 {
		t.Fatalf("ran %v with its own route in place", ran)
	}

	// Another network on the same device: the old gateway goes.
	ran = nil
	b.pin(true, "lo0", []route.Message{gatewayRoute(lo.Index, up|gw, [4]byte{192, 168, 1, 1})})
	want := []string{"-n delete -ifscope lo0 default", "-n add -ifscope lo0 default 192.168.1.1"}
	if !reflect.DeepEqual(ran, want) {
		t.Fatalf("ran %v, want %v", ran, want)
	}

	// Binding stops: the route it added goes.
	ran = nil
	b.pin(false, "", nil)
	if want := []string{"-n delete -ifscope lo0 default"}; !reflect.DeepEqual(ran, want) {
		t.Fatalf("ran %v, want %v", ran, want)
	}

	// A scoped default macOS made itself (two networks, or another VPN
	// primary) is left alone, and never removed.
	ran = nil
	b.pin(true, "lo0", []route.Message{
		gatewayRoute(lo.Index, up|gw|scoped, [4]byte{10, 207, 214, 39}),
		gatewayRoute(lo.Index, up|gw, [4]byte{10, 207, 214, 39}),
	})
	b.pin(false, "", nil)
	if len(ran) != 0 {
		t.Fatalf("ran %v around a scoped route macOS made", ran)
	}
}
