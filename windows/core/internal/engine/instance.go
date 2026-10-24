package engine

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	applog "github.com/xtls/xray-core/app/log"
	xnet "github.com/xtls/xray-core/common/net"
	"github.com/xtls/xray-core/common/serial"
	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/infra/conf"
	confserial "github.com/xtls/xray-core/infra/conf/serial"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/xray"
)

var logAppType = serial.ToTypedMessage(&applog.Config{}).Type

// startInstance builds cfg the way the core's own loader does, refusing any
// field it does not know, and starts it. The log module is left out: see
// LogSink for why.
func startInstance(cfg *xray.Config) (*core.Instance, error) {
	raw, err := json.Marshal(cfg)
	if err != nil {
		return nil, err
	}
	parsed, err := confserial.DecodeJSONConfigStrict(bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("configuration: %w", err)
	}
	built, err := parsed.Build()
	if err != nil {
		return nil, fmt.Errorf("configuration: %w", err)
	}
	stripLogApp(built)

	inst, err := core.New(built)
	if err != nil {
		return nil, fmt.Errorf("core: %w", err)
	}
	if err := inst.Start(); err != nil {
		_ = inst.Close()
		return nil, fmt.Errorf("core: %w", err)
	}
	return inst, nil
}

func stripLogApp(c *core.Config) {
	apps := c.App[:0]
	for _, app := range c.App {
		if app.Type != logAppType {
			apps = append(apps, app)
		}
	}
	c.App = apps
}

// addInbound adds an inbound to a running instance. For the TUN inbound this
// is the moment the adapter appears and the routes move to it.
func addInbound(inst *core.Instance, in xray.Inbound) error {
	raw, err := json.Marshal(in)
	if err != nil {
		return err
	}
	var detour conf.InboundDetourConfig
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&detour); err != nil {
		return fmt.Errorf("inbound: %w", err)
	}
	built, err := detour.Build()
	if err != nil {
		return fmt.Errorf("inbound: %w", err)
	}
	return core.AddInboundHandler(inst, built)
}

// httpThrough returns a client whose every connection goes through inst's
// routing, which for anything but Iranian and private addresses is its
// "proxy" outbound.
func httpThrough(inst *core.Instance, timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			DisableKeepAlives:     true,
			TLSHandshakeTimeout:   timeout,
			ResponseHeaderTimeout: timeout,
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				dest, err := xnet.ParseDestination(network + ":" + addr)
				if err != nil {
					return nil, err
				}
				return core.Dial(ctx, inst, dest)
			},
		},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
}

// probe fetches url through inst and returns how long it took. Only 204 and
// 200 count: a captive portal or a filter page answers too, with something
// else.
func probe(ctx context.Context, inst *core.Instance, url string, timeout time.Duration) (time.Duration, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, err
	}
	start := time.Now()
	resp, err := httpThrough(inst, timeout).Do(req)
	if err != nil {
		return 0, err
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 64<<10))
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("probe answered HTTP %d", resp.StatusCode)
	}
	return time.Since(start), nil
}

// verify checks that traffic flows through inst before the PC's traffic is
// handed to it, as Android does with its proxy-only start: a door can accept
// the connection and still forward nothing. Each URL gets one try.
func verify(ctx context.Context, inst *core.Instance, urls []string, timeout time.Duration) (time.Duration, error) {
	var errs []error
	for _, url := range urls {
		took, err := probe(ctx, inst, url, timeout)
		if err == nil {
			return took, nil
		}
		errs = append(errs, err)
		if ctx.Err() != nil {
			break
		}
	}
	return 0, errors.Join(errs...)
}
