//go:build darwin

package engine

import (
	"net"
	"net/netip"
	"os"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/xtls/xray-core/transport/internet"
	"golang.org/x/net/route"
	"golang.org/x/sys/unix"
)

// DarwinBinder binds the core's sockets to the interface that holds the
// Mac's real default route, so that while the tunnel's two IPv4 halves
// cover everything the core still reaches its doors, and sends direct
// traffic, over the physical network. It is the macOS twin of
// WindowsBinder.
//
// IP_BOUND_IF is the whole mechanism. macOS keeps a default route scoped to
// each interface, and a socket bound to one uses that interface's routes
// alone, so the tunnel's halves never apply to it.
//
// The interface is the default route's that has a gateway, which is what a
// physical network has, and is not a tunnel's. The unscoped one comes
// first: it is the primary network service's. With another VPN running,
// the core still goes out over Wi-Fi or Ethernet, not through it.
type DarwinBinder struct {
	onChange func()

	mu      sync.RWMutex
	active  bool
	index4  int
	index6  int
	device  string
	network string

	// ports maps a device ("en0") to its network kind, from the hardware
	// ports networksetup lists. Read again when a device is not in it.
	ports map[string]string

	// pinMu serializes pinning; pinned is the scoped default route this
	// binder added, empty when it added none (pin).
	pinMu  sync.Mutex
	pinned pinnedRoute
	run    func(name string, args ...string) (string, error)
}

// pinnedRoute is a scoped default route: the device it is scoped to and
// its gateway.
type pinnedRoute struct {
	device  string
	gateway netip.Addr
}

// NewDarwinBinder watches the routing table for as long as the process
// runs. onChange is called, on its own goroutine, when the interface
// holding the default route changes while binding is active.
func NewDarwinBinder(onChange func()) (*DarwinBinder, error) {
	b := &DarwinBinder{onChange: onChange, run: runTool}
	b.refresh()
	fd, err := unix.Socket(unix.AF_ROUTE, unix.SOCK_RAW, unix.AF_UNSPEC)
	if err != nil {
		return nil, err
	}
	go b.watch(os.NewFile(uintptr(fd), "route"))
	return b, nil
}

// macPollEvery is how often the routing table is read without a message
// from the kernel, in case one was lost.
const macPollEvery = 5 * time.Second

// refreshDelay gathers the burst of routing messages one change brings
// (addresses, routes, the interface itself) into one read of the table.
const refreshDelay = 300 * time.Millisecond

// watch reads the table again after every burst of routing messages, and
// every macPollEvery besides in case a message was lost.
func (b *DarwinBinder) watch(f *os.File) {
	kick := make(chan struct{}, 1)
	go func() {
		buf := make([]byte, 64<<10)
		for {
			if _, err := f.Read(buf); err != nil {
				return
			}
			select {
			case kick <- struct{}{}:
			default:
			}
		}
	}()
	poll := time.NewTicker(macPollEvery)
	defer poll.Stop()
	for {
		select {
		case <-kick:
			time.Sleep(refreshDelay)
			select {
			case <-kick:
			default:
			}
		case <-poll.C:
		}
		b.refresh()
	}
}

// SetActive implements Binder. Turning it off takes away the scoped
// default route it added (pin).
func (b *DarwinBinder) SetActive(active bool) {
	b.mu.Lock()
	b.active = active
	b.mu.Unlock()
	if active {
		b.refresh()
	} else {
		b.pin(false, "", nil)
	}
}

// Network implements Binder.
func (b *DarwinBinder) Network() string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.network
}

func (b *DarwinBinder) refresh() {
	msgs4 := routes(unix.AF_INET)
	index4 := pickDefaultRoute(msgs4, interfaceName)
	index6 := pickDefaultRoute(routes(unix.AF_INET6), interfaceName)
	device := ""
	if index4 != 0 {
		if iface, err := net.InterfaceByIndex(index4); err == nil {
			device = iface.Name
		}
	}

	b.mu.Lock()
	network, known := b.ports[device]
	if !known && device != "" {
		b.ports = hardwarePorts()
		network = b.ports[device]
	}
	if network == "" && device != "" {
		network = "other"
	}
	// While a tunnel is up, a network that is gone for a moment (Wi-Fi
	// roaming, a cable out, the Mac waking up) leaves the last interface in
	// place rather than none, as on Windows. A socket bound to an interface
	// that is down fails; an unbound one follows the tunnel's routes back
	// into the tunnel, and the core then carries its own traffic round and
	// round.
	if b.active {
		if index4 == 0 {
			index4, device, network = b.index4, b.device, b.network
		}
		if index6 == 0 {
			index6 = b.index6
		}
	}
	changed := index4 != b.index4 || index6 != b.index6
	b.index4, b.index6, b.device, b.network = index4, index6, device, network
	active := b.active
	notify := changed && active && b.onChange != nil
	b.mu.Unlock()

	if active {
		b.pin(true, device, msgs4)
	}
	if notify {
		go b.onChange()
	}
}

// pin makes sure, while active, that device has a default route scoped to
// it, and adds one through the gateway of its unscoped default route when
// it has none.
//
// IP_BOUND_IF looks a socket's destination up among the routes scoped to
// its interface. macOS keeps a scoped default route for each network
// service but the primary one: with Wi-Fi the only network, en0 has only
// the unscoped default. Once the tunnel's halves are in, a socket bound to
// en0 then finds no route at all, and every door the core dials is
// "network is unreachable" (found on a Mac, 2026-11-17). A second network,
// or another VPN that is primary, gives en0 its scoped route, which is why
// it worked there.
//
// The route it added goes when binding stops, or when the network moves
// to another device or gateway.
func (b *DarwinBinder) pin(active bool, device string, msgs []route.Message) {
	b.pinMu.Lock()
	defer b.pinMu.Unlock()
	want := pinnedRoute{}
	scoped := false
	if active && device != "" {
		index := 0
		if iface, err := net.InterfaceByName(device); err == nil {
			index = iface.Index
		}
		gateway, has := scopedDefault(msgs, index)
		if gateway.IsValid() {
			want = pinnedRoute{device: device, gateway: gateway}
		}
		scoped = has
	}
	if b.pinned.device != "" && b.pinned != want {
		_, _ = b.run(routeTool, "-n", "delete", "-ifscope", b.pinned.device, "default")
		b.pinned = pinnedRoute{}
		scoped = false
	}
	if want.device == "" || b.pinned == want || scoped {
		return
	}
	out, err := b.run(routeTool, "-n", "add", "-ifscope", want.device, "default", want.gateway.String())
	if err == nil || strings.Contains(out, "File exists") {
		b.pinned = want
	}
}

// scopedDefault reads the IPv4 default routes in msgs for the interface
// index: the gateway of its unscoped default route (invalid when it has
// none), and whether it has a scoped default route already.
func scopedDefault(msgs []route.Message, index int) (gateway netip.Addr, scoped bool) {
	for _, m := range msgs {
		rm, ok := m.(*route.RouteMessage)
		if !ok || rm.Index != index || index == 0 || !isDefaultRoute(rm) {
			continue
		}
		if rm.Flags&unix.RTF_UP == 0 || rm.Flags&unix.RTF_GATEWAY == 0 {
			continue
		}
		if rm.Flags&unix.RTF_IFSCOPE != 0 {
			scoped = true
			continue
		}
		if len(rm.Addrs) > unix.RTAX_GATEWAY {
			if gw, ok := rm.Addrs[unix.RTAX_GATEWAY].(*route.Inet4Addr); ok {
				gateway = netip.AddrFrom4(gw.IP)
			}
		}
	}
	return gateway, scoped
}

// routes is family's routing table, nil when it cannot be read.
func routes(family int) []route.Message {
	rib, err := route.FetchRIB(family, route.RIBTypeRoute, 0)
	if err != nil {
		return nil
	}
	msgs, err := route.ParseRIB(route.RIBTypeRoute, rib)
	if err != nil {
		return nil
	}
	return msgs
}

// interfaceName names an interface by its index, "" when there is none.
func interfaceName(index int) string {
	if iface, err := net.InterfaceByIndex(index); err == nil {
		return iface.Name
	}
	return ""
}

// pickDefaultRoute is the interface of the default route among msgs with
// a gateway, the unscoped one first, on an interface that is not a tunnel.
// Zero means none, which is what a Mac with no network has. nameOf names
// an interface by its index.
//
// A tunnel's interface is never picked. macOS keeps scoped IPv6 default
// routes with gateways on its own utuns (iCloud Private Relay and the
// like), and another VPN can hold a default route on its own; the core's
// doors must go out over the physical network all the same.
func pickDefaultRoute(msgs []route.Message, nameOf func(int) string) int {
	scoped := 0
	for _, m := range msgs {
		rm, ok := m.(*route.RouteMessage)
		if !ok || rm.Index == 0 || !isDefaultRoute(rm) {
			continue
		}
		if rm.Flags&unix.RTF_UP == 0 || rm.Flags&unix.RTF_GATEWAY == 0 {
			continue
		}
		if name := nameOf(rm.Index); name == "" || isTunnelInterface(name) {
			continue
		}
		if rm.Flags&unix.RTF_IFSCOPE == 0 {
			return rm.Index
		}
		if scoped == 0 {
			scoped = rm.Index
		}
	}
	return scoped
}

// isTunnelInterface reports whether name is a VPN's interface: the
// tunnel's own utun, another VPN's, or an IPsec one.
func isTunnelInterface(name string) bool {
	return strings.HasPrefix(name, "utun") || strings.HasPrefix(name, "ipsec")
}

// isDefaultRoute reports whether rm's destination is the whole address
// space. The kernel sends a default route's netmask as an empty address,
// which parses as nothing or as all zeroes.
func isDefaultRoute(rm *route.RouteMessage) bool {
	if len(rm.Addrs) <= unix.RTAX_DST {
		return false
	}
	var mask route.Addr
	if len(rm.Addrs) > unix.RTAX_NETMASK {
		mask = rm.Addrs[unix.RTAX_NETMASK]
	}
	switch dst := rm.Addrs[unix.RTAX_DST].(type) {
	case *route.Inet4Addr:
		if dst.IP != netip.IPv4Unspecified().As4() {
			return false
		}
		m, ok := mask.(*route.Inet4Addr)
		return mask == nil || (ok && m.IP == [4]byte{})
	case *route.Inet6Addr:
		if dst.IP != netip.IPv6Unspecified().As16() {
			return false
		}
		m, ok := mask.(*route.Inet6Addr)
		return mask == nil || (ok && m.IP == [16]byte{})
	default:
		return false
	}
}

// Control implements Binder. Loopback is left alone: binding it to a
// physical interface would make it unreachable.
func (b *DarwinBinder) Control(network, address string, c syscall.RawConn) error {
	b.mu.RLock()
	active, index4, index6 := b.active, b.index4, b.index6
	b.mu.RUnlock()
	if !active {
		return nil
	}
	if host, _, err := net.SplitHostPort(address); err == nil {
		if ip, err := netip.ParseAddr(host); err == nil && ip.IsLoopback() {
			return nil
		}
	}

	var sockErr error
	err := c.Control(func(fd uintptr) {
		switch network {
		case "tcp4", "udp4":
			if index4 != 0 {
				sockErr = unix.SetsockoptInt(int(fd), unix.IPPROTO_IP, unix.IP_BOUND_IF, index4)
			}
		case "tcp6", "udp6":
			// A socket of either family can be an IPv6 one that also
			// carries IPv4 (a listener on "udp" with no address). Its IPv4
			// goes out where IP_BOUND_IF says, which the kernel may refuse
			// on an IPv6 socket; that refusal is no failure.
			if index4 != 0 {
				_ = unix.SetsockoptInt(int(fd), unix.IPPROTO_IP, unix.IP_BOUND_IF, index4)
			}
			if index6 != 0 {
				sockErr = unix.SetsockoptInt(int(fd), unix.IPPROTO_IPV6, unix.IPV6_BOUND_IF, index6)
			} else if index4 != 0 {
				// No IPv6 network: an IPv6 socket that reached the routes
				// would go into the tunnel, which refuses IPv6.
				sockErr = unix.SetsockoptInt(int(fd), unix.IPPROTO_IPV6, unix.IPV6_BOUND_IF, index4)
			}
		}
	})
	if err != nil {
		return err
	}
	return sockErr
}

// NewBinder returns the binder for this platform and installs it as the
// core's dialer hook, which applies to every instance in the process.
func NewBinder(onChange func()) (Binder, error) {
	b, err := NewDarwinBinder(onChange)
	if err != nil {
		return nil, err
	}
	if err := internet.RegisterDialerController(b.Control); err != nil {
		return nil, err
	}
	return b, nil
}
