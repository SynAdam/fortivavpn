// Package psiphonquic holds the test for patches/psiphon-quic-go/. Nothing
// here is bound into the .aar.
//
// The patch moves the http3 package of Psiphon's quic-go fork from the
// quic-go/qpack v0.4 decoder to v0.6. The fork's own http3 tests still use the
// v0.4 API and do not compile, so this package checks the patched code from
// outside, through the fork's public API: one HTTP/3 request on 127.0.0.1,
// with headers and a trailer, decoded by every changed call.
//
// Run it with: ./stage-xray.sh && ./stage-psiphon.sh && go test -race ./psiphonquic/
package psiphonquic
