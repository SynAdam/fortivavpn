# VPN core maintenance

The core is the one dependency in this project where being out of date is a
*product* failure, not just a hygiene one. This document says what we ship, how
current it is, and when we move it.

## What we ship

| | Android | iOS |
|---|---|---|
| Core | Xray-core | Xray-core |
| Binding | [2dust/AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) | [XTLS/libXray](https://github.com/XTLS/libXray), stock upstream |
| Artifact | `android/app/libs/libv2ray.aar` | `ios/Frameworks/LibXray.xcframework` (Git LFS) |
| Reproducible | yes, `android/core/build-in-linux.sh` | yes, `ios/core/` |
| Pinned in | `android/core/go.mod` + `go.sum`, `android/core/stage-xray.sh`, the toolchain in `android/core/Dockerfile` | `LIBXRAY_TAG` in `ios/core/build.sh`, `ios/core/checksums.txt` |
| Patches | `android/core/patches/` (the `autoselect` outbound, its calmer failover, the backend's stability penalty, the sinkhole dial) | none |

Both platforms terminate VLESS in Xray-core and hand plaintext to a local
SOCKS5 inbound on `:10808`, which `tun2socks` (Android) / `hev-socks5-tunnel`
(iOS) bridges to the TUN device. The Windows tunnel service (`windows/core`)
builds Android's pinned source with Android's patches, and has no SOCKS
inbound: Xray's own TUN inbound takes the packets.

## Why currency matters here

For a censorship-circumvention core the dangerous failure mode is not a CVE, it
is **detectability**. Censors fingerprint TLS/uTLS behaviour, REALITY handling
and padding patterns, and upstream ships countermeasures continuously. A core
that is a year behind gets blocked long before it gets exploited. Treat an
upstream release that touches transport, TLS fingerprinting or REALITY as
urgent even when it carries no security label.

## Update policy

**Do not track every upstream tag.** These cores ship protocol changes and
occasional regressions, and every bump means re-testing the whole tunnel on a
real device. Churn in the component that carries all user traffic is its own
risk.

Instead:

- **Watch, then triage.** `.github/workflows/core-upstream-watch.yml` opens an
  issue when upstream publishes a release we are behind. Read the changelog and
  decide; do not auto-merge.
- **Take it immediately** for: anything security-labelled, anything touching
  TLS/uTLS/REALITY/transport fingerprinting, or a bug we are actually hitting.
- **Otherwise refresh quarterly**, regardless, so drift stays bounded.
- **Always device-test before release.** Both artifacts are prebuilt binaries:
  a changed binding compiles cleanly and fails when a user taps Connect.
- **Build the Android core with `android/core/build-in-linux.sh`.** It builds
  in `/build/fortiva-core` inside a linux/amd64 container whose toolchain
  `android/core/Dockerfile` pins. gomobile writes the absolute build folder
  into each `libgojni.so`, so a build on a laptop puts that laptop's folder
  into every APK, and a build in a home folder puts the account's name there.
  `android/core/build.sh` runs a full build only in `/build/fortiva-core` and
  never in a home folder. Anyone can run the script on a commit and compare
  the sha256 with `android/core/checksums.txt`.

Per-platform mechanics live in [`android/core/README.md`](android/core/README.md),
[`ios/core/README.md`](ios/core/README.md) and
[`windows/core/README.md`](windows/core/README.md).

## Psiphon

The Android core also contains psiphon-tunnel-core, Psiphon's tunnel library,
for the app's last resort: the app starts it only when our own doors and the
community links all fail to connect. It is built into the same `libv2ray.aar`
and the same `libgojni.so` as Xray-core. The mechanics are in
[`android/core/README.md`](android/core/README.md), section "Psiphon".

| | |
|---|---|
| Upstream | [Psiphon-Labs/psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core), GPL-3.0 |
| What we bind | its `MobileLibrary/psi` package |
| Pinned | release v2.0.41, commit `96f782c6f662` |
| Pinned in | `android/core/go.mod` + `go.sum`; `android/core/stage-psiphon.sh` for its quic-go fork |
| Patches | `android/core/patches/psiphon-quic-go/` (its quic-go fork moved to the qpack version Xray-core needs) |

Update policy for Psiphon:

- **Pin releases, never `master`.** Psiphon's `master` changes the Java API
  between releases. For example, `master` after v2.0.41 adds a method to the
  interface the app implements.
- **Watch, then triage.** `.github/workflows/core-upstream-watch.yml` opens an
  issue when Psiphon publishes a release whose commit is not the one we pin.
  Read the release notes and decide. Do not auto-merge.
- **Take it immediately** for a security fix or for a bug we are hitting.
- **Otherwise move it with the quarterly refresh**, so the drift stays small.
- **Check the build fixes at every bump.** Two changes let Psiphon build next
  to Xray-core: a newer `tailscale/netlink` and the quic-go patch. Check that
  each is still needed and still applies, and compare the `psi` Java API with
  what the app binds.
- **Test against our own `psiphond` before release.** Nothing may connect to
  Psiphon's network until Psiphon has given us partner IDs.
- A Psiphon bump and an Xray-core bump are separate changes. Either one
  rebuilds the `.aar`, so either one needs the device test.

## History: what the Xray migration fixed on Android

Until this migration Android did **not** run Xray-core. Its `libv2ray.aar`
embedded `v2fly/v2ray-core v5.38.0`, built from
`github.com/2dust/AndroidLibV2rayLite` via a `replace` directive pointing at
a working copy in a home folder on a developer's laptop, at an unknown commit.
Consequences:

1. **REALITY and XTLS-Vision were silently unsupported.** The Kotlin layer
   generates `realitySettings`, `publicKey`, `shortId`, `spiderX` and
   `flow: xtls-rprx-vision`, all Xray-only features that v2ray-core does not
   implement. The core could not honour them, so connections that were supposed
   to be camouflaged as REALITY were not.
2. **Nothing could rebuild it**, so it could not be patched or audited.
3. It carried a **~13-month-old Go runtime** (go1.24.5) and its TLS stack.

Android now builds Xray-core from pinned, checksum-verified sources, and
`build.sh` asserts REALITY/Vision are present so this cannot silently regress.

## iOS

iOS used to run a libXray fork that nobody had the source for, six months
behind and outside this policy. `ios/core/build.sh` now builds it from stock
upstream libXray at a pinned tag, on the same Xray-core commit Android pins,
and refuses a build that carries the fork's symbols. Android's patches are
not applied on iOS. The Swift call sites still use the fork's seven flat
entry points, which `ios/Runner/LibXrayCompat.swift` maps onto upstream's
single `LibXrayInvoke`. See [`ios/core/README.md`](ios/core/README.md).
