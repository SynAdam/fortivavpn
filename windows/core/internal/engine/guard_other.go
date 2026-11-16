//go:build !windows

package engine

// SystemGuard is nil away from Windows. The router refuses IPv6 in its
// routing table instead (ipv6_linux.go), and its lookups are its own.
func SystemGuard() Guard { return nil }
