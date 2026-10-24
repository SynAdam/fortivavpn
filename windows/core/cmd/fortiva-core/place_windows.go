//go:build windows

package main

import "golang.org/x/sys/windows/registry"

// place answers the app's "place" call: where the PC is, as the PC knows it
// rather than as its address says. The backend wants the time zone as an
// IANA name ("Asia/Tehran"). Windows names zones its own way ("Iran Standard
// Time"); the key name read here is the same on every display language,
// unlike the zone's display name, which the app would get from Dart.
func place() map[string]any {
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, `SYSTEM\CurrentControlSet\Control\TimeZoneInformation`, registry.QUERY_VALUE)
	if err != nil {
		return map[string]any{}
	}
	defer k.Close()
	name, _, err := k.GetStringValue("TimeZoneKeyName")
	if err != nil {
		return map[string]any{}
	}
	if iana, ok := windowsZones[name]; ok {
		return map[string]any{"time_zone": iana}
	}
	return map[string]any{}
}
