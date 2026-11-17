//go:build darwin

package control

import (
	"context"
	"net"
	"os"
	"strconv"
)

// SystemAddress is the socket the launchd daemon listens on and the app
// dials. /var/run belongs to root, so no other program can take the name
// before the daemon does, which /tmp would allow.
const SystemAddress = "/var/run/fortiva-tunnel.sock"

// DevAddress is where "fortiva-core run" listens when started without root,
// to drive the core without capturing anything while developing.
const DevAddress = "/tmp/fortiva-tunnel.sock"

// staffGID is the group every person who can sign in to a Mac is in.
const staffGID = 20

// Address is SystemAddress for the daemon, and for anything else while the
// daemon's socket exists; DevAddress otherwise.
var Address = address()

func address() string {
	if os.Geteuid() == 0 {
		return SystemAddress
	}
	if _, err := os.Stat(SystemAddress); err == nil {
		return SystemAddress
	}
	return DevAddress
}

// Listen opens the control socket, replacing one left by a run that was
// killed. The daemon's socket can be read and written by root and by the
// staff group, which is everyone signed in to the Mac, as the Windows pipe
// is open to every signed-in user. Under sudo the socket is handed to the
// user who ran sudo, and to nobody else.
func Listen(addr string) (net.Listener, error) {
	_ = os.Remove(addr)
	l, err := net.Listen("unix", addr)
	if err != nil {
		return nil, err
	}
	mode := os.FileMode(0o600)
	if uid, err := strconv.Atoi(os.Getenv("SUDO_UID")); err == nil {
		gid, _ := strconv.Atoi(os.Getenv("SUDO_GID"))
		_ = os.Chown(addr, uid, gid)
	} else if os.Geteuid() == 0 {
		if err := os.Chown(addr, 0, staffGID); err != nil {
			_ = l.Close()
			return nil, err
		}
		mode = 0o660
	}
	if err := os.Chmod(addr, mode); err != nil {
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
