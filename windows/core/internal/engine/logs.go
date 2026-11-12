package engine

import (
	"fmt"
	"io"
	"sync"
	"time"

	xlog "github.com/xtls/xray-core/common/log"
)

// LogSink is the one log handler of the process.
//
// Xray keeps a single log handler for the whole process, and each instance's
// log module installs its own when the instance is created. A door check
// would then take the tunnel's log with it when it closed. So the engine
// strips the log module out of every instance it starts (see stripLogApp) and
// this sink receives every message from all of them.
type LogSink struct {
	mu    sync.Mutex
	lines []string
	next  int
	full  bool
	out   io.Writer
	debug bool
	// coreOut is the least severe core message that also goes to out.
	coreOut xlog.Severity
}

// ringLines is how much of the log the diagnostics carry back.
const ringLines = 400

// maxLine bounds one stored line; an error that quotes a whole response
// should not push everything else out of the ring.
const maxLine = 600

// NewLogSink returns a sink that also writes every line to out when it is
// not nil, which is what "fortiva-core run" does with the console.
func NewLogSink(out io.Writer, debug bool) *LogSink {
	return &LogSink{lines: make([]string, ringLines), out: out, debug: debug, coreOut: xlog.Severity_Debug}
}

// QuietCore writes only the core's warnings and errors to out; the rest
// still goes into the tail. The engine's own lines go to out as before.
// The router build uses it: the core logs every connection at Info, with
// the address of the device on the LAN and the site it reached, and out is
// the router's syslog.
func (s *LogSink) QuietCore() {
	s.mu.Lock()
	s.coreOut = xlog.Severity_Warning
	s.mu.Unlock()
}

// Handle implements xray's log.Handler.
func (s *LogSink) Handle(msg xlog.Message) {
	// A message of another kind counts as Info.
	severity := xlog.Severity_Info
	switch m := msg.(type) {
	case *xlog.GeneralMessage:
		if m.Severity == xlog.Severity_Debug && !s.debug {
			return
		}
		severity = m.Severity
	case *xlog.AccessMessage:
		// The access log is off in every configuration; a stray one is
		// a connection list nobody asked to keep.
		return
	}
	s.mu.Lock()
	toOut := severity <= s.coreOut
	s.mu.Unlock()
	s.add(msg.String(), toOut)
}

// Printf adds one line of the engine's own.
func (s *LogSink) Printf(format string, args ...any) {
	s.add(fmt.Sprintf(format, args...), true)
}

func (s *LogSink) add(text string, toOut bool) {
	line := time.Now().Format("15:04:05.000 ") + text
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
	if out != nil && toOut {
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
