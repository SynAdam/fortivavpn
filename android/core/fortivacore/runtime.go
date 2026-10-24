package fortivacore

// Putting the Go runtime back after Psiphon (clients issue #299).
//
// Xray-core and Psiphon share one Go runtime in libgojni.so, and Psiphon
// changes two of its process-wide settings without putting them back:
//
//   - Psi.start calls psiphon.DoGarbageCollection before it reads its config,
//     and Psiphon calls it again while it runs (psiphon/utils.go,
//     controller.go, tactics.go, dataStore.go). It sets the GC percent to 5.
//     Go's default is 100.
//   - With LimitCPUThreads in its config, Psiphon's controller sets GOMAXPROCS
//     to 1 for the whole process (psiphon/controller.go, Controller.Run).
//
// Psi.stop resets neither. Without RestoreRuntime, every later Xray session in
// the same process would run with them: a garbage collection after every 5%
// of heap growth, and one thread for Go code, on the path that carries all of
// the tunnel's traffic.

import (
	"runtime"
	"runtime/debug"
)

// The GC percent this process started with: 100, unless GOGC set another.
var startGCPercent = currentGCPercent()

// currentGCPercent reads the GC percent. Go can only read it by setting it, so
// it sets a value and puts the old one straight back.
func currentGCPercent() int {
	p := debug.SetGCPercent(-1)
	debug.SetGCPercent(p)
	return p
}

// RestoreRuntime puts the GC percent back to the value this process started
// with, and GOMAXPROCS back to Go's default. Call it on every path that ends a
// Psiphon session, after Psi.stop has returned, and also after a Psi.start
// that threw, because Psi.start changes the GC percent before it can fail.
// Calling it while Psiphon runs does no harm, but Psiphon soon sets the GC
// percent again.
func RestoreRuntime() {
	defer func() { _ = recover() }()
	runtime.SetDefaultGOMAXPROCS()
	debug.SetGCPercent(startGCPercent)
}
