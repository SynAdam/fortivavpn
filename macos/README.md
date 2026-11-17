# macOS client

Fortiva for macOS 13 (Ventura) and newer, on Apple silicon and Intel Macs.
It is the Windows client's design on a Mac: the same Flutter app, and the
same tunnel core running as a system service. It is published since
2.4.2 (2026-11-17): fortivavpn.com/macos and the release pages on GitHub
serve a notarized disk image.

| | |
|---|---|
| App | `lib/`, as every platform has it; `flutter build macos` |
| Tunnel | `fortiva-core` from [`windows/core`](../windows/core/README.md), one universal binary |
| Capture | Xray's own `tun` inbound on a `utun` interface, IPv4 only |
| Privileges | a launchd daemon, run as root, added by the app with `SMAppService` |
| App link | `/var/run/fortiva-tunnel.sock`, root:staff 0660, the Windows pipe's protocol |
| Distribution | a Developer ID app on a disk image, from the website, not the Mac App Store |

## How it fits together

- **The app** is `Fortiva VPN.app`, built from `lib/` like Android and
  Windows. It has no tunnel code of its own:
  [`lib/services/desktop_tunnel.dart`](../lib/services/desktop_tunnel.dart)
  answers the calls the mobile platforms answer over
  `com.vpn.fortivavpn/tunnel` by asking the core over its socket, as it
  does on Windows over the pipe.
- **The core** is in the app, at `Contents/MacOS/fortiva-core`, with the
  routing data in `Contents/Resources`. `windows/core/build.sh macos` builds
  it for both processors, from the same pinned Xray-core and
  `android/core/patches` as Android and Windows.
- **The daemon.** `Contents/Library/LaunchDaemons/com.vpn.fortivavpn.tunnel.plist`
  tells launchd to run `fortiva-core service` as root and to start it again
  if it ends. The app adds it when it opens, and again before a connect or
  a door check finds it missing
  ([`Runner/TunnelDaemon.swift`](Runner/TunnelDaemon.swift),
  [`lib/services/mac_daemon.dart`](../lib/services/mac_daemon.dart)).
  macOS answers "not found" for a daemon that was never added, and the app
  adds it then too. macOS asks the person to allow it, and the app opens
  System Settings at General, Login Items & Extensions, where they do. That
  happens once.
- **Updates.** A new copy of the app brings a new core, but launchd would
  keep the old one running until the Mac restarts. The daemon looks at its
  own file every 10 seconds; once it has been replaced and no tunnel is up,
  the daemon ends and launchd starts the new core
  ([`cmd/fortiva-core/replaced_darwin.go`](../windows/core/cmd/fortiva-core/replaced_darwin.go)).
  A tunnel that is up is not taken down for an update.
- **Signing.** [`embed_tunnel.sh`](embed_tunnel.sh), a build phase of the
  Runner target, puts the core, its data and the property list in the app
  and signs the core with the app's identity. launchd refuses a daemon whose
  team is not the app's.

## What the Mac does around the tunnel

Xray's `tun` inbound makes the `utun` interface (the first free one from
`utun10`), gives it 10.10.14.2 with 10.10.14.1 at the far end, and routes
both IPv4 halves to it. The rest is the core's
([`internal/engine/host_darwin.go`](../windows/core/internal/engine/host_darwin.go),
[`bind_darwin.go`](../windows/core/internal/engine/bind_darwin.go)):

- **The core's own connections** are bound to the interface of the Mac's
  default route with a gateway (Wi-Fi, Ethernet, an iPhone over USB) with
  `IP_BOUND_IF`, so they do not loop into the tunnel. A tunnel's interface
  is never picked: with another VPN running, the doors still go out over
  the physical network.
- **A scoped default route for that interface.** A bound socket only finds
  the routes scoped to its interface, and macOS keeps a scoped default
  route for every network but the primary one. With Wi-Fi as the only
  network, `en0` has none, and every door failed with "network is
  unreachable" once the tunnel's routes were in. While it binds, the core
  adds `route add -ifscope en0 default <gateway>` when the interface has
  no scoped default, and removes it on disconnect or when the network
  moves. A scoped default that macOS made itself is left alone.
- **The resolvers.** Every network service with a device is pointed at the
  tunnel's resolvers (1.1.1.1, or what the DNS screen chose), which the
  first routing rule sends through the tunnel. Otherwise macOS would ask the
  router's or the ISP's, which are on the local network, never reach the
  tunnel's routes, and answer filtered names with the filter's addresses.
- **IPv6 is refused** with reject routes for both halves while the tunnel is
  up, as on the router, so a site with IPv6 falls back to IPv4 at once and
  no IPv6 goes around the tunnel. Routing IPv6 into the tunnel instead, as
  Windows does, made the core answer every IPv6 connection with an HTTP
  403 on the router, where a device that preferred IPv6 lost every HTTPS
  site.
- **A kill leaves nothing behind.** What the core changes is written to
  `/Library/Application Support/Fortiva VPN/tunnel-state.json` before it
  changes it. launchd starts a killed core again, and it puts the resolvers
  and routes back first. The `utun` interface and its routes go with the
  process. The scoped default route above stays after a kill. It points
  where the Mac's own default route does, and it goes when the Mac leaves
  that network or restarts.

## Building and trying it

On a Mac with Xcode, Flutter and Go:

```bash
windows/core/build.sh macos      # the core; embed_tunnel.sh builds it when missing
flutter build macos --debug      # build/macos/Build/Products/Debug/Fortiva VPN.app
```

The Xcode project signs with the team's Apple Development certificate
Open the app, tap connect, allow Fortiva in System
Settings when macOS asks, and connect again. To drive the core by hand
instead:

```bash
sudo dist/macos/fortiva-core run         # from windows/core, captures like the daemon
dist/macos/fortiva-core call hello       # the daemon's socket, or the run's
dist/macos/fortiva-core call connect '{"link":"vless://..."}'
dist/macos/fortiva-core call watch '{"after":1}'
netstat -rn -f inet | grep utun          # 0/1 and 128/1 on utun10
scutil --dns | grep nameserver           # 1.1.1.1 while the tunnel is up
curl -4 https://ifconfig.me              # the server's address, not the Mac's
dist/macos/fortiva-core call disconnect
```

Without `sudo` the core only dials through its doors and captures nothing,
on `/tmp/fortiva-tunnel.sock`.

### Tried on a Mac, 2026-11-17

The app, connected and disconnected from its own button on a MacBook on
Wi-Fi, with the daemon allowed in System Settings:

- **Connected:** `0/1` and `128/1` on `utun10`, a scoped default route for
  `en0`, the IPv6 reject routes, and 1.1.1.1 as the resolver, which goes
  through `utun10`. The public address was the server's. Google and
  YouTube opened, and no door failed with "network is unreachable".
  Asked for IPv6 only, the Mac sent the request over IPv4 through the
  tunnel; the server's IPv6 address came back, not the Mac's.
- **Disconnected:** `utun10`, its routes, the scoped default route, the
  reject routes and the state file were all gone, the router's resolver
  was back, and the public address was the Mac's own.

Not tried yet: `sudo pkill fortiva-core` while connected, moving between
Wi-Fi and Ethernet, a DNS leak test site, and a network with native IPv6
(the Wi-Fi above had none).

## Releasing

`macos/build.sh` builds a release: the core, the app, both signed with a
Developer ID certificate and the hardened runtime, on a disk image that
Apple notarizes and the script staples. It needs the team's Developer ID
Application certificate in the keychain and an App Store Connect API key
for `notarytool`:

```bash
MACOS_SIGN_IDENTITY="Developer ID Application" \
ASC_KEY_ID=<key id> ASC_ISSUER_ID=<issuer id> \
  macos/build.sh        # build/macos/FortivaVPN-<version>-macos.dmg and its .sha256
```

pub.dev refuses Iranian addresses. Where it cannot be reached and the
packages are already fetched, add `MACOS_FLUTTER_ARGS=--no-pub`.

A notarized image opens on any Mac without a warning. The person still
allows the daemon once in System Settings.

No workflow can sign it, so the Mac that built it puts it on the release:
once the release of the tag is published on the public repository, put the
disk image (with or without its .sha256) alone in a folder and run

```bash
python3 tool/public_sync.py vX.Y.Z --macos <folder>          # checks only
python3 tool/public_sync.py vX.Y.Z --macos <folder> --push   # attaches it
```

It attaches the image and its .sha256 to the release, as the Windows
workflow does with the installer. The bot then puts it on the website,
where fortivavpn.com/macos serves the newest one, and the backend's
`macos` block in `/app/config` offers it to the app's update prompt.

## Not done yet

- **A build in every release.** The disk image is built and attached by
  hand from a Mac (above); `tool/release.sh` does not do it yet.
- **Translating the two macOS messages** (allow the daemon in System
  Settings; the daemon is not running), which are in English, as the
  Windows service's are.
- **Proving the IPv6 refusal on a Mac with native IPv6.** The reject routes
  are tested against a stand-in for the system's tools, not yet on a Mac
  whose network has IPv6.
- **Checking that the socket's client is the app** and the server the
  daemon. Any program of a signed-in user can reach the socket, as any can
  reach the Windows pipe; the core builds every configuration itself for
  that reason.
- **A menu bar item**, so the tunnel can be seen and stopped with the
  window closed. Closing the window quits the app today; the tunnel keeps
  running in the daemon.

## What macOS cannot do that phones do

- The app cannot keep its own traffic out of the tunnel, as Android's
  per-app VPN does: its requests go through the tunnel while it is up, as
  on Windows.
