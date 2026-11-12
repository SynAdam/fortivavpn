package agent

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/engine"
)

// Tunnel is what the agent needs of the engine.
type Tunnel interface {
	Connect(req config.Request) (engine.Status, error)
	Disconnect() engine.Status
	Status() engine.Status
	Watch(ctx context.Context, after uint64) engine.Status
	RealPing(ctx context.Context, link string) int64
	TunnelStats() map[string]any
}

// Options configure an Agent.
type Options struct {
	Store  *Store
	API    *API
	Tunnel Tunnel
	// Platform is what the router registers as.
	Platform string
	Version  string
	// Model and OSVersion describe the router, for the backend's device row.
	Model     string
	OSVersion string
	// Language is the router's interface language, or "en".
	Language string
	// DNS is the resolvers lookups go to through the tunnel.
	DNS []string
	// Network names the WAN's kind ("ethernet", "mobile", "wifi").
	Network func() string
	// Liveness fetches a page through the tunnel every LivenessEvery, and a
	// tunnel that fails LivenessMisses checks in a row is replaced. Only a
	// router that captures its own traffic can check this way.
	Liveness       func(ctx context.Context) error
	LivenessEvery  time.Duration
	LivenessMisses int
	// Hook is told "up" when the tunnel carries traffic and "down" when it
	// stops, so the package can send the LAN's lookups through it. It is
	// also told "down" once when Run starts, since a process that was
	// killed could not say so itself.
	Hook func(event string)
	Logf func(format string, args ...any)

	// Timings, shortened by tests.
	Parallel      int
	Stagger       time.Duration
	PingTimeout   time.Duration
	ConnectWait   time.Duration
	RefreshEvery  time.Duration
	HeartbeatEach time.Duration
	RetryMin      time.Duration
	RetryMax      time.Duration
	ForgetFailed  time.Duration
	// NoDataWait is how long a router out of data waits before it asks the
	// backend again, unless the allowance resets sooner.
	NoDataWait time.Duration
}

func (o *Options) defaults() {
	if o.Platform == "" {
		o.Platform = "router"
	}
	if o.Language == "" {
		o.Language = "en"
	}
	if o.Logf == nil {
		o.Logf = func(string, ...any) {}
	}
	if o.Network == nil {
		o.Network = func() string { return "" }
	}
	if o.Hook == nil {
		o.Hook = func(string) {}
	}
	set := func(d *time.Duration, v time.Duration) {
		if *d <= 0 {
			*d = v
		}
	}
	// The app's defaults: four checks at once (door_parallel), staggered.
	if o.Parallel <= 0 {
		o.Parallel = 4
	}
	set(&o.Stagger, 300*time.Millisecond)
	set(&o.PingTimeout, 8*time.Second)
	set(&o.ConnectWait, 30*time.Second)
	set(&o.RefreshEvery, time.Hour)
	// The app's heartbeat interval (VpnService.heartbeatInterval).
	set(&o.HeartbeatEach, 5*time.Minute)
	set(&o.RetryMin, 15*time.Second)
	set(&o.RetryMax, 5*time.Minute)
	set(&o.ForgetFailed, 10*time.Minute)
	set(&o.NoDataWait, 15*time.Minute)
	set(&o.LivenessEvery, time.Minute)
	if o.LivenessMisses <= 0 {
		o.LivenessMisses = 3
	}
}

// State is what the agent is doing, for the router's status page.
type State string

const (
	StateStarting  State = "starting"
	StateSearching State = "searching"
	StateConnected State = "connected"
	StatePaused    State = "paused"
	StateOffline   State = "offline"
	StateNoData    State = "out_of_data"
)

// Status is the agent's answer to the status page.
type Status struct {
	State    State         `json:"state"`
	Since    int64         `json:"since"`
	DeviceID string        `json:"device_id"`
	Tunnel   engine.Status `json:"tunnel"`
	Door     *Path         `json:"door,omitempty"`
	Doors    int           `json:"doors"`
	Quota    *Quota        `json:"quota,omitempty"`
	Network  string        `json:"network,omitempty"`
	Route    string        `json:"api_route,omitempty"`
	Error    string        `json:"error,omitempty"`
	Version  string        `json:"version"`
	// ConfigsAt is when the doors were last fetched from the backend.
	ConfigsAt *time.Time `json:"configs_at,omitempty"`
}

// Agent keeps the router connected.
type Agent struct {
	o Options

	mu       sync.Mutex
	status   Status
	configs  *Configs
	memory   Memory
	failed   map[DoorKey]time.Time
	wake     chan struct{}
	events   []map[string]any
	deviceID string
}

// New returns an agent. Run starts it.
func New(o Options) *Agent {
	o.defaults()
	return &Agent{
		o:      o,
		status: Status{State: StateStarting, Since: time.Now().UnixMilli(), Version: o.Version},
		failed: map[DoorKey]time.Time{},
		wake:   make(chan struct{}, 1),
	}
}

// Status returns what the agent is doing now.
func (a *Agent) Status() Status {
	a.mu.Lock()
	defer a.mu.Unlock()
	st := a.status
	st.Tunnel = a.o.Tunnel.Status()
	st.Network = a.o.Network()
	st.Route = a.o.API.Route()
	if a.configs != nil {
		q := a.configs.Quota
		st.Quota = &q
		if at := a.configs.FetchedAt; !at.IsZero() {
			st.ConfigsAt = &at
		}
		st.Doors = len(a.configs.Usable())
	}
	return st
}

// SetPaused turns the tunnel off (true) or back on (false). The choice
// survives a restart.
func (a *Agent) SetPaused(paused bool) {
	a.mu.Lock()
	a.memory.Paused = paused
	m := a.memory
	a.mu.Unlock()
	if err := a.o.Store.SaveMemory(m); err != nil {
		a.o.Logf("[agent] save memory: %v", err)
	}
	a.poke()
}

// Refresh asks the agent to fetch its doors again at once, as after a
// Premium code changed what the router may use.
func (a *Agent) Refresh() {
	a.markStale()
	a.poke()
}

// markStale makes the next round fetch the doors again, without waking the
// agent. Run uses it after a wait of its own: a poke there would end the
// next wait at once.
func (a *Agent) markStale() {
	a.mu.Lock()
	if a.configs != nil {
		a.configs.FetchedAt = time.Time{}
	}
	a.mu.Unlock()
}

func (a *Agent) poke() {
	select {
	case a.wake <- struct{}{}:
	default:
	}
}

// DeviceID is the router's id with the backend.
func (a *Agent) DeviceID() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.deviceID
}

func (a *Agent) setState(s State, errText string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.status.State != s || a.status.Error != errText {
		a.o.Logf("[agent] %s %s", s, errText)
	}
	if a.status.State != s {
		a.status.Since = time.Now().UnixMilli()
	}
	a.status.State = s
	a.status.Error = errText
}

// Run keeps the router connected until ctx ends, then closes the tunnel.
func (a *Agent) Run(ctx context.Context) error {
	id, err := a.o.Store.DeviceID()
	if err != nil {
		return fmt.Errorf("device id: %w", err)
	}
	a.mu.Lock()
	a.deviceID = id
	a.status.DeviceID = id
	a.memory = a.o.Store.LoadMemory()
	if c, err := a.o.Store.LoadConfigs(); err == nil {
		a.configs = c
	}
	a.mu.Unlock()
	if len(a.memory.Relays) > 0 {
		a.o.API.SetRelays(a.memory.Relays)
	}
	// A process that crashed or was killed while its tunnel was up left the
	// lookups pointed at the tunnel. Without a tunnel they would go nowhere.
	a.o.Hook("down")

	defer func() {
		if a.o.Tunnel.Status().State == engine.Connected {
			a.o.Hook("down")
		}
		a.o.Tunnel.Disconnect()
	}()

	registered := false
	backoff := a.o.RetryMin
	for ctx.Err() == nil {
		if a.paused() {
			if a.o.Tunnel.Status().State != engine.Disconnected {
				a.o.Hook("down")
				a.o.Tunnel.Disconnect()
				a.event("disconnected", nil)
				a.flush(ctx)
			}
			a.setState(StatePaused, "")
			a.sleep(ctx, time.Hour)
			continue
		}
		if !registered {
			registered = a.register(ctx) == nil
			a.appConfig(ctx)
		}

		// Doors from the backend, asked around the tunnel so it orders them
		// for the router's own network; the saved ones when it cannot be
		// reached.
		if a.configsStale(a.o.RefreshEvery) {
			if err := a.fetch(ctx, true); err != nil {
				a.o.Logf("[agent] fetch doors: %v", err)
			}
		}
		cfg := a.currentConfigs()
		if cfg == nil {
			a.setState(StateOffline, "the backend could not be reached and no doors are saved")
			a.sleep(ctx, backoff)
			backoff = min(backoff*2, a.o.RetryMax)
			continue
		}
		if cfg.Quota.OutOfData() || len(cfg.Usable()) == 0 {
			a.setState(StateNoData, "")
			wait := a.o.NoDataWait
			if r := cfg.Quota.ResetsAt; r != nil && time.Until(*r) > 0 && time.Until(*r) < wait {
				wait = time.Until(*r) + 5*time.Second
			}
			a.sleep(ctx, wait)
			a.markStale()
			continue
		}

		if a.connect(ctx, cfg) {
			backoff = a.o.RetryMin
			a.stay(ctx)
			continue
		}
		// No door carried a tunnel. Ask the backend again before the next
		// round: the doors may have changed, and the network surely has.
		a.setState(StateOffline, "no door carried a tunnel")
		a.flush(ctx)
		a.sleep(ctx, backoff)
		backoff = min(backoff*2, a.o.RetryMax)
		a.markStale()
	}
	return nil
}

func (a *Agent) paused() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.memory.Paused
}

func (a *Agent) currentConfigs() *Configs {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.configs
}

func (a *Agent) configsStale(age time.Duration) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.configs == nil || time.Since(a.configs.FetchedAt) > age
}

// sleep waits for d, a poke or the end of ctx.
func (a *Agent) sleep(ctx context.Context, d time.Duration) {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
	case <-a.wake:
	case <-ctx.Done():
	}
}

func (a *Agent) register(ctx context.Context) error {
	body := map[string]any{
		"device_id":    a.DeviceID(),
		"platform":     a.o.Platform,
		"app_version":  a.o.Version,
		"device_model": a.o.Model,
		"os_version":   a.o.OSVersion,
		"language":     a.o.Language,
	}
	err := a.o.API.Post(ctx, "/api/v1/devices/register", body, nil, false)
	if err != nil {
		a.o.Logf("[agent] register: %v", err)
	}
	return err
}

// appConfig reads the backend's relays, which replace the built-in ones.
func (a *Agent) appConfig(ctx context.Context) {
	var out struct {
		Relays []Relay `json:"api_relays"`
	}
	if err := a.o.API.Get(ctx, "/api/v1/app/config", &out, false); err != nil {
		return
	}
	if relays := validRelays(out.Relays); len(relays) > 0 {
		a.o.API.SetRelays(relays)
		a.mu.Lock()
		a.memory.Relays = relays
		m := a.memory
		a.mu.Unlock()
		_ = a.o.Store.SaveMemory(m)
	}
}

// fetch asks the backend for the router's doors. aroundTunnel sends the
// request on the WAN, so the backend orders the doors for that network.
func (a *Agent) fetch(ctx context.Context, aroundTunnel bool) error {
	var c Configs
	body := map[string]any{"device_id": a.DeviceID(), "via_tunnel": !aroundTunnel && a.o.Tunnel.Status().State == engine.Connected}
	if err := a.o.API.Post(ctx, "/api/v1/configs/dedicated", body, &c, aroundTunnel); err != nil {
		var apiErr *APIError
		if errors.As(err, &apiErr) && apiErr.Status == http.StatusNotFound {
			// An unknown device: register before the next try.
			_ = a.register(ctx)
		}
		return err
	}
	c.FetchedAt = time.Now().UTC()
	a.mu.Lock()
	a.configs = &c
	a.mu.Unlock()
	if err := a.o.Store.SaveConfigs(&c); err != nil {
		a.o.Logf("[agent] save doors: %v", err)
	}
	return nil
}

// connect finds an open door and starts a tunnel through it. It reports
// whether a tunnel came up.
func (a *Agent) connect(ctx context.Context, cfg *Configs) bool {
	a.setState(StateSearching, "")
	a.mu.Lock()
	ordered := Order(cfg.Usable(), a.memory.LastDoor, a.failed, time.Now(), a.o.ForgetFailed)
	a.mu.Unlock()
	attempt := newAttemptID()

	ping := func(ctx context.Context, link string) int64 {
		ctx, cancel := context.WithTimeout(ctx, a.o.PingTimeout)
		defer cancel()
		return a.o.Tunnel.RealPing(ctx, link)
	}
	chosen, results := Search(ctx, ordered, ping, a.o.Parallel, a.o.Stagger)
	for i, ms := range results {
		if ms == -1 {
			a.noteFailed(ordered[i].Key())
		}
	}
	if chosen < 0 {
		a.event("connect_failed", map[string]any{"error": "no door open", "attempt_id": attempt})
		return false
	}

	// The chosen door, then the next open ones if it fails to carry.
	for chosen >= 0 && ctx.Err() == nil && !a.paused() {
		p := ordered[chosen]
		req := Request(ordered, chosen, results, a.o.DNS)
		a.o.Logf("[agent] connecting through %s on server %d with %d standby doors", p.Door, p.ServerID, len(req.Alternates))
		st, err := a.o.Tunnel.Connect(req)
		if err == nil {
			st = a.await(ctx, st.Seq)
		}
		if err == nil && st.State == engine.Connected {
			a.mu.Lock()
			k := p.Key()
			a.memory.LastDoor = &k
			delete(a.failed, k)
			m := a.memory
			door := p
			a.status.Door = &door
			a.mu.Unlock()
			_ = a.o.Store.SaveMemory(m)
			a.setState(StateConnected, "")
			a.o.Hook("up")
			a.event("connected", map[string]any{"door": p.Door, "server_host": p.Host(), "attempt_id": attempt})
			a.flush(ctx)
			return true
		}
		reason := "connect_failed"
		text := ""
		if err != nil {
			text = err.Error()
		} else {
			text = st.Error
			if st.Reason == engine.ReasonVerify {
				reason = "verify_failed"
			}
		}
		a.noteFailed(p.Key())
		a.event(reason, map[string]any{"door": p.Door, "server_host": p.Host(), "error": text, "attempt_id": attempt})
		chosen = nextOpen(results, chosen)
	}
	return false
}

// nextOpen is the next door after i that a check found open.
func nextOpen(results []int64, i int) int {
	for j := i + 1; j < len(results); j++ {
		if results[j] >= 0 {
			return j
		}
	}
	return -1
}

// await waits until the tunnel has left "connecting".
func (a *Agent) await(ctx context.Context, after uint64) engine.Status {
	ctx, cancel := context.WithTimeout(ctx, a.o.ConnectWait)
	defer cancel()
	for {
		st := a.o.Tunnel.Watch(ctx, after)
		if st.State != engine.Connecting || ctx.Err() != nil {
			return st
		}
		after = st.Seq
	}
}

// stay keeps the tunnel up: it beats every HeartbeatEach, fetches the doors
// every RefreshEvery, checks the tunnel carries traffic, and returns when the
// tunnel went down, the person paused it, or the allowance ran out.
func (a *Agent) stay(ctx context.Context) {
	up := time.Now()
	beat := time.NewTicker(a.o.HeartbeatEach)
	defer beat.Stop()
	live := time.NewTicker(a.o.LivenessEvery)
	defer live.Stop()
	refresh := time.NewTicker(a.o.RefreshEvery)
	defer refresh.Stop()
	misses := 0

	watchCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	changed := make(chan engine.Status, 1)
	go func() {
		seq := a.o.Tunnel.Status().Seq
		for watchCtx.Err() == nil {
			st := a.o.Tunnel.Watch(watchCtx, seq)
			if st.Seq > seq {
				seq = st.Seq
				if st.State != engine.Connected {
					select {
					case changed <- st:
					default:
					}
					return
				}
			}
		}
	}()

	// end closes the session. The lookups go back to the WAN first. The
	// last beat goes next, while the core still holds the bytes since the
	// one before. Then the event, which still names the door, and the door
	// is cleared so later events do not carry it.
	end := func(kind string, extra map[string]any, disconnect, failed bool) {
		a.o.Hook("down")
		a.heartbeat(up)
		if disconnect {
			a.o.Tunnel.Disconnect()
		}
		if extra == nil {
			extra = map[string]any{}
		}
		extra["duration_seconds"] = int(time.Since(up).Seconds())
		a.event(kind, extra)
		a.mu.Lock()
		if failed && a.status.Door != nil {
			a.failed[a.status.Door.Key()] = time.Now()
		}
		a.status.Door = nil
		a.mu.Unlock()
		a.flush(ctx)
	}
	// noData ends the session when a fetch says the allowance is spent or
	// no door is left, and reports whether it did.
	noData := func() bool {
		reason := a.refreshWhileUp(ctx)
		if reason == "" {
			return false
		}
		end("disconnected", map[string]any{"diag": map[string]any{"reason": reason}}, true, false)
		return true
	}

	for {
		select {
		case <-ctx.Done():
			// The service is stopping. procd kills the process if it takes
			// too long, so the lookups go back to the WAN before anything
			// that waits on the backend.
			a.o.Hook("down")
			a.heartbeat(up)
			a.event("disconnected", map[string]any{"duration_seconds": int(time.Since(up).Seconds())})
			flushCtx, done := context.WithTimeout(context.Background(), 5*time.Second)
			a.flush(flushCtx)
			done()
			return
		case st := <-changed:
			end("dropped", map[string]any{"error": st.Reason + " " + st.Error}, false, true)
			return
		case <-a.wake:
			if a.paused() {
				end("disconnected", nil, true, false)
				return
			}
			if noData() {
				return
			}
		case <-beat.C:
			a.heartbeat(up)
			a.flush(ctx)
		case <-refresh.C:
			if noData() {
				return
			}
		case <-live.C:
			if a.o.Liveness == nil {
				continue
			}
			lctx, done := context.WithTimeout(ctx, 15*time.Second)
			err := a.o.Liveness(lctx)
			done()
			if err == nil {
				misses = 0
				continue
			}
			misses++
			a.o.Logf("[agent] the tunnel did not carry a check (%d of %d): %v", misses, a.o.LivenessMisses, err)
			if misses >= a.o.LivenessMisses {
				end("dropped", map[string]any{"error": "stalled"}, true, true)
				return
			}
		}
	}
}

// refreshWhileUp fetches the doors through the tunnel and says why the
// tunnel must close: "out_of_data" when the allowance ran out, "no_doors"
// when the backend sent none. It returns "" to keep the tunnel.
func (a *Agent) refreshWhileUp(ctx context.Context) string {
	if err := a.fetch(ctx, false); err != nil {
		a.o.Logf("[agent] refresh doors: %v", err)
		return ""
	}
	cfg := a.currentConfigs()
	switch {
	case cfg == nil:
		return ""
	case cfg.Quota.OutOfData():
		return "out_of_data"
	case len(cfg.Usable()) == 0:
		return "no_doors"
	}
	return ""
}

func (a *Agent) noteFailed(k DoorKey) {
	a.mu.Lock()
	a.failed[k] = time.Now()
	a.mu.Unlock()
}

// heartbeat queues a beat with the bytes the doors carried since the last
// one, from the core's own counters, as the app's beat carries them.
func (a *Agent) heartbeat(up time.Time) {
	stats := a.o.Tunnel.TunnelStats()
	if stats == nil {
		return
	}
	extra := map[string]any{"duration_seconds": int(time.Since(up).Seconds())}
	if v, ok := stats["bytes_up"].(int64); ok {
		extra["bytes_up"] = v
	}
	if v, ok := stats["bytes_down"].(int64); ok {
		extra["bytes_down"] = v
	}
	diag := map[string]any{}
	if v, ok := stats["door_index"]; ok {
		diag["door_index"] = v
	}
	if len(diag) > 0 {
		extra["diag"] = diag
	}
	a.event("heartbeat", extra)
}

// event queues one row for /devices/{id}/events.
func (a *Agent) event(kind string, extra map[string]any) {
	e := map[string]any{
		"type":        kind,
		"app_version": a.o.Version,
		"platform":    a.o.Platform,
		"os_version":  a.o.OSVersion,
		"client_ts":   time.Now().UTC().Format(time.RFC3339),
	}
	if n := a.o.Network(); n != "" {
		e["network_type"] = n
	}
	a.mu.Lock()
	if door := a.status.Door; door != nil {
		e["door"] = door.Door
		e["server_host"] = door.Host()
	}
	a.mu.Unlock()
	for k, v := range extra {
		e[k] = v
	}
	a.mu.Lock()
	a.events = append(a.events, e)
	// A router that cannot reach the backend for days keeps the newest.
	if over := len(a.events) - 200; over > 0 {
		a.events = a.events[over:]
	}
	a.mu.Unlock()
}

// flush sends the queued events, and keeps them for the next try when the
// backend cannot be reached.
func (a *Agent) flush(ctx context.Context) {
	a.mu.Lock()
	batch := a.events
	a.events = nil
	a.mu.Unlock()
	if len(batch) == 0 {
		return
	}
	viaTunnel := a.o.Tunnel.Status().State == engine.Connected
	body := map[string]any{
		"events":     batch,
		"via_tunnel": viaTunnel,
		"sent_at":    time.Now().UTC().Format(time.RFC3339),
	}
	err := a.o.API.Post(ctx, "/api/v1/devices/"+a.DeviceID()+"/events", body, nil, false)
	var apiErr *APIError
	if err != nil && !errors.As(err, &apiErr) {
		a.mu.Lock()
		a.events = append(batch, a.events...)
		a.mu.Unlock()
	}
}

// Redeem applies a Premium code to the router, then fetches its doors
// again, since Premium changes them.
func (a *Agent) Redeem(ctx context.Context, code string) (map[string]any, error) {
	var out map[string]any
	err := a.o.API.Post(ctx, "/api/v1/devices/"+a.DeviceID()+"/billing/redeem", map[string]any{"code": code}, &out, false)
	if err != nil {
		return nil, err
	}
	a.Refresh()
	return out, nil
}

func newAttemptID() string {
	var b [8]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}
