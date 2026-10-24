package control

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"sync"
	"time"
)

// Handler answers one call. A returned *Error reaches the app with its code;
// any other error is reported as CodeInternal.
type Handler func(ctx context.Context, method string, params json.RawMessage) (any, error)

// Server serves one call per connection until its context ends.
type Server struct {
	Handler Handler

	// ReadTimeout bounds how long a client may take to send its request. A
	// client that connects and sends nothing would otherwise hold a pipe
	// instance for good.
	ReadTimeout time.Duration

	// CallTimeout bounds a call that does not set its own. "watch" waits on
	// purpose and passes its own limit in the context.
	CallTimeout time.Duration

	// Logf receives one line per failed call. Nil discards them.
	Logf func(format string, args ...any)
}

// Serve accepts connections on l until ctx ends or l fails. It closes l on
// return and waits for calls in flight to finish.
func (s *Server) Serve(ctx context.Context, l net.Listener) error {
	var wg sync.WaitGroup
	defer wg.Wait()

	stop := context.AfterFunc(ctx, func() { _ = l.Close() })
	defer stop()
	defer l.Close()

	for {
		conn, err := l.Accept()
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return err
		}
		wg.Add(1)
		go func() {
			defer wg.Done()
			s.serveConn(ctx, conn)
		}()
	}
}

func (s *Server) serveConn(ctx context.Context, conn net.Conn) {
	defer conn.Close()

	readTimeout := s.ReadTimeout
	if readTimeout <= 0 {
		readTimeout = 5 * time.Second
	}
	_ = conn.SetReadDeadline(time.Now().Add(readTimeout))

	req, err := readRequest(conn)
	if err != nil {
		s.logf("control: unreadable request: %v", err)
		s.reply(conn, nil, Errorf(CodeBadRequest, "%v", err))
		return
	}
	if req.V != ProtocolVersion {
		s.reply(conn, nil, Errorf(CodeVersion, "app speaks protocol %d, service speaks %d", req.V, ProtocolVersion))
		return
	}

	callTimeout := s.CallTimeout
	if callTimeout <= 0 {
		callTimeout = 30 * time.Second
	}
	callCtx, cancel := context.WithTimeout(ctx, callTimeout)
	defer cancel()

	result, err := s.call(callCtx, req)
	if err != nil {
		s.logf("control: %s failed: %v", req.Method, err)
	}
	s.reply(conn, result, err)
}

// call runs the handler and turns a panic into an error, so one bad call
// cannot take the service, and with it the user's tunnel, down.
func (s *Server) call(ctx context.Context, req *Request) (result any, err error) {
	defer func() {
		if r := recover(); r != nil {
			result = nil
			err = Errorf(CodeInternal, "panic in %s: %v", req.Method, r)
		}
	}()
	return s.Handler(ctx, req.Method, req.Params)
}

func (s *Server) reply(conn net.Conn, result any, err error) {
	resp := Response{OK: err == nil, Result: result}
	if err != nil {
		var coded *Error
		if !errors.As(err, &coded) {
			coded = &Error{Code: CodeInternal, Message: err.Error()}
		}
		resp.Result = nil
		resp.Error = coded
	}
	line, merr := json.Marshal(resp)
	if merr != nil {
		line, _ = json.Marshal(Response{Error: Errorf(CodeInternal, "unencodable result: %v", merr)})
	}
	_ = conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
	_, _ = conn.Write(append(line, '\n'))
}

func (s *Server) logf(format string, args ...any) {
	if s.Logf != nil {
		s.Logf(format, args...)
	}
}

func readRequest(r io.Reader) (*Request, error) {
	line, err := bufio.NewReaderSize(io.LimitReader(r, MaxRequestBytes+1), 4096).ReadBytes('\n')
	if len(line) > MaxRequestBytes {
		return nil, errors.New("request too large")
	}
	if err != nil && !(errors.Is(err, io.EOF) && len(line) > 0) {
		return nil, err
	}
	var req Request
	if err := json.NewDecoder(bytes.NewReader(line)).Decode(&req); err != nil {
		return nil, err
	}
	if req.Method == "" {
		return nil, errors.New("no method")
	}
	return &req, nil
}

// Call sends one request to the service at addr and decodes its result into
// out, which may be nil. It is what the Go tests and the "fortiva-core call"
// debugging command use; the app has its own client in Dart.
func Call(ctx context.Context, addr, method string, params, out any) error {
	conn, err := Dial(ctx, addr)
	if err != nil {
		return err
	}
	defer conn.Close()
	if deadline, ok := ctx.Deadline(); ok {
		_ = conn.SetDeadline(deadline)
	}

	req := Request{V: ProtocolVersion, Method: method}
	if params != nil {
		raw, err := json.Marshal(params)
		if err != nil {
			return err
		}
		req.Params = raw
	}
	line, err := json.Marshal(req)
	if err != nil {
		return err
	}
	if _, err := conn.Write(append(line, '\n')); err != nil {
		return err
	}

	respLine, err := bufio.NewReader(conn).ReadBytes('\n')
	if err != nil && !(errors.Is(err, io.EOF) && len(respLine) > 0) {
		return err
	}
	var resp struct {
		OK     bool            `json:"ok"`
		Result json.RawMessage `json:"result"`
		Error  *Error          `json:"error"`
	}
	if err := json.Unmarshal(respLine, &resp); err != nil {
		return err
	}
	if !resp.OK {
		if resp.Error == nil {
			return Errorf(CodeInternal, "failed without an error")
		}
		return resp.Error
	}
	if out != nil && len(resp.Result) > 0 {
		return json.Unmarshal(resp.Result, out)
	}
	return nil
}
