# Licensing

Copyright (C) 2026 NimusAI

[LICENSE](LICENSE) is the GNU General Public License, version 3. This file
says which builds of Fortiva VPN it covers, which licence each folder is
under, and which additional terms come with it.
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) lists the components from
other projects and their licences.

## Each build

| Build | Licence |
| --- | --- |
| Android, for phones and Android TV | GPL-3.0-or-later, with the additional terms below |
| Windows | GPL-3.0-or-later, with the additional terms below |
| iOS | Proprietary, see [The iOS build](#the-ios-build) |

### The Android and Windows builds

The Android and Windows apps are free software: you can redistribute them
and/or modify them under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version, with the additional terms below.

They are distributed in the hope that they will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License in
[LICENSE](LICENSE) for more details.

Both builds contain code under GPL-3.0:

- **Android.** The native layer under
  `android/app/src/main/java/com/vpn/fortivavpn/` is a fork of
  [v2rayNG](https://github.com/2dust/v2rayNG), and some of its files come
  from [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android).
  The core, `android/app/libs/libv2ray.aar`, links
  [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core).
  All three are GPL-3.0.
- **Windows.** The tunnel service, `fortiva-core.exe` (`windows/core/`),
  links the Shadowsocks support of Xray-core, which uses
  [sing](https://github.com/SagerNet/sing) and
  [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks). Both are
  GPL-3.0-or-later.

### The source of each release

The source of each release of the Android and Windows apps is published at
https://github.com/SynAdam/fortivavpn, one commit for each version, tagged
`vX.Y.Z`. Google Play, fortivavpn.com and the Telegram channel link to it
next to the download.

That copy leaves out a few addresses and keys that the app uses to reach
our service, so `lib/api/built_in.dart` is empty there. You can also get
the complete source of the version you have, with those values. Email
admin@fortivavpn.com and name the version. This offer is valid for three
years from the date you received that version.

### The iOS build

Copyright (c) 2026 NimusAI. All rights reserved.

The iOS application contains no GPL-licensed code. None of the Android
native layer is compiled into it; the iOS tunnel is built from entirely
different components:

```text
  Xray-core, via LibXray            Mozilla Public License 2.0
  hev-socks5-tunnel, via
    FortivaNetBridge (Tun2SocksKit) MIT
  Flutter packages                  MIT / BSD / Apache-2.0
```

MPL-2.0 is file-level copyleft: modifications to MPL-licensed files must be
published, but linking from other code is permitted, and we ship those files
unmodified. None of the above obliges the surrounding application to be free
software.

This distinction is not cosmetic. GPL-3.0 and the Apple App Store are widely
held to be incompatible, because Apple's terms of service impose usage
restrictions that GPL section 6 forbids a distributor from adding. VLC and
GNU Go were both removed from the App Store on those grounds. Shipping the
iOS app under a repository-wide GPL-3.0 grant would have asserted exactly
that conflict.

## The shared code in lib/

`lib/` is compiled into every build. NimusAI holds the copyright of its own
code in `lib/`, of the first-party Swift under `ios/` and of the first-party
Go under `windows/core/`. It licenses `lib/` under GPL-3.0-or-later as part
of the Android and Windows builds, and under the proprietary terms above as
part of the iOS build. A copyright holder may license its own work in more
than one way, and the two grants do not conflict. Outside contributions come
under the terms in [CONTRIBUTING.md](CONTRIBUTING.md), which let NimusAI ship
them in every build.

## Each folder

| Folder | What it holds | Licence |
| --- | --- | --- |
| `lib/` | The Flutter app, shared by every build | GPL-3.0-or-later in the Android and Windows builds. The iOS terms in the iOS build. |
| `test/` | Tests of `lib/` | GPL-3.0-or-later |
| `android/` | The Android app: its native layer, its core and its store text | GPL-3.0-or-later. Files from other projects keep their own licence, such as the Xray-core patches in `android/core/patches/` (MPL-2.0). |
| `windows/` | The Windows app: its runner, its tunnel service (`windows/core/`) and its installer | GPL-3.0-or-later. Wintun keeps its own licence. |
| `ios/` | The iOS app | The iOS terms. Components from other projects keep their own licence. |
| `assets/` | Fonts, images and the app icon | The fonts keep their own licence, the SIL Open Font License 1.1. The rest is GPL-3.0-or-later, and the logo also falls under the additional terms below. |
| `web/` | Flutter's web files. No web build is released. | GPL-3.0-or-later |
| `tool/`, `scripts/` | Scripts that draw store images, and a device test | GPL-3.0-or-later |
| `.github/` | Issue forms and the checks of this copy | GPL-3.0-or-later |

THIRD-PARTY-NOTICES.md names each file from another project and its
licence.

## Additional terms under GPL-3.0 section 7

NimusAI adds these terms, under section 7 of the GNU General Public License,
to the material it holds the copyright to. They do not apply to code from
other projects.

1. **No trademark rights, section 7(e).** This licence gives no right to use
   the names Fortiva and Fortiva VPN, or the Fortiva logo, as trademarks.
   They identify NimusAI's apps.
2. **A modified version is marked as different, section 7(c).** If you
   publish a modified version, give it its own name, its own icon and its
   own application ID, and do not present it as ours. On Android the
   application ID is `applicationId` in `android/app/build.gradle.kts`.
