// Package control is how the Fortiva app drives the tunnel service.
//
// The app runs as the signed-in user and the tunnel runs as a Windows
// service, because creating a Wintun adapter and changing the routing table
// need administrator rights and the app should not ask for them every time it
// starts. The two talk over a named pipe (a Unix socket on the development
// platforms), and every connection carries exactly one call: one line of JSON
// in, one line of JSON out, then the server closes it. Neither side needs
// framing beyond the newline, and an app that dies mid-call leaves nothing
// half-read behind.
//
// Everything the app sends is data the service checks and turns into a
// configuration itself. The service never accepts a ready-made Xray
// configuration, a file path or a command line: it runs as SYSTEM, and any
// local program can reach the pipe, so one would be a way to write files or
// open listeners with the service's rights.
package control

import (
	"encoding/json"
	"fmt"
)

// ProtocolVersion is bumped when a call changes in a way an older app cannot
// read. The app asks for it with "hello" and refuses to drive a service that
// does not match, which is what an update that replaced only one of the two
// executables would otherwise turn into: calls that fail in odd ways.
const ProtocolVersion = 1

// MaxRequestBytes bounds one request line. The largest real request is a
// connect with every door of every server, which is a few kilobytes.
const MaxRequestBytes = 1 << 20

// Request is one call from the app.
type Request struct {
	V      int             `json:"v"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params,omitempty"`
}

// Response is the service's answer to one Request.
type Response struct {
	OK     bool   `json:"ok"`
	Result any    `json:"result,omitempty"`
	Error  *Error `json:"error,omitempty"`
}

// Error is a failure the app can act on: Code is stable and machine-read,
// Message is for logs and is never shown to the user as is.
type Error struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

// Errorf returns an *Error with the given code.
func Errorf(code, format string, args ...any) *Error {
	return &Error{Code: code, Message: fmt.Sprintf(format, args...)}
}

// Error codes shared with the app (lib/services/windows_tunnel.dart).
const (
	CodeBadRequest     = "BAD_REQUEST"     // the request could not be read
	CodeUnknownMethod  = "UNKNOWN_METHOD"  // the service does not have this call
	CodeVersion        = "VERSION"         // the app and the service speak different protocols
	CodeInvalidLink    = "INVALID_LINK"    // a link could not be turned into an outbound
	CodeStartFailed    = "START_FAILED"    // the core refused the configuration or the adapter did not come up
	CodeNotConnected   = "NOT_CONNECTED"   // the call needs a running tunnel
	CodeTimeout        = "TIMEOUT"         // the call ran out of time
	CodeInternal       = "INTERNAL"        // a bug; the message says where
	CodeNotImplemented = "NOT_IMPLEMENTED" // known call, not built yet
)
