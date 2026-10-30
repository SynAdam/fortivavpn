<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center" dir="rtl">فورتیوا VPN یک VPN رایگان برای هر روز است: بدون ثبت‌نام، بدون ایمیل و بدون تبلیغات، و با یک لمس وصل می‌شود.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="گوگل پلی"></a>
  <a href="https://fortivavpn.com/fa/"><img src="https://img.shields.io/badge/website-fortivavpn.com-C8452B?style=flat-square&amp;labelColor=0E1318" alt="سایت: fortivavpn.com"></a>
  <a href="https://t.me/fortiva_vpn"><img src="https://img.shields.io/badge/Telegram-fortiva__vpn-C8452B?style=flat-square&amp;labelColor=0E1318" alt="کانال تلگرام"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="آخرین نسخه"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="مجوز: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <b>فارسی</b> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a></p>

<div dir="rtl">

## درباره‌ی فورتیوا VPN

فورتیوا VPN یک VPN رایگان برای گوشی‌های اندروید و اندروید TV است.
برای استفاده از آن به ثبت‌نام یا ایمیل نیازی نیست، تبلیغ ندارد و با یک لمس وصل می‌شود.
برنامه به ۱۸ زبان، از جمله فارسی، در دسترس است.
سایت فارسی فورتیوا در [fortivavpn.com/fa](https://fortivavpn.com/fa/) است.

## دانلود

- **گوگل پلی:** [فورتیوا VPN در گوگل پلی](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&referrer=utm_source%3Dgithub)
- **فایل APK، برای گوشی و اندروید TV:** از [سایت فورتیوا](https://fortivavpn.com/fa/)، با [لینک مستقیم دانلود](https://fortivavpn.com/apk)، یا از بخش [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) همین مخزن.
- **ویندوز ۱۰ و ۱۱:** فایل نصب با [لینک مستقیم دانلود](https://fortivavpn.com/windows)، یا از بخش [Releases](https://github.com/SynAdam/fortivavpn/releases) همین مخزن. فایل نصب امضای دیجیتال ندارد، پس ویندوز شاید پیش از اجرا هشدار بدهد. در این حالت More info و بعد Run anyway را بزنید.
- **تلگرام:** خبرها و نسخه‌های تازه در کانال فارسی ما، [t.me/fortiva_vpn](https://t.me/fortiva_vpn)، منتشر می‌شوند.

پیش از نصب فایل APK از هر جای دیگری، بررسی کنید که آن را ما منتشر کرده‌ایم.
روش بررسی در بخش [Check a download](README.md#check-a-download) در README انگلیسی آمده است.

## این مخزن

این مخزن کد منبع برنامه از نسخه‌ی 2.2.0 به بعد است.
برنامه در یک مخزن خصوصی توسعه داده می‌شود و هر تغییری که آنجا انجام شود، چند دقیقه بعد به‌صورت یک کامیت به این مخزن می‌آید.
هر نسخه با تگ `vX.Y.Z` روی کامیتی که از آن ساخته شده مشخص می‌شود.
برنامه با Flutter و Dart نوشته شده است و کد آن در پوشه‌ی `lib/` است.

از issue و pull request استقبال می‌کنیم.
تغییری که پذیرفته شود چند دقیقه بعد با کامیتی به این مخزن می‌آید که نام شما را به‌عنوان هم‌نویسنده (co-author) ثبت می‌کند، و در نسخه‌ی بعدی منتشر می‌شود.

چند آدرس و کلید که برنامه با آن‌ها به سرویس ما وصل می‌شود در این مخزن نیستند، و برای همین `lib/api/built_in.dart` و `assets/fallback/index.txt` این‌جا خالی‌اند.
ابزارهای انتشار و فروشگاه، که به کلیدهای امضا و حساب‌های فروشگاه ما نیاز دارند، و یادداشت‌های داخلی هم این‌جا نیستند.
بک‌اند سرویس متن‌باز نیست.
برنامه‌ای که خودتان از این کد بسازید، به همان سرویسی وصل می‌شود که برنامه‌ی گوگل پلی به آن وصل می‌شود، و با همان شرایط.

برای ساختن برنامه از این کد، بخش [Build from source](README.md#build-from-source) در README انگلیسی را ببینید.

## گزارش مشکل

برای گزارش مشکل یا پیشنهاد، [یک issue باز کنید](https://github.com/SynAdam/fortivavpn/issues/new/choose) و یکی از فرم‌ها را پر کنید.
می‌توانید فارسی یا انگلیسی بنویسید.

issueها عمومی هستند و همه می‌توانند آن‌ها را بخوانند.
پس این‌ها را در issue ننویسید و عکسی را هم که یکی از آن‌ها را نشان می‌دهد نگذارید:

- لینکی که با «کپی لینک» گرفته‌اید، کلید پریمیوم یا کدهای «کمک به اتصال دوست». هر کس یکی از این‌ها را داشته باشد، می‌تواند از آن استفاده کند.
- آدرس سرور یا آی‌پی خودتان.

برای کمک درباره‌ی حساب یا پرداخت، در برنامه به «تنظیمات» بروید و «تماس با ما» را بزنید.
این پیام‌ها عمومی نیستند.
[SUPPORT.md](SUPPORT.md) می‌گوید برای هر کاری از کجا کمک بگیرید.

## مشارکت

[CONTRIBUTING.md](CONTRIBUTING.md) مراحل فرستادن pull request، بررسی‌هایی که باید بدون خطا اجرا شوند و شرایط مشارکت را توضیح می‌دهد.
این فایل به انگلیسی است.

- **برای شروع:** issueهایی که برچسب [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) یا [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted) دارند.
- **ترجمه:** متن برنامه به ۱۸ زبان است و هر زبان یک فایل در پوشه‌ی [`lib/l10n/`](lib/l10n/) دارد. متن فارسی در `app_fa.arb` است و متن اصلی انگلیسی در `app_en.arb`. عبارت‌های داخل آکولاد، مثل `{query}`، را همان‌طور که هست نگه دارید. اصلاح یک جمله‌ی ترجمه‌شده شروع خوبی برای اولین pull request است.
- **تغییر بزرگ:** پیش از شروع، یک issue باز کنید تا درباره‌ی آن به توافق برسیم.

همه‌ی کسانی که در این پروژه مشارکت می‌کنند، [آیین‌نامه‌ی رفتار](CODE_OF_CONDUCT.md) (Code of Conduct) را رعایت می‌کنند.

## امنیت

اگر مشکلی امنیتی پیدا کرده‌اید، آن را در issue ننویسید، چون issueها عمومی هستند.
آن را [به‌صورت خصوصی در GitHub گزارش کنید](https://github.com/SynAdam/fortivavpn/security/advisories/new)، یا به admin@fortivavpn.com ایمیل بزنید و در عنوان ایمیل Security بنویسید.
جزئیات در [SECURITY.md](SECURITY.md) آمده است.

## سپاسگزاری

فورتیوا VPN بر پایه‌ی کار این پروژه‌های متن‌باز ساخته شده است.
از همه‌ی کسانی که آن‌ها را نوشته‌اند و نگهداری می‌کنند سپاسگزاریم.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) ساخته‌ی CluvexStudio، یک کلاینت VPN و پروکسی. هسته‌ی ما outbound به نام `autoselect` را دارد که CluvexStudio برای Xray-core نوشته است و از [fork آن‌ها از Xray-core](https://github.com/CluvexStudio/Xray-core) گرفته شده است. از آن‌ها برای انتشار این کد سپاسگزاریم.
- [Xray-core](https://github.com/XTLS/Xray-core) ساخته‌ی XTLS، هسته‌ی شبکه‌ی برنامه.
- [libXray](https://github.com/XTLS/libXray) ساخته‌ی XTLS، لایه‌ای که استفاده از Xray-core را در برنامه‌های موبایل ساده‌تر می‌کند.
- [v2rayNG](https://github.com/2dust/v2rayNG) ساخته‌ی 2dust، یک کلاینت اندروید برای Xray-core. لایه‌ی بومی (native) اندروید ما از آن گرفته شده است.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) ساخته‌ی 2dust، کتابخانه‌ای که برنامه‌های اندروید با آن از Xray-core استفاده می‌کنند.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) ساخته‌ی Psiphon Inc.، کتابخانه‌ی تونل Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)، یک کلاینت اندروید. چند فایل از لایه‌ی بومی اندروید ما از آن آمده است.
- [sing](https://github.com/SagerNet/sing) و [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) ساخته‌ی SagerNet، کتابخانه‌هایی به زبان Go که Xray-core از آن‌ها استفاده می‌کند.
- [BadVPN](https://github.com/ambrop72/badvpn) ساخته‌ی ambrop72، که برنامه‌ی اندروید از tun2socks آن استفاده می‌کند.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) ساخته‌ی Loyalsoldier، فایل‌های داده‌ی `geoip.dat` و `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) ساخته‌ی Tencent، یک انباره‌ی کلید و مقدار که تنظیمات لایه‌ی بومی اندروید را نگه می‌دارد.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) ساخته‌ی EbrahimTahernejad، یک بسته‌ی Swift برای hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) ساخته‌ی heiher، یک تونل tun2socks کوچک و سریع.
- [Wintun](https://www.wintun.net) ساخته‌ی WireGuard LLC، درایور آداپتور شبکه برای ویندوز.
- [Flutter](https://flutter.dev) و بسته‌های Dart که در [`pubspec.yaml`](pubspec.yaml) فهرست شده‌اند.

[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) مجوز هر پروژه را فهرست می‌کند.

## مجوز

نسخه‌ی اندروید برنامه، برای گوشی و اندروید TV، تحت مجوز GPL-3.0 است.
متن مجوز در [LICENSE](LICENSE) است، و [LICENSING.md](LICENSING.md) می‌گوید هر نسخه و هر پوشه‌ی این مخزن تحت چه مجوزی است.

این مجوز هیچ حقی برای استفاده از نام و لوگوی فورتیوا VPN به‌عنوان علامت تجاری نمی‌دهد.
اگر نسخه‌ی تغییریافته‌ای منتشر می‌کنید، به آن نام، آیکون و application ID خودش را بدهید و آن را برنامه‌ی ما معرفی نکنید.
این‌ها شرط‌های اضافه‌ای بر اساس بند ۷ مجوز GPL هستند و در [LICENSING.md](LICENSING.md) آمده‌اند.

</div>
