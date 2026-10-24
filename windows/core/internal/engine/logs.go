package engine

import (
	"fmt"
	"io"
	"regexp"
	"strings"
	"sync"
	"time"

	xlog "github.com/xtls/xray-core/common/log"
)

// LogSink is the one log handler of the process.
//
// Xray keeps a single log handler for the whole process, and each instance's
// log module installs its own when the instance is created. A door check
// would then take the tunnel's log with it when it closed, and with the log
// the sites the heartbeat reports. So the engine strips the log module out of
// every instance it starts (see stripLogApp) and this sink receives every
// message from all of them.
type LogSink struct {
	mu    sync.Mutex
	lines []string
	next  int
	full  bool
	out   io.Writer
	debug bool

	sites *siteTally
}

// ringLines is how much of the log the diagnostics carry back.
const ringLines = 400

// maxLine bounds one stored line; an error that quotes a whole response
// should not push everything else out of the ring.
const maxLine = 600

// NewLogSink returns a sink that also writes every line to out when it is
// not nil, which is what "fortiva-core run" does with the console.
func NewLogSink(out io.Writer, debug bool) *LogSink {
	return &LogSink{lines: make([]string, ringLines), out: out, debug: debug, sites: newSiteTally()}
}

// Handle implements xray's log.Handler.
func (s *LogSink) Handle(msg xlog.Message) {
	switch m := msg.(type) {
	case *xlog.GeneralMessage:
		if m.Severity == xlog.Severity_Debug && !s.debug {
			return
		}
	case *xlog.AccessMessage:
		// The access log is off in every configuration; a stray one is
		// a connection list nobody asked to keep.
		return
	}
	line := msg.String()
	s.sites.observe(line)
	s.Printf("%s", line)
}

// Printf adds one line of the engine's own.
func (s *LogSink) Printf(format string, args ...any) {
	line := time.Now().Format("15:04:05.000 ") + fmt.Sprintf(format, args...)
	if len(line) > maxLine {
		line = line[:maxLine] + "..."
	}
	s.mu.Lock()
	s.lines[s.next] = line
	s.next = (s.next + 1) % len(s.lines)
	if s.next == 0 {
		s.full = true
	}
	out := s.out
	s.mu.Unlock()
	if out != nil {
		fmt.Fprintln(out, line)
	}
}

// Tail returns up to n of the most recent lines, oldest first.
func (s *LogSink) Tail(n int) []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	var all []string
	if s.full {
		all = append(all, s.lines[s.next:]...)
	}
	all = append(all, s.lines[:s.next]...)
	if n > 0 && len(all) > n {
		all = all[len(all)-n:]
	}
	return all
}

// DrainSites returns the hosts that went through the tunnel since the last
// drain, with how many connections each had.
func (s *LogSink) DrainSites() map[string]int { return s.sites.drain() }

// siteTally counts the hosts the core sniffed from the user's own traffic,
// for the operators' Sites view, as SiteStats does on Android.
//
// A host is counted only when the core then routed that connection through
// the tunnel. The core logs "sniffed domain: <host>" before it picks the
// route, and the route right after under the same session id, as "taking
// detour [<tag>]" or "default route for"; direct and block are not the
// tunnel. Counting by route rather than by domain list also leaves out sites
// that went direct because of their Iranian address.
type siteTally struct {
	mu      sync.Mutex
	counts  map[string]int
	waiting map[string]string // session id -> host, sniffed but not yet routed
	order   []string          // waiting's ids, oldest first
}

// maxWaiting bounds connections sniffed but not yet routed. A route line
// that never comes would otherwise grow the map for the life of the tunnel.
const maxWaiting = 1000

var (
	sniffedLine = regexp.MustCompile(`\[(\d+)\] app/dispatcher: sniffed domain: (\S+)`)
	routedLine  = regexp.MustCompile(`\[(\d+)\] app/dispatcher: (?:taking detour \[([^\]]*)\]|default route for)`)
)

func newSiteTally() *siteTally {
	return &siteTally{counts: map[string]int{}, waiting: map[string]string{}}
}

func (t *siteTally) observe(line string) {
	if !strings.Contains(line, "app/dispatcher: ") {
		return
	}
	if m := sniffedLine.FindStringSubmatch(line); m != nil {
		host := strings.TrimSuffix(strings.ToLower(m[2]), ".")
		if host == "" {
			return
		}
		t.mu.Lock()
		if _, seen := t.waiting[m[1]]; !seen {
			t.order = append(t.order, m[1])
		}
		t.waiting[m[1]] = host
		for len(t.order) > maxWaiting {
			delete(t.waiting, t.order[0])
			t.order = t.order[1:]
		}
		t.mu.Unlock()
		return
	}
	m := routedLine.FindStringSubmatch(line)
	if m == nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	host, ok := t.waiting[m[1]]
	if !ok {
		return
	}
	delete(t.waiting, m[1])
	for i, id := range t.order {
		if id == m[1] {
			t.order = append(t.order[:i], t.order[i+1:]...)
			break
		}
	}
	// "default route" leaves the tag empty, and the default route is the
	// tunnel.
	if tag := m[2]; tag == "direct" || tag == "block" {
		return
	}
	t.counts[host]++
}

func (t *siteTally) drain() map[string]int {
	t.mu.Lock()
	defer t.mu.Unlock()
	counts := t.counts
	t.counts = map[string]int{}
	return counts
}
