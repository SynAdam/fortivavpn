//go:build linux

package engine

import (
	"errors"
	"fmt"
	"net"
	"os"

	"github.com/vishvananda/netlink"
	"golang.org/x/sys/unix"
)

// The router's tunnel carries IPv4 alone (RouterAdapter), and while a
// tunnel is starting or up the router refuses IPv6 in its routing table:
// a "prohibit" route for each half of the IPv6 space, more specific than
// any default route, like the tunnel's own IPv4 halves.
//
// A refusal in the routing table comes before any connection. The router's
// own programs (opkg, apk, uclient-fetch) then see IPv6 as unreachable and
// take IPv4 first, and a device behind the router gets "administratively
// prohibited" at once and falls back to IPv4, as browsers do. No IPv6 goes
// around the tunnel either. Routing IPv6 into the tunnel instead, as on
// Windows, made the core answer each IPv6 connection with an HTTP 403: a
// device with IPv6 from its ISP, which prefers it, got that for every site,
// and its HTTPS failed. OpenWrt's own uclient-fetch did not fall back even
// when the firewall refused it after the connect.
var ipv6Halves = []string{"::/1", "8000::/1"}

// kernelIPv6 is a file that exists when the kernel has IPv6. Tests
// replace it.
var kernelIPv6 = "/proc/net/if_inet6"

// refuseIPv6 adds the two prohibit routes (on) or removes them (off). A
// route already there, or already gone, is no error.
func refuseIPv6(on bool) error {
	if _, err := os.Stat(kernelIPv6); err != nil {
		return nil // no IPv6 to refuse
	}
	var errs []error
	for _, cidr := range ipv6Halves {
		_, dst, err := net.ParseCIDR(cidr)
		if err != nil {
			return err
		}
		route := &netlink.Route{
			Dst:      dst,
			Type:     unix.RTN_PROHIBIT,
			Priority: 1,
			Table:    unix.RT_TABLE_MAIN,
			Family:   netlink.FAMILY_V6,
		}
		if on {
			err = netlink.RouteReplace(route)
		} else if err = netlink.RouteDel(route); errors.Is(err, unix.ESRCH) || errors.Is(err, unix.ENOENT) {
			err = nil
		}
		if err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", cidr, err))
		}
	}
	return errors.Join(errs...)
}

func logRefuseIPv6(on bool) {
	if err := refuseIPv6(on); err != nil && RouterLog != nil {
		if on {
			RouterLog("[engine] could not refuse IPv6 while the tunnel is up: %v", err)
		} else {
			RouterLog("[engine] could not stop refusing IPv6: %v", err)
		}
	}
}
