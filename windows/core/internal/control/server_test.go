package control

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// serve starts a server on a fresh Unix socket. Unix-socket paths are short
// on macOS, so the socket goes in a short temporary directory, not t.TempDir.
func serve(t *testing.T, h Handler) string {
	t.Helper()
	dir, err := os.MkdirTemp("", "fc")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(dir) })
	addr := filepath.Join(dir, "s")
	l, err := Listen(addr)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		_ = (&Server{Handler: h, ReadTimeout: time.Second}).Serve(ctx, l)
		close(done)
	}()
	t.Cleanup(func() { cancel(); <-done })
	return addr
}

func echo(_ context.Context, method string, params json.RawMessage) (any, error) {
	switch method {
	case "echo":
		var v any
		_ = json.Unmarshal(params, &v)
		return v, nil
	case "coded":
		return nil, Errorf(CodeInvalidLink, "bad door")
	case "plain":
		return nil, errors.New("something broke")
	case "panic":
		panic("boom")
	}
	return nil, Errorf(CodeUnknownMethod, "%s", method)
}

func call(t *testing.T, addr, method string, params, out any) error {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return Call(ctx, addr, method, params, out)
}

func TestCallRoundTrip(t *testing.T) {
	addr := serve(t, echo)
	var out map[string]any
	if err := call(t, addr, "echo", map[string]any{"link": "vless://x", "n": 3}, &out); err != nil {
		t.Fatal(err)
	}
	if out["link"] != "vless://x" || out["n"] != float64(3) {
		t.Errorf("got %v", out)
	}
}

func TestErrors(t *testing.T) {
	addr := serve(t, echo)
	for method, code := range map[string]string{
		"coded":   CodeInvalidLink,
		"plain":   CodeInternal,
		"panic":   CodeInternal,
		"missing": CodeUnknownMethod,
	} {
		err := call(t, addr, method, nil, nil)
		var coded *Error
		if !errors.As(err, &coded) || coded.Code != code {
			t.Errorf("%s: got %v, want %s", method, err, code)
		}
	}
	// The server survived the panic.
	if err := call(t, addr, "echo", 1, nil); err != nil {
		t.Errorf("after a panic: %v", err)
	}
}

// raw sends one line as it is and returns the server's line.
func raw(t *testing.T, addr, line string) Response {
	t.Helper()
	conn, err := net.Dial("unix", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(5 * time.Second))
	if _, err := conn.Write([]byte(line)); err != nil {
		t.Fatal(err)
	}
	reply, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil {
		t.Fatal(err)
	}
	var resp Response
	if err := json.Unmarshal(reply, &resp); err != nil {
		t.Fatalf("%q: %v", reply, err)
	}
	return resp
}

func TestProtocolMismatch(t *testing.T) {
	addr := serve(t, echo)
	resp := raw(t, addr, `{"v":99,"method":"echo"}`+"\n")
	if resp.OK || resp.Error == nil || resp.Error.Code != CodeVersion {
		t.Errorf("got %+v, want %s", resp, CodeVersion)
	}
}

func TestBadRequests(t *testing.T) {
	addr := serve(t, echo)
	for _, line := range []string{
		"not json\n",
		`{"v":1}` + "\n",
		strings.Repeat("x", MaxRequestBytes+10) + "\n",
	} {
		resp := raw(t, addr, line)
		if resp.OK || resp.Error == nil || resp.Error.Code != CodeBadRequest {
			t.Errorf("%.20q: got %+v, want %s", line, resp, CodeBadRequest)
		}
	}
}

// A client that connects and says nothing must not hold its connection.
func TestSilentClientIsDropped(t *testing.T) {
	addr := serve(t, echo)
	conn, err := net.Dial("unix", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	reply, _ := bufio.NewReader(conn).ReadBytes('\n')
	var resp Response
	if json.Unmarshal(reply, &resp) != nil || resp.OK || resp.Error.Code != CodeBadRequest {
		t.Errorf("got %q, want a %s after the read timeout", reply, CodeBadRequest)
	}
}
