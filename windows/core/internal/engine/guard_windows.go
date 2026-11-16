//go:build windows

package engine

import (
	"crypto/md5"
	"errors"
	"fmt"
	"net"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wireguard/windows/tunnel/winipcfg"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/firewall"
)

// SystemGuard puts internal/firewall's filters on the tunnel's adapter: IPv6
// sent into the tunnel is refused at once, and lookups go only through it.
func SystemGuard() Guard {
	return func(adapter config.AdapterSpec) (func(), error) {
		luid, err := adapterLUID(adapter.Name)
		if err != nil {
			return nil, err
		}
		f, err := firewall.Add(uint64(luid))
		if err != nil {
			return nil, err
		}
		return f.Close, nil
	}
}

// adapterLUID finds the adapter the TUN inbound made. The core gives it a
// GUID made from its name (proxy/tun/tun_windows.go, open), which finds it
// directly; the name is the fallback.
func adapterLUID(name string) (winipcfg.LUID, error) {
	sum := md5.Sum([]byte(name))
	guid := *(*windows.GUID)(unsafe.Pointer(&sum[0]))
	luid, err := winipcfg.LUIDFromGUID(&guid)
	if err == nil && luid != 0 {
		return luid, nil
	}
	iface, ierr := net.InterfaceByName(name)
	if ierr != nil {
		return 0, fmt.Errorf("find the adapter %s: %w", name, errors.Join(err, ierr))
	}
	return winipcfg.LUIDFromIndex(uint32(iface.Index))
}
