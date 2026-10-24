//go:build !windows

// Package service runs fortiva-core under the Windows service manager. On the
// platforms the core is developed on there is no service; "fortiva-core run"
// serves the same control socket from a terminal.
package service

import (
	"context"
	"errors"
)

const Name = "FortivaTunnel"

var errWindowsOnly = errors.New("the service exists only on Windows; use \"fortiva-core run\"")

func IsService() bool { return false }

func Run(func(ctx context.Context) error) error { return errWindowsOnly }

func Install(string) error { return errWindowsOnly }

func Stop() error { return errWindowsOnly }

func Uninstall() error { return errWindowsOnly }
