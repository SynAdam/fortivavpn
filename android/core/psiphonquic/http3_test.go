package psiphonquic

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"io"
	"math/big"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"

	tls "github.com/Psiphon-Labs/psiphon-tls"
	"github.com/Psiphon-Labs/quic-go/http3"
)

func selfSigned(t *testing.T) tls.Certificate {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "localhost"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: key}
}

// TestHeadersSurviveQPACK sends one request through the patched fork. Each
// changed decoder call is on this path: the server decodes the request
// headers (server.go), the client decodes the response headers
// (http_stream.go) and the trailer (conn.go). The NewDecoder calls in
// client.go and conn.go build the decoders they use.
func TestHeadersSurviveQPACK(t *testing.T) {
	udp, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	// Longer than any static table entry, so it is sent as a literal.
	long := strings.Repeat("v", 3000)
	srv := &http3.Server{
		TLSConfig: http3.ConfigureTLSConfig(&tls.Config{Certificates: []tls.Certificate{selfSigned(t)}}),
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Trailer", "X-Trail")
			w.Header().Set("X-Echo", r.Header.Get("X-Custom"))
			w.Header().Set("X-Echo-Path", r.URL.RequestURI())
			w.Header().Set("X-Long", long)
			w.Header().Set("Content-Type", "text/plain")
			_, _ = io.WriteString(w, "ok")
			w.Header().Set("X-Trail", "after the body")
		}),
	}
	go func() { _ = srv.Serve(udp) }()
	defer srv.Close()

	tr := &http3.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
	defer tr.Close()

	req, err := http.NewRequest(http.MethodGet, "https://"+udp.LocalAddr().String()+"/a/path?q=1", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("X-Custom", "hello qpack")
	resp, err := tr.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if err != nil {
		t.Fatal(err)
	}

	if resp.StatusCode != http.StatusOK || string(body) != "ok" {
		t.Fatalf("got status %d and body %q, want 200 and \"ok\"", resp.StatusCode, body)
	}
	for name, want := range map[string]string{
		"X-Echo":       "hello qpack",
		"X-Echo-Path":  "/a/path?q=1",
		"X-Long":       long,
		"Content-Type": "text/plain",
	} {
		if got := resp.Header.Get(name); got != want {
			t.Errorf("response header %s: got %d bytes %.40q, want %d bytes %.40q", name, len(got), got, len(want), want)
		}
	}
	if got := resp.Trailer.Get("X-Trail"); got != "after the body" {
		t.Errorf("trailer X-Trail: got %q, want %q (all trailers: %v)", got, "after the body", resp.Trailer)
	}
}
