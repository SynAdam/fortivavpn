# Android VPN core

This directory builds `../app/libs/libv2ray.aar`, the Xray-core binary the
Android app tunnels through. Nothing here is compiled into the app; the app
consumes only the `.aar` this produces.

| | |
|---|---|
| Core | [Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0), with the patches in `patches/` |
| Java binding | [2dust/AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) (LGPL-3.0), plus our own `fortivacore/` |
| Last resort | [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) (GPL-3.0) v2.0.41, its `MobileLibrary/psi` package, in the same `libgojni.so`. See [Psiphon](#psiphon). |
| Pinned versions | `go.mod` (exact), `go.sum` (checksums), `stage-xray.sh` (Xray-core version and checksum), `stage-psiphon.sh` (Psiphon's quic-go fork version and checksum) |
| Toolchain | `Dockerfile` (Go, NDK, JDK, Android platform and base image, each by version and checksum); `build-in-linux.sh` builds in it |
| Last built | `checksums.txt` |

## Why this exists

The `.aar` that shipped before this directory was built on a contributor's
laptop and carried a `replace` directive pointing at a folder in their home
directory. Nothing in the repository could reproduce it, so nobody could tell
what was inside it, patch it, or verify it hadn't been tampered with.

Now the entire dependency tree is pinned by `go.sum`, and the toolchain by
`Dockerfile`. So `./build-in-linux.sh` produces the same core on any machine
that runs Docker, and `govulncheck` can be pointed at it.

## Building

The core the app ships is built in a Linux container by `build-in-linux.sh`.
It needs Docker and network access, and runs from any checkout:

```bash
android/core/build-in-linux.sh          # all four ABIs, required for anything you ship
android/core/build-in-linux.sh arm64    # one ABI, for local iteration only
```

The script builds the image that `Dockerfile` describes and runs `build.sh`
in a container of it, in the folder `/build/fortiva-core`. Then it copies
`../app/libs/libv2ray.aar` and `checksums.txt` back into the tree, and prints
the new sha256 next to the one `checksums.txt` had before. A one-ABI build
copies back only the `.aar`: `build.sh` writes `checksums.txt` only in a full
build, so a one-ABI `.aar` never matches it. The container gets
a copy of `android/core` as git sees it: tracked files and new files that
`.gitignore` does not hide, with their uncommitted changes. It gets nothing
else from the machine.

The image is linux/amd64 on every machine, because Google builds the NDK for
Linux for x86_64 only. Docker Desktop on an Apple silicon Mac runs it through
Rosetta or QEMU. The Go module cache and build cache stay in the Docker
volumes `fortiva-core-gomod` and `fortiva-core-gocache`, so a second build is
faster. `docker volume rm fortiva-core-gomod fortiva-core-gocache` removes
them.

`Dockerfile` pins every input:

| Input | Pinned to |
|---|---|
| Base image | `debian:bookworm-slim`, linux/amd64, by digest |
| Debian packages (`patch`, `unzip`, `binutils`, `perl`, `curl`, `ca-certificates`) | the snapshot.debian.org date the base image was made from |
| Go | the `toolchain` line of `go.mod`, with the sha256 that go.dev lists |
| Android NDK | `REQUIRED_NDK` in `build.sh` (r28c), with the sha256 of Google's download |
| Android SDK platform | `android-36.1` revision 1, with the sha256 of Google's download |
| JDK | Eclipse Temurin 25.0.1+8, with the sha256 that Adoptium publishes |
| gomobile and gobind | `golang.org/x/mobile` in `go.mod`; `build.sh` builds them into `.bin/` |

gomobile compiles the Java side of the binding against `android.jar` of the
newest platform in `$ANDROID_HOME/platforms`, so the image holds that one
platform and no other. Nothing else from the Android SDK is used, so the SDK
command-line tools are not installed.

### The build folder is part of the core

gomobile writes the absolute build folder into each `libgojni.so`: the build
info replaces this module and the two in `.src/` by their directories, and
`-trimpath` does not remove them. A build in a home folder would put that
account's name into every APK, and a build in any other folder of a laptop
would name that laptop's layout. So `build.sh`:

- refuses to run in a home folder (`$HOME`, `/Users/<name>` other than
  `/Users/Shared`, or `/home/<name>`);
- runs a full build only in `/build/fortiva-core/android/core`, the folder
  `build-in-linux.sh` builds in;
- refuses a built `libgojni.so` whose strings contain a home folder. In a full
  build it also refuses any `/Users/` or `/home/` path, and any folder in the
  build info outside `/build/fortiva-core`.

A one-ABI build (`./build.sh arm64`) still runs on your own machine, in any
folder outside a home folder, for quick iteration. It needs Go (the version
`go.mod` pins), NDK `28.2.13676358`, a JDK and an Android SDK platform. Its
`.aar` is not shippable, and it leaves `checksums.txt` as it was.

### Checking the shipped core

Anyone can rebuild the committed core and compare it:

```bash
git checkout <commit>
android/core/build-in-linux.sh
git status --short android/app/libs/libv2ray.aar android/core/checksums.txt
```

When the build reproduces the commit, the script prints the same sha256
twice, and `git status` shows neither file as changed. `checksums.txt` records
the versions the core came from, the build folder, and the sha256 of the
`Dockerfile` the image was built from. Commit it with the `.aar`.

### Moving the toolchain

`build-in-linux.sh` refuses to build when the image and the source disagree:

- A new `toolchain` line in `go.mod` needs `GO_VERSION` and `GO_SHA256` in
  `Dockerfile` (from <https://go.dev/dl/>).
- A new NDK changes `REQUIRED_NDK` in `build.sh`, `ndkVersion` in
  `android/app/build.gradle.kts`, and `NDK_VERSION`, `NDK_RELEASE` and
  `NDK_SHA256` in `Dockerfile`. Google's package index
  (`https://dl.google.com/android/repository/repository2-3.xml`) lists each
  download with a sha1. Check the file against it, then pin its sha256.

A change to the JDK or the platform is a change to `classes.jar`. Rebuild
and compare `classes.jar` with the old one before you commit it.

## Patches

The core is not stock Xray-core. `patches/` holds the changes we add to it,
and each patch file starts with where it came from and its licence.

| Patch | What it adds |
|---|---|
| `xray-autoselect.patch` | The `autoselect` outbound: a group of outbounds that sends each connection through the healthiest member and retries a failed connection on the next one. Written by CluvexStudio for ZedSecure, MPL-2.0. |
| `xray-failover-calm.patch` | Failover in the `autoselect` outbound leaves a failing door only for one that has been calmer, and prefers a door on the same server (the new `exits` setting), so the user's exit address changes less. Applied after `xray-autoselect.patch`. Ours, MPL-2.0. |
| `xray-sinkhole.patch` | A connection headed to Iran's filtering sinkhole (10.10.34.0/24) is dialled by its sniffed name, even with routeOnly. Apps that looked a name up before the tunnel came up hold that address. Ours, MPL-2.0. |
| `xray-stability-penalty.patch` | The `autoselect` outbound adds the backend's penalty for a door to that door's score (the new `penalties` setting), so a door that answers probes fast but fails in the middle of sessions stops winning on its probes alone. Applied after `xray-failover-calm.patch`. Ours, MPL-2.0. |
| `xray-wireguard-close.patch` | Closing a WireGuard outbound while it still carries traffic no longer ends the process. Its gVisor device closed a channel that a sender could still be waiting on, and that sender panicked on a goroutine where nothing recovers. It also sets the bind's functions before `device.NewDevice` starts using them. Ours: the change to `netstack.go` is MIT (the licence `netstack.go` carries), `client.go` and the new test are MPL-2.0. |
| `psiphon-quic-go/qpack-v0.6.patch` | Not an Xray-core patch. It moves the `http3` package of Psiphon's quic-go fork to the quic-go/qpack v0.6 API that Xray-core needs, so Psiphon builds next to Xray-core. `stage-psiphon.sh` applies it. Ours, MIT. See [Psiphon](#psiphon). |

`stage-xray.sh` copies the pinned Xray-core out of the Go module cache, checks
its checksum, applies every patch and leaves the result in `.src/xray-core`
(not committed). `go.mod` replaces `github.com/xtls/xray-core` with that
directory, so run `./stage-xray.sh` before any `go` command here. `build.sh`
runs it for you. It applies only the top-level `patches/*.patch`. The patch in
`patches/psiphon-quic-go/` is applied by `stage-psiphon.sh` instead (see
[Psiphon](#psiphon)).

To run a patch's tests against our base:

```bash
./stage-xray.sh
(cd .src/xray-core && go test -race ./proxy/wireguard/ ./proxy/autoselect/ ./app/dispatcher/)
```

Xray-core is MPL-2.0, so the changed files have to be available to anyone who
gets the app. They are: the patch is in this repository, which is the source
we hand over for the Android build.

## Bumping the core

1. Find the upstream tag you want on
   [AndroidLibXrayLite/releases](https://github.com/2dust/AndroidLibXrayLite/releases).
   Its tags (`v26.8.20`) are **not** valid Go module versions (the module path
   has no `/v26` suffix), so pin by commit instead:

   ```bash
   go get github.com/2dust/AndroidLibXrayLite@<commit-of-that-tag>
   go mod tidy
   ```

2. Update the note that pairs the tag with its commit at the top of `go.mod`.
3. If the bump changed the Xray-core version in `go.mod`, set `XRAY_VERSION`
   and `XRAY_SUM` in `stage-xray.sh` to the new one (`go mod download -json
   github.com/xtls/xray-core@<version>` prints the sum), run `./stage-xray.sh`
   and run each patch's tests. A patch that no longer applies has to be
   redone against the new source before anything is built.
4. `./build-in-linux.sh`
5. Rebuild the app and **test a real connection on a device**. The `.aar` is a
   prebuilt binary, so a binding change upstream compiles fine and fails at
   runtime.
6. Commit `go.mod`, `go.sum`, `stage-xray.sh`, `checksums.txt`, and the `.aar` together.

`build.sh` refuses to emit an `.aar` that is missing the Java API the Kotlin
layer calls, is missing REALITY/XTLS-Vision or the autoselect outbound, lacks
the geo data, or is not 16 KB page-aligned on 64-bit. Each of those otherwise fails on a user's phone
rather than in CI.

## Psiphon

The app's last resort: when our own doors and the community links all fail
to connect, the app can start Psiphon and send the tunnel through it. The
feature ships switched off, and only the backend turns it on.

The core contains Psiphon's `MobileLibrary/psi` package, bound by the same
`gomobile bind` as AndroidLibXrayLite and `fortivacore`, so one `libgojni.so`
holds all three. Psiphon's own `ca.psiphon.aar` cannot sit next to ours,
because both contain `go/Seq*.class` and `jni/<abi>/libgojni.so`. We do not
use its `PsiphonTunnel.java` either: the Kotlin layer implements the `psi`
interfaces itself, so the app needs no new permission.

### The pin

- Release **v2.0.41**, commit `96f782c6f662cb0a884029d70e1375ab3c1dece2`,
  published on 2026-09-01. It was the latest release when it was pinned.
- `go.mod` holds it as `v1.0.11-0.20260821154217-96f782c6f662`. Psiphon's
  `v2.x` tags are not valid versions for a module path without `/v2`, so Go
  can only address the release by its commit.
- Pin releases only, never `master`. The Java API changes between releases
  (step 6 of [Bumping Psiphon](#bumping-psiphon) has an example).
- `tools.go` imports `MobileLibrary/psi`, so `go mod tidy` keeps it.
- Psiphon's `go.mod` says `go 1.26.0`, so ours says the same.

### What it takes to build next to Xray-core

Two changes. Both were checked again at v2.0.41: without either one the
bind fails to compile.

1. **`github.com/tailscale/netlink` is bumped** from the commit Psiphon pins,
   `cabfb018fe85` (2021), to `4d49adab4de7` (2024-08-22, its newest commit).
   Psiphon's `psiphon/common/tun` imports it. The old commit imports
   `vishvananda/netlink/nl`, whose API changed in v1.3.1, the version
   Xray-core needs. The new commit only changes import paths, to tailscale's
   own copy of `nl`. It is an ordinary requirement in `go.mod`, so a Psiphon
   bump keeps it unless Psiphon itself requires a newer one.
2. **`patches/psiphon-quic-go/qpack-v0.6.patch`** moves the `http3` package of
   Psiphon's quic-go fork (`github.com/Psiphon-Labs/quic-go`) from the
   quic-go/qpack v0.4 API to v0.6. Xray-core needs qpack v0.6, and one build
   holds one version of a module. `stage-psiphon.sh` copies the fork out of
   the module cache, checks it against `QUIC_SUM`, applies the patch and
   leaves the result in `.src/psiphon-quic-go`, which `go.mod` replaces the
   fork with. The patch lives in a subdirectory because `stage-xray.sh`
   applies every top-level patch to Xray-core. Inside Psiphon this code runs
   only for meek over QUIC.

The fork's own `http3` tests use the v0.4 API and do not compile, so
`psiphonquic/` tests the patch from outside the fork, with one HTTP/3 request
that goes through every changed call:

```bash
./stage-xray.sh && ./stage-psiphon.sh
go test -race ./psiphonquic/
```

Other things to know:

- Psiphon's `go.mod` has two `replace` lines (obfs4 and `pion/dtls/v2`). Go
  ignores `replace` lines in a dependency, and both matter only with the
  build tag `PSIPHON_ENABLE_REFRACTION_NETWORKING`. We do not set it, so the
  core has no refraction networking (Conjure). Psiphon's own builds do.
  Building with the tag needs Psiphon's `replace/dtls`, which is not in the
  module download.
- 15 of Psiphon's dependencies are built at a newer version than Psiphon
  pins: andybalholm/brotli, klauspost/compress, klauspost/cpuid, miekg/dns,
  pires/go-proxyproto, quic-go/qpack (patched), refraction-networking/utls,
  syndtr/gocapability, tailscale/netlink, vishvananda/netlink and netns,
  x/exp, x/net, wireguard and protobuf. For most of them, Xray-core needs the
  newer version. syndtr/gocapability is different: gomobile builds in a
  module of its own that requires every module of ours directly, so a
  requirement that Go's graph pruning drops here (from runc) counts there.
  `go.mod` pins the version that is actually linked. They all compile. Only
  the end-to-end test against our own `psiphond` shows that Psiphon still
  works with them.
- Modules Xray-core already linked keep their versions, except
  `pion/dtls/v3`, which moves from v3.1.4 to v3.1.5.
- `build.sh` sets `psiphon/common/buildinfo.buildRev` to the first 10 hex
  digits of the commit (`96f782c6f6`), as Psiphon's own `make.bash` does with
  `git rev-parse --short=10`. Psiphon sends it to its servers as
  `client_build_rev`. `buildDate` stays empty, because a date would make
  every build different.
- `build.sh` also refuses an `.aar` without `psi/Psi.class` and
  `psi/PsiphonProvider.class`, and reads the build info Go writes into every
  `libgojni.so` (`go version -m`). Each one must link the Psiphon version in
  `go.mod`, take `Psiphon-Labs/quic-go` from `.src/psiphon-quic-go`, and be
  built by the Go that `go.mod` pins. Every other linked module that is not
  replaced must be at the version `go list -m all` gives, so a module that
  gomobile resolves higher stops the build instead of shipping unpinned.
  `checksums.txt` records the Psiphon version and commit, the quic-go fork's
  version and the patch's sha256.

### Bumping Psiphon

1. Pick a release on
   [psiphon-tunnel-core/releases](https://github.com/Psiphon-Labs/psiphon-tunnel-core/releases).
   `.github/workflows/core-upstream-watch.yml` opens an issue for each new
   one. Find the release's commit:

   ```bash
   gh api repos/Psiphon-Labs/psiphon-tunnel-core/commits/<tag> --jq .sha
   ```

2. Stage the sources, then move the pin:

   ```bash
   ./stage-xray.sh && ./stage-psiphon.sh
   go get github.com/Psiphon-Labs/psiphon-tunnel-core@<commit>
   go mod tidy
   ```

3. Update the tag and commit note at the top of `go.mod`.
4. If `go.mod` now requires another `Psiphon-Labs/quic-go`, `stage-psiphon.sh`
   stops and says so. Set `QUIC_VERSION` and `QUIC_SUM` in it
   (`go mod download -json github.com/Psiphon-Labs/quic-go@<version>`, run
   outside this directory, prints the sum), run `./stage-psiphon.sh`, and
   redo the patch if it no longer applies. If the fork has moved to qpack
   v0.6 by itself, delete the patch, `stage-psiphon.sh`, the `replace` line
   in `go.mod`, and in `build.sh` the call to `stage-psiphon.sh` and the
   quic-go check.
5. `go test -race ./psiphonquic/ ./fortivacore/`, then
   `./build-in-linux.sh`. If
   `build.sh` stops because a module is linked at another version than
   `go.mod` resolves, pin the linked one
   (`GOFLAGS= go get <module>@<linked version> && GOFLAGS= go mod tidy`) and
   build again.
6. Compare the Java API with the one the app binds (below):
   `javap -classpath classes.jar psi.Psi psi.PsiphonProvider` on the old and
   new `.aar`. A change there still builds here and breaks the Kotlin layer.
   For example, Psiphon's `master` after v2.0.41 adds `onAccessToken` to
   `PsiphonProvider`. Also look for Go runtime settings that Psiphon changes
   for the whole process, and extend `fortivacore/runtime.go` for any new one:

   ```bash
   cd "$(go list -m -f '{{.Dir}}' github.com/Psiphon-Labs/psiphon-tunnel-core)"
   grep -rn 'debug\.Set\|GOMAXPROCS(' psiphon MobileLibrary/psi --include='*.go' | grep -v _test.go
   ```

   At v2.0.41 this finds `SetGCPercent` and `GOMAXPROCS`, which
   `restoreRuntime()` undoes, and `SetPanicOnFault`, `SetTraceback` and
   `SetCrashOutput`, which Psiphon resets itself or which only run in calls
   the app does not make.
7. Test the fallback end to end against our own `psiphond` in Docker. Do not
   connect to Psiphon's network until Psiphon has given us partner IDs.
8. Commit `go.mod`, `go.sum`, `stage-psiphon.sh`, the patch,
   `checksums.txt` and the `.aar` together.

## The app's side of the contract

The Kotlin layer binds these, and only these:

- `Libv2ray.newCoreController`, `initCoreEnv`, `checkVersionX`, `measureOutboundDelay`
- `CoreController.startLoop(config, tunFd)`, `stopLoop`, `isRunning`, `measureDelay`,
  `queryAllOutboundTrafficStats`
- `CoreCallbackHandler.startup`, `shutdown`, `onEmitStatus`

From `fortivacore/`, our own package bound next to AndroidLibXrayLite:

- `Fortivacore.autoSelectStatus()`: every running autoselect group as JSON
- `Fortivacore.autoSelectNetworkChanged()`: measure all members again now
- `Fortivacore.autoSelectPin(group, member)`: hold new connections on one
  member. Exported, but nothing in the app calls it yet.
- `Fortivacore.prepareDoorChecks()`: installs the system dialer that lets a
  timed door check see its own sockets. `MainActivity` calls it once at start,
  in the main process, before any check. Dials of anything else go through
  unchanged, and the tunnel's process never calls it.
- `Fortivacore.checkDoorTimed(config, url, timeoutMs)`: the check
  `measureOutboundDelay` makes, on the same config, returned as JSON with how
  far it got: TCP connect time, first byte back, first byte of the reply,
  bytes each way, and a phase word (`fortivacore/doorcheck.go`, backend
  issue #365). A door reads open only when both requests finish within
  `timeoutMs`, as the app's wait around `measureOutboundDelay` accepts, so
  open and closed mean what they meant. The error text has every IP address
  cut out. Tests: `./stage-xray.sh`, then `go test -race ./fortivacore/`.
- `Fortivacore.restoreRuntime()`: puts the Go runtime's GC percent back to
  its value at process start and GOMAXPROCS back to Go's default, after
  Psiphon has changed them (see `Psi.start` below,
  `fortivacore/runtime.go`). The tunnel's process calls it on every path that
  ends a Psiphon session, after `Psi.stop()` returns, and also after a
  `Psi.start` that threw.

From `psi/`, Psiphon's package (see [Psiphon](#psiphon)), at v2.0.41:

- `Psi.start(config, embeddedServerEntryList, embeddedServerEntryListFilename,
  provider, useDeviceBinder, useIPv6Synthesizer, useHasIPv6RouteGetter)`:
  `config` is Psiphon's JSON config. It returns once Psiphon is running, and
  throws if it is already running or the config is refused (for example an
  empty `PropagationChannelId` or `SponsorId`). It can block while it imports
  an embedded server list, so call it off the main thread. The app passes
  `useDeviceBinder = false`, because its own sockets already skip its VPN.
  For reference, Psiphon's `PsiphonTunnel.java` passes
  `useIPv6Synthesizer = false` and `useHasIPv6RouteGetter = true` on Android.
  Two side effects reach Xray-core, because both share one Go runtime:
  - Before it reads the config, it sets the GC percent to 5 for the whole
    process (`psiphon.DoGarbageCollection`, `psiphon/utils.go`). Psiphon sets
    it again while it runs. Go's default is 100. So during a Psiphon session,
    Xray-core runs with far more garbage collection.
  - If the config has `"LimitCPUThreads": true`, Psiphon sets GOMAXPROCS to 1
    for the whole process (`psiphon/controller.go`, `Controller.Run`). The app
    must therefore always set `LimitCPUThreads` to `false` itself, as it does
    for the other keys it owns, whatever the backend sends.
- `Psi.stop()`: blocks until Psiphon has stopped. It does not undo either
  side effect, so call `Fortivacore.restoreRuntime()` after it.
- `Psi.networkChanged()`: drops all of Psiphon's connections, the tunnel
  included, so it reconnects on the current network.
- `PsiphonProvider`, which the Kotlin layer implements. Every call goes
  through one lock inside `psi`, so each method must return quickly: a slow
  `notice` also holds up the DNS and network lookups.
  - `notice(String)`: every notice, as JSON
    `{"noticeType", "data", "timestamp"}`. `Tunnels` with a count of 1 or more
    means connected.
  - `hasNetworkConnectivity(): long`: 1 or 0. While it returns 0, Psiphon
    waits.
  - `getNetworkID(): String`: must always return a value. The part before the
    first `-` (`WIFI`, `MOBILE`, `WIRED`, `VPN` or `UNKNOWN`) is sent to
    Psiphon's server as `network_type`.
  - `getDNSServersAsString(): String`: the resolvers, comma-separated. It may
    be empty.
  - `bindToDevice(long): String`, `iPv6Synthesize(String): String` and
    `hasIPv6Route(): long` must exist, but Psiphon calls each one only when
    its `use...` flag in `start` is true.

`PsiphonProvider` extends `PsiphonProviderNetwork` and
`PsiphonProviderNoticeHandler`. At v2.0.41 it has no `onAccessToken`.

`startLoop` is called with `tunFd = 0`, meaning the core does **not** open its
own TUN device: routing stays with `tun2socks` over the SOCKS inbound that
`V2RayVpnService` sets up. Passing a real fd would bypass that path entirely.

`queryAllOutboundTrafficStats` feeds the heartbeat's byte counts. It returns
`tag,direction,value;...` and resets every counter it reports, so nothing else
may call it. While the session readings run (backend issue #365), the
tunnel's process calls it once a period, never more than once a second, and
answers the app from what it counted (`service/SessionMeter.kt`). The core
also exposes `RegisterProcessFinder()`, which the app does not use.
