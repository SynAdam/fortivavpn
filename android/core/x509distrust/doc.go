// Package x509distrust holds only a test. Nothing here is bound into the
// .aar.
//
// In October 2026 the private keys of eight eMudhra intermediate CAs were
// found to be so small that anyone can recover them from the public
// certificates. Sectigo had cross-signed all eight under AAA Certificate
// Services, which the Android system store holds, so a Go that trusts them
// accepts a forged certificate for any name. go1.26.10 and go1.27.3 drop
// every chain that contains one of their keys (distrustedSPKIHashes in
// crypto/x509/verify.go, advisory GO-2026-6809). On Android, Xray's TLS,
// uTLS and Psiphon's TLS all verify with crypto/x509, so the toolchain in
// go.mod decides whether the core accepts these chains.
//
// The test needs no private key. It verifies each of the eight public
// cross-certificates against the AOSP copy of AAA Certificate Services. A
// Go without the fix accepts all eight; the toolchain go.mod pins must
// reject all eight.
//
// Run it with: CGO_ENABLED=0 go test ./x509distrust/
// It imports only the standard library, so it needs neither stage script.
package x509distrust
