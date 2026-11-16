/* SPDX-License-Identifier: MIT
 *
 * Copyright (C) 2019-2026 WireGuard LLC. All Rights Reserved.
 *
 * From tunnel/firewall/blocker.go and helpers.go of WireGuard for Windows
 * v1.0.1 (golang.zx2c4.com/wireguard/windows), with Fortiva's names: a
 * session of its own for each set of filters instead of one per process.
 */

package firewall

import (
	"fmt"
	"runtime"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

type wfpObjectInstaller func(uintptr) error

// The provider and the sublayer every filter of one set belongs to.
type baseObjects struct {
	provider windows.GUID
	filters  windows.GUID
}

// createWfpSession opens a dynamic session: Windows deletes everything added
// through it when the session is closed or the process ends, however it
// ends.
func createWfpSession() (uintptr, error) {
	sessionDisplayData, err := createWtFwpmDisplayData0("Fortiva", "Fortiva VPN tunnel filters")
	if err != nil {
		return 0, wrapErr(err)
	}

	session := wtFwpmSession0{
		displayData:          *sessionDisplayData,
		flags:                cFWPM_SESSION_FLAG_DYNAMIC,
		txnWaitTimeoutInMSec: windows.INFINITE,
	}

	sessionHandle := uintptr(0)

	err = fwpmEngineOpen0(nil, cRPC_C_AUTHN_WINNT, nil, &session, unsafe.Pointer(&sessionHandle))
	if err != nil {
		return 0, wrapErr(err)
	}

	return sessionHandle, nil
}

func registerBaseObjects(session uintptr) (*baseObjects, error) {
	bo := &baseObjects{}
	var err error
	bo.provider, err = windows.GenerateGUID()
	if err != nil {
		return nil, wrapErr(err)
	}
	bo.filters, err = windows.GenerateGUID()
	if err != nil {
		return nil, wrapErr(err)
	}

	{
		displayData, err := createWtFwpmDisplayData0("Fortiva", "Fortiva VPN")
		if err != nil {
			return nil, wrapErr(err)
		}
		provider := wtFwpmProvider0{
			providerKey: bo.provider,
			displayData: *displayData,
		}
		err = fwpmProviderAdd0(session, &provider, 0)
		if err != nil {
			return nil, wrapErr(err)
		}
	}

	{
		displayData, err := createWtFwpmDisplayData0("Fortiva filters", "What the tunnel refuses while it is up")
		if err != nil {
			return nil, wrapErr(err)
		}
		sublayer := wtFwpmSublayer0{
			subLayerKey: bo.filters,
			displayData: *displayData,
			providerKey: &bo.provider,
			weight:      ^uint16(0),
		}
		err = fwpmSubLayerAdd0(session, &sublayer, 0)
		if err != nil {
			return nil, wrapErr(err)
		}
	}

	return bo, nil
}

func runTransaction(session uintptr, operation wfpObjectInstaller) error {
	err := fwpmTransactionBegin0(session, 0)
	if err != nil {
		return wrapErr(err)
	}

	err = operation(session)
	if err != nil {
		fwpmTransactionAbort0(session)
		return wrapErr(err)
	}

	err = fwpmTransactionCommit0(session)
	if err != nil {
		fwpmTransactionAbort0(session)
		return wrapErr(err)
	}

	return nil
}

func createWtFwpmDisplayData0(name, description string) (*wtFwpmDisplayData0, error) {
	namePtr, err := windows.UTF16PtrFromString(name)
	if err != nil {
		return nil, wrapErr(err)
	}

	descriptionPtr, err := windows.UTF16PtrFromString(description)
	if err != nil {
		return nil, wrapErr(err)
	}

	return &wtFwpmDisplayData0{
		name:        namePtr,
		description: descriptionPtr,
	}, nil
}

func filterWeight(weight uint8) wtFwpValue0 {
	return wtFwpValue0{
		_type: cFWP_UINT8,
		value: uintptr(weight),
	}
}

func wrapErr(err error) error {
	if _, ok := err.(syscall.Errno); !ok {
		return err
	}
	_, file, line, ok := runtime.Caller(1)
	if !ok {
		return fmt.Errorf("firewall error at unknown location: %w", err)
	}
	return fmt.Errorf("firewall error at %s:%d: %w", file, line, err)
}
