package main

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/xtls/xray-core/core"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/control"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
)

// newHandler maps the calls of the control pipe to the engine. Where a call
// has a twin on the app's mobile channel (com.vpn.fortivavpn/tunnel) it has
// that name and answers in that shape, so the app's Windows bridge passes it
// through.
func newHandler(eng *engine.Engine, logs *engine.LogSink, binder engine.Binder) control.Handler {
	return func(ctx context.Context, method string, params json.RawMessage) (any, error) {
		switch method {
		case "hello":
			return hello(), nil

		case "status":
			return eng.Status(), nil

		case "watch":
			// Blocks until the status is newer than "after", so the app hears
			// of a change at once without polling. Bounded under the
			// server's call timeout; the app just asks again.
			var p struct {
				After     uint64 `json:"after"`
				TimeoutMs int    `json:"timeoutMs"`
			}
			if err := decode(params, &p); err != nil {
				return nil, err
			}
			wait := time.Duration(p.TimeoutMs) * time.Millisecond
			if wait <= 0 || wait > 25*time.Second {
				wait = 25 * time.Second
			}
			ctx, cancel := context.WithTimeout(ctx, wait)
			defer cancel()
			return eng.Watch(ctx, p.After), nil

		case "connect":
			var req config.Request
			if err := decode(params, &req); err != nil {
				return nil, err
			}
			return eng.Connect(req)

		case "disconnect":
			return eng.Disconnect(), nil

		case "tunnelStats":
			return eng.TunnelStats(), nil

		case "realPing", "realPingDetail":
			var p struct {
				Link string `json:"link"`
			}
			if err := decode(params, &p); err != nil {
				return nil, err
			}
			if method == "realPing" {
				return eng.RealPing(ctx, p.Link), nil
			}
			return eng.RealPingDetail(ctx, p.Link), nil

		case "drainSiteStats":
			return logs.DrainSites(), nil

		case "place":
			return place(), nil

		case "diagnostics":
			st := eng.Status()
			d := map[string]any{
				"core":     version,
				"xray":     core.Version(),
				"state":    string(st.State),
				"core_log": strings.Join(logs.Tail(80), "\n"),
			}
			if st.Reason != "" {
				d["failure"] = st.Reason
				d["failure_error"] = st.Error
			}
			if binder != nil {
				if network := binder.Network(); network != "" {
					d["network"] = network
				}
			}
			return d, nil

		case "logs":
			var p struct {
				Lines int `json:"lines"`
			}
			if err := decode(params, &p); err != nil {
				return nil, err
			}
			return logs.Tail(p.Lines), nil

		default:
			return nil, control.Errorf(control.CodeUnknownMethod, "%s", method)
		}
	}
}

// decode reads a call's parameters, refusing fields the call does not have:
// a misspelt field from the app should fail loudly, not be ignored.
func decode(params json.RawMessage, v any) error {
	if len(params) == 0 || string(params) == "null" {
		return nil
	}
	dec := json.NewDecoder(bytes.NewReader(params))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return control.Errorf(control.CodeBadRequest, "params: %v", err)
	}
	return nil
}
