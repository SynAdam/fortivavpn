# Third-party notices

Fortiva VPN is built on existing open-source work. Each component below
keeps its own licence, and those licences apply to the distributed app.

**The platforms differ.** The Android and Windows builds contain GPL-3.0
code and are GPL-3.0 as a whole. The iOS build contains none of it: its
tunnel is a different stack, all of it permissively licensed. See
`LICENSING.md` for what that means for each build.

---

# Android

## v2rayNG: GPL-3.0

The native Android layer (`android/app/src/main/java/com/vpn/fortivavpn/`,
72 Kotlin files) is derived from **v2rayNG** by 2dust:

- Upstream: https://github.com/2dust/v2rayNG
- Licence: GNU General Public License v3.0

Traces of the original package remain in the source, for example the
`com.v2ray.ang.action.*` broadcast constants in `AppConfig.kt` and the
`isXray()` application-id check in `util/Utils.kt`.

Because this is a derivative work, the whole application is distributed
under GPL-3.0 and the complete corresponding source must be offered to
anyone who receives the app.

## shadowsocks-android: GPL-3.0

Files under `android/app/src/main/java/com/vpn/fortivavpn/plugin/` carry
explicit GPL-3.0 headers:

- Copyright (C) 2021 nekohasekai <contact-sagernet@sekai.icu>
- Copyright (C) 2021 Max Lv <max.c.lv@gmail.com>
- Copyright (C) 2021 Mygod Studio <contact-shadowsocks-android@mygod.be>
- Upstream: https://github.com/shadowsocks/shadowsocks-android

## libv2ray (`android/app/libs/libv2ray.aar`)

The Android VPN core. Despite the `libv2ray` name (the Java package the
binding exposes, kept for source compatibility), this embeds **Xray-core**,
not v2ray-core.

- Xray-core: Mozilla Public License 2.0, https://github.com/XTLS/Xray-core
- The `autoselect` outbound, added to Xray-core by
  `android/core/patches/xray-autoselect.patch`: Mozilla Public License 2.0.
  Written by CluvexStudio for ZedSecure, taken from
  https://github.com/CluvexStudio/Xray-core (branch `zedsecure`). The patch
  file is the source of every Xray-core file we change.
- Dialling a sinkhole address by its sniffed name, added to Xray-core by
  `android/core/patches/xray-sinkhole.patch`: Mozilla Public License 2.0.
  Written for Fortiva. It changes `app/dispatcher/default.go` and adds
  `app/dispatcher/sinkhole.go` and its test.
- A calmer failover for the autoselect outbound, added to Xray-core by
  `android/core/patches/xray-failover-calm.patch`: Mozilla Public License
  2.0. Written for Fortiva. It changes files under `proxy/autoselect/` and
  `infra/conf/autoselect.go`, and adds `proxy/autoselect/failover_calm_test.go`.
- The backend's stability penalty in the autoselect outbound's choice of
  door, added to Xray-core by
  `android/core/patches/xray-stability-penalty.patch`: Mozilla Public
  License 2.0. Written for Fortiva. It changes files under
  `proxy/autoselect/` and `infra/conf/autoselect.go`, and adds
  `proxy/autoselect/stability_penalty_test.go` and
  `proxy/autoselect/stability_penalty_integration_test.go`.
- Closing the WireGuard outbound without a crash when it still carries
  traffic, added to Xray-core by
  `android/core/patches/xray-wireguard-close.patch`. Written for Fortiva. It
  changes `proxy/wireguard/netstack.go`, which stays under the MIT licence
  it carries (Copyright (C) 2017-2025 WireGuard LLC). It also changes
  `proxy/wireguard/client.go` and adds `proxy/wireguard/netstack_close_test.go`:
  Mozilla Public License 2.0.
- AndroidLibXrayLite (the gomobile binding): GNU Lesser General Public
  License 3.0. https://github.com/2dust/AndroidLibXrayLite
- sing and sing-shadowsocks, which the Shadowsocks support of Xray-core
  uses: GNU General Public License v3.0, or (at your option) any later
  version. Copyright (C) 2022 nekohasekai. https://github.com/SagerNet/sing
  and https://github.com/SagerNet/sing-shadowsocks

Exact versions are pinned in `android/core/go.mod` and recorded in
`android/core/checksums.txt`; the full transitive dependency set, with
checksums, is in `android/core/go.sum`. Built from source by
`android/core/build.sh`, which `android/core/build-in-linux.sh` runs in a
pinned Linux container for the core the app ships.

MPL-2.0 is file-level copyleft: modifications to MPL-licensed files must be
published, but linking from other code is permitted. The only MPL files we
change are the Xray-core files in the patch named above, and that patch is
published with the source of the Android build.

> Before 2026-08 this artifact instead embedded `v2fly/v2ray-core` v5.38.0 via
> `2dust/AndroidLibV2rayLite`, and this notice listed both cores because the
> build could not be inspected. That is no longer what ships.

## tun2socks (`android/app/libs/*/libtun2socks.so`)

Prebuilt native library derived from badvpn's tun2socks, extracted from the
v2rayNG 1.10.8 APK. Unlike the core, this is not yet built from pinned source.

The binaries identify themselves as BadVPN tun2socks 1.999.130, the last
tagged upstream release, built with Android clang 19.0.1 (NDK r27). See
`android/tun2socks/README.md` for how that was read off them and for what
`android/tun2socks/verify.sh` checks; issue #31 tracks building them.

- Upstream: https://github.com/ambrop72/badvpn
- Version: 1.999.130
- Licence: BSD-3-Clause

## psiphon-tunnel-core: GPL-3.0

Psiphon's tunnel library is compiled into `libgojni.so` inside
`android/app/libs/libv2ray.aar`, next to Xray-core. The app uses it as its
last resort, when nothing else connects. We bind its `MobileLibrary/psi`
package ourselves; we do not ship Psiphon's prebuilt `ca.psiphon.aar` or its
`PsiphonTunnel.java`.

- Upstream: https://github.com/Psiphon-Labs/psiphon-tunnel-core
- Version: v2.0.41, commit `96f782c6f662cb0a884029d70e1375ab3c1dece2`,
  pinned in `android/core/go.mod`
- Copyright: Psiphon Inc.
- Licence: GNU General Public License v3.0, or (at your option) any later
  version, as its file headers say

Its own dependencies keep their own licences. The full set, with checksums,
is in `android/core/go.sum`. Two of them are changed for this build:

- Psiphon's fork of quic-go (https://github.com/Psiphon-Labs/quic-go, MIT).
  `android/core/patches/psiphon-quic-go/qpack-v0.6.patch` moves its `http3`
  package to the quic-go/qpack version Xray-core needs. Written for Fortiva,
  MIT. The patch file is the source of every file we change.
- `github.com/tailscale/netlink` (Apache-2.0) is built at a newer commit
  than Psiphon pins. We do not change its code.

Several more are built at newer versions than Psiphon pins, without changes
to their code, mostly because Xray-core needs the newer version.
`android/core/README.md`, section Psiphon, lists them.

The GPL covers the code. Connecting to Psiphon's network is a separate
permission, set by Psiphon's own terms.

## Android helper code: Apache-2.0

`helper/ItemTouchHelperAdapter.kt`, `helper/ItemTouchHelperViewHolder.kt`
and `helper/SimpleItemTouchHelperCallback.kt`:

- Copyright (C) 2015 Paul Burke, Apache License 2.0

## Routing data (`geoip.dat` and `geosite.dat`): GPL-3.0

Two data files that Xray-core reads for its routing rules. The Android and
Windows builds ship the files that AndroidLibXrayLite carries, at the
version pinned in `android/core/go.mod`: inside `libv2ray.aar` on Android,
and next to `fortiva-core.exe` on Windows. They are separate data files,
not code linked into the app.

- Upstream: https://github.com/Loyalsoldier/v2ray-rules-dat
- Licence: GNU General Public License v3.0
- `geoip.dat` includes GeoLite2 data created by MaxMind, available from
  https://www.maxmind.com.

## MMKV: BSD-3-Clause, with OpenSSL, Apache-2.0 and zlib parts

MMKV 1.3.14 (`com.tencent:mmkv-static`) stores settings for the native
layer.

- Upstream: https://github.com/Tencent/MMKV
- Copyright (C) 2018 THL A29 Limited, a Tencent company. BSD 3-Clause
  License.
- It contains parts of OpenSSL 1.1.0i (its AES code), under the OpenSSL
  License and the original SSLeay License. Copyright (c) 1998-2018 The
  OpenSSL Project. Copyright (C) 1995-1998 Eric Young (eay@cryptsoft.com).
  - This product includes software developed by the OpenSSL Project for use
    in the OpenSSL Toolkit. (http://www.openssl.org/)
  - This product includes cryptographic software written by Eric Young
    (eay@cryptsoft.com).
- It also contains MultiprocessSharedPreferences 1.0 (Apache License 2.0)
  and zlib 1.2.11 (zlib License, Copyright (C) 1995-2017 Jean-loup Gailly
  and Mark Adler).

## Google Play libraries: not open source

The Android build includes these libraries from Google. They are not open
source, and they are not in this repository: Gradle downloads them from
Google's Maven repository when it builds the app. Google's terms apply to
them, not the GPL.

| Library | Version | Brought in by | Terms |
| --- | --- | --- | --- |
| Google Play Billing Library, `com.android.billingclient:billing` | 8.0.0 | the Flutter package `in_app_purchase_android` | Android Software Development Kit License |
| Play Install Referrer Library, `com.android.installreferrer:installreferrer` | 2.2 | the Flutter package `play_install_referrer` | Android Software Development Kit License |
| Play In-App Review, `com.google.android.play:review` | 2.0.2 | the app (`android/app/build.gradle.kts`) | Play Core Software Development Kit Terms of Service |
| Play Core Common, `com.google.android.play:core-common` | 2.0.4 | Play In-App Review | Play Core Software Development Kit Terms of Service |
| Google Play services `play-services-base` | 18.5.0 | Play Billing | Android Software Development Kit License |
| Google Play services `play-services-basement` | 18.4.0 | Play Billing and Play In-App Review | Android Software Development Kit License |
| Google Play services `play-services-tasks` | 18.2.0 | Play Billing and Play In-App Review | Android Software Development Kit License |
| Google Play services `play-services-location` | 19.0.0 | Play Billing | Android Software Development Kit License |
| Google Play services `play-services-places-placereport` | 17.0.0 | `play-services-location` | Android Software Development Kit License |

- Android Software Development Kit License: https://developer.android.com/studio/terms
- Play Core Software Development Kit Terms of Service:
  https://developer.android.com/guide/playcore/license

Play Billing also brings in Google's data transport libraries, which are
open source under the Apache License 2.0:
`com.google.android.datatransport` `transport-api` 3.0.0,
`transport-backend-cct` 3.1.8 and `transport-runtime` 3.1.8, and
`com.google.firebase` `firebase-encoders` 17.0.0, `firebase-encoders-json`
18.0.0 and `firebase-encoders-proto` 16.0.0.

---

# iOS

No GPL-licensed code reaches the iOS build. The Android native layer is not
compiled into it at all.

## LibXray / Xray-core: MPL-2.0

`ios/Frameworks/LibXray.xcframework` (Git LFS) is the iOS tunnel core.

- Xray-core: Mozilla Public License 2.0, https://github.com/XTLS/Xray-core
- libXray binding: https://github.com/XTLS/libXray

Unlike Android's, this artifact is a **local fork**: unpinned, not reproducible
from source, and outside the update policy in `CORE-MAINTENANCE.md`. Tracked
separately; it is a maintenance problem, not a licensing one.

MPL-2.0 is file-level copyleft. Modifications to MPL-licensed files must be
published; linking from other code is permitted. We ship these unmodified.

## FortivaNetBridge / Tun2SocksKit: MIT

`ios/FortivaNetBridge/` is a vendored fork of **Tun2SocksKit**, a Swift
packaging of **hev-socks5-tunnel**. It bridges the TUN device to the local
SOCKS5 inbound that Xray-core serves, the role `libtun2socks.so` plays on
Android.

- Tun2SocksKit: MIT, https://github.com/EbrahimTahernejad/Tun2SocksKit
- hev-socks5-tunnel: MIT, https://github.com/heiher/hev-socks5-tunnel

`Package.swift` pulls the `HevSocks5Tunnel` binary target from a pinned
release URL with a recorded SHA-256 checksum, so this dependency is verified
at fetch time even though it is prebuilt.

---

# Windows

The Windows build is GPL-3.0, because its tunnel service links GPL-3.0 code
(sing and sing-shadowsocks, below). The service, `fortiva-core.exe`
(`windows/core/`), is our Go code around the same Xray-core as Android.

## Xray-core: MPL-2.0

The same pinned commit and the same `android/core/patches` as the Android
core (see above), compiled into `fortiva-core.exe`. Its Go dependencies are
pinned in `windows/core/go.sum`, and each keeps its own licence.

## sing and sing-shadowsocks: GPL-3.0

The Shadowsocks support of Xray-core uses these two libraries, so
`fortiva-core.exe` links them.

- sing v0.7.13: https://github.com/SagerNet/sing
- sing-shadowsocks v0.2.9: https://github.com/SagerNet/sing-shadowsocks
- Copyright (C) 2022 nekohasekai
- Licence: GNU General Public License v3.0, or (at your option) any later
  version
- Pinned in `windows/core/go.mod` and `windows/core/go.sum`

## Routing data

The installer puts the same `geoip.dat` and `geosite.dat` as the Android
build next to the service. See "Routing data" under Android for their
source and licence.

## Wintun

The driver of the TUN adapter, by WireGuard LLC, shipped unmodified next to
the service with its licence (`wintun-LICENSE.txt`).

- Upstream: https://www.wintun.net
- Version: pinned in `windows/core/stage.sh` (`WINTUN_VERSION`), checked
  against a recorded SHA-256
- Licence: Prebuilt Binaries License (redistribution of the unmodified
  binaries)

---

# All platforms

## Flutter packages

The Dart layer's dependencies are listed in `pubspec.yaml` and are
permissively licensed (MIT / BSD / Apache-2.0). Run `flutter pub deps` for
the resolved set.

## This project's own licence

The **Android and Windows builds** are distributed under **GPL-3.0**. The
Android native layer is a derivative of GPL-3.0 work (v2rayNG,
shadowsocks-android), the Android VPN core links psiphon-tunnel-core, and
the Windows tunnel service links sing and sing-shadowsocks. The **iOS
build** contains no GPL code and is proprietary. NimusAI holds the
copyright of its own code in the shared Dart layer, the first-party Swift
and the first-party Go, and licenses the Dart layer under both. Outside
contributions come under the terms in `CONTRIBUTING.md`, which let NimusAI
ship them in every build. See `LICENSING.md`.

## The source of the Android and Windows builds

Anyone who gets the Android or Windows app is entitled to the complete
corresponding source of that version. It is available in two ways:

- **The public copy.** The source of each release is published at
  https://github.com/SynAdam/fortivavpn, and each release is tagged
  `vX.Y.Z` there. Its history starts at version 2.2.0, with one commit for
  each change made since the previous release. Every download of the app
  links to it: the Google Play listing, fortivavpn.com and the Telegram
  channel. The public copy leaves out the addresses and keys in
  `lib/api/built_in.dart`.
- **By email, the complete source.** Write to admin@fortivavpn.com and name
  the version you have. We send the complete source of that version, with
  the values the public copy leaves out. This written offer is valid for
  three years from the date you received that version. The app shows it at
  the bottom of Settings, under Open source licence.

The email offer alone does not meet the obligation for an app that is
downloaded. For a download, the GPL asks for the source to be offered from
a server, with directions next to the download, so every download links to
the public copy.

This offer is not for the iOS build, which carries no such obligation.

---

This file records what is known from inspecting the source tree. It is not
legal advice; confirm the full obligations with a lawyer before relying on
it commercially.
