//go:build darwin

// Package service runs fortiva-core under the system's service manager. On
// macOS that is launchd: the app registers the daemon its bundle carries
// (macos/Runner/LaunchDaemons) with SMAppService, the person allows it once
// in System Settings, and launchd starts "fortiva-core service" as root and
// keeps it running.
package service

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"syscall"
)

// Name is the daemon's launchd label, the name of the property list the
// app carries in Contents/Library/LaunchDaemons.
const Name = "com.vpn.fortivavpn.tunnel"

var errAppManaged = errors.New("the Fortiva app adds and removes the daemon on macOS (SMAppService); use \"fortiva-core run\" to try the core by hand")

// IsService reports whether launchd started the process.
func IsService() bool { return os.Getppid() == 1 }

// Run runs fn until launchd stops the daemon, which it does with SIGTERM.
func Run(fn func(ctx context.Context) error) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	return fn(ctx)
}

func Install(string) error { return errAppManaged }

func Stop() error { return errAppManaged }

func Uninstall() error { return errAppManaged }
