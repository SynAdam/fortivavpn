package engine

import (
	"context"
	"errors"
	"net"
	"os"
	"regexp"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/link"
)

// Door checks, as Android's realPing and realPingDetail make them: the door
// alone in its own instance, one request through it, 3 seconds at most.
// Without the cap a TLS failure holds a check for about ten seconds, and the
// app checks up to twelve doors at once.
const (
	pingTimeout = 3 * time.Second
	// tcpTimeout is under the check's own cap, so the plain connection
	// that runs next to it never makes the check wait longer.
	tcpTimeout = 2500 * time.Millisecond
	// maxPingError keeps the end of the core's error, where it puts the
	// most specific cause.
	maxPingError = 120
)

// RealPing returns how long a request through the door took, in
// milliseconds, or -1 when it failed.
func (e *Engine) RealPing(ctx context.Context, raw string) int64 {
	ms, _ := e.ping(ctx, raw)
	return ms
}

// RealPingDetail is RealPing that says why a check failed: "ms" (or -1) and
// "elapsedMs" always; on a failure "error", and when the link names an
// address, "tcp" and "tcpMs": how a plain TCP connection to the same address
// went. When that fails too, the address is blocked on this network; when
// it connects, what was cut is the handshake after it (DoorCheck on
// Android).
func (e *Engine) RealPingDetail(ctx context.Context, raw string) map[string]any {
	started := time.Now()
	out := map[string]any{"ms": int64(-1)}
	defer func() { out["elapsedMs"] = time.Since(started).Milliseconds() }()

	l, err := link.Parse(raw)
	if err != nil {
		out["error"] = "link could not be read"
		return out
	}
	type reach struct {
		outcome string
		ms      int64
	}
	tcp := make(chan reach, 1)
	go func() {
		outcome, took := e.tcpReach(ctx, l.Address, l.Port)
		tcp <- reach{outcome, took.Milliseconds()}
	}()

	ms, err := e.ping(ctx, raw)
	out["ms"] = ms
	if ms < 0 {
		out["error"] = shorten(err)
		r := <-tcp
		out["tcp"], out["tcpMs"] = r.outcome, r.ms
	}
	return out
}

func (e *Engine) ping(ctx context.Context, raw string) (int64, error) {
	cfg, err := config.Ping(raw)
	if err != nil {
		return -1, err
	}
	ctx, cancel := context.WithTimeout(ctx, pingTimeout)
	defer cancel()
	inst, err := startInstance(cfg)
	if err != nil {
		return -1, err
	}
	defer inst.Close()
	took, err := probe(ctx, inst, e.opts.PingURL, pingTimeout)
	if err != nil {
		if ctx.Err() != nil {
			return -1, errors.New("no answer in 3000 ms")
		}
		return -1, err
	}
	return took.Milliseconds(), nil
}

// tcpReach opens a plain TCP connection to the door's address and closes it
// at once. While a tunnel is up it is bound to the physical network like
// the core's own connections, so it says what that network does.
func (e *Engine) tcpReach(ctx context.Context, host string, port int) (string, time.Duration) {
	dialer := net.Dialer{Timeout: tcpTimeout}
	if e.opts.Binder != nil {
		dialer.Control = e.opts.Binder.Control
	}
	started := time.Now()
	conn, err := dialer.DialContext(ctx, "tcp", net.JoinHostPort(host, strconv.Itoa(port)))
	took := time.Since(started)
	if err != nil {
		return tcpOutcome(err), took
	}
	_ = conn.Close()
	return "ok", took
}

// Windows' socket errors. syscall's ECONNREFUSED and friends are made-up
// numbers there, so a refused connection does not match them.
const (
	wsaENETUNREACH  syscall.Errno = 10051
	wsaECONNRESET   syscall.Errno = 10054
	wsaETIMEDOUT    syscall.Errno = 10060
	wsaECONNREFUSED syscall.Errno = 10061
	wsaEHOSTUNREACH syscall.Errno = 10065
)

// tcpOutcome is one word for a failed connect: timeout (nothing came back,
// which is what a dropped address looks like), refused, reset, unreachable,
// dns, or error.
func tcpOutcome(err error) string {
	var dnsErr *net.DNSError
	if errors.As(err, &dnsErr) {
		return "dns"
	}
	var errno syscall.Errno
	if errors.As(err, &errno) {
		switch errno {
		case syscall.ECONNREFUSED, wsaECONNREFUSED:
			return "refused"
		case syscall.ECONNRESET, wsaECONNRESET:
			return "reset"
		case syscall.ENETUNREACH, syscall.EHOSTUNREACH, wsaENETUNREACH, wsaEHOSTUNREACH:
			return "unreachable"
		case syscall.ETIMEDOUT, wsaETIMEDOUT:
			return "timeout"
		}
	}
	var netErr net.Error
	if errors.As(err, &netErr) && netErr.Timeout() || errors.Is(err, os.ErrDeadlineExceeded) || errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	return "error"
}

var spaces = regexp.MustCompile(`\s+`)

// shorten puts the core's error on one line and keeps its last
// maxPingError characters.
func shorten(err error) string {
	if err == nil {
		return ""
	}
	flat := strings.TrimSpace(spaces.ReplaceAllString(err.Error(), " "))
	if len(flat) <= maxPingError {
		return flat
	}
	return "..." + flat[len(flat)-(maxPingError-3):]
}
