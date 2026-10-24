// Package fortivacore is the part of the Android core binding that Fortiva
// adds itself. gomobile binds it next to AndroidLibXrayLite, so the Kotlin
// layer sees it as fortivacore.Fortivacore.
//
// It exposes the autoselect outbound (patches/xray-autoselect.patch) to the
// app. Every function recovers from a panic, because a Go panic that crosses
// the JNI boundary kills the whole process, tunnel included.
package fortivacore

import "github.com/xtls/xray-core/proxy/autoselect"

// AutoSelectStatus returns every running autoselect group as a JSON array:
// the member new connections go to, why it was last changed, and what is
// known about each member. It returns "[]" when no group is running.
func AutoSelectStatus() (status string) {
	defer func() {
		if recover() != nil {
			status = "[]"
		}
	}()
	return autoselect.StatusJSON()
}

// AutoSelectNetworkChanged makes every group measure all of its members again
// now. Call it when the phone moves to another network, because what was
// measured on the previous one no longer applies.
func AutoSelectNetworkChanged() {
	defer func() { _ = recover() }()
	autoselect.KickAll()
}

// AutoSelectPin sends the new connections of group to member. An empty member
// returns the group to automatic selection. It reports whether the group and
// the member exist.
func AutoSelectPin(group string, member string) (ok bool) {
	defer func() {
		if recover() != nil {
			ok = false
		}
	}()
	return autoselect.PinMember(group, member)
}
