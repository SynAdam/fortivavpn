//go:build !windows

package engine

// NewBinder returns nil away from Windows, where the core runs without a
// TUN adapter and so has nothing to keep off it.
func NewBinder(func()) (Binder, error) { return nil, nil }
