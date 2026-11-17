//go:build darwin

package main

import (
	"context"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"
)

// An update copies a new app over the old one: the daemon's executable is
// then another file, though it may hold the same bytes.
func TestWatchFileSeesAReplacedExecutableOnceIdle(t *testing.T) {
	dir := t.TempDir()
	exe := filepath.Join(dir, "fortiva-core")
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}
	var tunnelUp atomic.Bool
	tunnelUp.Store(true)
	done := make(chan bool, 1)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	go func() { done <- watchFile(ctx, exe, 20*time.Millisecond, func() bool { return !tunnelUp.Load() }) }()

	// The same bytes in a new file, as ditto or a drag to Applications does,
	// once the watch has read the old one.
	time.Sleep(60 * time.Millisecond)
	if err := os.Remove(exe); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exe, []byte("old"), 0o755); err != nil {
		t.Fatal(err)
	}
	select {
	case <-done:
		t.Fatal("ended with the tunnel up")
	case <-time.After(150 * time.Millisecond):
	}
	tunnelUp.Store(false)
	select {
	case replaced := <-done:
		if !replaced {
			t.Fatal("did not see the new file")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("did not end once the tunnel was down")
	}
}

func TestWatchFileKeepsGoingWhileTheFileIsTheSame(t *testing.T) {
	exe := filepath.Join(t.TempDir(), "fortiva-core")
	if err := os.WriteFile(exe, []byte("core"), 0o755); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 150*time.Millisecond)
	defer cancel()
	if watchFile(ctx, exe, 20*time.Millisecond, func() bool { return true }) {
		t.Fatal("ended though nothing replaced the file")
	}
}
