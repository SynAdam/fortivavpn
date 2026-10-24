//go:build !windows

package control

import (
	"context"
	"net"
	"os"
	"strconv"
)

// Address is a Unix socket on the platforms the core is developed on. A fixed
// path rather than os.TempDir, which differs between a user and root under
// sudo, so the app finds the core however it was started.
const Address = "/tmp/fortiva-tunnel.sock"

// Listen opens the control socket, replacing one left by a run that was
// killed. Under sudo, which a TUN device needs, the socket is handed to the
// user who ran sudo so their app can reach it, and to nobody else.
func Listen(addr string) (net.Listener, error) {
	_ = os.Remove(addr)
	l, err := net.Listen("unix", addr)
	if err != nil {
		return nil, err
	}
	if uid, err := strconv.Atoi(os.Getenv("SUDO_UID")); err == nil {
		gid, _ := strconv.Atoi(os.Getenv("SUDO_GID"))
		_ = os.Chown(addr, uid, gid)
	}
	if err := os.Chmod(addr, 0o600); err != nil {
		_ = l.Close()
		return nil, err
	}
	return l, nil
}

// Dial connects to the control socket.
func Dial(ctx context.Context, addr string) (net.Conn, error) {
	var d net.Dialer
	return d.DialContext(ctx, "unix", addr)
}
