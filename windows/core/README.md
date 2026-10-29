# Windows tunnel (`fortiva-core`)

The tunnel of the Windows client: one Go executable that runs as a Windows
service, carries the PC's traffic through Fortiva's doors, and takes its
orders from the app over a named pipe. The app itself never runs elevated.

| | |
|---|---|
| Core | [Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0) with [`android/core/patches`](../../android/core/patches), the same source and patches Android ships |
| Capture | Xray's own `tun` inbound on a [Wintun](https://www.wintun.net) adapter; no tun2socks, no local proxy port |
| Privileges | a service (`FortivaTunnel`, LocalSystem) registered once by the installer |
| App link | `\\.\pipe\FortivaTunnel`, one JSON line in, one JSON line out |
| Pinned in | `go.mod` + `go.sum`, `../../android/core/stage-xray.sh` (the core), `stage.sh` (Wintun) |

## How a connect goes

1. The app sends `connect` with the chosen door, its standby doors, the
   server each one leaves from and the backend's penalty for each: the
   arguments Android's `connect` takes.
2. The service builds the configuration itself ([`internal/config`](internal/config)).
   It never accepts a ready-made one: it runs as SYSTEM, any local program can
   reach the pipe, and an Xray configuration can name files to write.
3. The doors start in an instance that captures nothing, and a request is
   fetched through them. Only when that works does the TUN inbound go in: the
   `Fortiva` adapter appears and the two halves of the address space, IPv4 and
   IPv6, are routed to it. This is Android's order (proxy first, then the
   VPN), for the same reason: a door can accept a connection and forward
   nothing.
4. The core's own sockets are bound to the interface that holds the real
   default route, so its doors and its `direct` traffic never loop into the
   tunnel they carry.

## What differs from Android, and why

The configuration is Android's, with its default settings (the only ones it
uses): the `white_iran` routing, route-only sniffing, the sinkhole patch, the
`autoselect` door group with `exits`, `penalties` and a 10 minute dwell,
lookups sent through the tunnel. The differences:

- **No SOCKS inbound.** Android needs one for tun2socks; here the TUN inbound
  feeds the core directly, so no program on the PC can find or use a local
  proxy port.
- **IPv6 is captured and refused.** Android routes only IPv4 into its tunnel
  and the system blocks IPv6 for tunnelled apps. Windows does neither, so a
  PC with native IPv6 would send it around the tunnel. The adapter gets a
  unique local IPv6 address, which also makes Windows prefer IPv4 while the
  tunnel is up, and anything that still arrives over IPv6 is refused at once
  so the app falls back instead of waiting.
- **Nothing depends on the core's process-wide tables.** Every Xray instance
  overwrites two of them when it starts: the resolver dialers use for a host
  name, and the outbounds a `dialerProxy` is looked up in. Android runs its
  door checks in another process than its tunnel; here they share one. So:
  - a door's host name is looked up before the tunnel starts and its address
    written into the door (Android keeps the name and a `hosts` entry);
  - a link's `fragment=tlshello,…` splits the hello inside the door's own
    stream with the core's finalmask `fragment` mask, which is the same
    splitter (Android chains a separate freedom outbound);
  - `direct` dials the address it is given, which with route-only sniffing is
    always an address.
- **Links the core would refuse are refused up front**, so a bad standby door
  is left out rather than failing the whole connect: `h2`/`quic` transports
  (removed from the core) and `allowInsecure=1` (the core now refuses the
  whole configuration over it).
- **`extra` and `fm` are checked against a list.** An xhttp `extra` may set
  the transport's own fields and a `downloadSettings` stream; a finalmask may
  hold TCP `fragment` masks, which is all Fortiva sends. Anything else could
  make a SYSTEM process open files (TLS key logs, certificate files) or raw
  sockets.
- **One log sink for the whole process.** Instances are started without Xray's
  log module, because each one would otherwise install itself as the process's
  only log handler and a door check would take the tunnel's log down with it.

## The pipe

`internal/control` serves one call per connection. A request is
`{"v":1,"method":"…","params":{…}}` and the answer
`{"ok":true,"result":…}` or `{"ok":false,"error":{"code":"…","message":"…"}}`.
Where a call has a twin on the app's mobile channel
(`com.vpn.fortivavpn/tunnel`) it has that name and that shape.

| Method | Params | Result |
|---|---|---|
| `hello` | | `{protocol, core, xray, os, arch}` |
| `status` | | `{seq, state, reason?, error?, since, doors?}` |
| `watch` | `{after, timeoutMs}` | the status once `seq` passes `after`, or the current one at the timeout (25 s at most) |
| `connect` | `{link, alternates?, exits?, penalties?, dns?}` | the status, `connecting`; the outcome arrives through `watch` |
| `disconnect` | | the status |
| `tunnelStats` | | Android's shape: `bytes_up`, `bytes_down` (since the last call), `door_index`, `door_status`, `network`; `null` without a tunnel |
| `realPing` | `{link}` | milliseconds, or -1 |
| `realPingDetail` | `{link}` | `{ms, elapsedMs, error?, tcp?, tcpMs?}` |
| `place` | | `{time_zone?}`, an IANA name |
| `diagnostics` | | `{core, xray, state, failure?, failure_error?, network?, core_log}` |
| `logs` | `{lines}` | the last lines of the log |

States are the strings the app's status stream already uses: `connecting`,
`connected`, `failed`, `disconnecting`, `disconnected`. A failure carries a
reason: `config`, `start`, `verify` or `adapter`; a tunnel that was up when
the service stopped ends as `disconnected` with reason `killed`.

## Building

```bash
./stage.sh          # the patched core, the routing data, Wintun; tests need it too
go test ./...       # runs on any platform; the engine tests run real doors in-process
./build.sh          # dist/windows-amd64/, with checksums.txt
./build.sh arm64    # Windows on ARM
```

`build.sh` refuses to emit a core that is not a Windows executable for the
architecture asked for, was not built from `android/core/.src/xray-core`, or
lacks REALITY, Vision, the autoselect outbound, the TUN inbound or the
finalmask fragment. Each of those otherwise fails at connect, on a user's PC.

On macOS or Linux, `go build ./cmd/fortiva-core && ./fortiva-core run -assets .assets`
serves the same pipe calls on `/tmp/fortiva-tunnel.sock`, without capturing
anything, and `./fortiva-core call <method> '<json>'` drives it.

## Trying it on Windows

The installer puts the service in `C:\Program Files\Fortiva VPN` and starts
it (see "Building the installer" in the root README). To drive it by hand,
from an administrator PowerShell in that folder, or in one holding the
contents of `dist/windows-amd64` when trying a build without the installer:

```powershell
.\fortiva-core.exe run            # only without the installer: in one window, or .\fortiva-core.exe install
.\fortiva-core.exe call hello     # in another
.\fortiva-core.exe call connect '{\"link\":\"vless://...\"}'
.\fortiva-core.exe call watch '{\"after\":1}'
Get-NetAdapter Fortiva; Get-NetRoute -InterfaceAlias Fortiva
curl.exe https://ifconfig.me      # the server's address, not the PC's
.\fortiva-core.exe call tunnelStats
.\fortiva-core.exe call disconnect
.\fortiva-core.exe uninstall      # without the installer; with it, uninstall Fortiva VPN in Settings
```

What to look at the first time: that the adapter and its four routes appear
on connect and are gone after disconnect (and after the process is killed),
that sites work with Wi-Fi and with Ethernet, that switching between the two
keeps the tunnel, that `tunnelStats` reports the network, and what a DNS leak
test shows.

## Not done yet

- DNS leak protection. Windows may also ask the physical network's resolvers
  (smart multi-homed name resolution). The tunnel still works, because the
  sinkhole patch dials a filtered name's answer by its sniffed name, but the
  question leaks. WireGuard's WFP rules (`wireguard/windows/tunnel/firewall`)
  block DNS everywhere but the tunnel; they also block the LAN, so they need
  adapting rather than reusing.
- Checking that the client of the pipe is the installed app, and that the
  server of the pipe is the service (pipe-name squatting).
- An adapter left behind by a crash is reused on the next connect, by name;
  confirm that on the VM.
