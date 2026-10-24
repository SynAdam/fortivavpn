//go:build windows

// Package service runs fortiva-core under the Windows service manager and
// registers it there.
//
// The service exists so that the app never runs elevated. Creating the Wintun
// adapter and changing routes need administrator rights; the installer, which
// already has them, registers the service once, and from then on the app,
// running as the signed-in user, asks the service over the control pipe.
package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

const (
	// Name is the service's key name. The installer and the uninstaller
	// address it by this name, so changing it orphans installed copies.
	Name = "FortivaTunnel"

	displayName = "Fortiva VPN tunnel"
	description = "Carries the connection of the Fortiva VPN app. " +
		"Nothing goes through it until you connect in the app."

	// stopTimeout is how long a stop request waits for the tunnel to close
	// before the service reports itself stopped anyway.
	stopTimeout = 20 * time.Second
)

// IsService reports whether the service manager started this process.
func IsService() bool {
	ok, err := svc.IsWindowsService()
	return err == nil && ok
}

// Run runs fn as the service until the service manager stops it. The context
// fn receives ends on stop and on system shutdown.
func Run(fn func(ctx context.Context) error) error {
	return svc.Run(Name, &handler{fn: fn})
}

type handler struct {
	fn func(ctx context.Context) error
}

func (h *handler) Execute(_ []string, requests <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	status <- svc.Status{State: svc.StartPending}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- h.fn(ctx) }()

	status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
	for {
		select {
		case err := <-done:
			if err != nil {
				// A service-specific exit code counts as a failure, so the
				// recovery actions Install sets restart the service.
				return true, 1
			}
			return false, 0
		case req := <-requests:
			switch req.Cmd {
			case svc.Interrogate:
				status <- req.CurrentStatus
			case svc.Stop, svc.Shutdown:
				status <- svc.Status{State: svc.StopPending, WaitHint: uint32(stopTimeout / time.Millisecond)}
				cancel()
				select {
				case <-done:
				case <-time.After(stopTimeout):
				}
				return false, 0
			}
		}
	}
}

// Install registers exePath as the service and starts it. Run again on an
// installed copy, it brings the registration up to date instead, which is
// what an upgrade does.
func Install(exePath string) error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("connect to the service manager (are you an administrator?): %w", err)
	}
	defer m.Disconnect()

	cfg := mgr.Config{
		ServiceType:  windows.SERVICE_WIN32_OWN_PROCESS,
		StartType:    mgr.StartAutomatic,
		ErrorControl: mgr.ErrorNormal,
		DisplayName:  displayName,
		Description:  description,
		// Gives the process its own service SID, which a firewall rule can
		// name to let the tunnel's own traffic out and nothing else.
		SidType: windows.SERVICE_SID_TYPE_UNRESTRICTED,
	}

	s, err := m.OpenService(Name)
	if err == nil {
		// mgr.CreateService quotes the path; UpdateConfig takes it as is.
		cfg.BinaryPathName = windows.EscapeArg(exePath) + " service"
		err = s.UpdateConfig(cfg)
	} else {
		s, err = m.CreateService(Name, exePath, cfg, "service")
	}
	if err != nil {
		return fmt.Errorf("register service: %w", err)
	}
	defer s.Close()

	// A crash, or the tunnel failing for good, restarts the service. The
	// app reconnects through it; it cannot do anything while it is gone.
	err = s.SetRecoveryActions([]mgr.RecoveryAction{
		{Type: mgr.ServiceRestart, Delay: time.Second},
		{Type: mgr.ServiceRestart, Delay: 5 * time.Second},
		{Type: mgr.ServiceRestart, Delay: 30 * time.Second},
	}, uint32((24 * time.Hour).Seconds()))
	if err != nil {
		return fmt.Errorf("set recovery actions: %w", err)
	}
	if err := s.SetRecoveryActionsOnNonCrashFailures(true); err != nil {
		return fmt.Errorf("set recovery on failure exits: %w", err)
	}

	if st, err := s.Query(); err == nil && st.State == svc.Running {
		return nil
	}
	if err := s.Start(); err != nil {
		return fmt.Errorf("start service: %w", err)
	}
	return nil
}

// Stop stops the service and waits until it has, which closes any tunnel
// and removes its adapter. An upgrade does this before it replaces the
// files the running service holds open. A service that is not installed or
// not running is not an error.
func Stop() error {
	return withService(func(s *mgr.Service) error {
		stopAndWait(s)
		return nil
	})
}

// Uninstall stops the service and deletes the registration. A service that
// is not installed is not an error.
func Uninstall() error {
	return withService(func(s *mgr.Service) error {
		stopAndWait(s)
		if err := s.Delete(); err != nil {
			return fmt.Errorf("delete service: %w", err)
		}
		return nil
	})
}

// withService runs fn on the installed service, and does nothing when there
// is none.
func withService(fn func(*mgr.Service) error) error {
	m, err := mgr.Connect()
	if err != nil {
		return fmt.Errorf("connect to the service manager (are you an administrator?): %w", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(Name)
	if err != nil {
		if errors.Is(err, windows.ERROR_SERVICE_DOES_NOT_EXIST) {
			return nil
		}
		return err
	}
	defer s.Close()
	return fn(s)
}

func stopAndWait(s *mgr.Service) {
	st, err := s.Control(svc.Stop)
	if err != nil {
		// Not running, or already stopping: either way, wait below.
		if st, err = s.Query(); err != nil {
			return
		}
	}
	deadline := time.Now().Add(stopTimeout + 5*time.Second)
	for st.State != svc.Stopped && time.Now().Before(deadline) {
		time.Sleep(300 * time.Millisecond)
		if st, err = s.Query(); err != nil {
			return
		}
	}
}
