//go:build darwin

package main

import (
	"context"
	"os"
	"syscall"
	"time"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
)

// replacedEvery is how often the daemon looks at its own executable.
const replacedEvery = 10 * time.Second

// watchReplaced ends the daemon, by cancelling serve's context, once its
// executable on disk is not the one it started from and no tunnel is up.
// An update replaces the whole app, and launchd would keep running the old
// core until the Mac restarts; ending it lets launchd start the new one at
// once, as the Windows installer restarts its service. A tunnel that is up
// is not taken down for it: the daemon waits until it is down.
func watchReplaced(ctx context.Context, stop context.CancelFunc, eng *engine.Engine, logf func(string, ...any)) {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	idle := func() bool {
		switch eng.Status().State {
		case engine.Disconnected, engine.Failed:
			return true
		}
		return false
	}
	if watchFile(ctx, exe, replacedEvery, idle) {
		logf("[core] %s was replaced; ending so launchd starts the new one", exe)
		stop()
	}
}

// watchFile reports true once the file at path is not the one that was
// there when it started and idle says so, and false when ctx ends first.
func watchFile(ctx context.Context, path string, every time.Duration, idle func() bool) bool {
	started, ok := fileID(path)
	if !ok {
		return false
	}
	t := time.NewTicker(every)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return false
		case <-t.C:
		}
		if now, ok := fileID(path); ok && now == started {
			continue
		}
		if idle() {
			return true
		}
	}
}

type fileIdentity struct {
	dev, ino uint64
	size     int64
	mtime    int64
}

// fileID is what tells one file at path from another: a new copy of the app
// has new inodes even where its bytes are the same. Not ok when there is no
// file there, which is what the moment between removing the old app and
// copying the new one looks like.
func fileID(path string) (fileIdentity, bool) {
	fi, err := os.Stat(path)
	if err != nil {
		return fileIdentity{}, false
	}
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return fileIdentity{}, false
	}
	return fileIdentity{dev: uint64(st.Dev), ino: st.Ino, size: fi.Size(), mtime: fi.ModTime().UnixNano()}, true
}
