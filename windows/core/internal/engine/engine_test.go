package engine

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"sync/atomic"
	"testing"
	"time"

	xlog "github.com/xtls/xray-core/common/log"
	_ "github.com/xtls/xray-core/main/distro/all"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/control"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/xray"
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

const testUUID = "11111111-2222-3333-4444-555555555555"

// probeHost is a name no routing list holds, so a request for it goes to the
// door rather than straight out the way a private address would. Only the
// test server knows where it is.
const probeHost = "probe.fortiva-e2e.net"

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// door is a VLESS server in this process, standing in for a Fortiva server:
// it accepts testUUID and sends everything it carries to target, which is
// how probeHost reaches the test's web server without any resolver knowing
// the name.
func door(t *testing.T, target string) (link string, closeDoor func()) {
	t.Helper()
	port := freePort(t)
	inst, err := startInstance(&xray.Config{
		Inbounds: []xray.Inbound{{
			Tag: "door", Protocol: "vless", Listen: "127.0.0.1", Port: port,
			Settings: map[string]any{"clients": []any{map[string]any{"id": testUUID}}, "decryption": "none"},
		}},
		Outbounds: []xray.Outbound{{Tag: "out", Protocol: "freedom", Settings: map[string]any{
			"redirect": target,
			// A server refuses to send its clients to its own private
			// addresses unless told otherwise, and the web server is one.
			"finalRules": []any{map[string]any{"action": "allow"}},
		}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	link = fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none&encryption=none#test", testUUID, port)
	return link, func() { _ = inst.Close() }
}

// web answers the probe the doors are checked with, and counts the answers.
// addr is where a door must send the probe to reach it.
func web(t *testing.T) (url, addr string, hits *atomic.Int32) {
	t.Helper()
	hits = new(atomic.Int32)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/generate_204" {
			hits.Add(1)
			w.WriteHeader(http.StatusNoContent)
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(srv.Close)
	port := srv.Listener.Addr().(*net.TCPAddr).Port
	return "http://" + probeHost + ":" + strconv.Itoa(port) + "/generate_204", srv.Listener.Addr().String(), hits
}

func testEngine(url string) *Engine {
	return New(Options{
		VerifyURLs:    []string{url},
		VerifyTimeout: 5 * time.Second,
		PingURL:       url,
		Resolve: func(context.Context, string) ([]netip.Addr, error) {
			return nil, errors.New("no lookups in this test")
		},
	})
}

// settle waits for the attempt that started at seq to end.
func settle(t *testing.T, e *Engine, seq uint64) Status {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	for {
		st := e.Watch(ctx, seq)
		if ctx.Err() != nil {
			t.Fatalf("still %s after 20s", st.State)
		}
		if st.State != Connecting {
			return st
		}
		seq = st.Seq
	}
}

func TestConnectVerifyAndDisconnect(t *testing.T) {
	url, addr, hits := web(t)
	link, closeDoor := door(t, addr)
	defer closeDoor()
	e := testEngine(url)

	st, err := e.Connect(config.Request{Link: link})
	if err != nil {
		t.Fatal(err)
	}
	if st.State != Connecting {
		t.Fatalf("connect returned %s, want connecting", st.State)
	}
	st = settle(t, e, st.Seq)
	if st.State != Connected {
		t.Fatalf("state %s (%s: %s), want connected", st.State, st.Reason, st.Error)
	}
	if hits.Load() == 0 {
		t.Error("the probe never reached the web server through the door")
	}

	// Only the download is asserted: on plain TCP without TLS, which this
	// stand-in door is and no Fortiva door is, the core takes a direct copy
	// path that skips the upload counter. Over TLS both directions count.
	stats := e.TunnelStats()
	if _, ok := stats["bytes_up"].(int64); !ok {
		t.Errorf("no upload reading: %v", stats)
	}
	if down, _ := stats["bytes_down"].(int64); down <= 0 {
		t.Errorf("verification traffic not counted: %v", stats)
	}
	if again := e.TunnelStats(); again["bytes_up"] != int64(0) || again["bytes_down"] != int64(0) {
		t.Errorf("counters should restart at every read: %v", again)
	}

	if ms := e.RealPing(context.Background(), link); ms < 0 {
		t.Errorf("door check failed on a working door: %d", ms)
	}
	detail := e.RealPingDetail(context.Background(), link)
	if ms, _ := detail["ms"].(int64); ms < 0 {
		t.Errorf("detailed check failed: %v", detail)
	}
	if _, ok := detail["tcp"]; ok {
		t.Errorf("a passing check needs no TCP verdict: %v", detail)
	}

	st = e.Disconnect()
	if st.State != Disconnected {
		t.Errorf("after disconnect: %s", st.State)
	}
	if e.TunnelStats() != nil {
		t.Error("no stats without a tunnel")
	}
}

// The door report carries each door's penalty, as Android's does, so the
// backend can read what the group was told next to what it chose.
func TestTheDoorReportCarriesThePenalties(t *testing.T) {
	url, addr, _ := web(t)
	first, closeFirst := door(t, addr)
	defer closeFirst()
	second, closeSecond := door(t, addr)
	defer closeSecond()
	e := testEngine(url)

	st, err := e.Connect(config.Request{Link: first, Alternates: []string{second}, Penalties: []int64{0, 1500}})
	if err != nil {
		t.Fatal(err)
	}
	if st = settle(t, e, st.Seq); st.State != Connected {
		t.Fatalf("state %s (%s: %s), want connected", st.State, st.Reason, st.Error)
	}
	defer e.Disconnect()

	raw, _ := e.TunnelStats()["door_status"].(string)
	var report struct {
		Doors []struct {
			Index     int   `json:"index"`
			PenaltyMs int64 `json:"penalty_ms"`
		} `json:"doors"`
	}
	if err := json.Unmarshal([]byte(raw), &report); err != nil {
		t.Fatalf("door_status %q: %v", raw, err)
	}
	got := map[int]int64{}
	for _, d := range report.Doors {
		got[d.Index] = d.PenaltyMs
	}
	if want := map[int]int64{0: 0, 1: 1500}; !reflect.DeepEqual(got, want) {
		t.Errorf("penalties by door %v, want %v", got, want)
	}
}

func TestDeadDoorFails(t *testing.T) {
	url, _, _ := web(t)
	e := testEngine(url)
	dead := fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none#dead", testUUID, freePort(t))

	st, err := e.Connect(config.Request{Link: dead})
	if err != nil {
		t.Fatal(err)
	}
	st = settle(t, e, st.Seq)
	if st.State != Failed || st.Reason != ReasonVerify {
		t.Errorf("state %s reason %q, want failed/verify", st.State, st.Reason)
	}

	detail := e.RealPingDetail(context.Background(), dead)
	if detail["ms"] != int64(-1) || detail["tcp"] != "refused" {
		t.Errorf("detail %v, want ms -1 and tcp refused", detail)
	}
	if detail["error"] == "" || detail["error"] == nil {
		t.Errorf("a failed check should say why: %v", detail)
	}
}

func TestBadLinkIsRefusedAtOnce(t *testing.T) {
	e := testEngine("http://unused.invalid/")
	before := e.Status()
	_, err := e.Connect(config.Request{Link: "vmess://whatever"})
	var coded *control.Error
	if !errors.As(err, &coded) || coded.Code != control.CodeInvalidLink {
		t.Fatalf("got %v, want %s", err, control.CodeInvalidLink)
	}
	if after := e.Status(); after.Seq != before.Seq {
		t.Errorf("a refused link must not change the state: %+v", after)
	}
}

func TestConnectReplacesTheRunningTunnel(t *testing.T) {
	url, addr, _ := web(t)
	link, closeDoor := door(t, addr)
	defer closeDoor()
	e := testEngine(url)

	st, _ := e.Connect(config.Request{Link: link})
	if st = settle(t, e, st.Seq); st.State != Connected {
		t.Fatalf("first connect: %s %s", st.State, st.Error)
	}
	first, _ := e.running()

	st, _ = e.Connect(config.Request{Link: link})
	if st = settle(t, e, st.Seq); st.State != Connected {
		t.Fatalf("second connect: %s %s", st.State, st.Error)
	}
	second, _ := e.running()
	if first == second {
		t.Error("the second connect kept the first instance")
	}
	if first.IsRunning() {
		t.Error("the replaced instance is still running")
	}
	e.Disconnect()
}

func TestSiteTally(t *testing.T) {
	sink := NewLogSink(nil, false)
	for _, line := range []string{
		"[Info] [111] app/dispatcher: sniffed domain: www.YouTube.com.",
		"[Info] [111] app/dispatcher: taking detour [proxy] for [tcp:www.youtube.com:443]",
		"[Info] [222] app/dispatcher: sniffed domain: divar.ir",
		"[Info] [222] app/dispatcher: taking detour [direct] for [tcp:divar.ir:443]",
		"[Info] [333] app/dispatcher: sniffed domain: example.org",
		"[Info] [333] app/dispatcher: default route for tcp:example.org:443",
		"[Info] [444] app/dispatcher: sniffed domain: later.example.net",
		"[Info] [555] app/dispatcher: taking detour [proxy@1] for [tcp:1.2.3.4:443]",
		"[Info] [666] app/dispatcher: sniffed domain: ads.example.com",
		"[Info] [666] app/dispatcher: taking detour [block] for [tcp:ads.example.com:443]",
	} {
		sink.sites.observe(line)
	}
	if got, want := sink.DrainSites(), map[string]int{"www.youtube.com": 1, "example.org": 1}; !reflect.DeepEqual(got, want) {
		t.Errorf("first drain %v, want %v", got, want)
	}
	if got := sink.DrainSites(); len(got) != 0 {
		t.Errorf("a drain must not count again: %v", got)
	}
	// The route of a connection sniffed before the drain arrives after it.
	sink.sites.observe("[Info] [444] app/dispatcher: taking detour [proxy@0] for [tcp:later.example.net:443]")
	if got, want := sink.DrainSites(), map[string]int{"later.example.net": 1}; !reflect.DeepEqual(got, want) {
		t.Errorf("late route %v, want %v", got, want)
	}
}

func TestLogTail(t *testing.T) {
	sink := NewLogSink(nil, false)
	for i := range ringLines + 5 {
		sink.Printf("line %d", i)
	}
	tail := sink.Tail(3)
	if len(tail) != 3 || !endsWith(tail[2], fmt.Sprintf("line %d", ringLines+4)) || !endsWith(tail[0], fmt.Sprintf("line %d", ringLines+2)) {
		t.Errorf("tail %q", tail)
	}
	if all := sink.Tail(0); len(all) != ringLines {
		t.Errorf("ring holds %d lines, want %d", len(all), ringLines)
	}
}

func endsWith(s, suffix string) bool {
	return len(s) >= len(suffix) && s[len(s)-len(suffix):] == suffix
}

// A door check starts and closes an instance of its own. Had it installed
// its log module, the process's log would end with it, and with the log the
// tunnel's site counts.
func TestDoorCheckKeepsTheLog(t *testing.T) {
	sink := NewLogSink(nil, false)
	xlog.RegisterHandler(sink)

	cfg, err := config.Ping(fmt.Sprintf("vless://%s@127.0.0.1:1?type=tcp#x", testUUID))
	if err != nil {
		t.Fatal(err)
	}
	inst, err := startInstance(cfg)
	if err != nil {
		t.Fatal(err)
	}
	_ = inst.Close()

	xlog.Record(&xlog.GeneralMessage{Severity: xlog.Severity_Info, Content: "after the check"})
	tail := sink.Tail(1)
	if len(tail) != 1 || !endsWith(tail[0], "after the check") {
		t.Errorf("the log stopped reaching the sink: %q", tail)
	}
}
