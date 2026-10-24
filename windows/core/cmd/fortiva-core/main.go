// Copyright (C) 2026 NimusAI. GPL-3.0-or-later, with the additional terms
// under section 7 in LICENSING.md.

// Command fortiva-core is the Windows tunnel of the Fortiva app: Xray-core
// with android/core/patches applied, its Wintun TUN inbound, and the control
// pipe the app drives it through (internal/control).
//
//	fortiva-core service     run under the service manager; what the installer registers
//	fortiva-core run         the same in a console, for development (as administrator on Windows)
//	fortiva-core install     register the service and start it (administrator)
//	fortiva-core stop        stop the service and wait, closing any tunnel (administrator)
//	fortiva-core uninstall   stop the service and remove it (administrator)
//	fortiva-core version     print what the core was built from
//	fortiva-core call M [P]  send method M with JSON params P to a running core and print the answer
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net"
	"net/netip"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	xlog "github.com/xtls/xray-core/common/log"
	"github.com/xtls/xray-core/core"
	_ "github.com/xtls/xray-core/main/distro/all"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/control"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/service"
)

// version is set by build.sh from the app's version in pubspec.yaml.
var version = "dev"

func main() {
	cmd := "help"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}
	var err error
	switch cmd {
	case "service":
		err = service.Run(func(ctx context.Context) error {
			return serve(ctx, engine.NewLogSink(nil, false), "")
		})
	case "run":
		err = runConsole(os.Args[2:])
	case "install":
		var exe string
		if exe, err = os.Executable(); err == nil {
			err = service.Install(exe)
		}
	case "stop":
		err = service.Stop()
	case "uninstall":
		err = service.Uninstall()
	case "version":
		out, _ := json.MarshalIndent(hello(), "", "  ")
		fmt.Println(string(out))
	case "call":
		err = call(os.Args[2:])
	default:
		fmt.Fprintln(os.Stderr, "usage: fortiva-core service | run [-assets DIR] [-debug] | install | stop | uninstall | version | call METHOD [JSON]")
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "fortiva-core:", err)
		os.Exit(1)
	}
}

func runConsole(args []string) error {
	flags := flag.NewFlagSet("run", flag.ExitOnError)
	assets := flags.String("assets", "", "directory holding geoip.dat and geosite.dat (default: next to the executable)")
	debug := flags.Bool("debug", false, "log the core's debug messages too")
	_ = flags.Parse(args)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	return serve(ctx, engine.NewLogSink(os.Stderr, *debug), *assets)
}

// serve runs the tunnel and its control endpoint until ctx ends, then closes
// the tunnel, which removes the adapter and its routes.
func serve(ctx context.Context, logs *engine.LogSink, assets string) error {
	if err := setAssetLocation(assets); err != nil {
		return err
	}
	// The one log handler of the process; instances are started without
	// their own (engine.LogSink).
	xlog.RegisterHandler(logs)

	var eng *engine.Engine
	binder, err := engine.NewBinder(func() {
		if eng != nil {
			logs.Printf("[engine] the network changed; measuring the doors again")
			eng.NetworkChanged()
		}
	})
	if err != nil {
		return fmt.Errorf("watch the routing table: %w", err)
	}
	eng = engine.New(engine.Options{
		// Only Windows captures traffic. Elsewhere the core dials through
		// its doors and nothing more, which is enough to drive it from the
		// app and the tests.
		Capture: runtime.GOOS == "windows",
		Resolve: resolve,
		Binder:  binder,
		Logs:    logs,
	})

	l, err := control.Listen(control.Address)
	if err != nil {
		return fmt.Errorf("open %s: %w", control.Address, err)
	}
	logs.Printf("[core] %s (Xray %s) listening on %s", version, core.Version(), control.Address)

	srv := &control.Server{Handler: newHandler(eng, logs, binder), Logf: logs.Printf}
	err = srv.Serve(ctx, l)
	eng.Close()
	return err
}

// setAssetLocation tells the core where the routing data is. A service runs
// in System32, so nothing may be left to the working directory.
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

func resolve(ctx context.Context, host string) ([]netip.Addr, error) {
	return net.DefaultResolver.LookupNetIP(ctx, "ip", host)
}

func hello() map[string]any {
	return map[string]any{
		"protocol": control.ProtocolVersion,
		"core":     version,
		"xray":     core.Version(),
		"os":       runtime.GOOS,
		"arch":     runtime.GOARCH,
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
