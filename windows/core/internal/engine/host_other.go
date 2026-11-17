//go:build !darwin

package engine

import "github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"

// NewHost returns nil away from macOS: the TUN inbound sets up all Windows
// and the router need by itself.
func NewHost() Host { return nil }

// PlatformAdapter is nil away from macOS: the engine's default, the Wintun
// adapter, is the one Windows captures with.
var PlatformAdapter func() config.AdapterSpec
