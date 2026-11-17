//go:build !darwin

package main

import (
	"context"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
)

// watchReplaced does nothing away from macOS: the Windows installer stops
// and starts the service itself, and the router's package restarts the
// program.
func watchReplaced(context.Context, context.CancelFunc, *engine.Engine, func(string, ...any)) {}
