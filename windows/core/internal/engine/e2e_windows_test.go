//go:build windows

package engine

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	xlog "github.com/xtls/xray-core/common/log"
	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wireguard/windows/tunnel/winipcfg"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/xray"
)

// TestWindowsEndToEnd runs the tunnel as the service runs it, on a real
// Windows PC: the Wintun adapter, its routes and everything else a connect
// sets up, through a door in this process that sends what it carries to the
// internet. Then it checks what other programs on the PC get, the way a
// person would see it: pages in curl and in Chrome, IPv6, and where lookups
// go. It changes the PC's routes while it runs, so it runs only where it is
// asked to, as in the Windows e2e workflow of the public copy.
func TestWindowsEndToEnd(t *testing.T) {
	if os.Getenv("FORTIVA_WINDOWS_E2E") != "1" {
		t.Skip("set FORTIVA_WINDOWS_E2E=1 on a Windows PC whose network may be taken over, as an administrator")
	}
	logs := NewLogSink(os.Stderr, false)
	xlog.RegisterHandler(logs)

	gateway, ifIndex := physicalGateway(t)
	t.Logf("the physical network's gateway: %s, interface %d", gateway, ifIndex)
	// A resolver reached over the physical network, as a PC's own resolvers
	// are: a host route through the gateway wins over the tunnel's routes.
	const outside = "8.8.4.4"
	powershell(t, fmt.Sprintf(`New-NetRoute -DestinationPrefix %s/32 -InterfaceIndex %d -NextHop %s -PolicyStore ActiveStore | Out-Null`, outside, ifIndex, gateway))
	t.Cleanup(func() {
		powershell(t, fmt.Sprintf(`Remove-NetRoute -DestinationPrefix %s/32 -Confirm:$false`, outside))
	})
	if got := lookupVia(t, outside); !strings.HasPrefix(got, "answered") {
		t.Fatalf("before connecting, a lookup over the physical network: %q", got)
	}
	link, closeDoor := internetDoor(t)
	defer closeDoor()

	binder, err := NewBinder(nil)
	if err != nil {
		t.Fatal(err)
	}
	e := New(Options{
		Capture: true,
		Resolve: func(ctx context.Context, host string) ([]netip.Addr, error) {
			return net.DefaultResolver.LookupNetIP(ctx, "ip", host)
		},
		Binder: binder,
		Guard:  SystemGuard(),
		Logs:   logs,
	})
	defer e.Disconnect()

	connect := func() {
		t.Helper()
		st, err := e.Connect(config.Request{Link: link})
		if err != nil {
			t.Fatal(err)
		}
		if st = settle(t, e, st.Seq); st.State != Connected {
			t.Fatalf("state %s (%s: %s), want connected", st.State, st.Reason, st.Error)
		}
	}
	connect()
	t.Log(powershell(t, `Get-NetIPAddress -InterfaceAlias Fortiva | Format-Table IPAddress, PrefixLength -AutoSize | Out-String
Get-NetRoute -InterfaceAlias Fortiva | Format-Table DestinationPrefix, NextHop, RouteMetric -AutoSize | Out-String
Get-DnsClientServerAddress | Where-Object ServerAddresses | Format-Table InterfaceAlias, AddressFamily, ServerAddresses -AutoSize | Out-String
'The order Windows gives a program the addresses of www.google.com in:'
[System.Net.Dns]::GetHostAddresses('www.google.com') | ForEach-Object { $_.ToString() }`))
	e.TunnelStats() // restart the counters

	t.Run("pages load through the tunnel", func(t *testing.T) {
		for _, url := range []string{"https://www.google.com/", "https://www.bing.com/"} {
			out, err := curl(t, "-sS", "-o", "NUL", "-w", "%{http_code} %{remote_ip}", url)
			t.Logf("curl %s: %s %v", url, out, err)
			if err != nil || !strings.HasPrefix(out, "200 ") {
				t.Errorf("%s: %q, %v; want HTTP 200", url, out, err)
			}
			if ip, err := netip.ParseAddr(strings.TrimPrefix(out, "200 ")); err == nil && !ip.Is4() {
				t.Errorf("%s went over %s; with the tunnel up a program should end up on IPv4", url, ip)
			}
		}
		if down, _ := e.TunnelStats()["bytes_down"].(int64); down < 10_000 {
			t.Errorf("the tunnel counted %d bytes down; the pages did not go through it", down)
		}
	})

	ipv6Refused := func(t *testing.T) {
		// Any IPv6 address on the internet: the tunnel's routes send it all
		// to the adapter, and the doors carry no IPv6. From another program
		// than this one, which the filters let through as the service.
		out := strings.TrimSpace(powershell(t, `$c = [System.Net.Sockets.TcpClient]::new([System.Net.Sockets.AddressFamily]::InterNetworkV6)
$w = [Diagnostics.Stopwatch]::StartNew()
try {
  if ($c.ConnectAsync('2606:4700:4700::1111', 443).Wait(5000)) { "connected $($w.ElapsedMilliseconds)" } else { "waiting $($w.ElapsedMilliseconds)" }
} catch {
  $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }
  "refused $($w.ElapsedMilliseconds) $($e.SocketErrorCode)"
} finally { $c.Dispose() }`))
		t.Logf("a TCP connection over IPv6: %s", out)
		var verdict string
		var ms int
		fmt.Sscanf(out, "%s %d", &verdict, &ms)
		switch {
		case verdict == "connected":
			t.Errorf("a TCP connection over IPv6 was accepted (%s); it must be refused, or a browser that tries IPv6 first gets no page and no reason to try IPv4", out)
		case verdict != "refused":
			t.Errorf("a TCP connection over IPv6: %q; it must be refused", out)
		case ms > 3000:
			t.Errorf("refusing IPv6 took %d ms; it must be at once, so a program falls back to IPv4 without waiting", ms)
		}
		out, err := curl(t, "-6", "-sS", "-o", "NUL", "-w", "%{http_code}", "http://[2606:4700:4700::1111]/")
		t.Logf("curl -6: %q %v", out, err)
		if err == nil && out != "000" {
			t.Errorf("curl over IPv6 got an answer, HTTP %s, from inside the PC; it must fail to connect", out)
		}
	}
	t.Run("IPv6 is refused at once", ipv6Refused)

	t.Run("lookups go only through the tunnel", func(t *testing.T) {
		t.Log(powershell(t, `Find-NetRoute -RemoteIPAddress `+outside+` | Select-Object -Last 1 | Format-List InterfaceAlias, DestinationPrefix, NextHop | Out-String`))
		if got := lookupVia(t, outside); !strings.HasPrefix(got, "failed") {
			t.Errorf("a lookup over the physical network: %q; it must be refused while the tunnel is up", got)
		}
		// Only lookups: the rest goes over the physical network as before.
		if out, err := curl(t, "-sS", "-o", "NUL", "-w", "%{http_code}", "https://"+outside+"/"); err != nil || out == "000" {
			t.Errorf("HTTPS over the physical network: %q, %v; only lookups are refused", out, err)
		}
		if !loopbackLookupArrives(t) {
			t.Error("a lookup to a resolver on this PC did not arrive")
		}
		// The tunnel's resolver is reached through the door here, whose UDP
		// to the internet is a socket of the kind the binder once left
		// unbound: this lookup also checks that it no longer loops.
		out := powershell(t, `Clear-DnsClientCache
(Resolve-DnsName -Name www.wikipedia.org -Type A -DnsOnly -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1).IPAddress`)
		if _, err := netip.ParseAddr(strings.TrimSpace(out)); err != nil {
			t.Errorf("Windows could not look a name up with the tunnel up: %q", out)
		}
	})

	t.Run("a browser opens the search engines", func(t *testing.T) {
		for _, page := range []struct{ url, want string }{
			{"https://www.google.com/", "<title>google</title>"},
			{"https://www.bing.com/", "bing"},
			{"https://www.yahoo.com/", "yahoo"},
		} {
			dom, err := chrome(t, page.url)
			if err != nil || !strings.Contains(strings.ToLower(dom), page.want) {
				t.Errorf("Chrome on %s: %d bytes, %v; want a page with %q", page.url, len(dom), err, page.want)
				continue
			}
			t.Logf("Chrome on %s: %d bytes", page.url, len(dom))
		}
	})

	// Two connects at once, as the app's recovery can send them: the first is
	// replaced, and only one tunnel takes the adapter.
	if _, err := e.Connect(config.Request{Link: link}); err != nil {
		t.Fatal(err)
	}
	connect()
	t.Run("a second connect refuses IPv6 too", ipv6Refused)

	e.Disconnect()
	t.Run("a disconnect takes everything back", func(t *testing.T) {
		if _, err := net.InterfaceByName(config.Adapter.Name); err == nil {
			t.Error("the adapter is still there")
		}
		if got := lookupVia(t, outside); !strings.HasPrefix(got, "answered") {
			t.Errorf("a lookup over the physical network after the disconnect: %q", got)
		}
		out, err := curl(t, "-sS", "-o", "NUL", "-w", "%{http_code}", "https://www.google.com/")
		if err != nil || out != "200" {
			t.Errorf("without the tunnel: %q, %v; want HTTP 200", out, err)
		}
	})
}

// internetDoor is a VLESS server in this process that sends what it carries
// to the internet, as a Fortiva server does.
func internetDoor(t *testing.T) (link string, closeDoor func()) {
	t.Helper()
	port := freePort(t)
	inst, err := startInstance(&xray.Config{
		Inbounds: []xray.Inbound{{
			Tag: "door", Protocol: "vless", Listen: "127.0.0.1", Port: port,
			Settings: map[string]any{"clients": []any{map[string]any{"id": testUUID}}, "decryption": "none"},
		}},
		Outbounds: []xray.Outbound{{Tag: "out", Protocol: "freedom", Settings: map[string]any{}}},
	})
	if err != nil {
		t.Fatal(err)
	}
	link = fmt.Sprintf("vless://%s@127.0.0.1:%d?type=tcp&security=none&encryption=none#e2e", testUUID, port)
	return link, func() { _ = inst.Close() }
}

// physicalGateway is the next hop of the default route the PC uses, which
// is on the local network, and the index of its interface.
func physicalGateway(t *testing.T) (netip.Addr, uint32) {
	t.Helper()
	luid, index := defaultInterface(windows.AF_INET)
	routes, err := winipcfg.GetIPForwardTable2(windows.AF_INET)
	if err != nil {
		t.Fatal(err)
	}
	for i := range routes {
		r := &routes[i]
		if r.DestinationPrefix.PrefixLength == 0 && r.InterfaceLUID == luid {
			if hop := r.NextHop.Addr(); hop.IsValid() && !hop.IsUnspecified() {
				return hop, index
			}
		}
	}
	t.Fatal("no default route with a gateway")
	return netip.Addr{}, 0
}

// lookupVia asks server for a name from another program than this one,
// which the filters let through as the service: "answered" and an address,
// or "failed" and why.
func lookupVia(t *testing.T, server string) string {
	t.Helper()
	return strings.TrimSpace(powershell(t, fmt.Sprintf(`try {
  $r = Resolve-DnsName -Name example.com -Type A -Server %s -DnsOnly -QuickTimeout -ErrorAction Stop
  'answered ' + ($r | Where-Object IPAddress | Select-Object -First 1).IPAddress
} catch { 'failed ' + $_.Exception.Message }`, server)))
}

// loopbackLookupArrives sends a datagram to port 53 on 127.0.0.1 from
// another program and reports whether this process received it.
func loopbackLookupArrives(t *testing.T) bool {
	t.Helper()
	conn, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 53})
	if err != nil {
		t.Logf("listen on 127.0.0.1:53: %v", err)
		return false
	}
	defer conn.Close()
	powershell(t, `$u = [System.Net.Sockets.UdpClient]::new(); try { [void]$u.Send([byte[]]::new(12), 12, '127.0.0.1', 53) } finally { $u.Dispose() }`)
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _, err = conn.ReadFromUDP(make([]byte, 64))
	return err == nil
}

func curl(t *testing.T, args ...string) (string, error) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	args = append([]string{"--max-time", "20"}, args...)
	out, err := exec.CommandContext(ctx, "curl.exe", args...).Output()
	return strings.TrimSpace(string(out)), err
}

func powershell(t *testing.T, script string) string {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script).CombinedOutput()
	if err != nil {
		t.Logf("powershell: %v", err)
	}
	return string(out)
}

// chrome loads url in a headless Chrome and returns the page as it ended up.
func chrome(t *testing.T, url string) (string, error) {
	t.Helper()
	exe := filepath.Join(os.Getenv("ProgramFiles"), `Google\Chrome\Application\chrome.exe`)
	if _, err := os.Stat(exe); err != nil {
		t.Skipf("no Chrome on this PC: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, exe,
		"--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
		"--user-data-dir="+t.TempDir(), "--virtual-time-budget=10000", "--dump-dom", url).Output()
	return string(out), err
}
