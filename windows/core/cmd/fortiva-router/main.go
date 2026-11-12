// Copyright (C) 2026 NimusAI. GPL-3.0-or-later, with the additional terms
// under section 7 in LICENSING.md.

// Command fortiva-router is Fortiva for routers: the Windows build's tunnel
// (the same patched Xray-core and configuration), capturing on a Linux TUN
// interface everything the router forwards, and an agent that does on the
// router what the app does on a phone (internal/agent). OpenWrt runs it as
// the service /etc/init.d/fortiva; router/README.md has the package.
//
//	fortiva-router run [flags]     the service: keep the router connected
//	fortiva-router status          what it is doing, as JSON
//	fortiva-router connect         turn the tunnel on (it stays on across restarts)
//	fortiva-router disconnect      turn the tunnel off (it stays off across restarts)
//	fortiva-router redeem CODE     apply a Premium code to this router
//	fortiva-router version         what it was built from
//	fortiva-router call M [JSON]   send any control call and print the answer
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"

	xlog "github.com/xtls/xray-core/common/log"
	"github.com/xtls/xray-core/core"
	_ "github.com/xtls/xray-core/main/distro/all"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/agent"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/control"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
)

// version is set by router/build.sh from the app's version in pubspec.yaml.
var version = "dev"

func main() {
	cmd := "help"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}
	var err error
	switch cmd {
	case "run":
		err = run(os.Args[2:])
	case "status":
		err = call([]string{"agent"})
	case "connect":
		err = call([]string{"resume"})
	case "disconnect":
		err = call([]string{"pause"})
	case "redeem":
		if len(os.Args) < 3 {
			err = errors.New("redeem needs a code")
			break
		}
		params, _ := json.Marshal(map[string]string{"code": strings.TrimSpace(os.Args[2])})
		err = call([]string{"redeem", string(params)})
	case "version":
		out, _ := json.MarshalIndent(hello(), "", "  ")
		fmt.Println(string(out))
	case "call":
		err = call(os.Args[2:])
	default:
		fmt.Fprintln(os.Stderr, "usage: fortiva-router run [flags] | status | connect | disconnect | redeem CODE | version | call METHOD [JSON]")
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "fortiva-router:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	flags := flag.NewFlagSet("run", flag.ExitOnError)
	state := flags.String("state", "/etc/fortiva", "directory for the device id and the saved doors (kept on flash)")
	assets := flags.String("assets", "", "directory holding geoip.dat and geosite.dat (default: next to the executable)")
	wan := flags.String("wan", "", "WAN device to bind the tunnel's own connections to (default: the device of the default route)")
	dns := flags.String("dns", config.DefaultDNS, "resolvers asked through the tunnel, comma separated IPv4 addresses")
	model := flags.String("model", "", "the router's model, for the backend")
	osVersion := flags.String("os", "", "the firmware and its version, for the backend")
	lang := flags.String("lang", "en", "the router's interface language")
	hook := flags.String("hook", "", "program run with \"up\" when the tunnel starts carrying traffic and \"down\" when it stops, and with \"down\" at the start")
	dnsTunnel := flags.Bool("dns-tunnel", true, "run the hook with \"up\" too; off, it only takes the lookups back")
	api := flags.String("api", agent.DefaultBase, "the backend")
	capture := flags.Bool("capture", runtime.GOOS == "linux", "capture the router's traffic on a TUN interface (off: only dial the doors, for development)")
	debug := flags.Bool("debug", false, "log the core's debug lines, and write its info lines to stderr")
	_ = flags.Parse(args)

	if err := setAssetLocation(*assets); err != nil {
		return err
	}
	logs := engine.NewLogSink(os.Stderr, *debug)
	// stderr is the router's syslog. The core's Info lines name every
	// device's connections and sites, so only -debug lets them in.
	if !*debug {
		logs.QuietCore()
	}
	xlog.RegisterHandler(logs)

	engine.RouterWAN = *wan
	engine.RouterAdapterName = config.RouterAdapter.Name
	var eng *engine.Engine
	binder, err := engine.NewBinder(func() {
		if eng != nil {
			logs.Printf("[engine] the WAN changed; measuring the doors again")
			eng.NetworkChanged()
		}
	})
	if err != nil {
		return fmt.Errorf("watch the routing table: %w", err)
	}
	eng = engine.New(engine.Options{
		Capture: *capture,
		Resolve: resolver(binder),
		Binder:  binder,
		Logs:    logs,
		Adapter: engine.RouterAdapter,
	})

	store, err := agent.NewStore(*state)
	if err != nil {
		return fmt.Errorf("state directory: %w", err)
	}
	client := &agent.API{
		Base:     strings.TrimRight(*api, "/"),
		Version:  version,
		Platform: "router",
		TunnelUp: func() bool { return *capture && eng.Status().State == engine.Connected },
	}
	if b, ok := binder.(interface {
		Bind(network, address string, c syscall.RawConn) error
	}); ok {
		client.Bind = b.Bind
	}

	opts := agent.Options{
		Store:     store,
		API:       client,
		Tunnel:    eng,
		Platform:  "router",
		Version:   version,
		Model:     *model,
		OSVersion: *osVersion,
		Language:  *lang,
		DNS:       splitList(*dns),
		Network: func() string {
			if binder == nil {
				return ""
			}
			return binder.Network()
		},
		Hook: runHook(*hook, *dnsTunnel, logs),
		Logf: logs.Printf,
	}
	if *capture {
		opts.Liveness = liveness
	}
	ag := agent.New(opts)

	l, err := control.Listen(control.Address)
	if err != nil {
		return fmt.Errorf("open %s: %w", control.Address, err)
	}
	logs.Printf("[router] %s (Xray %s) on %s/%s, listening on %s", version, core.Version(), runtime.GOOS, runtime.GOARCH, control.Address)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	srv := &control.Server{Handler: handler(eng, ag, logs), Logf: logs.Printf}
	serveErr := make(chan error, 1)
	go func() { serveErr <- srv.Serve(ctx, l) }()

	runErr := ag.Run(ctx)
	stop()
	eng.Close()
	if err := <-serveErr; err != nil && !errors.Is(err, net.ErrClosed) {
		logs.Printf("[router] control socket: %v", err)
	}
	return runErr
}

// handler serves the control socket. The calls the Windows app uses keep
// their names and shapes; the agent adds its own.
func handler(eng *engine.Engine, ag *agent.Agent, logs *engine.LogSink) control.Handler {
	return func(ctx context.Context, method string, params json.RawMessage) (any, error) {
		switch method {
		case "hello":
			return hello(), nil
		case "status":
			return eng.Status(), nil
		case "agent":
			return ag.Status(), nil
		case "resume":
			ag.SetPaused(false)
			return ag.Status(), nil
		case "pause":
			ag.SetPaused(true)
			return ag.Status(), nil
		case "refresh":
			ag.Refresh()
			return ag.Status(), nil
		case "redeem":
			var p struct {
				Code string `json:"code"`
			}
			if err := json.Unmarshal(params, &p); err != nil || strings.TrimSpace(p.Code) == "" {
				return nil, control.Errorf(control.CodeBadRequest, "redeem needs {\"code\": ...}")
			}
			ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
			defer cancel()
			out, err := ag.Redeem(ctx, strings.TrimSpace(p.Code))
			if err != nil {
				var apiErr *agent.APIError
				if errors.As(err, &apiErr) {
					return map[string]any{"ok": false, "status": apiErr.Status, "detail": apiErr.Body}, nil
				}
				return nil, control.Errorf(control.CodeTimeout, "%v", err)
			}
			return map[string]any{"ok": true, "result": out}, nil
		case "tunnelStats":
			return eng.TunnelStats(), nil
		case "logs":
			var p struct {
				Lines int `json:"lines"`
			}
			_ = json.Unmarshal(params, &p)
			if p.Lines <= 0 || p.Lines > 500 {
				p.Lines = 100
			}
			return logs.Tail(p.Lines), nil
		default:
			return nil, control.Errorf(control.CodeUnknownMethod, "%s", method)
		}
	}
}

// liveness fetches the probe page the ordinary way, which on a router with a
// tunnel up goes through it.
func liveness(ctx context.Context) error {
	client := &http.Client{
		Transport: &http.Transport{Proxy: nil, DisableKeepAlives: true},
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, config.ProbeURL, nil)
	if err != nil {
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		return fmt.Errorf("probe answered %d", resp.StatusCode)
	}
	return nil
}

// runHook runs the program at path with the event. Without up it runs only
// for "down", so a router whose lookups no longer go through the tunnel
// still removes what an earlier run left behind.
func runHook(path string, up bool, logs *engine.LogSink) func(string) {
	if path == "" {
		return nil
	}
	return func(event string) {
		if event == "up" && !up {
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		out, err := exec.CommandContext(ctx, path, event).CombinedOutput()
		if err != nil {
			logs.Printf("[router] hook %s: %v %s", event, err, strings.TrimSpace(string(out)))
		}
	}
}

// resolver looks door names up on the WAN, around a tunnel that may be up.
func resolver(binder engine.Binder) config.Resolver {
	r := &net.Resolver{PreferGo: true}
	if b, ok := binder.(interface {
		Bind(network, address string, c syscall.RawConn) error
	}); ok {
		d := &net.Dialer{Timeout: 5 * time.Second, Control: b.Bind}
		r.Dial = d.DialContext
	}
	return func(ctx context.Context, host string) ([]netip.Addr, error) {
		return r.LookupNetIP(ctx, "ip", host)
	}
}

func splitList(s string) []string {
	var out []string
	for _, part := range strings.Split(s, ",") {
		if part = strings.TrimSpace(part); part != "" {
			out = append(out, part)
		}
	}
	return out
}

func setAssetLocation(dir string) error {
	if dir == "" {
		exe, err := os.Executable()
		if err != nil {
			return err
		}
		dir = filepath.Dir(exe)
	}
	dir, err := filepath.Abs(dir)
	if err != nil {
		return err
	}
	for _, dat := range []string{"geoip.dat", "geosite.dat"} {
		if _, err := os.Stat(filepath.Join(dir, dat)); err != nil {
			return fmt.Errorf("no %s in %s; every routing rule needs it", dat, dir)
		}
	}
	return os.Setenv("XRAY_LOCATION_ASSET", dir)
}

func hello() map[string]any {
	return map[string]any{
		"protocol": control.ProtocolVersion,
		"core":     version,
		"xray":     core.Version(),
		"os":       runtime.GOOS,
		"arch":     runtime.GOARCH,
		"platform": "router",
	}
}

func call(args []string) error {
	if len(args) == 0 {
		return errors.New("call needs a method")
	}
	var params any
	if len(args) > 1 {
		params = json.RawMessage(args[1])
	}
	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	var out json.RawMessage
	if err := control.Call(ctx, control.Address, args[0], params, &out); err != nil {
		return err
	}
	if len(out) == 0 {
		out = json.RawMessage("null")
	}
	var pretty any
	if json.Unmarshal(out, &pretty) == nil {
		indented, _ := json.MarshalIndent(pretty, "", "  ")
		out = indented
	}
	fmt.Println(string(out))
	return nil
}
