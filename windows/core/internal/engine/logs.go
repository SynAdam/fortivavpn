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
}

// ringLines is how much of the log the diagnostics carry back.
const ringLines = 400

// maxLine bounds one stored line; an error that quotes a whole response
// should not push everything else out of the ring.
const maxLine = 600

// NewLogSink returns a sink that also writes every line to out when it is
// not nil, which is what "fortiva-core run" does with the console.
func NewLogSink(out io.Writer, debug bool) *LogSink {
	return &LogSink{lines: make([]string, ringLines), out: out, debug: debug}
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
	s.Printf("%s", msg.String())
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
