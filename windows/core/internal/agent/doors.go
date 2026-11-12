package agent

import (
	"context"
	"net/url"
	"strconv"
	"sync"
	"time"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
)

// Quota is QuotaStatus in the backend's configs answer.
type Quota struct {
	Unlimited      bool       `json:"unlimited"`
	LimitBytes     int64      `json:"limit_bytes"`
	UsedBytes      int64      `json:"used_bytes"`
	RemainingBytes int64      `json:"remaining_bytes"`
	Blocked        bool       `json:"blocked"`
	BonusBytes     int64      `json:"bonus_bytes,omitempty"`
	PromoBytes     int64      `json:"promo_bytes,omitempty"`
	ResetsAt       *time.Time `json:"resets_at,omitempty"`
}

// OutOfData says whether the allowance is spent. The backend sends no doors
// then, as it does to a phone.
func (q Quota) OutOfData() bool {
	return q.Blocked || (!q.Unlimited && q.LimitBytes > 0 && q.RemainingBytes <= 0)
}

// Path is one door of one server (DedicatedPath in the backend).
type Path struct {
	ServerID  int    `json:"server_id"`
	InboundID int    `json:"inbound_id"`
	Door      string `json:"door"`
	Label     string `json:"label"`
	URI       string `json:"uri"`
	Preferred bool   `json:"preferred,omitempty"`
	PenaltyMs int64  `json:"penalty_ms,omitempty"`
}

// Key names the door for the memory of what worked and what failed.
func (p Path) Key() DoorKey { return DoorKey{ServerID: p.ServerID, InboundID: p.InboundID} }

// Host is the address the door dials, for the reports' server_host.
func (p Path) Host() string {
	u, err := url.Parse(p.URI)
	if err != nil {
		return ""
	}
	return u.Hostname()
}

// Configs is the part of the backend's /configs/dedicated answer the router
// uses.
type Configs struct {
	Configs []string `json:"configs"`
	Paths   []Path   `json:"paths"`
	Quota   Quota    `json:"quota"`
	// FetchedAt is when the agent got this answer. Not from the backend,
	// and not saved: an answer that did not change then writes nothing to
	// the flash, and a router that restarts asks the backend at once.
	FetchedAt time.Time `json:"-"`
}

// Usable is every door that can be dialled, in the backend's order. A
// backend that sends no paths sends one config per server, as for the
// oldest app builds.
func (c *Configs) Usable() []Path {
	var out []Path
	for _, p := range c.Paths {
		if p.URI != "" && p.Door != "" {
			out = append(out, p)
		}
	}
	if len(out) > 0 {
		return out
	}
	for i, uri := range c.Configs {
		if uri != "" {
			out = append(out, Path{ServerID: -1 - i, Door: "config", URI: uri})
		}
	}
	return out
}

// Order puts the door that last worked first, then the others in the
// backend's order, and the doors that failed lately last, in the order
// they failed. The backend orders the doors for the network the request
// came from, so its order is kept wherever memory says nothing.
func Order(paths []Path, last *DoorKey, failed map[DoorKey]time.Time, now time.Time, forget time.Duration) []Path {
	var first, rest, late []Path
	for _, p := range paths {
		k := p.Key()
		if at, ok := failed[k]; ok && now.Sub(at) < forget {
			late = append(late, p)
			continue
		}
		if last != nil && k == *last {
			first = append(first, p)
			continue
		}
		rest = append(rest, p)
	}
	// Oldest failure first, so the door that failed longest ago is tried
	// before the one that just did.
	for i := 1; i < len(late); i++ {
		for j := i; j > 0 && failed[late[j].Key()].Before(failed[late[j-1].Key()]); j-- {
			late[j], late[j-1] = late[j-1], late[j]
		}
	}
	out := append(first, rest...)
	return append(out, late...)
}

// Pinger checks one door: the milliseconds a request through it took, or
// -1 when nothing came back.
type Pinger func(ctx context.Context, link string) int64

// Search checks the doors several at a time and returns the index of the
// first open one in order, as the app's checklist does: the door a one by
// one search would land on, found sooner. It returns -1 when none is open,
// and the result of every check that finished, by index (-2 for a check
// that never ran, or that the end of the search cut short).
func Search(ctx context.Context, paths []Path, ping Pinger, parallel int, stagger time.Duration) (int, []int64) {
	if parallel < 1 {
		parallel = 1
	}
	results := make([]int64, len(paths))
	done := make([]chan struct{}, len(paths))
	for i := range results {
		results[i] = -2
		done[i] = make(chan struct{})
	}
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	var mu sync.Mutex
	next := 0
	var wg sync.WaitGroup
	for w := 0; w < parallel && w < len(paths); w++ {
		wg.Add(1)
		go func(w int) {
			defer wg.Done()
			// Staggered, so a door that is open answers first rather than
			// four checks fighting over one slow uplink.
			select {
			case <-time.After(time.Duration(w) * stagger):
			case <-ctx.Done():
				return
			}
			for {
				mu.Lock()
				i := next
				next++
				mu.Unlock()
				if i >= len(paths) || ctx.Err() != nil {
					return
				}
				ms := ping(ctx, paths[i].URI)
				// A check cut short because the search ended found nothing
				// about its door, so it stays -2 and is not counted closed.
				if ms >= 0 || ctx.Err() == nil {
					mu.Lock()
					results[i] = ms
					mu.Unlock()
				}
				close(done[i])
			}
		}(w)
	}

	chosen := -1
	for i := range paths {
		select {
		case <-done[i]:
		case <-ctx.Done():
		}
		if ctx.Err() != nil {
			break
		}
		mu.Lock()
		ms := results[i]
		mu.Unlock()
		if ms >= 0 {
			chosen = i
			break
		}
	}
	cancel()
	wg.Wait()
	return chosen, results
}

// Request is the connect request for the door at chosen in paths, with up
// to config.MaxAlternates standby doors: the doors after it in order that
// a check did not find closed. The core's door group moves a failed
// connection to one of them by itself.
func Request(paths []Path, chosen int, results []int64, dns []string) config.Request {
	p := paths[chosen]
	req := config.Request{
		Link:      p.URI,
		Exits:     []string{exitOf(p)},
		Penalties: []int64{p.PenaltyMs},
		DNS:       dns,
	}
	for i := chosen + 1; i < len(paths) && len(req.Alternates) < config.MaxAlternates; i++ {
		if i < len(results) && results[i] == -1 {
			continue
		}
		req.Alternates = append(req.Alternates, paths[i].URI)
		req.Exits = append(req.Exits, exitOf(paths[i]))
		req.Penalties = append(req.Penalties, paths[i].PenaltyMs)
	}
	return req
}

// exitOf names the server a door leaves from. The core only compares them,
// to prefer a standby door on the same server.
func exitOf(p Path) string {
	if p.ServerID > 0 {
		return "s" + strconv.Itoa(p.ServerID)
	}
	return p.Host()
}
