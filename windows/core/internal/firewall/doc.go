// Package firewall holds the Windows Filtering Platform filters the tunnel
// puts on the PC while it is up (filters_windows.go).
//
// The WFP types and calls are WireGuard for Windows' tunnel/firewall package
// (golang.zx2c4.com/wireguard/windows v1.0.1, MIT): types_windows*.go,
// syscall_windows.go, zsyscall_windows.go and mksyscall.go as they are there,
// except that the two size-specific type files also say they are for
// Windows, and session_windows.go from its blocker.go and helpers.go. That
// package itself is not used because it only blocks everything that does not
// go through the tunnel, the local network included.
package firewall
