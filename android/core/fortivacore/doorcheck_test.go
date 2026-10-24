package fortivacore

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	xctx "github.com/xtls/xray-core/common/ctx"
	xnet "github.com/xtls/xray-core/common/net"
	// Registers the outbounds and config loaders, as libv2ray does in the app.
	_ "github.com/xtls/xray-core/main/distro/all"
	"github.com/xtls/xray-core/transport/internet"
)

// A config with a direct outbound stands in for a door: the check's socket
// goes straight to the test server, through the same dialer a door's would.
const directConfig = `{"log":{"loglevel":"none"},"outbounds":[{"protocol":"freedom","tag":"proxy"}]}`

func TestMain(m *testing.M) {
	// xray's own race in core.New (see coreNewLock), kept out of the race
	// detector's way so it reports this package's races only.
	coreNewLock = &sync.Mutex{}
	m.Run()
}

func check(t *testing.T, url string, timeoutMs int64) doorResult {
	t.Helper()
	PrepareDoorChecks()
	var r doorResult
	out := CheckDoorTimed(directConfig, url, timeoutMs)
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatalf("result is not JSON: %v: %s", err, out)
	}
	return r
}

func noContent(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) }

// insecureProbe makes the check's probe trust server's test certificate for
// the rest of the test.
func insecureProbe(t *testing.T, server *httptest.Server) {
	t.Helper()
	probeTLS = server.Client().Transport.(*http.Transport).TLSClientConfig
	t.Cleanup(func() { probeTLS = nil })
}

func TestAnOpenDoorReportsItsWholeTimeline(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()

	r := check(t, server.URL+"/generate_204", 3000)

	if r.Ms < 0 || r.Phase != "ok" || r.Error != "" {
		t.Fatalf("want an open door, got %+v", r)
	}
	if r.ColdMs == nil || r.DialMs == nil || r.FirstByteMs == nil || r.ReplyMs == nil {
		t.Fatalf("a timeline field is missing: %+v", r)
	}
	if r.Dials < 1 || r.DialFails != 0 {
		t.Fatalf("want at least one good connect, got %d with %d failed", r.Dials, r.DialFails)
	}
	if r.BytesOut == 0 || r.BytesIn == 0 {
		t.Fatalf("want bytes both ways, got out %d in %d", r.BytesOut, r.BytesIn)
	}
	if *r.FirstByteMs > *r.ReplyMs+50 {
		t.Fatalf("the first byte came after the reply: %+v", r)
	}
}

func TestADoorDialledAtAnAddressWithNoTLSHasNoLookupOrHandshakeTime(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()

	r := check(t, server.URL+"/generate_204", 3000)

	if r.Phase != "ok" || r.DnsMs != nil || r.TlsMs != nil {
		t.Fatalf("want no dns_ms and no tls_ms on a plain door at an address, got %+v", r)
	}
}

func TestATLSDoorSaysWhenItsHandshakeWasDone(t *testing.T) {
	// The probe's own TLS goes straight through the direct outbound onto the
	// counted socket, as a door's TLS or REALITY does through its outbound.
	server := httptest.NewTLSServer(http.HandlerFunc(noContent))
	defer server.Close()
	insecureProbe(t, server)

	r := check(t, server.URL+"/generate_204", 3000)

	if r.Phase != "ok" || r.TlsMs == nil || r.FirstByteMs == nil || r.ReplyMs == nil {
		t.Fatalf("want an open TLS door with tls_ms, got %+v", r)
	}
	// The handshake ends after the server's first bytes and before the reply.
	if *r.TlsMs < *r.FirstByteMs || *r.TlsMs > *r.ReplyMs {
		t.Fatalf("tls_ms is out of order: first byte %d, tls %d, reply %d",
			*r.FirstByteMs, *r.TlsMs, *r.ReplyMs)
	}
}

func TestADoorNamedByHostSaysHowLongTheLookupTook(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()
	_, port, _ := net.SplitHostPort(server.Listener.Addr().String())

	r := check(t, "http://localhost:"+port+"/generate_204", 3000)

	if r.Phase != "ok" || r.DnsMs == nil || *r.DnsMs < 0 {
		t.Fatalf("want dns_ms for a door named by host, got %+v", r)
	}
}

func TestOnlyASocketThatStartsWithAClientHelloIsTakenForTLS(t *testing.T) {
	for _, tc := range []struct {
		name string
		b    []byte
		want bool
	}{
		{"TLS 1.0 record version (what a ClientHello carries)", []byte{0x16, 0x03, 0x01, 0x02, 0x00}, true},
		{"TLS 1.2 record version", []byte{0x16, 0x03, 0x03, 0x00, 0x10}, true},
		{"VLESS request", []byte{0x00, 0x8f, 0x3c, 0x11}, false},
		{"HTTP", []byte("GET / HTTP/1.1\r\n"), false},
		{"application data record", []byte{0x17, 0x03, 0x03, 0x00, 0x10}, false},
		{"too short", []byte{0x16, 0x03}, false},
	} {
		if got := looksLikeClientHello(tc.b); got != tc.want {
			t.Errorf("%s: looksLikeClientHello = %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestAClosedPortFailsAtTCP(t *testing.T) {
	// A port that was just free: nothing listens there now.
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := l.Addr().String()
	l.Close()

	r := check(t, "http://"+addr+"/generate_204", 3000)

	if r.Ms != -1 || r.Phase != "tcp" {
		t.Fatalf("want a tcp failure, got %+v", r)
	}
	if r.Dials == 0 || r.Dials != r.DialFails {
		t.Fatalf("want only failed connects, got %d with %d failed", r.Dials, r.DialFails)
	}
	if r.DialMs != nil || r.FirstByteMs != nil || r.ReplyMs != nil {
		t.Fatalf("a failed connect has no timeline: %+v", r)
	}
	if r.Error == "" || strings.Contains(r.Error, "127.0.0.1") {
		t.Fatalf("want an error without the address, got %q", r.Error)
	}
}

func TestADoorThatNeverAnswersFailsAtTheHandshakeWhenTheWaitRunsOut(t *testing.T) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	var held []net.Conn
	var mu sync.Mutex
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			mu.Lock()
			held = append(held, c) // accepted, never answered
			mu.Unlock()
		}
	}()
	defer func() {
		mu.Lock()
		for _, c := range held {
			c.Close()
		}
		mu.Unlock()
	}()

	began := time.Now()
	r := check(t, "http://"+l.Addr().String()+"/generate_204", 800)

	if took := time.Since(began); took > 2*time.Second {
		t.Fatalf("the check outlived its wait: %v", took)
	}
	if r.Ms != -1 || r.Error != "no answer in 800 ms" {
		t.Fatalf("want the app's own words for a wait that ran out, got %+v", r)
	}
	if r.Phase != "tls" || r.DialMs == nil || r.BytesOut == 0 || r.BytesIn != 0 {
		t.Fatalf("want connected, sent, nothing back: %+v", r)
	}
}

func TestAConnectStillWaitingWhenTheWaitEndsIsAFailedConnect(t *testing.T) {
	// 192.0.2.1 is TEST-NET-1: nothing answers there, so the SYN waits, as a
	// dropped SYN does on a blocked address.
	r := check(t, "http://192.0.2.1:9/generate_204", 800)

	if r.Ms != -1 || r.Phase != "tcp" {
		t.Fatalf("want a tcp failure for a connect that never finished, got %+v", r)
	}
	if r.Dials < 1 || r.DialFails != r.Dials || r.DialMs != nil {
		t.Fatalf("want every connect counted as failed, got %d with %d failed", r.Dials, r.DialFails)
	}
	if strings.Contains(r.Error, "192.0.2.1") {
		t.Fatalf("an address in the error: %q", r.Error)
	}
}

func TestAConnectStartedButNotFinishedCountsAsFailedInTheTrace(t *testing.T) {
	// The network test above races the dial's own timeout against the end
	// of the wait; this one holds the connect open for certain.
	var tr doorTrace
	tr.begin(time.Now())
	tr.dialing()
	var r doorResult
	failed := tr.fill(&r, time.Time{})
	if r.Dials != 1 || r.DialFails != 1 || r.DialMs != nil || failed != "tcp" {
		t.Fatalf("want one connect, failed, phase tcp: %+v, phase %q", r, failed)
	}
	// No connect at all says nothing of how far the check got.
	var none doorTrace
	none.begin(time.Now())
	if got := none.fill(&doorResult{}, time.Time{}); got != "" {
		t.Fatalf("want no phase with no connect, got %q", got)
	}
}

// blockingDialer holds every dial until release is closed, as a dropped
// SYN holds a connect.
type blockingDialer struct {
	started chan struct{}
	release chan struct{}
}

func (b *blockingDialer) Dial(ctx context.Context, src xnet.Address, dest xnet.Destination, sockopt *internet.SocketConfig) (net.Conn, error) {
	close(b.started)
	<-b.release
	return nil, errors.New("connect timed out")
}

func (b *blockingDialer) DestIpAddress() net.IP { return nil }

func TestTheDialerCountsAConnectWhenItStarts(t *testing.T) {
	var tr doorTrace
	tr.begin(time.Now())
	// An id no check in this run is given (they count up from firstDoorID).
	id := xctx.ID(firstDoorID + 0x00F00000)
	doorTraces.Store(id, &tr)
	defer doorTraces.Delete(id)
	inner := &blockingDialer{started: make(chan struct{}), release: make(chan struct{})}
	d := &tracingDialer{inner: inner}
	done := make(chan struct{})
	go func() {
		defer close(done)
		_, _ = d.Dial(xctx.ContextWithID(context.Background(), id), nil,
			xnet.TCPDestination(xnet.LocalHostIP, xnet.Port(443)), nil)
	}()
	<-inner.started
	// The wait ends while the connect is still out.
	var r doorResult
	failed := tr.fill(&r, time.Time{})
	close(inner.release)
	<-done
	if r.Dials != 1 || r.DialFails != 1 || r.DialMs != nil || failed != "tcp" {
		t.Fatalf("want one connect counted as failed, phase tcp: %+v, phase %q", r, failed)
	}
}

func TestAReplyThatIsNotTheProbesAnswerFailsAfterTheHandshake(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusForbidden)
	}))
	defer server.Close()

	r := check(t, server.URL+"/generate_204", 3000)

	if r.Ms != -1 || r.Phase != "proxy" || r.ReplyMs == nil {
		t.Fatalf("want a reply that failed the check, got %+v", r)
	}
	if !strings.Contains(r.Error, "invalid status") {
		t.Fatalf("want the status in the error, got %q", r.Error)
	}
}

func TestASlowSecondRequestReadsClosedAsTheAppsWaitWouldAndSaysItWasLate(t *testing.T) {
	var mu sync.Mutex
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		mu.Lock()
		calls++
		n := calls
		mu.Unlock()
		if n > 1 {
			time.Sleep(1500 * time.Millisecond)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	r := check(t, server.URL+"/generate_204", 700)

	if r.Ms != -1 || r.Error != "no answer in 700 ms" {
		t.Fatalf("both requests must be done within the wait, got %+v", r)
	}
	if r.Phase != "late" || r.ColdMs == nil || r.ReplyMs == nil {
		t.Fatalf("want the first reply kept as a late door, got %+v", r)
	}
}

func TestChecksRunningAtOnceCountOnlyTheirOwnSockets(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()

	const n = 12
	results := make([]doorResult, n)
	var wg sync.WaitGroup
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results[i] = check(t, server.URL+"/generate_204", 5000)
		}(i)
	}
	wg.Wait()

	for i, r := range results {
		if r.Phase != "ok" {
			t.Fatalf("check %d: %+v", i, r)
		}
		// One connection each: the second request rides the first's.
		if r.Dials != 1 {
			t.Fatalf("check %d counted %d connects, want its own one", i, r.Dials)
		}
		if r.BytesOut != results[0].BytesOut || r.BytesIn != results[0].BytesIn {
			t.Fatalf("check %d moved %d/%d bytes, check 0 moved %d/%d: counts leaked between checks",
				i, r.BytesOut, r.BytesIn, results[0].BytesOut, results[0].BytesIn)
		}
	}
}

func TestAResultNeverHoldsAnAddress(t *testing.T) {
	for _, tc := range []struct{ in, want string }{
		{"read tcp 10.0.2.15:51234->203.0.113.224:443: read: connection reset by peer",
			"read tcp <addr>-><addr>: read: connection reset by peer"},
		{"dial tcp [2001:db8:f10::1]:8443: connect: network is unreachable",
			"dial tcp <addr>: connect: network is unreachable"},
		{"lookup fe80::1%wlan0 failed", "lookup <addr> failed"},
		{"proxy/vless: 2001:db8:f12::/64 refused", "proxy/vless: <addr>/64 refused"},
		{`Get "https://www.gstatic.com/generate_204": EOF`, `Get "https://www.gstatic.com/generate_204": EOF`},
		{"stalled at 13:45:01 after 3 s", "stalled at 13:45:01 after 3 s"},
		{"REALITY: processed invalid connection", "REALITY: processed invalid connection"},
	} {
		if got := scrubAddresses(tc.in); got != tc.want {
			t.Errorf("scrubAddresses(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestADialOutsideAnyCheckGoesThroughUntouched(t *testing.T) {
	PrepareDoorChecks()
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()
	// A check that ended leaves nothing behind for the next dial to find.
	_ = check(t, server.URL+"/generate_204", 3000)
	count := 0
	doorTraces.Range(func(any, any) bool { count++; return true })
	if count != 0 {
		t.Fatalf("%d traces left behind", count)
	}
	if traceOf(t.Context()) != nil {
		t.Fatal("a context without a check id found a trace")
	}
}

func TestTheResultIsTheShapeTheAppReads(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()
	out := CheckDoorTimed(directConfig, server.URL+"/generate_204", 3000)
	for _, key := range []string{"ms", "boot_ms", "cold_ms", "dial_ms", "first_byte_ms", "reply_ms",
		"bytes_out", "bytes_in", "dials", "dial_fails", "phase"} {
		// dns_ms and tls_ms are left out here: this door has neither a name
		// nor TLS (TestADoorDialledAtAnAddressWithNoTLSHasNoLookupOrHandshakeTime).
		if !strings.Contains(out, fmt.Sprintf("%q:", key)) {
			t.Errorf("key %s missing from %s", key, out)
		}
	}
	if regexp.MustCompile(`\d+\.\d+\.\d+\.\d+`).MatchString(out) {
		t.Errorf("an address in %s", out)
	}
}

func TestAConfigTheCoreCannotLoadIsAnErrorNotAPanic(t *testing.T) {
	var r doorResult
	if err := json.Unmarshal([]byte(CheckDoorTimed("{not json", "", 1000)), &r); err != nil {
		t.Fatal(err)
	}
	if r.Ms != -1 || r.Error == "" || r.Phase != "" || r.Dials != 0 {
		t.Fatalf("want a load error and nothing dialled, got %+v", r)
	}
}

// The Android app reads a result with no phase, nothing dialled and one of
// these words at the start of its error as a config the core never started.
// A door check of the backend's own outbound is then made again from the
// door's link (DoorOutbounds.notStartedTimed in the app), so the words must
// not change without the app.
func TestAConfigTheCoreRefusesSaysItNeverStarted(t *testing.T) {
	refused := map[string]string{
		"not JSON": "{not json",
		"a setting of the wrong type": `{"outbounds":[{"tag":"proxy","protocol":"vless",` +
			`"settings":{"vnext":[{"address":"127.0.0.1","port":443,` +
			`"users":[{"id":"b831381d-6324-4d53-ad4f-8cda48b30811","encryption":"none"}]}]},` +
			`"streamSettings":{"network":"xhttp","xhttpSettings":{"mode":5}}}]}`,
		"a protocol the core does not have": `{"outbounds":[{"tag":"proxy","protocol":"nothing-such"}]}`,
	}
	words := []string{"config load error:", "instance creation failed:", "startup failed:"}
	for name, config := range refused {
		var r doorResult
		if err := json.Unmarshal([]byte(CheckDoorTimed(config, "", 1000)), &r); err != nil {
			t.Fatal(err)
		}
		said := false
		for _, w := range words {
			said = said || strings.HasPrefix(r.Error, w)
		}
		if r.Ms != -1 || r.Phase != "" || r.Dials != 0 || r.DialMs != nil || !said {
			t.Errorf("%s: want the core's start error and nothing dialled, got %+v", name, r)
		}
	}
}
