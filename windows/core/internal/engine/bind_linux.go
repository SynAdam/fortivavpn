//go:build linux

package engine

import (
	"os"
	"sync"
	"syscall"
	"time"

	"github.com/xtls/xray-core/transport/internet"
	"golang.org/x/sys/unix"
)

// LinuxBinder binds the core's sockets to the interface that holds the
// default route: on a router, the WAN device. It is the Linux twin of
// WindowsBinder. The TUN inbound's routes are more specific than the
// default route, so without this a door's connection, and "direct" traffic,
// would go into the tunnel it carries.
//
// SO_BINDTODEVICE is the whole mechanism. A socket bound to a device only
// uses routes through that device, so the default route via the WAN wins
// over the two half routes via the TUN interface for it alone.
type LinuxBinder struct {
	onChange func()
	// fixed is the device to bind to when the person set one. Empty means
	// the one with the IPv4 default route.
	fixed string
	// skip is the TUN interface's name, which never counts as the WAN.
	skip string

	wan    wanDevice
	mu     sync.RWMutex
	active bool
	stop   chan struct{}
	// ipv6 refuses IPv6 in the routing table while a tunnel is starting or
	// up (ipv6_linux.go). The router build's binder (NewBinder) does.
	ipv6 bool
}

// routeFile is where the IPv4 routing table is read from. Tests replace it.
var routeFile = "/proc/net/route"

// pollEvery is how often the routing table is read without a change
// message from the kernel, in case one was lost.
const pollEvery = 5 * time.Second

// NewLinuxBinder watches the routing table for as long as the process runs.
// fixed names the WAN device, or "" to follow the default route; skip is
// the TUN interface's name.
func NewLinuxBinder(onChange func(), fixed, skip string) *LinuxBinder {
	b := &LinuxBinder{onChange: onChange, fixed: fixed, skip: skip, stop: make(chan struct{})}
	b.wan.set(b.read())
	go b.watch()
	return b
}

// watch reads the routing table whenever the kernel says a route or a link
// changed, and every pollEvery besides. A PPPoE or DHCP WAN can go away and
// come back on another device, and the door group must measure its doors
// again when it does. Without a netlink socket it only polls.
func (b *LinuxBinder) watch() {
	fd, err := routeEvents()
	if err != nil {
		t := time.NewTicker(pollEvery)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				b.refresh()
			case <-b.stop:
				return
			}
		}
	}
	defer unix.Close(fd)
	buf := make([]byte, 64<<10)
	for {
		select {
		case <-b.stop:
			return
		default:
		}
		// A message, the receive timeout (pollEvery) or a lost message
		// (ENOBUFS): the table is read again in every case.
		if _, _, err := unix.Recvfrom(fd, buf, 0); err == nil {
			// One change comes as several messages; read the table once.
			for {
				if _, _, err := unix.Recvfrom(fd, buf, unix.MSG_DONTWAIT); err != nil {
					break
				}
			}
		}
		b.refresh()
	}
}

// routeEvents opens a netlink socket that hears of every change to the
// IPv4 routes and the links, and times out after pollEvery.
func routeEvents() (int, error) {
	fd, err := unix.Socket(unix.AF_NETLINK, unix.SOCK_RAW|unix.SOCK_CLOEXEC, unix.NETLINK_ROUTE)
	if err != nil {
		return -1, err
	}
	addr := &unix.SockaddrNetlink{Family: unix.AF_NETLINK, Groups: unix.RTMGRP_IPV4_ROUTE | unix.RTMGRP_LINK}
	tv := unix.NsecToTimeval(pollEvery.Nanoseconds())
	if err := unix.Bind(fd, addr); err != nil {
		unix.Close(fd)
		return -1, err
	}
	if err := unix.SetsockoptTimeval(fd, unix.SOL_SOCKET, unix.SO_RCVTIMEO, &tv); err != nil {
		unix.Close(fd)
		return -1, err
	}
	return fd, nil
}

// Close stops the watch.
func (b *LinuxBinder) Close() { close(b.stop) }

// read is the WAN device now.
func (b *LinuxBinder) read() string {
	if b.fixed != "" {
		return b.fixed
	}
	return defaultRouteDevice(b.skip)
}

func (b *LinuxBinder) refresh() {
	if b.wan.set(b.read()) && b.onChange != nil {
		b.onChange()
	}
}

// Device is the interface sockets are bound to, or "" when there is none.
func (b *LinuxBinder) Device() string {
	return b.wan.get()
}

// SetActive implements Binder. On a router it also refuses IPv6 while a
// tunnel is starting or up, and stops when none is.
func (b *LinuxBinder) SetActive(active bool) {
	b.mu.Lock()
	changed := b.active != active
	b.active = active
	b.mu.Unlock()
	if changed && b.ipv6 {
		logRefuseIPv6(active)
	}
}

// Network implements Binder. A router's WAN is a cable most of the time; a
// cellular modem or a Wi-Fi uplink is told apart by the device's name.
func (b *LinuxBinder) Network() string {
	return networkOf(b.Device())
}

// Control implements Binder. While a tunnel is starting or up, a socket of
// the core is bound to the WAN, or refused when there is no WAN.
func (b *LinuxBinder) Control(network, address string, c syscall.RawConn) error {
	b.mu.RLock()
	active := b.active
	b.mu.RUnlock()
	return bindTo(active, b.Device(), address, c)
}

// Bind is Control for a socket the process opens outside the core, such as
// a call to the backend that must go around the tunnel. It binds whether
// or not a tunnel is up. With no WAN known it leaves the socket to the
// routing table when no tunnel is up, and refuses it when one is.
func (b *LinuxBinder) Bind(network, address string, c syscall.RawConn) error {
	b.mu.RLock()
	active := b.active
	b.mu.RUnlock()
	device := b.Device()
	if device == "" && !active {
		return nil
	}
	return bindTo(true, device, address, c)
}

func bindTo(active bool, device, address string, c syscall.RawConn) error {
	device, err := bindDevice(active, device, address)
	if err != nil || device == "" {
		return err
	}
	var sockErr error
	err = c.Control(func(fd uintptr) {
		sockErr = unix.BindToDevice(int(fd), device)
	})
	if err != nil {
		return err
	}
	return sockErr
}

// defaultRouteDevice is the device of the IPv4 default route with the
// lowest metric, leaving out skip.
func defaultRouteDevice(skip string) string {
	f, err := os.Open(routeFile)
	if err != nil {
		return ""
	}
	defer f.Close()
	return parseDefaultRoute(f, skip)
}

// NewBinder returns the binder for this platform and installs it as the
// core's dialer hook. The router build passes its WAN device through
// RouterWAN before it calls this.
func NewBinder(onChange func()) (Binder, error) {
	b := NewLinuxBinder(onChange, RouterWAN, RouterAdapterName)
	if err := internet.RegisterDialerController(b.Control); err != nil {
		return nil, err
	}
	// A program that was killed while a tunnel was up left IPv6 refused.
	b.ipv6 = true
	logRefuseIPv6(false)
	return b, nil
}
