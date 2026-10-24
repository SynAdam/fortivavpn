# iOS VPN core

`ios/Frameworks/LibXray.xcframework` is built from pinned upstream sources by
`build.sh` in this directory. Run that rather than editing the framework.

```
ios/core/build.sh                    # rebuild at the pinned tag
LIBXRAY_TAG=v26.8.1 ios/core/build.sh   # bump
```

## What is pinned

| | |
|---|---|
| Upstream | [XTLS/libXray](https://github.com/XTLS/libXray) |
| Tag | `v26.7.28` |
| Xray-core | `v1.260327.1-0.20260728075948-5ca6f4b7d4dc` |

That Xray-core commit is the same one `android/core` pins. Both platforms run
one core version, with one upstream to watch, which is what
`CORE-MAINTENANCE.md` asks for and what iOS was previously exempt from.

## What changed, and why the Swift shim exists

The framework used to be a fork nobody had the source for. It exported
`LibXrayFortivaGetBuildInfo` and `LibXrayFortivaGetEngineVersion`, which exist
in no upstream release and which nothing in this repo ever called, plus seven
flat entry points that upstream has since replaced with a single dispatcher:

```objc
NSString *LibXrayInvoke(NSString *requestJSON);
```

`ios/Runner/LibXrayCompat.swift` re-implements the old seven names on top of
`Invoke`, so the call sites in `AppDelegate.swift` and
`FortivaSecureTunnelProvider.swift` did not have to change. Delete that file
once the call sites speak `Invoke` directly.

## Slices

Only `ios-arm64` and `ios-arm64_x86_64-simulator` are built. Upstream's own
script also builds `macos` and `maccatalyst`, which is where most of the
previous 516 MB went. The simulator slice is kept because the app has to link
for simulator builds even though the tunnel itself cannot run there:
`NEPacketTunnelProvider` is device-only.

## Verifying a build

`build.sh` fails if the result contains fork symbols or is missing
`LibXrayInvoke`, and writes `checksums.txt`. To check the committed framework
matches what the script produced:

```
shasum -a 256 -c <(grep -v '^#' ios/core/checksums.txt | \
  sed 's|  |  ios/Frameworks/LibXray.xcframework/|')
```

## Still to do

The app bundles no `geoip.dat` or `geosite.dat`, so `geoip:` and `geosite:`
tokens cannot resolve and `AppDelegate` strips `routing` and `dns` from ping
configs to work around it. `LibXrayCompat` sets `XRAY_LOCATION_ASSET` from the
directory the callers already pass, so shipping the databases is the only
remaining step. Android solved the same problem in #38.
