//go:build windows

package engine

import (
	"encoding/binary"
	"net"
	"net/netip"
	"sync"
	"syscall"
	"unsafe"

	"github.com/xtls/xray-core/transport/internet"
	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wireguard/windows/tunnel/winipcfg"
)

// Socket options that pin a socket's unicast traffic to one interface,
// whatever the routing table says. IPv4 takes the index in network byte
// order, IPv6 in host order.
const (
	ipUnicastIf   = 31
	ipv6UnicastIf = 31
)

// WindowsBinder binds the core's sockets to the interface that holds the
// real default route, so that while the tunnel's routes cover everything the
// core still reaches its doors, and sends direct traffic, over the physical
// network.
//
// The core can do this itself ("autoOutboundsInterface": "auto"), but it
// picks the interface by its name and address, preferring Wi-Fi and
// 192.168.x.x, and so can bind to a virtual machine's host-only adapter on a
// PC whose real network is Ethernet on 10.x.x.x. This picks the interface
// the system itself would use: the default route with the lowest route plus
// interface metric on an interface that is up, as WireGuard for Windows
// does. The tunnel's own routes are the two halves of the address space,
// never a default route, so they are never picked.
type WindowsBinder struct {
	mu       sync.RWMutex
	active   bool
	index4   uint32
	index6   uint32
	network  string
	onChange func()

	routeCB *winipcfg.RouteChangeCallback
	ifaceCB *winipcfg.InterfaceChangeCallback
}

// NewWindowsBinder watches the routing table for as long as the process
// runs. onChange is called, on its own goroutine, when the interface holding
// the default route changes while binding is active.
func NewWindowsBinder(onChange func()) (*WindowsBinder, error) {
	b := &WindowsBinder{onChange: onChange}
	b.refresh()
	var err error
	b.routeCB, err = winipcfg.RegisterRouteChangeCallback(func(_ winipcfg.MibNotificationType, route *winipcfg.MibIPforwardRow2) {
		if route == nil || route.DestinationPrefix.PrefixLength == 0 {
			b.refresh()
		}
	})
	if err != nil {
		return nil, err
	}
	b.ifaceCB, err = winipcfg.RegisterInterfaceChangeCallback(func(winipcfg.MibNotificationType, *winipcfg.MibIPInterfaceRow) {
		b.refresh()
	})
	if err != nil {
		_ = b.routeCB.Unregister()
		return nil, err
	}
	return b, nil
}

// SetActive implements Binder.
func (b *WindowsBinder) SetActive(active bool) {
	b.mu.Lock()
	b.active = active
	b.mu.Unlock()
	if active {
		b.refresh()
	}
}

// Network implements Binder.
func (b *WindowsBinder) Network() string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	return b.network
}

func (b *WindowsBinder) refresh() {
	luid4, index4 := defaultInterface(windows.AF_INET)
	_, index6 := defaultInterface(windows.AF_INET6)
	network := ""
	if luid4 != 0 {
		network = networkKind(luid4)
	}

	b.mu.Lock()
	changed := index4 != b.index4 || index6 != b.index6
	b.index4, b.index6, b.network = index4, index6, network
	notify := changed && b.active && b.onChange != nil
	b.mu.Unlock()

	if notify {
		go b.onChange()
	}
}

// defaultInterface returns the interface the system sends to the internet
// through for family: its default route with the lowest combined metric, on
// an interface that is up. Zero means none, which is what an unplugged PC
// has.
func defaultInterface(family winipcfg.AddressFamily) (winipcfg.LUID, uint32) {
	routes, err := winipcfg.GetIPForwardTable2(family)
	if err != nil {
		return 0, 0
	}
	lowest := ^uint64(0)
	var (
		luid  winipcfg.LUID
		index uint32
	)
	for i := range routes {
		r := &routes[i]
		if r.DestinationPrefix.PrefixLength != 0 {
			continue
		}
		row, err := r.InterfaceLUID.Interface()
		if err != nil || row.OperStatus != winipcfg.IfOperStatusUp {
			continue
		}
		ipif, err := r.InterfaceLUID.IPInterface(family)
		if err != nil {
			continue
		}
		if metric := uint64(r.Metric) + uint64(ipif.Metric); metric < lowest {
			lowest, luid, index = metric, r.InterfaceLUID, r.InterfaceIndex
		}
	}
	return luid, index
}

// networkKind names an interface's medium the way the app's diagnostics do.
func networkKind(luid winipcfg.LUID) string {
	row, err := luid.Interface()
	if err != nil {
		return ""
	}
	switch row.Type {
	case 71: // IF_TYPE_IEEE80211
		return "wifi"
	case 6: // IF_TYPE_ETHERNET_CSMACD
		return "ethernet"
	case 243, 244: // IF_TYPE_WWANPP, IF_TYPE_WWANPP2: a SIM in the PC or a USB modem
		return "mobile"
	default:
		return "other"
	}
}

// Control implements Binder. Loopback is left alone: binding it to a
// physical interface would make it unreachable.
func (b *WindowsBinder) Control(network, address string, c syscall.RawConn) error {
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
			if index4 == 0 {
				return
			}
			var be [4]byte
			binary.BigEndian.PutUint32(be[:], index4)
			sockErr = windows.SetsockoptInt(windows.Handle(fd), windows.IPPROTO_IP, ipUnicastIf, int(*(*uint32)(unsafe.Pointer(&be[0]))))
		case "tcp6", "udp6":
			if index6 == 0 {
				return
			}
			sockErr = windows.SetsockoptInt(windows.Handle(fd), windows.IPPROTO_IPV6, ipv6UnicastIf, int(index6))
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
	b, err := NewWindowsBinder(onChange)
	if err != nil {
		return nil, err
	}
	if err := internet.RegisterDialerController(b.Control); err != nil {
		return nil, err
	}
	return b, nil
}
