<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN adalah VPN yang gratis setiap hari: tanpa daftar, tanpa email, tanpa iklan, dan cukup satu ketukan untuk terhubung.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=id&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Unduh APK"></a>
  <a href="https://t.me/fortivavpn_id"><img src="https://img.shields.io/badge/Telegram-fortivavpn__id-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Kanal Telegram"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Rilis terbaru"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Lisensi: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <b>Bahasa Indonesia</b> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Tentang Fortiva VPN

Fortiva VPN adalah VPN gratis untuk ponsel Android dan Android TV.
Tanpa daftar, tanpa email, tanpa iklan, dan cukup satu ketukan untuk terhubung.
Anda mendapat data gratis setiap hari, dan kuotanya direset setiap hari. Premium menghilangkan batas harian.
Fortiva dibuat untuk jaringan tempat VPN biasa gagal terhubung. Servernya sudah ada di dalam aplikasi dan diperbarui otomatis, jadi tidak ada konfigurasi yang perlu dicari dan tidak ada yang perlu ditempel.
Aplikasi ini tersedia dalam 18 bahasa, termasuk bahasa Indonesia.

## Unduh

- **APK (untuk ponsel dan Android TV):** [unduh langsung](https://fortivavpn.com/apk), atau dari halaman [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) di repositori ini. [APK Lite](https://fortivavpn.com/apk/lite) ukurannya lebih kecil, dibuat untuk ponsel 32-bit, dan juga bisa berjalan di sebagian besar ponsel 64-bit.
- **Windows 10 dan 11:** [unduh penginstalnya langsung](https://fortivavpn.com/windows), atau dari halaman [Releases](https://github.com/SynAdam/fortivavpn/releases) di repositori ini. Penginstalnya tidak ditandatangani, jadi Windows mungkin memberi peringatan sebelum menjalankannya: pilih More info, lalu Run anyway.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=id&referrer=utm_source%3Dgithub)
- **Situs web:** [fortivavpn.com/id/](https://fortivavpn.com/id/)
- **Telegram:** berita dan versi baru diposting di kanal bahasa Indonesia kami, [t.me/fortivavpn_id](https://t.me/fortivavpn_id).

Sebelum memasang APK dari sumber lain, pastikan dulu bahwa APK itu milik kami.
README bahasa Inggris menjelaskan caranya, di bagian [Check a download](README.md#check-a-download).

## Repositori ini

Repositori ini berisi kode sumber aplikasi, mulai dari versi 2.2.0.
Aplikasi dikembangkan di repositori privat, dan setiap perubahan di sana masuk ke sini dalam hitungan menit, sebagai satu commit.
Setiap rilis diberi tag `vX.Y.Z` pada commit yang dipakai untuk membangunnya.
Aplikasi ini ditulis dengan Flutter dan Dart, dan kodenya ada di `lib/`.

Silakan kirim issue dan pull request.
Perubahan yang diterima masuk ke sini dalam hitungan menit setelah di-merge, dalam commit yang mencantumkan Anda sebagai co-author, dan ikut dalam rilis berikutnya.

Beberapa alamat dan kunci yang dipakai aplikasi untuk menjangkau layanan kami tidak ada di repositori ini, jadi `lib/api/built_in.dart` dan `assets/fallback/index.txt` kosong di sini.
Alat untuk rilis dan toko aplikasi, yang memerlukan kunci penandatanganan dan akun toko aplikasi kami, juga tidak ada di sini, begitu pula catatan internal kami.
Layanan backend tidak open source.
Build yang Anda buat dari kode sumber ini terhubung ke layanan yang sama dengan aplikasi dari Google Play, dengan ketentuan yang sama.

Untuk membangun aplikasi dari kode sumber, lihat [Build from source](README.md#build-from-source) di README bahasa Inggris.

## Laporkan masalah

Untuk melaporkan masalah atau memberi saran, [buka issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) dan isi salah satu formulirnya.
Sebaiknya pakai bahasa Inggris kalau bisa, tetapi bahasa lain juga boleh.

Issue bersifat publik, dan siapa saja bisa membacanya.
Jadi, jangan cantumkan hal-hal berikut di issue atau di tangkapan layar:

- Tautan dari "Salin tautan", kunci Premium, atau kode dari "Bantu teman terhubung". Siapa pun yang memilikinya bisa memakainya.
- Alamat server atau alamat IP Anda sendiri.
- Nama atau nomor telepon Anda, log, atau tangkapan layar halaman "Periksa IP saya".

Untuk bantuan soal akun atau pembayaran, buka Pengaturan di aplikasi lalu ketuk Hubungi Kami.
Pesan-pesan itu tidak bersifat publik.
[SUPPORT.md](SUPPORT.md) menjelaskan ke mana Anda bisa mengajukan setiap jenis pertanyaan.

## Berkontribusi

[CONTRIBUTING.md](CONTRIBUTING.md) berisi langkah-langkah mengirim pull request, pemeriksaan yang harus lolos, dan ketentuannya.
File itu berbahasa Inggris.

- **Mulai dari mana:** issue berlabel [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) atau [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Terjemahan:** teks aplikasi tersedia dalam 18 bahasa, masing-masing satu file di [`lib/l10n/`](lib/l10n/). Bahasa Indonesia ada di `app_id.arb`, dan teks asli bahasa Inggris ada di `app_en.arb`. Jangan ubah apa pun yang ada di dalam kurung kurawal, seperti `{query}`. Perbaikan satu kalimat terjemahan bisa menjadi pull request pertama yang bagus.
- **Perubahan yang lebih besar:** buka issue sebelum mulai, supaya kita bisa sepakat soal pendekatannya.

Setiap orang yang ikut serta dalam proyek ini diharapkan mematuhi [kode etik](CODE_OF_CONDUCT.md).

## Keamanan

Jika Anda menemukan masalah keamanan, jangan menuliskannya di issue, karena issue bersifat publik.
[Laporkan secara privat lewat GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new), atau kirim email ke admin@fortivavpn.com dengan kata Security di subjeknya.
[SECURITY.md](SECURITY.md) berisi detailnya.

## Kredit

Fortiva VPN dibangun di atas karya proyek-proyek open source berikut.
Terima kasih kepada semua orang yang menulis dan memeliharanya.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) oleh CluvexStudio, klien VPN dan proxy. Inti kami menyertakan outbound `autoselect` yang ditulis CluvexStudio untuk Xray-core, diambil dari [fork Xray-core mereka](https://github.com/CluvexStudio/Xray-core). Terima kasih sudah memublikasikannya.
- [Xray-core](https://github.com/XTLS/Xray-core) oleh XTLS, inti jaringan yang menjadi dasar aplikasi ini.
- [libXray](https://github.com/XTLS/libXray) oleh XTLS, pembungkus yang membuat Xray-core lebih mudah dipakai di aplikasi seluler.
- [v2rayNG](https://github.com/2dust/v2rayNG) oleh 2dust, klien Android untuk Xray-core. Lapisan native Android kami merupakan turunan dari proyek ini.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) oleh 2dust, binding yang memungkinkan aplikasi Android memakai Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) oleh Psiphon Inc., pustaka tunnel milik Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), klien Android. Beberapa file di lapisan native Android kami berasal dari proyek ini.
- [sing](https://github.com/SagerNet/sing) dan [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) oleh SagerNet, pustaka Go yang dipakai Xray-core.
- [BadVPN](https://github.com/ambrop72/badvpn) oleh ambrop72, yang tun2socks-nya dipakai aplikasi Android.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) oleh Loyalsoldier, file data `geoip.dat` dan `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) oleh Tencent, penyimpanan key-value untuk pengaturan lapisan native Android.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) oleh EbrahimTahernejad, paket Swift dari hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) oleh heiher, tunnel tun2socks yang kecil dan cepat.
- [Wintun](https://www.wintun.net) oleh WireGuard LLC, driver adaptor jaringan untuk Windows.
- [Flutter](https://flutter.dev) dan paket Dart yang tercantum di [`pubspec.yaml`](pubspec.yaml).

[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) mencantumkan lisensi setiap proyek.

## Lisensi

Build aplikasi untuk Android dan Windows berlisensi GPL-3.0.
[LICENSE](LICENSE) adalah teks lisensinya, dan [LICENSING.md](LICENSING.md) menjelaskan lisensi yang berlaku untuk setiap build dan setiap folder di repositori ini.

Lisensi ini tidak memberikan hak apa pun atas nama dan logo Fortiva VPN sebagai merek dagang.
Jika Anda menerbitkan versi yang dimodifikasi, gunakan nama, ikon, dan ID aplikasi sendiri, dan jangan menampilkannya seolah-olah milik kami.
Ini adalah ketentuan tambahan berdasarkan pasal 7 GPL, seperti yang dijelaskan di [LICENSING.md](LICENSING.md).
