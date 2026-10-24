package fortivacore

import (
	"crypto/ecdh"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	core "github.com/xtls/xray-core/core"
	coreserial "github.com/xtls/xray-core/infra/conf/serial"
)

// wgKeys is a fresh WireGuard (X25519) key pair, base64 as xray reads it.
// It uses the standard library, so go.mod needs no new direct requirement.
func wgKeys(t *testing.T) (private, public string) {
	t.Helper()
	k, err := ecdh.X25519().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(k.Bytes()), base64.StdEncoding.EncodeToString(k.PublicKey().Bytes())
}

func freeUDPPort(t *testing.T) int {
	t.Helper()
	c, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer c.Close()
	return c.LocalAddr().(*net.UDPAddr).Port
}

// A WireGuard door check whose wait runs out while the reply still streams
// in closes the outbound under traffic. Before xray-wireguard-close.patch a
// sender of the outbound's gVisor stack could be waiting in
// netTun.WriteNotify then, and panicked with "send on closed channel" on a
// goroutine CheckDoorTimed's recover does not cover: the test binary died,
// as the app's main process did on 2026-10-19.
func TestAWireGuardCheckCutUnderTrafficLeavesTheProcessRunning(t *testing.T) {
	PrepareDoorChecks()
	stream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		chunk := make([]byte, 32<<10)
		for r.Context().Err() == nil {
			if _, err := w.Write(chunk); err != nil {
				return
			}
			w.(http.Flusher).Flush()
		}
	}))
	defer stream.Close()

	exitPrivate, exitPublic := wgKeys(t)
	phonePrivate, phonePublic := wgKeys(t)
	port := freeUDPPort(t)
	// The exit sends whatever the tunnel carries to the stream server. A
	// WireGuard inbound's freedom refuses private targets unless told.
	exitConfig := fmt.Sprintf(`{"log":{"loglevel":"none"},
		"inbounds":[{"protocol":"wireguard","listen":"127.0.0.1","port":%d,
			"settings":{"secretKey":%q,"mtu":1420,
				"peers":[{"publicKey":%q,"allowedIPs":["10.66.0.2/32"]}]}}],
		"outbounds":[{"protocol":"freedom","settings":{"redirect":%q,
			"finalRules":[{"action":"allow","ip":["127.0.0.1/32"]}]}}]}`,
		port, exitPrivate, phonePublic, strings.TrimPrefix(stream.URL, "http://"))
	parsed, err := coreserial.LoadJSONConfig(strings.NewReader(exitConfig))
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
	defer exit.Close()

	doorConfig := fmt.Sprintf(`{"log":{"loglevel":"none"},
		"outbounds":[{"protocol":"wireguard","tag":"proxy",
			"settings":{"secretKey":%q,"address":["10.66.0.2/32"],"mtu":1420,"noKernelTun":true,
				"peers":[{"publicKey":%q,"endpoint":"127.0.0.1:%d","allowedIPs":["0.0.0.0/0"]}]}}]}`,
		phonePrivate, exitPublic, port)
	streamed := 0
	for i := 0; i < 20; i++ {
		var r doorResult
		out := CheckDoorTimed(doorConfig, "http://10.66.0.1/", 1500)
		if err := json.Unmarshal([]byte(out), &r); err != nil {
			t.Fatalf("result is not JSON: %v: %s", err, out)
		}
		if strings.HasPrefix(r.Error, "panic:") {
			t.Fatalf("check %d panicked: %s", i, r.Error)
		}
		if r.ReplyMs != nil {
			streamed++
		}
	}
	if streamed == 0 {
		t.Fatal("no check got the stream's reply: the outbound never carried traffic, so nothing was tested")
	}
}
