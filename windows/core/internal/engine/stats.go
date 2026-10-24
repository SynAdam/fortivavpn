package engine

import (
	"encoding/json"
	"strings"

	"github.com/xtls/xray-core/features/stats"
	"github.com/xtls/xray-core/proxy/autoselect"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
)

// TunnelStats is the tunnelStats call of the app's channel, as Android
// answers it: the bytes the doors carried since the previous call, and, when
// the tunnel holds several doors, the position of the one in use and what
// the group knows about each. It returns nil when no tunnel is up.
func (e *Engine) TunnelStats() map[string]any {
	inst, doors := e.running()
	if inst == nil {
		return nil
	}
	out := map[string]any{}
	if up, down, ok := proxyTraffic(inst.GetFeature(stats.ManagerType())); ok {
		out["bytes_up"], out["bytes_down"] = up, down
	} else {
		// No reading is not zero bytes: a beat that says the tunnel carried
		// nothing is a finding, and must not be made out of a missing count.
		out["bytes_up"], out["bytes_down"] = nil, nil
	}
	if len(doors) > 1 {
		if index, report, ok := doorStatus(); ok {
			out["door_index"] = index
			out["door_status"] = report
		}
	}
	if e.opts.Binder != nil {
		if network := e.opts.Binder.Network(); network != "" {
			out["network"] = network
		}
	}
	return out
}

// proxyTraffic reads and resets the byte counters of every door. A door's
// counters count its own connection to its server, so the doors of a group
// are summed and the group, which dials nothing itself, adds nothing.
// direct and block are not the tunnel.
func proxyTraffic(feature any) (up, down int64, ok bool) {
	manager, isManager := feature.(stats.Manager)
	if !isManager || manager == nil {
		return 0, 0, false
	}
	manager.VisitCounters(func(name string, counter stats.Counter) bool {
		parts := strings.Split(name, ">>>")
		if len(parts) != 4 || parts[0] != "outbound" || !strings.HasPrefix(parts[1], config.ProxyTag) {
			return true
		}
		switch parts[3] {
		case "uplink":
			up += counter.Set(0)
		case "downlink":
			down += counter.Set(0)
		}
		return true
	})
	return up, down, true
}

// doorReport is the door group as the app reports it, the same shape
// Android sends (V2RayServiceManager.doorReport): the group's recent moves
// between doors with the reason and time of each, and each door's
// measurements now. Doors are named by their position in the list the app
// sent, so the app never needs to know how the core spells their tags.
type doorReport struct {
	State       string       `json:"state"`
	SwitchCount int          `json:"switch_count"`
	Switches    []doorSwitch `json:"switches"`
	Doors       []doorFacts  `json:"doors"`
}

type doorSwitch struct {
	From   *int   `json:"from"`
	To     *int   `json:"to"`
	Reason string `json:"reason"`
	At     int64  `json:"at"`
}

type doorFacts struct {
	Index       int     `json:"index"`
	State       string  `json:"state"`
	DelayMs     int64   `json:"delay_ms"`
	JitterMs    int64   `json:"jitter_ms"`
	FailRatio   float64 `json:"fail_ratio"`
	Score       float64 `json:"score"`
	PenaltyMs   int64   `json:"penalty_ms"`
	Connections int     `json:"connections"`
	LastError   string  `json:"last_error,omitempty"`
}

// doorStatus returns the position of the door new connections go through
// and the group's report as JSON, or false when there is no group.
func doorStatus() (int, string, bool) {
	for _, group := range autoselect.Statuses() {
		if group.Tag != config.ProxyTag {
			continue
		}
		selected, ok := config.MemberIndex(group.Selected)
		if !ok {
			return 0, "", false
		}
		report := doorReport{State: group.State, SwitchCount: group.Switches, Switches: []doorSwitch{}, Doors: []doorFacts{}}
		for _, ev := range group.Events {
			report.Switches = append(report.Switches, doorSwitch{
				From: position(ev.From), To: position(ev.To), Reason: ev.Reason, At: ev.AtMs,
			})
		}
		for _, m := range group.Members {
			index, ok := config.MemberIndex(m.Tag)
			if !ok {
				continue
			}
			report.Doors = append(report.Doors, doorFacts{
				Index: index, State: m.State, DelayMs: m.DelayMs, JitterMs: m.JitterMs,
				FailRatio: m.FailRatio, Score: m.Score, PenaltyMs: m.PenaltyMs,
				Connections: m.Connections, LastError: strings.TrimSpace(m.LastError),
			})
		}
		raw, err := json.Marshal(report)
		if err != nil {
			return 0, "", false
		}
		return selected, string(raw), true
	}
	return 0, "", false
}

func position(tag string) *int {
	if i, ok := config.MemberIndex(tag); ok {
		return &i
	}
	return nil
}
