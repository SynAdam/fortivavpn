//go:build darwin

package main

import (
	"os"
	"strings"
)

// place answers with the Mac's time zone as an IANA name. Go names the
// local zone "Local", so the name is read from where /etc/localtime points,
// which is how macOS records the zone set in System Settings
// (/var/db/timezone/zoneinfo/Asia/Tehran).
func place() map[string]any {
	target, err := os.Readlink("/etc/localtime")
	if err != nil {
		return map[string]any{}
	}
	if _, name, ok := strings.Cut(target, "/zoneinfo/"); ok && name != "" {
		return map[string]any{"time_zone": name}
	}
	return map[string]any{}
}
