//go:build darwin

package engine

import (
	"net"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
)

// PlatformAdapter is the TUN interface the core captures with on this
// platform.
var PlatformAdapter = MacAdapter

// MacAdapter is config.MacAdapter named with the first free utun from
// firstUtun on, asked at each connect.
func MacAdapter() config.AdapterSpec {
	a := config.MacAdapter
	a.Name = freeUtun(interfaceNames())
	return a
}

func interfaceNames() map[string]bool {
	names := map[string]bool{}
	ifaces, _ := net.Interfaces()
	for _, i := range ifaces {
		names[i.Name] = true
	}
	return names
}
