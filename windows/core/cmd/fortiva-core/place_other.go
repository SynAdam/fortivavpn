//go:build !windows

package main

import "time"

// place answers with the local zone when it has an IANA name. On the
// platforms the core is developed on, it usually does.
func place() map[string]any {
	if name := time.Local.String(); name != "" && name != "Local" {
		return map[string]any{"time_zone": name}
	}
	return map[string]any{}
}
