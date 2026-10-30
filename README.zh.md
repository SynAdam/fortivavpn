<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN 是一款每天免费的 VPN：无需注册，不用邮箱，没有广告，一键连接。</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=zh-CN&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="下载 APK"></a>
  <a href="https://t.me/fortivavpn"><img src="https://img.shields.io/badge/Telegram-fortivavpn-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Telegram 频道"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="最新版本"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="许可证：GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.fa.md">فارسی</a> · <a href="README.ar.md">العربية</a> · <b>简体中文</b></p>

## 关于 Fortiva VPN

Fortiva VPN 是一款适用于安卓手机和 Android TV 的免费 VPN。
无需注册，也不用邮箱，没有广告，一键即可连接。
您每天都有免费流量，额度每天自动恢复；高级版取消每日流量上限。
Fortiva 专为普通 VPN 连不上的网络而设计。服务器已内置在应用中并会自动更新，不用找节点，也不用导入配置。
应用支持 18 种语言，包括简体中文。

## 下载

- **APK 安装包（手机和 Android TV 通用）：** [直接下载](https://fortivavpn.com/apk)，或在本仓库的 [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) 页面下载。[Lite 版 APK](https://fortivavpn.com/apk/lite) 体积更小，适用于 32 位手机，也能在大多数 64 位手机上运行。
- **Windows 10 和 11：** [直接下载](https://fortivavpn.com/windows)安装程序，或在本仓库的 [Releases](https://github.com/SynAdam/fortivavpn/releases) 页面下载。安装程序没有数字签名，Windows 可能会在运行前发出警告，此时请点击 More info，再点击 Run anyway。
- **Google Play：** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=zh-CN&referrer=utm_source%3Dgithub)
- **Telegram：** 新闻和新版本会发布在我们的英文频道 [t.me/fortivavpn](https://t.me/fortivavpn)。

如果 APK 来自其他地方，安装前请先确认它是我们发布的。
确认方法见英文 README 的 [Check a download](README.md#check-a-download) 部分。

## 关于本仓库

本仓库是应用 2.2.0 及之后版本的源代码。
应用在一个私有仓库中开发，那里的每次改动都会在几分钟后以一个提交（commit）的形式同步到这里。
每个版本都会在构建它的那个提交上打上 `vX.Y.Z` 标签。
应用使用 Flutter 和 Dart 编写，代码位于 `lib/` 目录。

欢迎提交 issue 和 pull request。
被接受的改动会在合并几分钟后同步到这里，相应的提交会把您列为共同作者（co-author），并随下一个版本发布。

应用连接我们的服务所用的少量地址和密钥不在本仓库中，因此这里的 `lib/api/built_in.dart` 和 `assets/fallback/index.txt` 是空的。
需要我们的签名密钥和商店账号的发布与应用商店工具，以及内部笔记，也不在这里。
后端服务不开源。
您用这份代码自己构建的应用，会连接到与 Google Play 版相同的服务，并适用相同的条款。

如需从源代码构建应用，请参阅英文 README 的 [Build from source](README.md#build-from-source) 部分。

## 报告问题

如需报告问题或提出建议，请[新建 issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) 并填写其中一个表单。
请用英文填写。

issue 是公开的，任何人都能看到。
因此请不要在 issue 中写下以下内容，也不要附上显示这些内容的截图：

- 通过“复制链接”得到的链接、高级版密钥，或“帮好友连接”的代码。任何人拿到它们都可以使用。
- 服务器地址或您自己的 IP 地址。

如需账号或付款方面的帮助，请在应用中打开“设置”，然后点按“联系我们”。
这些消息不会公开。
[SUPPORT.md](SUPPORT.md) 说明了各类问题该去哪里寻求帮助。

## 参与贡献

[CONTRIBUTING.md](CONTRIBUTING.md) 介绍了提交 pull request 的步骤、必须通过的检查以及贡献条款。
该文件为英文。

- **入门：** 带有 [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) 或 [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted) 标签的 issue。
- **翻译：** 应用文字有 18 种语言，每种语言在 [`lib/l10n/`](lib/l10n/) 目录中有一个文件。简体中文在 `app_zh.arb`，英文原文在 `app_en.arb`。花括号中的内容，例如 `{query}`，请保持原样。修正一句翻译，是提交第一个 pull request 的好起点。
- **较大的改动：** 开始之前请先新建一个 issue，以便我们先商定方案。

所有参与本项目的人都应遵守[行为准则](CODE_OF_CONDUCT.md)（Code of Conduct）。

## 安全

如果您发现了安全问题，请不要写在 issue 中，因为 issue 是公开的。
请[通过 GitHub 私下报告](https://github.com/SynAdam/fortivavpn/security/advisories/new)，或发送邮件至 admin@fortivavpn.com，并在邮件标题中写上 Security。
详情见 [SECURITY.md](SECURITY.md)。

## 致谢

Fortiva VPN 基于以下开源项目构建。
感谢所有编写和维护它们的人。

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure)，由 CluvexStudio 开发的 VPN 和代理客户端。我们的核心包含 CluvexStudio 为 Xray-core 编写的 `autoselect` outbound，取自[他们的 Xray-core fork](https://github.com/CluvexStudio/Xray-core)。感谢他们公开这段代码。
- [Xray-core](https://github.com/XTLS/Xray-core)，由 XTLS 开发，是本应用所基于的网络核心。
- [libXray](https://github.com/XTLS/libXray)，由 XTLS 开发，让移动应用更容易使用 Xray-core 的封装层。
- [v2rayNG](https://github.com/2dust/v2rayNG)，由 2dust 开发的 Xray-core 安卓客户端。我们安卓应用的原生层源自它。
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite)，由 2dust 开发，让安卓应用可以使用 Xray-core 的绑定库。
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core)，由 Psiphon Inc. 开发的 Psiphon 隧道库。
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)，一款安卓客户端。我们安卓原生层中的几个文件来自它。
- [sing](https://github.com/SagerNet/sing) 和 [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks)，由 SagerNet 开发、Xray-core 所用的 Go 库。
- [BadVPN](https://github.com/ambrop72/badvpn)，由 ambrop72 开发，安卓应用使用它的 tun2socks。
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)，由 Loyalsoldier 维护的 `geoip.dat` 和 `geosite.dat` 数据文件。
- [MMKV](https://github.com/Tencent/MMKV)，由腾讯开发的键值存储，用来保存安卓原生层的设置。
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit)，由 EbrahimTahernejad 开发的 hev-socks5-tunnel Swift 包。
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel)，由 heiher 开发的小巧快速的 tun2socks 隧道。
- [Wintun](https://www.wintun.net)，由 WireGuard LLC 开发的 Windows 网络适配器驱动。
- [Flutter](https://flutter.dev)，以及 [`pubspec.yaml`](pubspec.yaml) 中列出的 Dart 包。

[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) 列出了每个项目的许可证。

## 许可证

本应用的 Android 版（手机和 Android TV）采用 GPL-3.0 许可证。
许可证全文见 [LICENSE](LICENSE)；[LICENSING.md](LICENSING.md) 说明了每个版本以及本仓库中每个目录所采用的许可证。

该许可证不授予将 Fortiva VPN 名称和标志作为商标使用的任何权利。
如果您发布修改后的版本，请为它使用自己的名称、图标和 application ID，不要把它说成是我们的应用。
这些是依据 GPL 第 7 条附加的条款，详见 [LICENSING.md](LICENSING.md)。
