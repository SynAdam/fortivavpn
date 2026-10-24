package fortivacore

import (
	"os"
	"runtime"
	"runtime/debug"
	"testing"
)

func TestStartGCPercentIsGoDefault(t *testing.T) {
	if os.Getenv("GOGC") != "" {
		t.Skip("GOGC is set, so the start value is not Go's default")
	}
	if startGCPercent != 100 {
		t.Fatalf("startGCPercent = %d, want Go's default 100", startGCPercent)
	}
	if got := currentGCPercent(); got != 100 {
		t.Fatalf("currentGCPercent() = %d, want 100", got)
	}
}

func TestRestoreRuntimeUndoesPsiphon(t *testing.T) {
	procs := runtime.GOMAXPROCS(0)
	t.Cleanup(func() {
		runtime.GOMAXPROCS(procs)
		debug.SetGCPercent(startGCPercent)
	})

	// What psiphon.DoGarbageCollection and LimitCPUThreads do.
	debug.SetGCPercent(5)
	runtime.GOMAXPROCS(1)

	RestoreRuntime()

	if got := currentGCPercent(); got != startGCPercent {
		t.Errorf("GC percent after RestoreRuntime = %d, want %d", got, startGCPercent)
	}
	if os.Getenv("GOMAXPROCS") != "" || procs == 1 {
		t.Logf("GOMAXPROCS part not checked: env %q, start value %d", os.Getenv("GOMAXPROCS"), procs)
		return
	}
	if got := runtime.GOMAXPROCS(0); got != procs {
		t.Errorf("GOMAXPROCS after RestoreRuntime = %d, want the default %d", got, procs)
	}
}

func TestRestoreRuntimeTwiceIsHarmless(t *testing.T) {
	RestoreRuntime()
	RestoreRuntime()
	if got := currentGCPercent(); got != startGCPercent {
		t.Errorf("GC percent = %d, want %d", got, startGCPercent)
	}
}
