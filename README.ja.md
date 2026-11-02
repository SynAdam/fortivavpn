<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN は毎日無料で使える VPN です。登録もメールアドレスも不要で、広告もなく、ワンタップで接続できます。</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=ja&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="APK をダウンロード"></a>
  <a href="https://t.me/fortivavpn"><img src="https://img.shields.io/badge/Telegram-fortivavpn-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Telegram チャンネル"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="最新リリース"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="ライセンス：GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <b>日本語</b> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Fortiva VPN について

Fortiva VPN は、Android スマホと Android TV 向けの無料の VPN です。
登録もメールアドレスも不要で、広告もなく、ワンタップで接続できます。
毎日無料のデータが使えます。データ量は毎日リセットされます。プレミアムでは日ごとの上限がなくなります。
Fortiva は、一般的な VPN がつながらないネットワーク向けに作られています。サーバーはアプリに組み込まれていて自動で更新されるので、設定ファイルを探す必要も、何かを貼り付ける必要もありません。
アプリは日本語を含む 18 言語で利用できます。

## ダウンロード

- **APK（スマホと Android TV 用）：** [直接ダウンロード](https://fortivavpn.com/apk)するか、このリポジトリの [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) ページから入手してください。[Lite 版 APK](https://fortivavpn.com/apk/lite) はファイルサイズが小さく、32 ビットのスマホ向けです。ほとんどの 64 ビットのスマホでも動作します。
- **Windows 10 と 11：** [インストーラーを直接ダウンロード](https://fortivavpn.com/windows)するか、このリポジトリの [Releases](https://github.com/SynAdam/fortivavpn/releases) ページから入手してください。インストーラーには署名がないため、実行前に Windows が警告を表示することがあります。その場合は More info を選び、続けて Run anyway を選んでください。
- **Google Play：** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=ja&referrer=utm_source%3Dgithub)
- **ウェブサイト：** [fortivavpn.com](https://fortivavpn.com)
- **Telegram：** お知らせと新しいバージョンは、Fortiva の英語チャンネル [t.me/fortivavpn](https://t.me/fortivavpn) で公開しています。

ほかの場所から入手した APK をインストールする前に、Fortiva が公開したものかどうかを確認してください。
確認方法は、英語版 README の [Check a download](README.md#check-a-download) に書いてあります。

## このリポジトリについて

このリポジトリには、バージョン 2.2.0 以降のアプリのソースコードがあります。
アプリは非公開のリポジトリで開発しています。そこで行った変更は、それぞれ 1 つのコミットとして数分以内にここへ反映されます。
各リリースには、ビルド元のコミットに `vX.Y.Z` というタグが付いています。
アプリは Flutter と Dart で書かれていて、コードは `lib/` にあります。

Issue とプルリクエストを歓迎します。
採用された変更は、マージから数分以内に、あなたを共同作成者として記載したコミットでここへ反映され、次のリリースに含まれます。

アプリが Fortiva のサービスに接続するために使う一部のアドレスとキーは、このリポジトリにはありません。そのため、ここでは `lib/api/built_in.dart` と `assets/fallback/index.txt` は空になっています。
署名鍵とストアのアカウントが必要なリリース用とストア用のツール、および内部メモもここにはありません。
バックエンドのサービスはオープンソースではありません。
このソースからビルドしたアプリは、Google Play のアプリと同じサービスに、同じ条件で接続します。

ソースからアプリをビルドする方法は、英語版 README の [Build from source](README.md#build-from-source) をご覧ください。

## 問題の報告

問題を報告したり提案したりするには、[Issue を作成](https://github.com/SynAdam/fortivavpn/issues/new/choose)し、いずれかのフォームに記入してください。
できれば英語でお願いしますが、ほかの言語でも構いません。

Issue は公開されていて、誰でも読むことができます。
そのため、次のものは Issue にもスクリーンショットにも載せないでください。

- 「リンクをコピー」で得たリンク、プレミアムのキー、「友達の接続を手伝う」のコード。これらは、持っている人なら誰でも使えます。
- サーバーのアドレス、またはご自身の IP アドレス。
- お名前や電話番号、ログ、「IP情報」画面のスクリーンショット。

アカウントやお支払いについてのサポートが必要な場合は、アプリの「設定」を開いて「お問い合わせ」をタップしてください。
これらのメッセージは公開されません。
質問の種類ごとの連絡先は [SUPPORT.md](SUPPORT.md) に書いてあります。

## 貢献について

プルリクエストを送る手順、通過する必要があるチェック、適用される条件は [CONTRIBUTING.md](CONTRIBUTING.md) に書いてあります。
そのファイルは英語で書かれています。

- **どこから始めるか：** [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) または [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted) のラベルが付いた Issue から始めてください。
- **翻訳：** アプリのテキストは 18 言語で用意されていて、[`lib/l10n/`](lib/l10n/) に言語ごとに 1 つずつファイルがあります。日本語は `app_ja.arb`、英語の原文は `app_en.arb` にあります。`{query}` のように波かっこで囲まれた部分は、そのまま残してください。翻訳の 1 文を直すのは、最初のプルリクエストにちょうどよい作業です。
- **大きな変更：** 進め方をすり合わせるため、作業を始める前に Issue を作成してください。

このプロジェクトに参加するすべての方に、[行動規範](CODE_OF_CONDUCT.md)を守っていただくようお願いしています。

## セキュリティ

セキュリティ上の問題を見つけた場合は、Issue に書かないでください。Issue は公開されているためです。
[GitHub から非公開で報告](https://github.com/SynAdam/fortivavpn/security/advisories/new)するか、件名に Security と入れて admin@fortivavpn.com にメールしてください。
詳しくは [SECURITY.md](SECURITY.md) をご覧ください。

## クレジット

Fortiva VPN は、次のオープンソースプロジェクトの成果をもとに作られています。
これらを開発し、メンテナンスしているすべての方に感謝します。

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure)（CluvexStudio）：VPN とプロキシのクライアントです。Fortiva のコアには CluvexStudio が Xray-core 向けに書いた `autoselect` アウトバウンドが含まれていて、これは [CluvexStudio の Xray-core フォーク](https://github.com/CluvexStudio/Xray-core)から取り入れたものです。公開してくださったことに感謝します。
- [Xray-core](https://github.com/XTLS/Xray-core)（XTLS）：アプリの土台となっているネットワークコアです。
- [libXray](https://github.com/XTLS/libXray)（XTLS）：モバイルアプリで Xray-core を使いやすくするラッパーです。
- [v2rayNG](https://github.com/2dust/v2rayNG)（2dust）：Xray-core の Android クライアントです。Fortiva の Android ネイティブ層はこれをもとにしています。
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite)（2dust）：Android アプリから Xray-core を使えるようにするバインディングです。
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core)（Psiphon Inc.）：Psiphon のトンネルライブラリです。
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)：Android クライアントです。Fortiva の Android ネイティブ層の一部のファイルは、これに由来します。
- [sing](https://github.com/SagerNet/sing) と [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks)（SagerNet）：Xray-core が使っている Go ライブラリです。
- [BadVPN](https://github.com/ambrop72/badvpn)（ambrop72）：Android アプリは、このプロジェクトの tun2socks を使っています。
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)（Loyalsoldier）：`geoip.dat` と `geosite.dat` のデータファイルです。
- [MMKV](https://github.com/Tencent/MMKV)（Tencent）：Android ネイティブ層の設定を保存するキーバリューストアです。
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit)（EbrahimTahernejad）：hev-socks5-tunnel の Swift パッケージです。
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel)（heiher）：小さくて高速な tun2socks トンネルです。
- [Wintun](https://www.wintun.net)（WireGuard LLC）：Windows 用のネットワークアダプタードライバーです。
- [Flutter](https://flutter.dev) と、[`pubspec.yaml`](pubspec.yaml) に記載されている Dart パッケージ。

各プロジェクトのライセンスは [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) に記載しています。

## ライセンス

アプリの Android 版と Windows 版のビルドは GPL-3.0 のもとで提供しています。
ライセンスの本文は [LICENSE](LICENSE) にあります。各ビルドと、このリポジトリの各フォルダーに適用されるライセンスは [LICENSING.md](LICENSING.md) に書いてあります。

このライセンスは、Fortiva VPN の名前とロゴについて、商標としての権利を一切与えるものではありません。
改変版を公開する場合は、独自の名前、アイコン、アプリケーション ID を付けてください。また、Fortiva のものであるかのように見せないでください。
[LICENSING.md](LICENSING.md) で説明しているとおり、これらは GPL 第 7 条に基づく追加条項です。
