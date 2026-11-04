package fortivacore

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	core "github.com/xtls/xray-core/core"
	coreserial "github.com/xtls/xray-core/infra/conf/serial"
)

// A made-up id for the test door and its exit.
const grpcTestID = "0f0e0d0c-0b0a-4908-8706-050403020100"

// countingDoor stands between a check and the door's exit and counts the
// connections the check's core opens to it. With exit empty it closes each
// connection as soon as it is accepted, like a door whose port answers and
// whose handshake fails.
type countingDoor struct {
	l        net.Listener
	exit     string
	accepted atomic.Int64
	open     atomic.Int64
}

func newCountingDoor(t *testing.T, exit string) *countingDoor {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	d := &countingDoor{l: l, exit: exit}
	t.Cleanup(func() { l.Close() })
	go d.serve()
	return d
}

func (d *countingDoor) port() int { return d.l.Addr().(*net.TCPAddr).Port }

func (d *countingDoor) serve() {
	for {
		c, err := d.l.Accept()
		if err != nil {
			return
		}
		d.accepted.Add(1)
		if d.exit == "" {
			c.Close()
			continue
		}
		d.open.Add(1)
		go func() {
			defer d.open.Add(-1)
			defer c.Close()
			up, err := net.Dial("tcp", d.exit)
			if err != nil {
				return
			}
			defer up.Close()
			var once sync.Once
			done := make(chan struct{})
			pipe := func(dst, src net.Conn) {
				io.Copy(dst, src)
				once.Do(func() { close(done) })
			}
			go pipe(up, c)
			go pipe(c, up)
			<-done
		}()
	}
}

func grpcDoorConfig(port int) string {
	return fmt.Sprintf(`{"log":{"loglevel":"none"},
		"outbounds":[{"protocol":"vless","tag":"proxy",
			"settings":{"vnext":[{"address":"127.0.0.1","port":%d,
				"users":[{"id":%q,"encryption":"none"}]}]},
			"streamSettings":{"network":"grpc","grpcSettings":{"serviceName":"door"}}}]}`,
		port, grpcTestID)
}

// startGRPCExit runs a VLESS over gRPC exit on a free local port and returns
// its address. Its freedom outbound may reach local test servers.
func startGRPCExit(t *testing.T) string {
	t.Helper()
	free, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := free.Addr().String()
	port := free.Addr().(*net.TCPAddr).Port
	free.Close()
	config := fmt.Sprintf(`{"log":{"loglevel":"none"},
		"inbounds":[{"protocol":"vless","listen":"127.0.0.1","port":%d,
			"settings":{"clients":[{"id":%q}],"decryption":"none"},
			"streamSettings":{"network":"grpc","grpcSettings":{"serviceName":"door"}}}],
		"outbounds":[{"protocol":"freedom","settings":{
			"finalRules":[{"action":"allow","ip":["127.0.0.1/32"]}]}}]}`,
		port, grpcTestID)
	parsed, err := coreserial.LoadJSONConfig(strings.NewReader(config))
	if err != nil {
		t.Fatal(err)
	}
	exit, err := core.New(parsed)
	if err != nil {
		t.Fatal(err)
	}
	if err := exit.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { exit.Close() })
	return addr
}

func checkDoor(t *testing.T, config, url string, timeoutMs int64) doorResult {
	t.Helper()
	PrepareDoorChecks()
	var r doorResult
	out := CheckDoorTimed(config, url, timeoutMs)
	if err := json.Unmarshal([]byte(out), &r); err != nil {
		t.Fatalf("result is not JSON: %v: %s", err, out)
	}
	return r
}

// xray keeps each outbound's gRPC client in a cache for the whole process.
// Before xray-grpc-close.patch a check's client stayed connected to the door
// after the check's core had closed: the app's main process kept a socket
// open to every gRPC door it had checked.
func TestAGRPCDoorCheckLeavesNoConnectionOpen(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(noContent))
	defer server.Close()
	door := newCountingDoor(t, startGRPCExit(t))

	r := checkDoor(t, grpcDoorConfig(door.port()), server.URL+"/generate_204", 3000)
	if r.Phase != "ok" {
		t.Fatalf("the check did not get through the gRPC door, so nothing was tested: %+v", r)
	}

	deadline := time.Now().Add(3 * time.Second)
	for door.open.Load() != 0 {
		if time.Now().After(deadline) {
			t.Fatalf("%d connections to the door stayed open after the check", door.open.Load())
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// A gRPC client whose door fails redials with backoff, every 30 to 40
// seconds once the backoff tops out. Before xray-grpc-close.patch it went on
// after the check's core had closed, in the main process and in the tunnel's
// process, which runs one core after another.
func TestAFailingGRPCDoorIsNotDialledAfterItsCheck(t *testing.T) {
	door := newCountingDoor(t, "")

	r := checkDoor(t, grpcDoorConfig(door.port()), "http://192.0.2.1/generate_204", 1500)
	if r.Phase == "ok" || door.accepted.Load() == 0 {
		t.Fatalf("the check never reached the failing door, so nothing was tested: %+v", r)
	}

	// A connect that had started before the core closed can still arrive.
	time.Sleep(200 * time.Millisecond)
	after := door.accepted.Load()
	// After the check's 1.5 s the backoff is under 3 s: a client still alive
	// dials at least once in this wait.
	time.Sleep(4 * time.Second)
	if got := door.accepted.Load(); got != after {
		t.Fatalf("the door was dialled %d more times after its check", got-after)
	}
}
