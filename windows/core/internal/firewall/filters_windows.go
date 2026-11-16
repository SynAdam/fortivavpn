// Copyright (C) 2026 NimusAI. GPL-3.0-or-later, with the additional terms
// under section 7 in LICENSING.md.
//
// The WFP types and calls this file uses are WireGuard for Windows' (MIT),
// in the other files of this package.

package firewall

import (
	"errors"
	"os"
	"runtime"
	"sync"
	"unsafe"

	"golang.org/x/sys/windows"
)

// Filter weights inside the sublayer: the highest matching filter decides.
const (
	weightLoop     = 15
	weightSelf     = 14
	weightPermit   = 13
	weightTunnelV6 = 12
	weightBlockDNS = 11
	dnsPort        = 53
)

// Filters is one set of the tunnel's filters, in a WFP session of its own.
type Filters struct {
	mu      sync.Mutex
	session uintptr
	// luid is where a filter condition points while the filters are added.
	// It lives in this struct, which is on the heap, because the condition
	// holds its address as a number the garbage collector does not follow.
	luid uint64
}

// Add puts the tunnel's filters on the adapter with luid:
//
//   - IPv6 that the routes send into the tunnel is refused when a program
//     connects, so it gets an error at once and tries IPv4. The tunnel itself
//     would otherwise accept the connection and have nothing to send it to:
//     the doors carry no IPv6.
//   - Lookups (port 53, UDP and TCP) go only through the tunnel, to the
//     resolvers the adapter hands out. Windows also asks the resolvers of the
//     physical network, at the same time, and takes the first answer, which
//     there is the network's own: a filtered name gets the filter's address,
//     and the network sees every name.
//
// The service's own traffic is never filtered on the physical network: its
// doors, on whatever port, and what it sends straight out. Into its own
// tunnel it is refused, because there it can only be a loop: a socket the
// binder could not pin to the physical network would otherwise carry the
// tunnel's traffic back into the tunnel. Lookups to a resolver on the PC
// itself stay allowed, and nothing else on the local network is touched.
//
// The session is dynamic, so the filters go when Close is called or when the
// process ends, a crash included.
func Add(luid uint64) (*Filters, error) {
	if luid == 0 {
		return nil, errors.New("no adapter to put the filters on")
	}
	f := &Filters{luid: luid}
	session, err := createWfpSession()
	if err != nil {
		return nil, err
	}
	err = runTransaction(session, func(session uintptr) error {
		bo, err := registerBaseObjects(session)
		if err != nil {
			return err
		}
		appID, err := currentAppID()
		if err != nil {
			return err
		}
		defer fwpmFreeMemory0(unsafe.Pointer(&appID))
		return addRules(session, bo, &f.luid, appID)
	})
	runtime.KeepAlive(f)
	if err != nil {
		fwpmEngineClose0(session)
		return nil, err
	}
	f.session = session
	return f, nil
}

// Close takes the filters away. It is safe to call more than once.
func (f *Filters) Close() {
	if f == nil {
		return
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.session != 0 {
		fwpmEngineClose0(f.session)
		f.session = 0
	}
}

var (
	layersV4 = []windows.GUID{cFWPM_LAYER_ALE_AUTH_CONNECT_V4, cFWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V4}
	layersV6 = []windows.GUID{cFWPM_LAYER_ALE_AUTH_CONNECT_V6, cFWPM_LAYER_ALE_AUTH_RECV_ACCEPT_V6}
	layers   = append(append([]windows.GUID{}, layersV4...), layersV6...)
)

// currentAppID is how WFP names this process's program. WFP allocates it;
// fwpmFreeMemory0 frees it.
func currentAppID() (*wtFwpByteBlob, error) {
	exe, err := os.Executable()
	if err != nil {
		return nil, err
	}
	path, err := windows.UTF16PtrFromString(exe)
	if err != nil {
		return nil, err
	}
	var appID *wtFwpByteBlob
	if err := fwpmGetAppIdFromFileName0(path, unsafe.Pointer(&appID)); err != nil {
		return nil, wrapErr(err)
	}
	return appID, nil
}

func addRules(session uintptr, bo *baseObjects, luid *uint64, appID *wtFwpByteBlob) error {
	// The program path alone, not the service's SID as WireGuard adds: the
	// path is in Program Files, which only an administrator can write to,
	// and the same rule then holds for "fortiva-core run" and the tests.
	self := wtFwpmFilterCondition0{
		fieldKey:  cFWPM_CONDITION_ALE_APP_ID,
		matchType: cFWP_MATCH_EQUAL,
		conditionValue: wtFwpConditionValue0{
			_type: cFWP_BYTE_BLOB_TYPE,
			value: uintptr(unsafe.Pointer(appID)),
		},
	}
	onTunnel := wtFwpmFilterCondition0{
		fieldKey:  cFWPM_CONDITION_IP_LOCAL_INTERFACE,
		matchType: cFWP_MATCH_EQUAL,
		conditionValue: wtFwpConditionValue0{
			_type: cFWP_UINT64,
			value: uintptr(unsafe.Pointer(luid)),
		},
	}
	loopback := wtFwpmFilterCondition0{
		fieldKey:  cFWPM_CONDITION_FLAGS,
		matchType: cFWP_MATCH_FLAGS_ALL_SET,
		conditionValue: wtFwpConditionValue0{
			_type: cFWP_UINT32,
			value: uintptr(cFWP_CONDITION_FLAG_IS_LOOPBACK),
		},
	}
	// Conditions on different fields must all hold; conditions on the same
	// field are alternatives. So this is port 53 over UDP or TCP.
	dns := []wtFwpmFilterCondition0{
		{
			fieldKey:       cFWPM_CONDITION_IP_REMOTE_PORT,
			matchType:      cFWP_MATCH_EQUAL,
			conditionValue: wtFwpConditionValue0{_type: cFWP_UINT16, value: uintptr(dnsPort)},
		},
		{
			fieldKey:       cFWPM_CONDITION_IP_PROTOCOL,
			matchType:      cFWP_MATCH_EQUAL,
			conditionValue: wtFwpConditionValue0{_type: cFWP_UINT8, value: uintptr(cIPPROTO_UDP)},
		},
		{
			fieldKey:       cFWPM_CONDITION_IP_PROTOCOL,
			matchType:      cFWP_MATCH_EQUAL,
			conditionValue: wtFwpConditionValue0{_type: cFWP_UINT8, value: uintptr(cIPPROTO_TCP)},
		},
	}

	rules := []struct {
		name       string
		layers     []windows.GUID
		weight     uint8
		action     wtFwpActionType
		conditions []wtFwpmFilterCondition0
	}{
		{"Fortiva: refuse the tunnel service's own traffic into the tunnel", layers, weightLoop, cFWP_ACTION_BLOCK, []wtFwpmFilterCondition0{self, onTunnel}},
		{"Fortiva: allow the tunnel service", layers, weightSelf, cFWP_ACTION_PERMIT, []wtFwpmFilterCondition0{self}},
		{"Fortiva: allow loopback", layers, weightPermit, cFWP_ACTION_PERMIT, []wtFwpmFilterCondition0{loopback}},
		{"Fortiva: allow lookups through the tunnel", layersV4, weightPermit, cFWP_ACTION_PERMIT, append([]wtFwpmFilterCondition0{onTunnel}, dns...)},
		{"Fortiva: refuse IPv6 into the tunnel", layersV6, weightTunnelV6, cFWP_ACTION_BLOCK, []wtFwpmFilterCondition0{onTunnel}},
		{"Fortiva: refuse lookups around the tunnel", layers, weightBlockDNS, cFWP_ACTION_BLOCK, dns},
	}
	for _, r := range rules {
		display, err := createWtFwpmDisplayData0(r.name, "")
		if err != nil {
			return err
		}
		for _, layer := range r.layers {
			filter := wtFwpmFilter0{
				displayData:         *display,
				providerKey:         &bo.provider,
				layerKey:            layer,
				subLayerKey:         bo.filters,
				weight:              filterWeight(r.weight),
				numFilterConditions: uint32(len(r.conditions)),
				filterCondition:     (*wtFwpmFilterCondition0)(unsafe.Pointer(&r.conditions[0])),
				action:              wtFwpmAction0{_type: r.action},
			}
			var id uint64
			if err := fwpmFilterAdd0(session, &filter, 0, &id); err != nil {
				return wrapErr(err)
			}
		}
	}
	runtime.KeepAlive(luid)
	return nil
}
