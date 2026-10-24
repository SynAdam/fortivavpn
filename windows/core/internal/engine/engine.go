// Package engine runs the tunnel: one Xray instance that carries the PC's
// traffic, and short-lived ones that check doors.
//
// A connect follows Android's order. The doors start in an instance that
// captures nothing, a request is fetched through them, and only when that
// works does the TUN inbound go in and the PC's traffic move to the tunnel.
// A door can accept a connection and forward nothing, and a user should not
// lose their connection to find that out.
package engine

import (
	"context"
	"errors"
	"sync"
	"syscall"
	"time"

	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/proxy/autoselect"

	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/config"
	"github.com/fortiva/fortiva-vpn-clients/windows/core/internal/control"
)

// State is where the tunnel is. The strings are the ones the app's status
// stream carries on every platform (lib/services/vpn_service.dart).
type State string

const (
	Disconnected  State = "disconnected"
	Connecting    State = "connecting"
	Connected     State = "connected"
	Disconnecting State = "disconnecting"
	Failed        State = "failed"
)

// Reasons a tunnel failed to start or went down, in Status.Reason.
const (
	// ReasonConfig: the request could not be turned into a configuration.
	ReasonConfig = "config"
	// ReasonStart: the core refused the configuration.
	ReasonStart = "start"
	// ReasonVerify: the doors started but nothing came back through them.
	ReasonVerify = "verify"
	// ReasonAdapter: the Wintun adapter or its routes could not be set up.
	ReasonAdapter = "adapter"
	// ReasonKilled: the service stopped while the tunnel was up. Android
	// uses the same word when the system kills its tunnel.
	ReasonKilled = "killed"
)

// Status is the tunnel's state, numbered so a watcher can ask for anything
// newer than what it has.
type Status struct {
	Seq    uint64 `json:"seq"`
	State  State  `json:"state"`
	Reason string `json:"reason,omitempty"`
	// Error is the failure in the core's words, for logs and diagnostics.
	Error string `json:"error,omitempty"`
	// Since is when the tunnel entered this state, in Unix milliseconds.
	Since int64 `json:"since"`
	// Doors is how many doors the running tunnel holds.
	Doors int `json:"doors,omitempty"`
}

// Binder keeps the core's own connections on the physical network while the
// PC's traffic goes to the tunnel, so that the core does not dial its doors
// through itself.
type Binder interface {
	// SetActive turns binding on while a tunnel is starting or up.
	SetActive(active bool)
	// Control is the dialer hook that binds one socket.
	Control(network, address string, c syscall.RawConn) error
	// Network names the kind of network the core dials over: "wifi",
	// "ethernet", "mobile", "other", or "" when unknown.
	Network() string
}

// Options configure an Engine.
type Options struct {
	// Capture adds the TUN inbound once a door works. Without it the tunnel
	// only dials, which is how the core is exercised away from Windows.
	Capture bool
	// Resolve looks door host names up before the tunnel exists.
	Resolve config.Resolver
	// Binder is nil where nothing needs binding.
	Binder Binder
	Logs   *LogSink
	// VerifyURLs are fetched through the doors, in order, until one answers.
	VerifyURLs []string
	// VerifyTimeout bounds each of them. The app gives a whole connect 20
	// seconds before it calls the attempt failed.
	VerifyTimeout time.Duration
	// PingURL is what a door check fetches. Android's default, the group's
	// probe URL, when empty.
	PingURL string
}

// Engine is the tunnel. It is safe for concurrent use.
type Engine struct {
	opts Options

	mu      sync.Mutex
	status  Status
	changed chan struct{}
	inst    *core.Instance
	doors   []string
	attempt uint64
	cancel  context.CancelFunc
}

// New returns an engine with no tunnel.
func New(opts Options) *Engine {
	if len(opts.VerifyURLs) == 0 {
		opts.VerifyURLs = []string{config.ProbeURL, config.FallbackProbeURL}
	}
	if opts.VerifyTimeout <= 0 {
		opts.VerifyTimeout = 5 * time.Second
	}
	if opts.PingURL == "" {
		opts.PingURL = config.ProbeURL
	}
	if opts.Logs == nil {
		opts.Logs = NewLogSink(nil, false)
	}
	return &Engine{
		opts:    opts,
		status:  Status{State: Disconnected, Since: time.Now().UnixMilli()},
		changed: make(chan struct{}),
	}
}

// Status returns the tunnel's current status.
func (e *Engine) Status() Status {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.status
}

// Watch returns the status once it is newer than after, or the current one
// when ctx ends first. The app holds one Watch open at a time, which is how
// a status change reaches it without polling.
func (e *Engine) Watch(ctx context.Context, after uint64) Status {
	for {
		e.mu.Lock()
		st, changed := e.status, e.changed
		e.mu.Unlock()
		if st.Seq > after {
			return st
		}
		select {
		case <-changed:
		case <-ctx.Done():
			return st
		}
	}
}

// setLocked moves to a new state and wakes every watcher. e.mu must be held.
func (e *Engine) setLocked(state State, reason, errText string) {
	e.status = Status{
		Seq:    e.status.Seq + 1,
		State:  state,
		Reason: reason,
		Error:  errText,
		Since:  time.Now().UnixMilli(),
		Doors:  len(e.doors),
	}
	if state != Connected {
		e.status.Doors = 0
	}
	close(e.changed)
	e.changed = make(chan struct{})

	// The core's sockets are bound to the physical network from the moment
	// a capturing tunnel starts dialling: a door connection opened before
	// the routes moved, and reused after, would otherwise loop into the
	// tunnel it carries.
	if e.opts.Binder != nil && e.opts.Capture {
		e.opts.Binder.SetActive(state == Connecting || state == Connected)
	}
	e.opts.Logs.Printf("[engine] %s %s %s", state, reason, errText)
}

// Connect starts a tunnel through req's doors, replacing any running one.
// It returns once the attempt has started; the outcome arrives as a status
// change. A link that cannot be read is refused at once.
func (e *Engine) Connect(req config.Request) (Status, error) {
	if _, err := config.Ping(req.Link); err != nil {
		return e.Status(), control.Errorf(control.CodeInvalidLink, "%v", err)
	}

	e.mu.Lock()
	if e.cancel != nil {
		e.cancel()
	}
	old := e.inst
	e.inst, e.doors = nil, nil
	e.attempt++
	id := e.attempt
	ctx, cancel := context.WithCancel(context.Background())
	e.cancel = cancel
	e.setLocked(Connecting, "", "")
	st := e.status
	e.mu.Unlock()

	go func() {
		// The old tunnel goes first: its adapter holds the routes and its
		// name, and the new one is created with the same name.
		if old != nil {
			_ = old.Close()
		}
		e.run(ctx, id, req)
	}()
	return st, nil
}

func (e *Engine) run(ctx context.Context, id uint64, req config.Request) {
	fail := func(reason string, err error) {
		e.mu.Lock()
		defer e.mu.Unlock()
		if e.attempt == id {
			e.setLocked(Failed, reason, err.Error())
		}
	}

	resolveCtx, cancel := context.WithTimeout(ctx, 8*time.Second)
	built, err := config.Build(resolveCtx, req, e.opts.Resolve)
	cancel()
	if err != nil {
		fail(ReasonConfig, err)
		return
	}
	for i, why := range built.Skipped {
		e.opts.Logs.Printf("[engine] door %d left out: %s", i, why)
	}

	inst, err := startInstance(built.Config)
	if err != nil && len(built.Doors) > 1 {
		// Android falls back to the chosen door alone when the core refuses
		// the group, so a bad standby door cannot keep the user offline.
		e.opts.Logs.Printf("[engine] door group refused, trying the chosen door alone: %v", err)
		single := config.Request{Link: req.Link, DNS: req.DNS}
		if built, err = config.Build(ctx, single, e.opts.Resolve); err == nil {
			inst, err = startInstance(built.Config)
		}
	}
	if err != nil {
		fail(ReasonStart, err)
		return
	}

	took, err := verify(ctx, inst, e.opts.VerifyURLs, e.opts.VerifyTimeout)
	if err != nil {
		_ = inst.Close()
		fail(ReasonVerify, err)
		return
	}
	e.opts.Logs.Printf("[engine] doors answered in %v", took.Round(time.Millisecond))

	if e.opts.Capture {
		if err := addInbound(inst, built.Tun); err != nil {
			_ = inst.Close()
			fail(ReasonAdapter, err)
			return
		}
	}

	e.mu.Lock()
	defer e.mu.Unlock()
	if e.attempt != id {
		// Disconnected or replaced while starting.
		_ = inst.Close()
		return
	}
	e.inst, e.doors = inst, built.Doors
	e.setLocked(Connected, "", "")
}

// Disconnect closes the tunnel, or abandons one that is starting. Closing
// the instance removes the adapter, and the routes go with it.
func (e *Engine) Disconnect() Status {
	return e.stop("")
}

// Close is Disconnect for the service stopping: a tunnel that was up is
// reported as killed, which the app reports as a drop.
func (e *Engine) Close() Status {
	return e.stop(ReasonKilled)
}

func (e *Engine) stop(reason string) Status {
	e.mu.Lock()
	if e.cancel != nil {
		e.cancel()
		e.cancel = nil
	}
	e.attempt++
	inst := e.inst
	wasUp := inst != nil
	e.inst, e.doors = nil, nil
	if inst != nil {
		e.setLocked(Disconnecting, "", "")
	}
	e.mu.Unlock()

	if inst != nil {
		_ = inst.Close()
	}

	e.mu.Lock()
	defer e.mu.Unlock()
	if !wasUp {
		reason = ""
	}
	if e.status.State != Disconnected || reason != "" {
		e.setLocked(Disconnected, reason, "")
	}
	return e.status
}

// NetworkChanged tells a door group to measure its doors again: what it knew
// about them on the previous network no longer applies. Android does the
// same when the phone moves to another network.
func (e *Engine) NetworkChanged() {
	e.mu.Lock()
	group := e.inst != nil && len(e.doors) > 1
	e.mu.Unlock()
	if group {
		autoselect.KickAll()
	}
}

// running returns the tunnel's instance and doors, or nil when it is not up.
func (e *Engine) running() (*core.Instance, []string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.inst, e.doors
}

// ErrNotConnected is returned by calls that need a running tunnel.
var ErrNotConnected = errors.New("no tunnel is up")
