//go:build tools

// Package tools pins the code-generation toolchain in this module's
// dependency graph so `gomobile` is resolved from go.sum like any other
// dependency, instead of whatever happens to be on the builder's PATH.
//
// It also keeps the packages build.sh binds in the graph, so `go mod tidy`
// does not drop them: AndroidLibXrayLite, and Psiphon's MobileLibrary/psi.
package tools

import (
	_ "github.com/2dust/AndroidLibXrayLite"
	_ "github.com/Psiphon-Labs/psiphon-tunnel-core/MobileLibrary/psi"
	_ "golang.org/x/mobile/cmd/gomobile"
)
