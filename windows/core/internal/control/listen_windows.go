//go:build windows

package control

import (
	"context"
	"net"

	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wireguard/ipc/namedpipe"
)

// Address is the pipe the service listens on and the app dials.
const Address = `\\.\pipe\FortivaTunnel`

// pipeSDDL gives SYSTEM and administrators full control of the pipe and lets
// a signed-in user (console or Remote Desktop) read and write it. The
// listener refuses clients on other machines by itself
// (FILE_PIPE_REJECT_REMOTE_CLIENTS), so the pipe is not reachable over SMB.
const pipeSDDL = "O:SYD:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)"

// Listen opens the control pipe. It fails if another process already holds
// the name, which is what a second copy of the service, or a program
// squatting on the name before the service started, looks like.
func Listen(addr string) (net.Listener, error) {
	sd, err := windows.SecurityDescriptorFromString(pipeSDDL)
	if err != nil {
		return nil, err
	}
	return (&namedpipe.ListenConfig{SecurityDescriptor: sd}).Listen(addr)
}

// Dial connects to the control pipe.
func Dial(ctx context.Context, addr string) (net.Conn, error) {
	return namedpipe.DialContext(ctx, addr)
}
