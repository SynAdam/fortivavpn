package agent

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/xtls/xray-core/core"
	_ "github.com/xtls/xray-core/main/distro/all"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
)

func TestMain(m *testing.M) {
	assets, err := filepath.Abs("../../.assets")
	if err != nil {
		panic(err)
	}
	if _, err := os.Stat(filepath.Join(assets, "geosite.dat")); err != nil {
		fmt.Fprintln(os.Stderr, "run windows/core/stage.sh first: it stages the routing data these tests build against")
		os.Exit(1)
	}
	os.Setenv("XRAY_LOCATION_ASSET", assets)
	os.Exit(m.Run())
}

func path(server, inbound int, uri string) Path {
	return Path{ServerID: server, InboundID: inbound, Door: "tcp-reality", URI: uri}
}

func TestTheDoorThatLastWorkedGoesFirstAndFailedOnesLast(t *testing.T) {
	now := time.Now()
	paths := []Path{path(1, 1, "a"), path(1, 2, "b"), path(2, 1, "c"), path(2, 2, "d"), path(3, 1, "e")}
	last := &DoorKey{ServerID: 2, InboundID: 1}
	failed := map[DoorKey]time.Time{
		{ServerID: 1, InboundID: 1}: now.Add(-time.Minute),
		{ServerID: 1, InboundID: 2}: now.Add(-3 * time.Minute),
		// Long enough ago to be forgotten.
		{ServerID: 3, InboundID: 1}: now.Add(-time.Hour),
	}
	var got []string
	for _, p := range Order(paths, last, failed, now, 10*time.Minute) {
		got = append(got, p.URI)
	}
	if strings.Join(got, "") != "cdeba" {
		t.Fatalf("order %v, want c d e b a", got)
	}
}

func TestSearchLandsWhereAOneByOneSearchWould(t *testing.T) {
	paths := []Path{path(1, 1, "slow-closed"), path(1, 2, "slow-open"), path(2, 1, "fast-open"), path(2, 2, "never")}
	var asked sync.Map
	ping := func(ctx context.Context, link string) int64 {
		asked.Store(link, true)
		switch link {
		case "slow-closed":
			time.Sleep(150 * time.Millisecond)
			return -1
		case "slow-open":
			time.Sleep(100 * time.Millisecond)
			return 100
		case "fast-open":
			return 5
		}
		<-ctx.Done()
		return -1
	}
	chosen, results := Search(context.Background(), paths, ping, 3, 0)
	if chosen != 1 {
		t.Fatalf("chose %d, want 1: the fast door comes later in the backend's order (results %v)", chosen, results)
	}
	if results[0] != -1 || results[2] != 5 {
		t.Fatalf("results %v", results)
	}
}

func TestSearchFindsNothingWhenEveryDoorIsClosed(t *testing.T) {
	paths := []Path{path(1, 1, "a"), path(1, 2, "b")}
	chosen, results := Search(context.Background(), paths, func(context.Context, string) int64 { return -1 }, 4, 0)
	if chosen != -1 || results[0] != -1 || results[1] != -1 {
		t.Fatalf("chose %d with %v", chosen, results)
	}
}

func TestChecksTheSearchCutShortDoNotCountAsClosed(t *testing.T) {
	paths := []Path{path(1, 1, "open"), path(1, 2, "slow"), path(2, 1, "slower")}
	ping := func(ctx context.Context, link string) int64 {
		if link == "open" {
			time.Sleep(50 * time.Millisecond)
			return 20
		}
		// Still checking when the first door answers.
		<-ctx.Done()
		return -1
	}
	chosen, results := Search(context.Background(), paths, ping, 3, 0)
	if chosen != 0 || results[1] != -2 || results[2] != -2 {
		t.Fatalf("chose %d with %v, want 0 with the other two never finished (-2)", chosen, results)
	}
	if req := Request(paths, chosen, results, nil); len(req.Alternates) != 2 {
		t.Fatalf("standby doors %v, want both unfinished doors", req.Alternates)
	}
}

func TestStandbyDoorsLeaveOutTheOnesFoundClosed(t *testing.T) {
	paths := []Path{path(1, 1, "a"), path(1, 2, "b"), path(2, 1, "c"), path(2, 2, "d"), path(3, 1, "e"), path(3, 2, "f"), path(4, 1, "g")}
	paths[2].PenaltyMs = 700
	req := Request(paths, 1, []int64{-1, 50, 30, -1, -2, -2, -2}, []string{"9.9.9.9"})
	if req.Link != "b" || strings.Join(req.Alternates, "") != "cefg" {
		t.Fatalf("link %s standby %v", req.Link, req.Alternates)
	}
	if strings.Join(req.Exits, ",") != "s1,s2,s3,s3,s4" || req.Penalties[1] != 700 {
		t.Fatalf("exits %v penalties %v", req.Exits, req.Penalties)
	}
	if len(req.DNS) != 1 || req.DNS[0] != "9.9.9.9" {
		t.Fatalf("dns %v", req.DNS)
	}
}

func TestARelayIsTrustedOnlyByItsPin(t *testing.T) {
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"ok":true}`)
	}))
	defer srv.Close()
	sum := sha256.Sum256(srv.Certificate().Raw)
	good := Relay{URL: srv.URL, Pin: hex.EncodeToString(sum[:])}
	bad := Relay{URL: srv.URL, Pin: strings.Repeat("0", 64)}

	var out map[string]bool
	if err := (&API{}).once(context.Background(), relayClient(good, nil), http.MethodGet, srv.URL+"/x", nil, &out); err != nil || !out["ok"] {
		t.Fatalf("the pinned relay was refused: %v", err)
	}
	if err := (&API{}).once(context.Background(), relayClient(bad, nil), http.MethodGet, srv.URL+"/x", nil, &out); err == nil {
		t.Fatal("a relay with another certificate was trusted")
	}
}

func TestACallFallsBackToARelayWhenTheBackendCannotBeReached(t *testing.T) {
	relay := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, `{"path":"`+r.URL.Path+`"}`)
	}))
	defer relay.Close()
	sum := sha256.Sum256(relay.Certificate().Raw)
	pinned := []Relay{{URL: relay.URL, Pin: hex.EncodeToString(sum[:])}}

	// Fortiva's backend out of reach: the relay carries the call. The
	// backend's own address is made unreachable through the dialer, since
	// DefaultBase is a real name.
	api := &API{Bind: refuseAll(relay.Listener.Addr().String())}
	api.SetRelays(pinned)
	var out map[string]string
	if err := api.Get(context.Background(), "/api/v1/app/config", &out, false); err != nil {
		t.Fatal(err)
	}
	if out["path"] != "/api/v1/app/config" || api.Route() != "relay" {
		t.Fatalf("answer %v via %s", out, api.Route())
	}

	// Another backend, as in a test: never a relay, which would reach
	// Fortiva's own backend instead.
	other := &API{Base: "http://127.0.0.1:" + strconv.Itoa(deadPort(t))}
	other.SetRelays(pinned)
	if err := other.Get(context.Background(), "/api/v1/app/config", &out, false); err == nil {
		t.Fatalf("a router pointed at another backend used a relay (via %s)", other.Route())
	}
}

func TestTheBackendsAnswerThroughARelayKeepsItsStatus(t *testing.T) {
	relay := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = io.WriteString(w, `{"detail":"code not accepted"}`)
	}))
	defer relay.Close()
	sum := sha256.Sum256(relay.Certificate().Raw)
	api := &API{Bind: refuseAll(relay.Listener.Addr().String())}
	api.SetRelays([]Relay{{URL: relay.URL, Pin: hex.EncodeToString(sum[:])}})
	err := api.Post(context.Background(), "/api/v1/devices/x/billing/redeem", map[string]string{"code": "BAD"}, nil, false)
	var apiErr *APIError
	if !errors.As(err, &apiErr) || apiErr.Status != http.StatusBadRequest || !strings.Contains(apiErr.Body, "code not accepted") {
		t.Fatalf("the backend's answer through the relay is %v", err)
	}
	_, port, _ := net.SplitHostPort(relay.Listener.Addr().String())
	if strings.Contains(err.Error(), port) || !strings.Contains(err.Error(), "relay 1") {
		t.Fatalf("the error names the relay's address, or not its number: %v", err)
	}
}

// refuseAll fails every dial but the one to allowed.
func refuseAll(allowed string) func(network, address string, c syscall.RawConn) error {
	return func(network, address string, c syscall.RawConn) error {
		if address == allowed {
			return nil
		}
		return errors.New("refused by the test")
	}
}

func TestARelaysAddressNeverReachesAnError(t *testing.T) {
	// Every dial refused, so the backend and both relays fail. 192.0.2.0/24
	// is for documentation.
	deadRelay := strconv.Itoa(deadPort(t))
	api := &API{Bind: refuseAll("")}
	api.SetRelays([]Relay{
		{URL: "https://192.0.2.44:443", Pin: strings.Repeat("a", 64)},
		{URL: "https://127.0.0.1:" + deadRelay, Pin: strings.Repeat("b", 64)},
	})
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	err := api.Get(ctx, "/api/v1/app/config", nil, false)
	if err == nil {
		t.Fatal("nothing answers, yet the call worked")
	}
	if strings.Contains(err.Error(), "192.0.2.44") || strings.Contains(err.Error(), deadRelay) {
		t.Fatalf("a relay's address is in the error: %v", err)
	}
	if !strings.Contains(err.Error(), "relay 1: failed") || !strings.Contains(err.Error(), "relay 2: failed") {
		t.Fatalf("the relays are not named by number: %v", err)
	}
}

func deadPort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := l.Addr().(*net.TCPAddr).Port
	l.Close()
	return port
}

func TestTheDeviceIdIsMadeOnceAndKept(t *testing.T) {
	dir := t.TempDir()
	s, _ := NewStore(dir)
	a, err := s.DeviceID()
	if err != nil || !validUUID(a) {
		t.Fatalf("id %q %v", a, err)
	}
	s2, _ := NewStore(dir)
	if b, _ := s2.DeviceID(); b != a {
		t.Fatalf("a second start made another id: %s then %s", a, b)
	}
}

func TestAFileIsNotRewrittenWhenNothingChanged(t *testing.T) {
	dir := t.TempDir()
	s, _ := NewStore(dir)
	if err := s.SaveMemory(Memory{Paused: true}); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(dir, memoryFile)
	old := time.Now().Add(-time.Hour)
	_ = os.Chtimes(file, old, old)
	if err := s.SaveMemory(Memory{Paused: true}); err != nil {
		t.Fatal(err)
	}
	if info, _ := os.Stat(file); info.ModTime().After(old.Add(time.Minute)) {
		t.Fatal("the same memory was written again")
	}
	if err := s.SaveMemory(Memory{Paused: false}); err != nil {
		t.Fatal(err)
	}
	if info, _ := os.Stat(file); !info.ModTime().After(old.Add(time.Minute)) {
		t.Fatal("changed memory was not written")
	}
}

func TestAFileIsSyncedBeforeItsRenameAndTheDirectoryAfter(t *testing.T) {
	dir := t.TempDir()
	s, _ := NewStore(dir)
	path := filepath.Join(dir, memoryFile)
	var steps []string
	oldFile, oldDir := syncFile, syncDir
	t.Cleanup(func() { syncFile, syncDir = oldFile, oldDir })
	syncFile = func(f *os.File) error {
		// Still the temporary file: the rename has not happened yet.
		if _, err := os.Stat(path); err == nil {
			steps = append(steps, "file synced after the rename")
		} else {
			steps = append(steps, "file "+filepath.Base(f.Name()))
		}
		return f.Sync()
	}
	syncDir = func(d string) error {
		data, err := os.ReadFile(path)
		if err != nil || !strings.Contains(string(data), "paused") {
			steps = append(steps, "directory synced before the rename")
		} else {
			steps = append(steps, "directory "+filepath.Base(d))
		}
		return nil
	}
	if err := s.SaveMemory(Memory{Paused: true}); err != nil {
		t.Fatal(err)
	}
	want := "file " + memoryFile + ".tmp, directory " + filepath.Base(dir)
	if got := strings.Join(steps, ", "); got != want {
		t.Fatalf("steps %q, want %q", got, want)
	}
	if _, err := os.Stat(path + ".tmp"); err == nil {
		t.Fatal("the temporary file was left behind")
	}
}

// --- the whole agent, on the real engine and real doors ------------------

const testUUID = "11111111-2222-3333-4444-555555555555"

// probeHost is a name no routing list holds, so the probe goes to the door.
const probeHost = "probe.fortiva-router-e2e.net"

// door is a VLESS server in this process that sends everything to target.
func door(t *testing.T, target string) string {
	t.Helper()
	port := deadPort(t)
	cfg := fmt.Sprintf(`{
	  "inbounds": [{"listen": "127.0.0.1", "port": %d, "protocol": "vless",
	    "settings": {"clients": [{"id": %q}], "decryption": "none"}}],
	  "outbounds": [{"protocol": "freedom", "settings": {"redirect": %q,
	    "finalRules": [{"action": "allow"}]}}]
	}`, port, testUUID, target)
	inst, err := core.StartInstance("json", []byte(cfg))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = inst.Close() })
	return fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none&encryption=none#test", testUUID, port)
}

// probe answers the request every door check and every connect fetches.
func probe(t *testing.T) (url, addr string) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(srv.Close)
	port := srv.Listener.Addr().(*net.TCPAddr).Port
	return "http://" + probeHost + ":" + strconv.Itoa(port) + "/generate_204", srv.Listener.Addr().String()
}

// backend is the API, recording what the router sent.
type backend struct {
	mu        sync.Mutex
	paths     []Path
	quota     Quota
	registers []map[string]any
	events    []map[string]any
	redeemed  []string
	// fetches is when each /configs/dedicated call arrived.
	fetches []time.Time
	down    atomic.Bool
	// conns counts the connections the router opened to the backend.
	conns atomic.Int32
	// holdEvents keeps every events call waiting until release is closed.
	holdEvents atomic.Bool
	release    chan struct{}
}

func (b *backend) handler(t *testing.T) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if b.down.Load() {
			hj, _ := w.(http.Hijacker)
			conn, _, _ := hj.Hijack()
			conn.Close()
			return
		}
		if strings.HasSuffix(r.URL.Path, "/events") && b.holdEvents.Load() {
			// Read first: the server sees the client leave only once the
			// body is read.
			raw, _ := io.ReadAll(r.Body)
			r.Body = io.NopCloser(bytes.NewReader(raw))
			select {
			case <-b.release:
			case <-r.Context().Done():
				return
			}
		}
		if got := r.Header.Get("X-App-Platform"); got != "router" {
			t.Errorf("%s came with X-App-Platform %q", r.URL.Path, got)
		}
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		b.mu.Lock()
		defer b.mu.Unlock()
		switch {
		case r.URL.Path == "/api/v1/devices/register":
			b.registers = append(b.registers, body)
			_, _ = io.WriteString(w, `{}`)
		case r.URL.Path == "/api/v1/app/config":
			_, _ = io.WriteString(w, `{"api_relays":[]}`)
		case r.URL.Path == "/api/v1/configs/dedicated":
			b.fetches = append(b.fetches, time.Now())
			_ = json.NewEncoder(w).Encode(map[string]any{"configs": []string{}, "paths": b.paths, "quota": b.quota})
		case strings.HasSuffix(r.URL.Path, "/events"):
			for _, e := range body["events"].([]any) {
				b.events = append(b.events, e.(map[string]any))
			}
			_, _ = io.WriteString(w, `{"accepted":1}`)
		case strings.HasSuffix(r.URL.Path, "/billing/redeem"):
			b.redeemed = append(b.redeemed, body["code"].(string))
			b.quota = Quota{Unlimited: true}
			_, _ = io.WriteString(w, `{"premium":true}`)
		default:
			http.NotFound(w, r)
		}
	})
}

func (b *backend) fetchTimes() []time.Time {
	b.mu.Lock()
	defer b.mu.Unlock()
	return append([]time.Time(nil), b.fetches...)
}

func (b *backend) eventList() []map[string]any {
	b.mu.Lock()
	defer b.mu.Unlock()
	return append([]map[string]any(nil), b.events...)
}

func (b *backend) eventTypes() []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	var out []string
	for _, e := range b.events {
		out = append(out, e["type"].(string))
	}
	return out
}

func testAgent(t *testing.T, b *backend, probeURL string, dir string, tweaks ...func(*Options)) (*Agent, *engine.Engine) {
	t.Helper()
	srv := httptest.NewUnstartedServer(b.handler(t))
	srv.Config.ConnState = func(_ net.Conn, s http.ConnState) {
		if s == http.StateNew {
			b.conns.Add(1)
		}
	}
	srv.Start()
	t.Cleanup(srv.Close)
	eng := engine.New(engine.Options{
		VerifyURLs: []string{probeURL}, PingURL: probeURL, VerifyTimeout: 5 * time.Second,
		Resolve: func(context.Context, string) ([]netip.Addr, error) { return nil, errors.New("no lookups here") },
	})
	store, err := NewStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	api := &API{Base: srv.URL, Version: "9.9.9", Platform: "router"}
	o := Options{
		Store: store, API: api, Tunnel: eng, Version: "9.9.9",
		Model: "Test Router", OSVersion: "OpenWrt 24.10.0",
		Parallel: 2, PingTimeout: 3 * time.Second, ConnectWait: 15 * time.Second,
		HeartbeatEach: 200 * time.Millisecond, RetryMin: 100 * time.Millisecond, RetryMax: 200 * time.Millisecond,
		Logf: t.Logf,
	}
	for _, tweak := range tweaks {
		tweak(&o)
	}
	return New(o), eng
}

// start runs ag until the test ends, and waits for it to stop.
func start(t *testing.T, ag *Agent) {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = ag.Run(ctx); close(done) }()
	t.Cleanup(func() { cancel(); <-done })
}

func waitFor(t *testing.T, what string, ok func() bool) {
	t.Helper()
	deadline := time.Now().Add(30 * time.Second)
	for !ok() {
		if time.Now().After(deadline) {
			t.Fatalf("timed out waiting until %s", what)
		}
		time.Sleep(50 * time.Millisecond)
	}
}

func TestTheRouterConnectsThroughTheFirstOpenDoorAndReports(t *testing.T) {
	probeURL, probeAddr := probe(t)
	open := door(t, probeAddr)
	closed := fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none#closed", testUUID, deadPort(t))
	b := &backend{
		paths: []Path{
			{ServerID: 1, InboundID: 1, Door: "tcp-reality", URI: closed},
			{ServerID: 2, InboundID: 7, Door: "xhttp-reality", URI: open},
		},
		quota: Quota{LimitBytes: 1 << 30, RemainingBytes: 1 << 30},
	}
	dir := t.TempDir()
	ag, eng := testAgent(t, b, probeURL, dir)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = ag.Run(ctx); close(done) }()

	waitFor(t, "the router is connected", func() bool { return ag.Status().State == StateConnected })
	st := ag.Status()
	if st.Door == nil || st.Door.ServerID != 2 || eng.Status().State != engine.Connected {
		t.Fatalf("status %+v", st)
	}
	if st.Quota == nil || st.Quota.RemainingBytes != 1<<30 {
		t.Fatalf("quota %+v", st.Quota)
	}
	waitFor(t, "a heartbeat arrived", func() bool { return contains(b.eventTypes(), "heartbeat") })

	b.mu.Lock()
	reg := b.registers[0]
	b.mu.Unlock()
	if reg["platform"] != "router" || reg["device_model"] != "Test Router" || reg["device_id"] != ag.DeviceID() {
		t.Fatalf("registered as %v", reg)
	}
	saved, err := ag.o.Store.LoadConfigs()
	if err != nil || len(saved.Paths) != 2 {
		t.Fatalf("the doors were not saved: %v", err)
	}
	if m := ag.o.Store.LoadMemory(); m.LastDoor == nil || m.LastDoor.InboundID != 7 {
		t.Fatalf("memory %+v", m)
	}

	// Paused, it closes the tunnel and says so; resumed, it comes back.
	ag.SetPaused(true)
	waitFor(t, "the router is paused", func() bool { return ag.Status().State == StatePaused })
	if eng.Status().State == engine.Connected {
		t.Fatal("the tunnel stayed up while paused")
	}
	waitFor(t, "a disconnected event arrived", func() bool { return contains(b.eventTypes(), "disconnected") })
	ag.SetPaused(false)
	waitFor(t, "the router is connected again", func() bool { return ag.Status().State == StateConnected })

	// A Premium code reaches the backend, and the doors are fetched again.
	ctxR, cancelR := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancelR()
	if _, err := ag.Redeem(ctxR, "ABCD-1234"); err != nil {
		t.Fatal(err)
	}
	waitFor(t, "the router is Premium", func() bool {
		q := ag.Status().Quota
		return q != nil && q.Unlimited
	})

	cancel()
	<-done
	if eng.Status().State == engine.Connected {
		t.Fatal("the tunnel outlived the agent")
	}
	for _, e := range b.eventTypes() {
		if e == "connect_failed" {
			// The closed door was found closed by its check and never dialled.
			t.Fatalf("a connect failed: %v", b.eventTypes())
		}
	}
}

func TestARouterThatCannotReachTheBackendUsesItsSavedDoors(t *testing.T) {
	probeURL, probeAddr := probe(t)
	open := door(t, probeAddr)
	dir := t.TempDir()
	store, _ := NewStore(dir)
	_ = store.SaveConfigs(&Configs{
		Paths:     []Path{{ServerID: 3, InboundID: 1, Door: "tcp-reality", URI: open}},
		Quota:     Quota{Unlimited: true},
		FetchedAt: time.Now().Add(-48 * time.Hour),
	})
	b := &backend{}
	b.down.Store(true)
	ag, _ := testAgent(t, b, probeURL, dir)
	start(t, ag)
	waitFor(t, "the router is connected on its saved doors", func() bool { return ag.Status().State == StateConnected })
}

func TestARouterOutOfDataWaitsWithoutDialling(t *testing.T) {
	probeURL, _ := probe(t)
	reset := time.Now().Add(time.Hour)
	b := &backend{quota: Quota{LimitBytes: 100, UsedBytes: 100, Blocked: true, ResetsAt: &reset}}
	ag, eng := testAgent(t, b, probeURL, t.TempDir())
	start(t, ag)
	waitFor(t, "the router says its data is used up", func() bool { return ag.Status().State == StateNoData })
	if eng.Status().State != engine.Disconnected {
		t.Fatalf("tunnel %s", eng.Status().State)
	}
}

// lastBefore is the event of type kind just before the first one of type
// then, and that one.
func lastBefore(events []map[string]any, kind, then string) (before, at map[string]any) {
	for _, e := range events {
		if e["type"] == then {
			return before, e
		}
		if e["type"] == kind {
			before = e
		} else if e["type"] != "connected" {
			before = nil
		}
	}
	return nil, nil
}

func TestTheAllowanceRunningOutWhileUpEndsTheSessionWithABeat(t *testing.T) {
	probeURL, probeAddr := probe(t)
	open := door(t, probeAddr)
	b := &backend{
		paths: []Path{{ServerID: 2, InboundID: 7, Door: "tcp-reality", URI: open}},
		quota: Quota{LimitBytes: 1 << 30, RemainingBytes: 1 << 30},
	}
	ag, eng := testAgent(t, b, probeURL, t.TempDir(), func(o *Options) {
		// No beat of its own and no fetch of its own: only the end sends one.
		o.HeartbeatEach, o.RefreshEvery, o.NoDataWait = time.Hour, time.Hour, time.Hour
	})
	start(t, ag)
	waitFor(t, "the router is connected", func() bool { return ag.Status().State == StateConnected })

	b.mu.Lock()
	b.quota = Quota{LimitBytes: 1 << 30, UsedBytes: 1 << 30, Blocked: true}
	b.mu.Unlock()
	ag.Refresh()
	waitFor(t, "the session ended", func() bool { return contains(b.eventTypes(), "disconnected") })
	beat, ended := lastBefore(b.eventList(), "heartbeat", "disconnected")
	if beat == nil {
		t.Fatalf("no heartbeat before the end: %v", b.eventTypes())
	}
	if _, ok := beat["bytes_up"]; !ok {
		t.Fatalf("the last beat carries no bytes: %v", beat)
	}
	if diag, _ := ended["diag"].(map[string]any); ended["door"] != "tcp-reality" || diag["reason"] != "out_of_data" {
		t.Fatalf("the end was reported as %v", ended)
	}
	if eng.Status().State == engine.Connected || ag.Status().Door != nil {
		t.Fatalf("tunnel %s, door %v after the allowance ran out", eng.Status().State, ag.Status().Door)
	}

	// After the reset no door opens; that failure names no door.
	closed := fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none#closed", testUUID, deadPort(t))
	b.mu.Lock()
	b.quota = Quota{Unlimited: true}
	b.paths = []Path{{ServerID: 3, InboundID: 1, Door: "tcp-closed", URI: closed}}
	b.mu.Unlock()
	ag.Refresh()
	waitFor(t, "the closed door is reported", func() bool { return contains(b.eventTypes(), "connect_failed") })
	_, failed := lastBefore(b.eventList(), "", "connect_failed")
	if _, ok := failed["door"]; ok || failed["server_host"] != nil {
		t.Fatalf("a later event carries the old door: %v", failed)
	}
}

func TestAStalledTunnelEndsWithItsLastBeat(t *testing.T) {
	probeURL, probeAddr := probe(t)
	open := door(t, probeAddr)
	b := &backend{paths: []Path{{ServerID: 2, InboundID: 7, Door: "tcp-reality", URI: open}}, quota: Quota{Unlimited: true}}
	var stalled atomic.Bool
	ag, _ := testAgent(t, b, probeURL, t.TempDir(), func(o *Options) {
		o.HeartbeatEach = time.Hour
		o.LivenessEvery, o.LivenessMisses = 100*time.Millisecond, 2
		o.Liveness = func(context.Context) error {
			if stalled.Load() {
				return errors.New("the page did not load")
			}
			return nil
		}
	})
	start(t, ag)
	waitFor(t, "the router is connected", func() bool { return ag.Status().State == StateConnected })
	stalled.Store(true)
	waitFor(t, "the stall is reported", func() bool { return contains(b.eventTypes(), "dropped") })
	stalled.Store(false)
	beat, dropped := lastBefore(b.eventList(), "heartbeat", "dropped")
	if beat == nil {
		t.Fatalf("no heartbeat before the drop: %v", b.eventTypes())
	}
	if _, ok := beat["bytes_up"]; !ok {
		t.Fatalf("the last beat carries no bytes: %v", beat)
	}
	if dropped["error"] != "stalled" || dropped["door"] != "tcp-reality" {
		t.Fatalf("the drop was reported as %v", dropped)
	}
}

func TestAStartingRouterTakesTheLookupsBackFirst(t *testing.T) {
	probeURL, _ := probe(t)
	b := &backend{quota: Quota{LimitBytes: 100, UsedBytes: 100, Blocked: true}}
	var mu sync.Mutex
	var hooks []string
	ag, _ := testAgent(t, b, probeURL, t.TempDir(), func(o *Options) {
		o.Hook = func(event string) {
			mu.Lock()
			hooks = append(hooks, event)
			mu.Unlock()
		}
	})
	start(t, ag)
	waitFor(t, "the router says its data is used up", func() bool { return ag.Status().State == StateNoData })
	mu.Lock()
	defer mu.Unlock()
	// A process killed while its tunnel was up left the lookups pointed at
	// it, and this one cannot connect.
	if strings.Join(hooks, " ") != "down" {
		t.Fatalf("hook calls %v, want one down", hooks)
	}
}

func TestAStoppingRouterTakesTheLookupsBackBeforeItReports(t *testing.T) {
	probeURL, probeAddr := probe(t)
	open := door(t, probeAddr)
	b := &backend{
		paths:   []Path{{ServerID: 2, InboundID: 7, Door: "tcp-reality", URI: open}},
		quota:   Quota{Unlimited: true},
		release: make(chan struct{}),
	}
	hooks := make(chan string, 16)
	ag, _ := testAgent(t, b, probeURL, t.TempDir(), func(o *Options) {
		o.HeartbeatEach = time.Hour
		o.Hook = func(event string) { hooks <- event }
	})
	release := sync.OnceFunc(func() { close(b.release) })
	t.Cleanup(release)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { _ = ag.Run(ctx); close(done) }()
	defer func() { cancel(); <-done }()
	for up := false; !up; {
		select {
		case e := <-hooks:
			up = e == "up"
		case <-time.After(30 * time.Second):
			t.Fatal("the tunnel never came up")
		}
	}

	// A backend too slow to take the last events: procd would kill the
	// process while it waits, so the lookups must be back before that.
	b.holdEvents.Store(true)
	cancel()
	select {
	case e := <-hooks:
		if e != "down" {
			t.Fatalf("hook %s on stopping", e)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("the lookups were still on the tunnel while the last events waited")
	}
	release()
	<-done
}

func TestARouterOutOfDataAsksAgainOnlyAfterItsWait(t *testing.T) {
	probeURL, _ := probe(t)
	reset := time.Now().Add(time.Hour)
	b := &backend{quota: Quota{LimitBytes: 100, UsedBytes: 100, Blocked: true, ResetsAt: &reset}}
	dir := t.TempDir()
	const wait = 300 * time.Millisecond
	ag, _ := testAgent(t, b, probeURL, dir, func(o *Options) { o.NoDataWait = wait })
	start(t, ag)
	waitFor(t, "the router says its data is used up", func() bool { return ag.Status().State == StateNoData })

	// The answer does not change, so the saved doors are not written again.
	file := filepath.Join(dir, configsFile)
	old := time.Now().Add(-time.Hour)
	if err := os.Chtimes(file, old, old); err != nil {
		t.Fatal(err)
	}
	time.Sleep(5 * wait)

	fetches := b.fetchTimes()
	if len(fetches) < 3 || len(fetches) > 8 {
		t.Fatalf("%d fetches in %v with a wait of %v", len(fetches), 5*wait, wait)
	}
	for i := 1; i < len(fetches); i++ {
		if gap := fetches[i].Sub(fetches[i-1]); gap < wait {
			t.Fatalf("fetch %d came %v after the one before, sooner than the wait of %v", i, gap, wait)
		}
	}
	if info, err := os.Stat(file); err != nil || info.ModTime().After(old.Add(time.Minute)) {
		t.Fatalf("an unchanged answer was written to the flash again (%v)", err)
	}
	if n := b.conns.Load(); n > 2 {
		t.Fatalf("%d connections to the backend for %d fetches and the calls around them: they are not reused", n, len(fetches))
	}
}

func TestEveryDoorClosedBacksOff(t *testing.T) {
	probeURL, _ := probe(t)
	closed := fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none#closed", testUUID, deadPort(t))
	b := &backend{paths: []Path{{ServerID: 1, InboundID: 1, Door: "tcp-reality", URI: closed}}, quota: Quota{Unlimited: true}}
	const first, most = 100 * time.Millisecond, 400 * time.Millisecond
	// A short check, so the waits and not the checks set the pace.
	ag, _ := testAgent(t, b, probeURL, t.TempDir(), func(o *Options) {
		o.RetryMin, o.RetryMax, o.PingTimeout = first, most, 200*time.Millisecond
	})
	start(t, ag)
	time.Sleep(3 * time.Second)

	// Rounds of a 200 ms check and a wait of 100, 200, 400, 400 ms and so
	// on: about six.
	fetches := b.fetchTimes()
	if len(fetches) < 3 || len(fetches) > 9 {
		t.Fatalf("%d fetches in 3s with waits from %v to %v", len(fetches), first, most)
	}
	for i := 1; i < len(fetches); i++ {
		want := min(first<<(i-1), most)
		if gap := fetches[i].Sub(fetches[i-1]); gap < want {
			t.Fatalf("round %d began %v after the one before, sooner than its wait of %v", i, gap, want)
		}
	}
	if n := len(b.eventTypes()); n > 2*len(fetches) {
		t.Fatalf("%d events for %d rounds", n, len(fetches))
	}
}

func TestEveryDoorClosedIsReported(t *testing.T) {
	probeURL, _ := probe(t)
	closed := fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none#closed", testUUID, deadPort(t))
	b := &backend{paths: []Path{{ServerID: 1, InboundID: 1, Door: "tcp-reality", URI: closed}}, quota: Quota{Unlimited: true}}
	ag, _ := testAgent(t, b, probeURL, t.TempDir())
	start(t, ag)
	waitFor(t, "the failure is reported", func() bool { return contains(b.eventTypes(), "connect_failed") })
	if s := ag.Status().State; s != StateOffline && s != StateSearching {
		t.Fatalf("state %s", s)
	}
}

func contains(list []string, s string) bool {
	for _, item := range list {
		if item == s {
			return true
		}
	}
	return false
}

var _ = config.MaxAlternates
