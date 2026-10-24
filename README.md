# Fortiva VPN

Fortiva VPN is a free VPN for every day: no sign-up, no email and no ads,
and it connects in one tap.

The source code of the [Fortiva VPN](https://fortivavpn.com) apps: Android
(phones and Android TV), iOS and Windows. They are one Flutter app (`lib/`)
on top of a native tunnel for each platform, built on
[Xray-core](https://github.com/XTLS/Xray-core).

<div dir="rtl">

این مخزن کد منبع اپ‌های فورتیوا VPN برای اندروید، اندروید TV، iOS و ویندوز است. هر کامیت کد یک نسخه‌ی منتشرشده‌ی اپ است. برای گزارش مشکل یا پیشنهاد، یک issue باز کنید. برای تغییر کد، یک pull request بفرستید. روش کار در CONTRIBUTING.md آمده است.

</div>

- **Get the app:** [Google Play](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn),
  [fortivavpn.com](https://fortivavpn.com), [Telegram](https://t.me/fortiva_vpn)
- **Report a bug or suggest something:** [open an issue](../../issues)
- **Change the code:** open a pull request; see [CONTRIBUTING.md](CONTRIBUTING.md)
- **Report a security problem:** see [SECURITY.md](SECURITY.md), not an issue

## What this repository is

The apps are developed in a private repository. At each release, this copy
gets one commit for each change made there since the previous release, and
the release is tagged `vX.Y.Z`. The history here starts at version 2.2.0.

Pull requests are welcome. An accepted change ships in the next release,
and the commit that brings it here names you as a co-author.
[CONTRIBUTING.md](CONTRIBUTING.md) has the steps and the terms.

Three things in the builds we ship are not in this copy:

- **A few addresses and keys** that the app uses to reach our service.
  [`lib/api/built_in.dart`](lib/api/built_in.dart) and
  `assets/fallback/index.txt` are empty here.
- **Release and store tooling**, which needs our signing keys and store
  accounts.
- **Internal notes**: research, measurements and review correspondence.

The backend that hands out servers and accounts is not open source. A build
you make from this source talks to the same service as the app from the
store, under the same terms.

## How it works

```
┌──────────────────────────────────────────────────────────┐
│  Flutter  (lib/)                                          │
│    screens/ widgets/  ──  Provider state  ──  api/        │
└───────────────┬──────────────────────────────────────────┘
                │  MethodChannel  com.vpn.fortivavpn/tunnel
   ┌────────────┴─────────────┬────────────────────────────┐
   │                          │                            │
┌──▼──────────────────┐   ┌───▼──────────────────────┐  ┌──▼──────────────────┐
│ iOS                 │   │ Android                  │  │ Windows             │
│ NEPacketTunnel-     │   │ V2RayVpnService          │  │ fortiva-core.exe    │
│   Provider          │   │ libv2ray.aar (Xray-core) │  │   (a service:       │
│ LibXray +           │   │ + libtun2socks           │  │   Xray-core with    │
│   hev-socks5-tunnel │   │                          │  │   its TUN inbound   │
│                     │   │                          │  │   on Wintun)        │
└─────────────────────┘   └──────────────────────────┘  └─────────────────────┘
```

On first launch the app registers the device with the backend, with no
account, and receives credentials for the servers. Xray-core carries the
connection, and on Android and iOS a tun2socks layer feeds the device's TCP
and UDP traffic through it.

Android's native layer is derived from
[v2rayNG](https://github.com/2dust/v2rayNG). The cores are built from pinned
sources: see [`CORE-MAINTENANCE.md`](CORE-MAINTENANCE.md),
[`android/core/`](android/core/README.md), [`ios/core/`](ios/core/README.md)
and [`windows/core/`](windows/core/README.md).

## Building

You need the Flutter SDK (the version in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)), and for each
platform its own tools: JDK 17 and the Android SDK, Xcode on a Mac, or
Visual Studio 2022 with the C++ desktop workload on Windows.

```bash
flutter pub get
flutter analyze
flutter test
```

### Android

```bash
flutter run                          # a debug build on a phone or emulator
flutter build apk --debug
```

The core, `android/app/libs/libv2ray.aar`, is included. To build it
yourself from the pinned sources, run `android/core/build-in-linux.sh`. It
needs Docker, and it builds the core in a Linux container with the pinned
Go and Android NDK. See [`android/core/README.md`](android/core/README.md)
for how to check that your build matches ours. A release build needs your
own signing key: create `android/keystore.properties` with `storeFile`,
`storePassword`, `keyAlias` and `keyPassword`.

To install your build next to the app from the store, change
`applicationId` in [`android/app/build.gradle.kts`](android/app/build.gradle.kts).
Android does not install a build over ours, because yours is signed with a
different key.

### iOS

The core is not included because it is too large for this repository.
Build it first:

```bash
ios/core/build.sh          # Go and Xcode; writes ios/Frameworks/LibXray.xcframework
cd ios && pod install
```

Then set your own team, bundle identifiers and app group for the `Runner`
and `tunnel-ext` targets in Xcode. The packet tunnel runs only on a real
iPhone, not in the Simulator.

### Windows

See [`windows/core/README.md`](windows/core/README.md) for the tunnel service
and [`windows/installer/`](windows/installer/) for the installer.
`flutter build windows` builds the app.

## How releases are built

Each release is built from its tagged commit with Flutter 3.38.7:

- The Google Play bundle: `flutter build appbundle --release`.
- The APK on fortivavpn.com and in the Telegram channel, for 32-bit and
  64-bit ARM phones:
  `flutter build apk --release --target-platform android-arm,android-arm64`.
- The Lite APK, a smaller download for 32-bit ARM that also runs on most
  64-bit phones: `flutter build apk --release --target-platform android-arm`.

A build from this source is not the same file as ours. A few addresses and
keys are not published (see above), and ours is signed with our key.

## Check your copy

The APKs on fortivavpn.com and in the Telegram channel are signed with our
upload key. Its certificate has this SHA-256 fingerprint:

```text
D4:A0:BA:F7:0A:62:66:54:A6:3F:F9:9A:B7:27:5D:85:B4:3D:77:6A:26:85:4D:24:48:AC:2F:6D:10:AC:B1:41
```

To check a file, run `apksigner verify --print-certs FortivaVPN-X.Y.Z.apk`.
apksigner is in the Android SDK build tools. The line "Signer #1
certificate SHA-256 digest" must show the same value, in lower case and
without colons. If it shows another value, the file is not ours, so do not
install it.

The app from Google Play is signed by Google Play's app signing key, not by
our upload key. Its certificate has this SHA-256 fingerprint:

```text
E1:F5:F9:1D:AA:A7:F9:AE:07:FF:3B:02:06:0F:6E:33:BA:21:21:5C:16:F2:EA:70:9B:E0:B1:96:D7:C9:08:A5
```

## Licence

- **The Android and Windows builds are GPL-3.0.** Both contain GPL-3.0 code
  from other projects. [LICENSE](LICENSE) is the licence text.
- **The iOS build** contains no GPL code and is not licensed for
  redistribution.
- **The shared Flutter code** (`lib/`) is licensed under GPL-3.0 as part of
  the Android and Windows builds.

[LICENSING.md](LICENSING.md) says which licence each build and each folder
is under. [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) lists every
component and its licence.

## Name and logo

The licence gives no rights to the Fortiva VPN name and logo as
trademarks. If you publish a modified version, give it its own name, icon
and application ID, and do not present it as ours. These are additional
terms under section 7 of the GPL; see [LICENSING.md](LICENSING.md).
