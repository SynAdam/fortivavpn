package fortivacore

// A door check that says how far it got (backend issue #365, item 1).
//
// libv2ray's MeasureOutboundDelay returns one number or one error. A check
// that failed therefore reads the same whether the door's address never
// answered, the handshake was cut, or our server replied and the traffic
// stalled. CheckDoorTimed runs the same check and also records what happened
// on the sockets the check opened to the door: how long the name lookup and
// the TCP connect took, when the first byte came back, when the TLS or
// REALITY handshake was done, how many bytes went each way, and when the
// probe's HTTP reply began.
//
// The sockets are seen through a system dialer that wraps xray's own. It is
// installed once, by PrepareDoorChecks, in the app's main process, where door
// checks run. The tunnel runs in another process and never sees it. A dial
// that belongs to no running check goes straight through, unchanged.
//
// Nothing here leaves the phone with an address in it: the result holds
// times, counts and one word, and the error text has every IP address cut out.

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptrace"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	xctx "github.com/xtls/xray-core/common/ctx"
	xnet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/serial"
	"github.com/xtls/xray-core/common/session"
	core "github.com/xtls/xray-core/core"
	coreserial "github.com/xtls/xray-core/infra/conf/serial"
	"github.com/xtls/xray-core/transport/internet"
)

// The check's two requests, as libv2ray makes them: the first opens the
// tunnel, the second normally rides the same connection.
const doorAttempts = 2

// The wait the app uses when it sends none (handler/TestLink.kt).
const defaultDoorTimeoutMs = 3000

// Session ids handed to checks start here, far from the small counters and
// random ids xray uses for its own sessions, so a lookup cannot hit one.
const firstDoorID uint32 = 0xFD000000

var (
	prepareOnce sync.Once
	nextDoorID  atomic.Uint32
	doorTraces  sync.Map // xctx.ID -> *doorTrace

	// Set only by tests, so the probe trusts a local test server's
	// certificate. Nil in the app: the probe checks certificates as before.
	probeTLS *tls.Config

	// Set only by tests. core.New writes two xray package globals on every
	// call (internet.InitSystemDialer), a race that checks running at once
	// have always had through MeasureOutboundDelay too. Starting cores one at
	// a time on the phone would spend the check's wait, so only the race
	// detector's runs take this lock.
	coreNewLock sync.Locker
)

// PrepareDoorChecks installs the dialer that lets CheckDoorTimed see its
// sockets. Call it once, early, in the process that runs door checks, before
// any check starts: swapping xray's system dialer is not safe while another
// check is dialling. Later calls do nothing.
func PrepareDoorChecks() {
	defer func() { _ = recover() }()
	prepareOnce.Do(func() {
		nextDoorID.Store(firstDoorID)
		internet.UseAlternativeSystemDialer(&tracingDialer{inner: &internet.DefaultSystemDialer{}})
	})
}

// doorResult is what CheckDoorTimed returns, as JSON. Times are milliseconds.
// first_byte_ms and reply_ms count from the moment the first request was
// sent, after the core started. A field the check never reached is left out.
type doorResult struct {
	// The fastest request that got its reply, as libv2ray reports it, or -1.
	Ms int64 `json:"ms"`
	// Loading the config and starting the core, inside the same wait.
	BootMs int64 `json:"boot_ms"`
	// The first request alone, when it got its reply: the cold open.
	ColdMs *int64 `json:"cold_ms,omitempty"`
	// The first lookup of the door's name that succeeded, for a door the
	// link names by host. A door dialled at an address has none.
	DnsMs *int64 `json:"dns_ms,omitempty"`
	// The first TCP connect to the door that succeeded.
	DialMs *int64 `json:"dial_ms,omitempty"`
	// The first byte that came back on any socket to the door: for TLS and
	// REALITY, the server's first handshake flight.
	FirstByteMs *int64 `json:"first_byte_ms,omitempty"`
	// When the first TLS or REALITY handshake on a socket to the door was
	// done: the phone's first write after the server's first bytes, on a
	// socket whose first write was a TLS ClientHello (see countedConn). In
	// TLS 1.3, which REALITY and today's TLS doors speak, that write is the
	// phone's Finished. A door with no TLS has none.
	TlsMs *int64 `json:"tls_ms,omitempty"`
	// The first byte of the probe's HTTP reply, through the tunnel.
	ReplyMs  *int64 `json:"reply_ms,omitempty"`
	BytesOut int64  `json:"bytes_out"`
	BytesIn  int64  `json:"bytes_in"`
	// TCP connects to the door, and how many of them failed or were still
	// waiting when the check ended. A transport that keeps a pooled connection
	// may open none.
	Dials     int `json:"dials"`
	DialFails int `json:"dial_fails"`
	// How far it got: ok, tcp (no connect), tls (connected, the handshake was
	// not answered or failed), proxy (the handshake was answered, no reply
	// came), late (a reply came but the check ran out of time). Empty when it
	// never dialled.
	Phase string `json:"phase,omitempty"`
	Error string `json:"error,omitempty"`
}

// CheckDoorTimed runs the door check MeasureOutboundDelay runs, on the same
// config, and reports how far it got. It counts as open only when both
// requests are done within timeoutMs and one of them got its reply, which is
// what the app's wait around MeasureOutboundDelay accepts today, so a door
// reads open or closed exactly as before.
func CheckDoorTimed(config string, url string, timeoutMs int64) (out string) {
	defer func() {
		if r := recover(); r != nil {
			out = encodeDoorResult(doorResult{Ms: -1, Error: scrubAddresses(fmt.Sprint("panic: ", r))})
		}
	}()
	if timeoutMs <= 0 {
		timeoutMs = defaultDoorTimeoutMs
	}
	if url == "" {
		url = "https://www.google.com/generate_204"
	}
	began := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()

	result := doorResult{Ms: -1}
	inst, err := startCheckCore(config)
	result.BootMs = time.Since(began).Milliseconds()
	if err != nil {
		result.Error = scrubAddresses(err.Error())
		return encodeDoorResult(result)
	}
	defer inst.Close()

	trace := &doorTrace{}
	id := xctx.ID(nextDoorID.Add(1))
	doorTraces.Store(id, trace)
	defer doorTraces.Delete(id)
	// The dial context carries the check's id down to the system dialer (every
	// transport passes it on, gRPC included) and collects the outbound's own
	// error, which says more than the HTTP client's "EOF". It is kept apart
	// from the request's context, so the probe's trace does not fire for the
	// transport's own requests to the door.
	dialCtx := session.TrackedConnectionError(xctx.ContextWithID(ctx, id), trace)

	transport := &http.Transport{
		TLSClientConfig:     probeTLS,
		TLSHandshakeTimeout: 6 * time.Second,
		DisableKeepAlives:   false,
		DialContext: func(_ context.Context, network, addr string) (net.Conn, error) {
			dest, err := xnet.ParseDestination(network + ":" + addr)
			if err != nil {
				return nil, err
			}
			return core.Dial(dialCtx, inst, dest)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 12 * time.Second}

	trace.begin(time.Now())
	var (
		best     int64 = -1
		lastErr  error
		finished int
		reply    time.Time
	)
	for i := 0; i < doorAttempts && ctx.Err() == nil; i++ {
		// Set from the transport's own goroutine, which can still be running
		// after a cancelled request has returned.
		var replyNanos atomic.Int64
		reqCtx := httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{
			GotFirstResponseByte: func() { replyNanos.CompareAndSwap(0, time.Now().UnixNano()) },
		})
		req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, url, nil)
		if err != nil {
			lastErr = err
			finished++
			continue
		}
		start := time.Now()
		resp, err := client.Do(req)
		if err == nil {
			_, err = io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
				err = fmt.Errorf("invalid status: %s", resp.Status)
			}
		}
		if at := replyNanos.Load(); reply.IsZero() && at != 0 {
			reply = time.Unix(0, at)
		}
		if ctx.Err() != nil {
			// The wait ran out during this request, so it does not count,
			// as the app would not have heard of it.
			break
		}
		finished++
		if err != nil {
			lastErr = err
			continue
		}
		took := time.Since(start).Milliseconds()
		if i == 0 {
			result.ColdMs = &took
		}
		if best < 0 || took < best {
			best = took
		}
	}

	failed := trace.fill(&result, reply)
	switch {
	case finished < doorAttempts:
		// What the app says when its own wait runs out (MainActivity).
		result.Error = fmt.Sprintf("no answer in %d ms", timeoutMs)
		if result.ReplyMs != nil {
			result.Phase = "late"
		}
	case best >= 0:
		result.Ms = best
		result.Phase = "ok"
	default:
		result.Error = describeFailure(lastErr, trace.outboundError())
	}
	if result.Ms < 0 && result.Phase == "" {
		result.Phase = failed
	}
	return encodeDoorResult(result)
}

// startCheckCore loads config the way MeasureOutboundDelay does: no inbounds,
// and only the apps a check needs.
func startCheckCore(config string) (*core.Instance, error) {
	parsed, err := coreserial.LoadJSONConfig(strings.NewReader(config))
	if err != nil {
		return nil, fmt.Errorf("config load error: %w", err)
	}
	parsed.Inbound = nil
	var keep []*serial.TypedMessage
	for _, app := range parsed.App {
		if app.Type == "xray.app.proxyman.OutboundConfig" ||
			app.Type == "xray.app.dispatcher.Config" ||
			app.Type == "xray.app.log.Config" {
			keep = append(keep, app)
		}
	}
	parsed.App = keep
	if coreNewLock != nil {
		coreNewLock.Lock()
		defer coreNewLock.Unlock()
	}
	inst, err := core.New(parsed)
	if err != nil {
		return nil, fmt.Errorf("instance creation failed: %w", err)
	}
	if err := inst.Start(); err != nil {
		inst.Close()
		return nil, fmt.Errorf("startup failed: %w", err)
	}
	return inst, nil
}

// doorTrace is what one check's sockets did. Sockets are read and written
// from several goroutines, so every field is guarded.
type doorTrace struct {
	mu        sync.Mutex
	start     time.Time
	dials     int
	connected int
	dnsMs     int64
	dialMs    int64
	firstByte time.Time
	handshook time.Time
	outbound  error

	bytesOut atomic.Int64
	bytesIn  atomic.Int64
}

func (t *doorTrace) begin(at time.Time) {
	t.mu.Lock()
	t.start = at
	t.dnsMs = -1
	t.dialMs = -1
	t.mu.Unlock()
}

// resolved keeps the first lookup of the door's name that worked.
func (t *doorTrace) resolved(took time.Duration, err error) {
	if err != nil {
		return
	}
	t.mu.Lock()
	if t.dnsMs < 0 {
		t.dnsMs = took.Milliseconds()
	}
	t.mu.Unlock()
}

// handshakeDone keeps the first TLS or REALITY handshake that was done.
func (t *doorTrace) handshakeDone(at time.Time) {
	t.mu.Lock()
	if t.handshook.IsZero() || at.Before(t.handshook) {
		t.handshook = at
	}
	t.mu.Unlock()
}

// dialing counts a TCP connect when it starts. A connect still waiting when
// the check's wait ends (a dropped SYN, the commonest block) is then counted
// as one that failed, not as none at all.
func (t *doorTrace) dialing() {
	t.mu.Lock()
	t.dials++
	t.mu.Unlock()
}

func (t *doorTrace) dialed(took time.Duration, err error) {
	if err != nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.connected++
	if t.dialMs < 0 {
		t.dialMs = took.Milliseconds()
	}
}

func (t *doorTrace) read(n int) {
	t.bytesIn.Add(int64(n))
	t.mu.Lock()
	if t.firstByte.IsZero() {
		t.firstByte = time.Now()
	}
	t.mu.Unlock()
}

// SubmitError receives the outbound's error (session.TrackedConnectionError).
func (t *doorTrace) SubmitError(err error) {
	if err == nil {
		return
	}
	t.mu.Lock()
	t.outbound = err
	t.mu.Unlock()
}

func (t *doorTrace) outboundError() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.outbound
}

// fill copies the trace into r and returns how far a failed check got,
// both from one look at the trace: a connect that starts in between cannot
// give a row that reads "tcp" with no connect counted.
func (t *doorTrace) fill(r *doorResult, reply time.Time) (failedPhase string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	r.Dials = t.dials
	r.DialFails = t.dials - t.connected
	if t.dnsMs >= 0 {
		ms := t.dnsMs
		r.DnsMs = &ms
	}
	if t.dialMs >= 0 {
		ms := t.dialMs
		r.DialMs = &ms
	}
	if !t.handshook.IsZero() && !t.start.IsZero() {
		ms := t.handshook.Sub(t.start).Milliseconds()
		r.TlsMs = &ms
	}
	if !t.firstByte.IsZero() && !t.start.IsZero() {
		ms := t.firstByte.Sub(t.start).Milliseconds()
		r.FirstByteMs = &ms
	}
	if !reply.IsZero() && !t.start.IsZero() {
		ms := reply.Sub(t.start).Milliseconds()
		r.ReplyMs = &ms
	}
	r.BytesOut = t.bytesOut.Load()
	r.BytesIn = t.bytesIn.Load()
	return t.phaseLocked(r.ReplyMs != nil, r.BytesIn)
}

// handshakeWords are what xray and Go put in an error that came from the
// TLS or REALITY handshake.
var handshakeWords = regexp.MustCompile(`(?i)\btls:|handshake|x509|certificate|reality`)

// phaseLocked is how far a failed check got, from what its sockets saw.
// The caller holds t.mu.
func (t *doorTrace) phaseLocked(replied bool, bytesIn int64) string {
	switch {
	case t.dials == 0:
		return ""
	case t.connected == 0:
		return "tcp"
	case replied:
		return "proxy"
	case !t.handshook.IsZero():
		// The handshake was done, so what failed came after it.
		return "proxy"
	case bytesIn == 0:
		return "tls"
	case t.outbound != nil && handshakeWords.MatchString(t.outbound.Error()):
		return "tls"
	default:
		return "proxy"
	}
}

// describeFailure is the HTTP client's error, as the app has always shown,
// with the outbound's own error after it: the app keeps the end of the text.
func describeFailure(httpErr, outbound error) string {
	text := ""
	if httpErr != nil {
		text = httpErr.Error()
	}
	if outbound != nil && !errors.Is(httpErr, outbound) {
		cause := outbound.Error()
		if text == "" {
			text = cause
		} else if !strings.Contains(text, cause) {
			text += "; " + cause
		}
	}
	if text == "" {
		text = "no reply"
	}
	return scrubAddresses(text)
}

// tracingDialer is xray's system dialer with the sockets of a running check
// counted. Every other dial goes to the inner dialer untouched.
type tracingDialer struct {
	inner internet.SystemDialer
}

func (d *tracingDialer) Dial(ctx context.Context, src xnet.Address, dest xnet.Destination, sockopt *internet.SocketConfig) (net.Conn, error) {
	trace := traceOf(ctx)
	if trace == nil || dest.Network != xnet.Network_TCP {
		return d.inner.Dial(ctx, src, dest, sockopt)
	}
	if dest.Address != nil && dest.Address.Family().IsDomain() {
		// The door is named by host: how long the system resolver takes for
		// it, looked up once here. The dial below looks it up again, which
		// the resolver's cache answers, so the connect itself is unchanged.
		looked := time.Now()
		_, lookErr := net.DefaultResolver.LookupIPAddr(ctx, dest.Address.Domain())
		trace.resolved(time.Since(looked), lookErr)
	}
	trace.dialing()
	began := time.Now()
	conn, err := d.inner.Dial(ctx, src, dest, sockopt)
	trace.dialed(time.Since(began), err)
	if err != nil {
		return nil, err
	}
	return &countedConn{Conn: conn, trace: trace}, nil
}

func (d *tracingDialer) DestIpAddress() net.IP {
	return d.inner.DestIpAddress()
}

func traceOf(ctx context.Context) *doorTrace {
	id := xctx.IDFromContext(ctx)
	if uint32(id) < firstDoorID {
		return nil
	}
	if t, ok := doorTraces.Load(id); ok {
		return t.(*doorTrace)
	}
	return nil
}

// countedConn passes every read and write through as it is, one call for one
// call, so a split ClientHello leaves the phone exactly as it would unwrapped.
//
// It also sees when a TLS or REALITY handshake on the socket is done. The
// phone speaks first: a socket whose first write starts with a TLS handshake
// record (looksLikeClientHello) carries TLS, REALITY included. The server
// then sends its whole flight, and the phone writes nothing until it has it,
// so the phone's first write after the server's first bytes ends the
// handshake on its side: the Finished message in TLS 1.3. In TLS 1.2 it is
// the key exchange, one round trip before the end. A socket whose first
// write is anything else carries no TLS and says nothing.
type countedConn struct {
	net.Conn
	trace *doorTrace
	tls   atomic.Int32 // one of the tls* states below
}

const (
	tlsUnknown  int32 = iota // nothing written yet
	tlsSent                  // a ClientHello went out, nothing came back yet
	tlsAnswered              // the server's first bytes came back
	tlsSettled               // the handshake was done, or the socket has no TLS
)

func (c *countedConn) Read(b []byte) (int, error) {
	n, err := c.Conn.Read(b)
	if n > 0 {
		c.trace.read(n)
		c.tls.CompareAndSwap(tlsSent, tlsAnswered)
	}
	return n, err
}

func (c *countedConn) Write(b []byte) (int, error) {
	if c.tls.Load() == tlsUnknown {
		if looksLikeClientHello(b) {
			c.tls.CompareAndSwap(tlsUnknown, tlsSent)
		} else {
			c.tls.CompareAndSwap(tlsUnknown, tlsSettled)
		}
	}
	answered := c.tls.Load() == tlsAnswered
	n, err := c.Conn.Write(b)
	if n > 0 {
		c.trace.bytesOut.Add(int64(n))
		if answered && c.tls.CompareAndSwap(tlsAnswered, tlsSettled) {
			c.trace.handshakeDone(time.Now())
		}
	}
	return n, err
}

// looksLikeClientHello says whether b starts a TLS handshake record: content
// type 22 and a TLS major version of 3. A split ClientHello starts the same
// way, since each piece is a record of its own or the first piece holds the
// record's start.
func looksLikeClientHello(b []byte) bool {
	return len(b) >= 3 && b[0] == 0x16 && b[1] == 0x03 && b[2] <= 0x04
}

// CloseWrite keeps the half close of the TCP socket underneath.
func (c *countedConn) CloseWrite() error {
	if cw, ok := c.Conn.(interface{ CloseWrite() error }); ok {
		return cw.CloseWrite()
	}
	return nil
}

func encodeDoorResult(r doorResult) string {
	b, err := json.Marshal(r)
	if err != nil {
		return `{"ms":-1,"boot_ms":0,"bytes_out":0,"bytes_in":0,"dials":0,"dial_fails":0}`
	}
	return string(b)
}

var (
	ipv4Text = regexp.MustCompile(`\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?`)
	ipv6Text = regexp.MustCompile(`\[?[0-9A-Fa-f]{0,4}(?::[0-9A-Fa-f]{0,4}){2,7}(?:%[0-9A-Za-z]+)?\]?(?::\d{1,5})?`)
)

// scrubAddresses cuts every IP address out of an error. A socket error names
// the phone's own address next to the server's ("read tcp A->B: ..."), and
// the phone's address must never leave it.
func scrubAddresses(text string) string {
	text = ipv4Text.ReplaceAllStringFunc(text, func(m string) string {
		host := m
		if h, _, err := net.SplitHostPort(m); err == nil {
			host = h
		}
		if net.ParseIP(host) != nil {
			return "<addr>"
		}
		return m
	})
	return ipv6Text.ReplaceAllStringFunc(text, func(m string) string {
		host := strings.Trim(m, "[]")
		if h, _, err := net.SplitHostPort(m); err == nil {
			host = h
		}
		if i := strings.IndexByte(host, '%'); i >= 0 {
			host = host[:i]
		}
		if strings.Count(host, ":") >= 2 && net.ParseIP(host) != nil {
			return "<addr>"
		}
		return m
	})
}
