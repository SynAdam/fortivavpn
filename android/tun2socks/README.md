# libtun2socks.so

The second native binary in the tunnel path. `libv2ray.aar` is built from
pinned sources by `../core/build.sh`; this one is not built by anything.
Every packet the app tunnels passes through it.

Issue #31 tracks making it reproducible. This directory holds the part
that could be done without building it: what it is, and a check that the
files have not changed.

## What is shipped

Extracted from the v2rayNG 1.10.8 APK into
`../app/libs/<abi>/libtun2socks.so`.

Read out of the binaries themselves rather than taken on trust:

| Fact | Value | Where it comes from |
|---|---|---|
| Project | BadVPN tun2socks | `./badvpn/tun2socks/tun2socks.c` in the debug paths |
| Version | 1.999.130 | the `initializing BadVPN tun2socks 1.999.130` string |
| Compiler | Android clang 19.0.1, build 13624864, based on r530567e | the `.comment` section |
| ABIs | arm64-v8a, armeabi-v7a, x86, x86_64 | the files present |

1.999.130 is the last tagged release of
[ambrop72/badvpn](https://github.com/ambrop72/badvpn). The clang build
corresponds to NDK r27, which is older than the r28 this app builds
everything else with.

Upstream is BSD-3-Clause, recorded in `../../THIRD-PARTY-NOTICES.md`.

## What is checked

`./verify.sh` does two things:

1. Compares each `.so` against `checksums.txt`, so a swapped binary shows
   up as a failure instead of shipping unnoticed.
2. Asserts 16 KB `LOAD` alignment on the 64-bit ABIs. An unaligned `.so`
   fails at `System.loadLibrary("tun2socks")` at runtime on an Android 15
   device with 16 KB pages, not at build time, and that failure is a total
   outage for whoever hits it.

The 32-bit ABIs keep 4 KB pages and are not subject to the requirement.

## What is still missing

The build. Nobody can currently reproduce, audit or patch these files, and
recording a checksum does not change that: it pins what we have, not what
it should be.

The remaining work in #31 is a `build.sh` next to `../core/build.sh` that
compiles all four ABIs from badvpn at a pinned commit with the NDK this
app already requires, writes the checksums itself, and asserts the
alignment on the output rather than on a binary someone else produced.
