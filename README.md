<p align="center">
  <img src=".github/readme/banner.png" alt="Fortiva VPN. Free every day. No sign-up. One tap to connect." width="100%">
</p>

<p align="center">
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img alt="Latest release" src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&style=flat-square&label=release&labelColor=1B2127&color=6CD5B3"></a>
  <a href="LICENSING.md"><img alt="Licence: GPL-3.0" src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&labelColor=1B2127"></a>
  <img alt="Platforms: Android, Android TV, iOS and Windows" src="https://img.shields.io/badge/platforms-Android%20%7C%20Android%20TV%20%7C%20iOS%20%7C%20Windows-30363C?style=flat-square&labelColor=1B2127">
  <img alt="Built with Flutter" src="https://img.shields.io/badge/Flutter-3.38-02569B?style=flat-square&logo=flutter&logoColor=white&labelColor=1B2127">
  <img alt="18 languages" src="https://img.shields.io/badge/languages-18-30363C?style=flat-square&labelColor=1B2127">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn"><img alt="Get it on Google Play" src="https://img.shields.io/badge/Get_it_on_Google_Play-C8452B?style=for-the-badge&logo=googleplay&logoColor=white"></a>
  <a href="https://fortivavpn.com/apk"><img alt="Download the APK" src="https://img.shields.io/badge/Download_the_APK-1B2127?style=for-the-badge&logo=android&logoColor=6CD5B3"></a>
  <a href="https://t.me/fortivavpn"><img alt="Telegram channel" src="https://img.shields.io/badge/Telegram-1B2127?style=for-the-badge&logo=telegram&logoColor=white"></a>
</p>

<p align="center">
  <img src=".github/readme/showcase.png" alt="Four screens of the app: tap to connect, connected, the list of languages, and the home screen in Persian" width="100%">
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#download">Download</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#build-from-source">Build</a> ·
  <a href="#check-a-download">Check a download</a> ·
  <a href="#contributing">Contributing</a> ·
  <a href="#licence">Licence</a>
</p>

<div dir="rtl">

### فورتیوا به فارسی

فورتیوا یک فیلترشکن رایگان و قوی است: بدون ثبت‌نام، بدون تبلیغات و با اتصال با یک لمس. اپ را از [گوگل‌پلی](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn) یا [سایت فورتیوا](https://fortivavpn.com/apk) بگیرید و خبرها را در [کانال تلگرام](https://t.me/fortiva_vpn) دنبال کنید.

این مخزن کد منبع اپ‌های فورتیوا برای اندروید، اندروید TV، iOS و ویندوز است. کد هر نسخه‌ی منتشرشده با تگ `vX.Y.Z` مشخص شده است. برای گزارش مشکل یا پیشنهاد، یک issue باز کنید. برای تغییر کد، یک pull request بفرستید. روش کار در [CONTRIBUTING.md](CONTRIBUTING.md) آمده است.

</div>

## Features

<table>
<tr>
<td width="33%" valign="top">

**Free every day**<br>
A data allowance every day that refills on its own. Premium lifts the
limit.

</td>
<td width="33%" valign="top">

**No sign-up**<br>
No email, no phone number and no password. Install the app and connect.

</td>
<td width="33%" valign="top">

**One tap**<br>
No configs to find and no keys to paste. The servers are built in and
update themselves.

</td>
</tr>
<tr>
<td width="33%" valign="top">

**Made for filtered networks**<br>
Fortiva is built for networks where ordinary VPNs fail to connect.

</td>
<td width="33%" valign="top">

**No ads, no trackers**<br>
No ad or tracking SDKs, and we never record the pages you open.
[Privacy policy](https://fortivavpn.com/privacy)

</td>
<td width="33%" valign="top">

**Your language**<br>
18 languages, with right-to-left screens for Persian, Arabic and Urdu.

</td>
</tr>
</table>

A speed test in the app compares your speed with and without the VPN.

## Download

| | Where to get it | Source |
| --- | --- | --- |
| **Android** phones and tablets | [Google Play](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn), or the APK from [fortivavpn.com/apk](https://fortivavpn.com/apk). The [Lite APK](https://fortivavpn.com/apk/lite) is a smaller download for 32-bit phones that also runs on most 64-bit ones. | [`android/`](android/) |
| **Android TV** | The same app and APK as on phones | [`android/`](android/) |
| **iOS** | Build it from source | [`ios/`](ios/) |
| **Windows** | Build it from source | [`windows/`](windows/) |

New versions are announced on Telegram, in [English](https://t.me/fortivavpn)
and in [Persian](https://t.me/fortiva_vpn). Before you install an APK from
anywhere else, [check that it is ours](#check-a-download).

## What this repository is

The apps are developed in a private repository. At each release, this copy
gets one commit for each change made there since the previous release, and
the release is tagged `vX.Y.Z`. The history here starts at version 2.2.0.

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

The apps are one Flutter app (`lib/`) on top of a native tunnel for each
platform, built on [Xray-core](https://github.com/XTLS/Xray-core).

```mermaid
flowchart TB
    app["<b>Flutter app</b> (lib/)<br/>screens, widgets, Provider state, api/"]
    channel(["MethodChannel<br/>com.vpn.fortivavpn/tunnel"])
    app --> channel
    channel --> android
    channel --> ios
    channel --> windows
    android["<b>Android</b><br/>V2RayVpnService<br/>libv2ray.aar (Xray-core)<br/>libtun2socks"]
    ios["<b>iOS</b><br/>NEPacketTunnelProvider<br/>LibXray<br/>hev-socks5-tunnel"]
    windows["<b>Windows</b><br/>fortiva-core.exe, a service:<br/>Xray-core with its TUN<br/>inbound on Wintun"]
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

## Build from source

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

### How releases are built

Each release is built from its tagged commit with Flutter 3.38.7:

- The Google Play bundle: `flutter build appbundle --release`.
- The APK on fortivavpn.com and in the Telegram channel, for 32-bit and
  64-bit ARM phones:
  `flutter build apk --release --target-platform android-arm,android-arm64`.
- The Lite APK, a smaller download for 32-bit ARM that also runs on most
  64-bit phones: `flutter build apk --release --target-platform android-arm`.

A build from this source is not the same file as ours. A few addresses and
keys are not published (see [What this repository is](#what-this-repository-is)),
and ours is signed with our key.

## Check a download

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

## Contributing

Pull requests are welcome. An accepted change ships in the next release,
and the commit that brings it here names you as a co-author.
[CONTRIBUTING.md](CONTRIBUTING.md) has the steps and the terms.

- **Found a bug or have an idea?** [Open an issue](../../issues).
- **Want to change the code?** Open a pull request. See
  [CONTRIBUTING.md](CONTRIBUTING.md).
- **Found a security problem?** Follow [SECURITY.md](SECURITY.md). Do not
  open an issue for it.

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

<br>

<p align="center">
  <sub>Made for internet freedom.
  <a href="https://fortivavpn.com">fortivavpn.com</a> ·
  <a href="https://fortivavpn.com/privacy">Privacy</a> ·
  <a href="https://t.me/fortivavpn">Telegram</a></sub>
</p>
