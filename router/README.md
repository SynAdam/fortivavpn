# Fortiva for routers (OpenWrt)

Fortiva on an OpenWrt router. Every device behind the router, phones,
laptops, TVs and game consoles included, connects through Fortiva without
an app of its own. A page under Services in LuCI turns it on and off, shows
the allowance and takes a Premium code.

## What a router needs

| | |
|---|---|
| Firmware | OpenWrt 23.05 or newer. Tested on 24.10 (`test/e2e.sh`). |
| Processor | 64-bit Arm (`aarch64_*`), 32-bit Arm v7 (`arm_cortex-a7`, `-a9`, `-a15`), MIPS little-endian (`mipsel_*`, such as MT7621), MIPS big-endian (`mips_*`, such as ath79), or x86-64 |
| Memory | 256 MB |
| Storage | 16 MB free. With more than about 35 MB free the program is kept on flash; with less it stays packed there and is unpacked into memory at every start. An upgrade counts the room of the program it replaces as free. |
| Packages | `kmod-tun` and `ca-bundle`; `install.sh` installs them |

## Installing

On the router, as root:

```sh
wget -O /tmp/install.sh https://raw.githubusercontent.com/SynAdam/fortivavpn/main/router/install.sh
sh /tmp/install.sh
```

It picks the build for the router's processor, checks memory and storage,
installs `kmod-tun` and `ca-bundle` when they are missing, downloads the
build from the newest release on https://github.com/SynAdam/fortivavpn/releases
that has router files, checks it against `fortiva-router-SHA256SUMS`, and
starts Fortiva. Running it again upgrades and keeps the settings.

A router that cannot reach GitHub can take the files from a computer:
download `fortiva-router-install.sh` and `fortiva-router-<target>.tar.gz`
from the release, copy both to the router, and run
`sh fortiva-router-install.sh fortiva-router-<target>.tar.gz`. The targets
are `arm64`, `armv7`, `mipsle`, `mips` and `amd64`; `install.sh` says which
one the router needs when it is given the wrong one.

`router/build.sh` also makes an `.ipk` for each OpenWrt architecture, for
`opkg install` after `opkg update`. The releases carry only the builds above.

The router is a device of its own with the backend, with its own allowance.
A Premium key works on it as on a phone: enter it on the LuCI page or run
`fortiva redeem <code>`.

## Using it

LuCI: Services, Fortiva VPN. Or on the command line:

```sh
fortiva status          # what it is doing, as JSON
fortiva disconnect      # off; the network uses its own connection
fortiva connect         # on again
fortiva redeem CODE     # a Premium key or a gift code
fortiva uninstall       # take Fortiva off the router
```

On or off survives a restart. Settings are in `/etc/config/fortiva`:
`enabled` (start with the router), `dns_through_tunnel` and `dns` (where
the network's lookups go while the tunnel is up), and `wan` (the internet
device, when the default route's is not the right one). A test points the
router at another backend by writing its URL to `/etc/fortiva/api`, a file
only root can write; the settings page and its ACL cannot reach it.

## Removing it

`fortiva uninstall`, or `sh install.sh --remove`, stops the service, gives
the network's lookups back to the WAN, removes the firewall zone and every
forwarding to or from it, and deletes every file the install put on the
router (listed in `/usr/share/fortiva/FILES`). `/etc/fortiva` stays: it
holds the router's id, so a later install is the same router with its
Premium. `fortiva uninstall --purge` deletes it too. `opkg remove fortiva`
does the same for an `.ipk` install, through the package's `prerm`.

## How it works

One program, `fortiva`, built from `windows/core` (`cmd/fortiva-router`).
It holds two parts.

- **The tunnel** is the Windows build's engine: the same patched Xray-core,
  the same configuration and the same door group with standby doors. Xray's
  TUN inbound makes the `fortiva0` interface and adds the two half routes
  (`0.0.0.0/1`, `128.0.0.0/1`, and the same for IPv6) to the main table.
  Traffic the router forwards from its LAN uses the main table, so every
  device reaches the tunnel without a rule of its own. The program's own
  connections are bound to the WAN device (`SO_BINDTODEVICE`,
  `internal/engine/bind_linux.go`), so the doors do not go into the tunnel
  they carry. While a tunnel is up and the WAN has no default route, they
  are refused instead. The binder hears of route changes from the kernel
  (netlink), and reads the table every 5 seconds besides. IPv6 that reaches
  the tunnel is refused, so devices fall back to IPv4 at once, as on
  Windows. On a router with IPv6 turned off
  (`net.ipv6.conf.default.disable_ipv6=1`, which
  `net.ipv6.conf.all.disable_ipv6=1` also sets) `fortiva0` gets no IPv6
  address or routes. This is checked at each connect.
- **The agent** (`internal/agent`) does what the app does on a phone. It
  registers the router as platform `router`, fetches its own doors from
  `/configs/dedicated` around the tunnel, checks four at a time and connects
  through the first open one in the backend's order with up to four standby
  doors, sends the app's events and five-minute heartbeats with the bytes
  the doors carried, fetches the doors again every hour, and starts over
  when the tunnel drops or a page stops loading through it three minutes in
  a row. The last doors are saved, so a router that restarts while the
  backend is out of reach still connects. Calls to the backend go direct
  first, then through the API relays, as the app's calls do.

The program's own lines and the core's warnings and errors go to the
system log (`logread`). The core's line for each connection names the
device's address and the site, so those lines stay out of the system log
unless the program runs with `-debug`. `fortiva call logs` still shows the
last of them, from memory.

The package around it:

- `/etc/init.d/fortiva` runs it under procd with a memory limit of a
  quarter of the router's memory (48 to 160 MB). It gives the program 15
  seconds to stop, so it can take the lookups back and send its last
  events first.
- `/usr/share/fortiva/firewall.sh` puts `fortiva0` in a firewall zone of
  its own, and gives every zone that forwards to `wan` a forwarding to it,
  since the tunnel's routes carry every zone's traffic. The install
  (`/etc/uci-defaults/90-fortiva`) and every start of the service run it,
  so a zone added later gets its forwarding at the next start. No
  masquerading: the tunnel ends in the program, which answers for every
  address.
- `/usr/share/fortiva/hook.sh` points dnsmasq at the resolvers in `dns`
  while the tunnel is up, so the network's lookups go through it, and back
  to the WAN's when it stops. The program also runs it with `down` when it
  starts, and so does the service before it starts the program, so a crash
  or a kill cannot leave the lookups on a tunnel that is gone.
- `/usr/share/fortiva/geoip.dat` and `geosite.dat` hold only the lists the
  routing rules use (`cmd/geotrim`): 40 KB instead of 27 MB.
- LuCI: `www/luci-static/resources/view/fortiva/status.js`, its menu entry
  and its rpcd ACL. The page reads `fortiva status`, so the page and the
  command line always agree.
- `/etc/fortiva` (the router's id and saved doors) and `/etc/config/fortiva`
  are kept through a firmware upgrade (`lib/upgrade/keep.d/fortiva`), so an
  upgraded router stays the same device, with its Premium.

What the router does not do that the app does: community and shared links,
the backup network, the door tests that run in the background, and the
fallback file. Its doors come from the backend or from its last saved
answer.

## Building

```bash
router/build.sh                 # every target, into router/dist/
router/build.sh arm64 mipsle    # only these
```

It cross-compiles from any computer with Go. For each target it makes
`fortiva-router-<target>.tar.gz` for `install.sh` and an `.ipk` for each
OpenWrt architecture name of that processor family, with
`fortiva-router-SHA256SUMS` (not `SHA256SUMS`, which is the APKs' name on a
release). It
refuses a program not built from the patched core, or without what the
doors need. The API relays are read from `lib/api/built_in.dart` and passed
to the compiler; they are never written to a file. The public copy's
`built_in.dart` holds none, so a router built there reaches the backend
directly and through the relays the backend sends.

## Tests

```bash
(cd windows/core && ./stage.sh && go test -race ./...)
router/build.sh arm64 && router/test/e2e.sh <xray> router/dist/fortiva-router-arm64.tar.gz
router/test/upgrade.sh
```

The Go tests run the agent against real doors in the process and a fake
backend: the door order, the search, the standby doors, the relays' pins,
saved doors when the backend is out of reach, a used-up allowance, pausing
and a Premium code.

`test/e2e.sh` runs the package on OpenWrt 24.10 in Docker: a fake backend
(`test/fake_api.py`), a door (an Xray binary for the Docker host's
processor, built from `android/core/.src/xray-core` with
`go build ./main`), the router, and a device behind it whose default route
is the router. It installs with `install.sh`, waits for the router to
connect, and checks that the device's page went through the door, that
the lookups went to the tunnel, that a guest zone may forward to it, that
turning it off takes the routes and the lookups back, that it reconnects
after a restart, that it sees the WAN's default route go and come back
within a second, that it connects with IPv6 turned off, that the events
reached the backend, and that a kill while connected leaves no lookups on
the tunnel once the door is gone. `/etc/fortiva/api` points the router at
the fake backend before the first start, so it never reaches Fortiva's.
`install.sh` downloads the build from a fake list of releases whose newest
release has no router files, after refusing a download whose checksum does
not match. At the end the test runs `fortiva uninstall` and checks that
nothing of Fortiva is left but `/etc/fortiva`, installs again from the file
and checks that it is the same router, runs `--purge`, and installs and
removes the `.ipk` next to the build, when there is one for the router.
Use the `arm64` build on an Arm Mac and `amd64` on a PC.

`test/upgrade.sh` runs `setup.sh` on OpenWrt in Docker with a small file
system for the program, and checks that an upgrade keeps on flash a
program that only fits because it replaces the old one.

## Publishing

The router files go on a release of the public copy by hand, like the
Windows installer: start the Router workflow there
(`tool/public/overlay/.github/workflows/router.yml`) with the release tag,
once that release is published. It builds every target at the tag and runs
`tool/public_sync.py --router`, which checks each build (its version, its
program, no one's home folder in it) and attaches the five builds,
`fortiva-router-install.sh` and `fortiva-router-SHA256SUMS`. With publish
off it only builds and checks them, and keeps them as the run's artifact
for three days, to try on a router first. A release without router files
changes nothing for routers: `install.sh` takes the newest release that has
them.

## Not done yet

- The LuCI page is in English only. It can take all 18 languages through
  LuCI's own translation files.
- Choosing which devices on the network use Fortiva. Today every device
  does.
- Choosing a location, as the app and the browser extension can. The page
  shows the door's name where it could show the location.
- Updating itself. A router keeps its version until `install.sh` runs again.
- The program is about 30 MB, because the core's configuration loader
  links in every protocol. Building the configuration without it would
  make it much smaller.
- OpenWrt 25's apk packages. `install.sh` installs there without one.
