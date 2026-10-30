<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center" dir="rtl">Fortiva VPN هو VPN مجاني كل يوم: بدون تسجيل، وبدون بريد إلكتروني، وبدون إعلانات، ويتصل بلمسة واحدة.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=ar&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com"><img src="https://img.shields.io/badge/website-fortivavpn.com-C8452B?style=flat-square&amp;labelColor=0E1318" alt="الموقع: fortivavpn.com"></a>
  <a href="https://t.me/fortivavpn"><img src="https://img.shields.io/badge/Telegram-fortivavpn-C8452B?style=flat-square&amp;labelColor=0E1318" alt="قناة تيليجرام"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="أحدث إصدار"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="الرخصة: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.fa.md">فارسی</a> · <b>العربية</b> · <a href="README.zh.md">简体中文</a></p>

<div dir="rtl">

## عن Fortiva VPN

Fortiva VPN تطبيق VPN مجاني لهواتف أندرويد وأجهزة Android TV.
لا يحتاج إلى تسجيل أو بريد إلكتروني، ولا يعرض إعلانات، ويتصل بلمسة واحدة.
تحصل على بيانات مجانية كل يوم، وتتجدد حصتك تلقائيًا كل يوم، ويزيل بريميوم الحد اليومي.
صُمّم Fortiva للشبكات التي تفشل فيها تطبيقات VPN العادية في الاتصال. الخوادم مدمجة في التطبيق وتتحدّث تلقائيًا، فلا حاجة إلى البحث عن إعدادات أو لصق مفاتيح.
التطبيق متاح بـ 18 لغة، منها العربية، وتظهر شاشاته العربية من اليمين إلى اليسار.

## التنزيل

- **Google Play:** [Fortiva VPN على Google Play](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=ar&referrer=utm_source%3Dgithub)
- **ملف APK للهاتف و Android TV:** من [رابط التنزيل المباشر](https://fortivavpn.com/apk)، أو من قسم [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) في هذا المستودع. ملف [APK Lite](https://fortivavpn.com/apk/lite) أصغر حجمًا، وهو للهواتف ذات 32 بت ويعمل أيضًا على معظم هواتف 64 بت.
- **تيليجرام:** ننشر الأخبار والإصدارات الجديدة في قناتنا باللغة الإنجليزية، [t.me/fortivavpn](https://t.me/fortivavpn).

قبل أن تثبّت ملف APK حصلت عليه من أي مكان آخر، تحقّق من أننا نحن من نشره.
طريقة التحقق موجودة في قسم [Check a download](README.md#check-a-download) من README الإنجليزي.

## هذا المستودع

يضم هذا المستودع الشفرة المصدرية للتطبيق من الإصدار 2.2.0 فما بعد.
نطوّر التطبيق في مستودع خاص، وكل تغيير يُجرى هناك يصل إلى هذا المستودع بعد دقائق في صورة commit واحد.
يحمل كل إصدار الوسم `vX.Y.Z` على الـ commit الذي بُني منه.
التطبيق مكتوب بـ Flutter و Dart، وشفرته في المجلد `lib/`.

نرحّب بالـ issues والـ pull requests.
التغيير الذي نقبله يصل إلى هنا بعد دقائق من دمجه، في commit يذكر اسمك كمؤلف مشارك (co-author)، ويُنشر في الإصدار التالي.

بعض العناوين والمفاتيح التي يستخدمها التطبيق للوصول إلى خدمتنا ليست في هذا المستودع، ولذلك فإن `lib/api/built_in.dart` و `assets/fallback/index.txt` فارغان هنا.
أدوات النشر والمتاجر، التي تحتاج إلى مفاتيح التوقيع وحسابات المتاجر الخاصة بنا، ليست هنا أيضًا، ولا الملاحظات الداخلية.
الخادم الخلفي (backend) للخدمة ليس مفتوح المصدر.
التطبيق الذي تبنيه بنفسك من هذه الشفرة يتصل بالخدمة نفسها التي يتصل بها تطبيق Google Play، وبالشروط نفسها.

لبناء التطبيق من هذه الشفرة، راجع قسم [Build from source](README.md#build-from-source) في README الإنجليزي.

## الإبلاغ عن مشكلة

للإبلاغ عن مشكلة أو تقديم اقتراح، [افتح issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) واملأ أحد النماذج.
اكتب بالإنجليزية من فضلك.

الـ issues عامة ويستطيع أي شخص قراءتها.
لذلك لا تكتب فيها ما يلي، ولا ترفق صورة تُظهر أيًّا منه:

- رابطًا حصلت عليه من «نسخ الرابط»، أو مفتاح بريميوم، أو رموز «ساعد صديقك على الاتصال». أي شخص يحصل على أحدها يستطيع استخدامه.
- عنوان الخادم أو عنوان IP الخاص بك.

للمساعدة في الحساب أو الدفع، افتح «الإعدادات» في التطبيق واضغط «اتصل بنا».
هذه الرسائل ليست عامة.
يوضح [SUPPORT.md](SUPPORT.md) أين تطلب المساعدة في كل أمر.

## المساهمة

يشرح [CONTRIBUTING.md](CONTRIBUTING.md) خطوات إرسال pull request، والفحوص التي يجب أن تنجح، وشروط المساهمة.
هذا الملف باللغة الإنجليزية.

- **للبداية:** الـ issues التي تحمل الوسم [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) أو [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **الترجمة:** نصوص التطبيق بـ 18 لغة، ولكل لغة ملف في المجلد [`lib/l10n/`](lib/l10n/). النص العربي في `app_ar.arb`، والنص الأصلي الإنجليزي في `app_en.arb`. اترك ما بين الأقواس المعقوفة، مثل `{query}`، كما هو. تصحيح جملة مترجمة بداية جيدة لأول pull request.
- **تغيير كبير:** قبل أن تبدأ، افتح issue حتى نتفق عليه.

يلتزم كل من يشارك في هذا المشروع بـ[مدونة السلوك](CODE_OF_CONDUCT.md) (Code of Conduct).

## الأمان

إذا وجدت مشكلة أمنية، فلا تكتبها في issue، لأن الـ issues عامة.
[أبلغ عنها بشكل خاص على GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new)، أو أرسل بريدًا إلى admin@fortivavpn.com واكتب Security في عنوان الرسالة.
التفاصيل في [SECURITY.md](SECURITY.md).

## شكر وتقدير

بُني Fortiva VPN على عمل هذه المشاريع مفتوحة المصدر.
شكرًا لكل من كتبها ويعتني بها.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) من CluvexStudio، عميل VPN وبروكسي. تتضمن نواتنا الـ outbound المسمى `autoselect` الذي كتبه CluvexStudio لـ Xray-core، وقد أخذناه من [نسختهم المتفرعة (fork) من Xray-core](https://github.com/CluvexStudio/Xray-core). شكرًا لهم على نشره.
- [Xray-core](https://github.com/XTLS/Xray-core) من XTLS، نواة الشبكة التي بُني عليها التطبيق.
- [libXray](https://github.com/XTLS/libXray) من XTLS، طبقة تسهّل استخدام Xray-core في تطبيقات الهاتف.
- [v2rayNG](https://github.com/2dust/v2rayNG) من 2dust، عميل أندرويد لـ Xray-core. الطبقة الأصلية (native) لتطبيق أندرويد لدينا مشتقة منه.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) من 2dust، المكتبة التي تتيح لتطبيقات أندرويد استخدام Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) من Psiphon Inc.، مكتبة النفق الخاصة بـ Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android)، عميل أندرويد. بعض ملفات الطبقة الأصلية لتطبيق أندرويد لدينا مأخوذة منه.
- [sing](https://github.com/SagerNet/sing) و [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) من SagerNet، مكتبات بلغة Go يستخدمها Xray-core.
- [BadVPN](https://github.com/ambrop72/badvpn) من ambrop72، ويستخدم تطبيق أندرويد أداة tun2socks الخاصة به.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) من Loyalsoldier، ملفا البيانات `geoip.dat` و `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) من Tencent، مخزن مفاتيح وقيم يحفظ إعدادات الطبقة الأصلية في أندرويد.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) من EbrahimTahernejad، حزمة Swift لـ hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) من heiher، نفق tun2socks صغير وسريع.
- [Wintun](https://www.wintun.net) من WireGuard LLC، برنامج تشغيل محوّل شبكة لنظام ويندوز.
- [Flutter](https://flutter.dev) وحزم Dart المذكورة في [`pubspec.yaml`](pubspec.yaml).

يسرد [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) رخصة كل مشروع.

## الرخصة

نسخة أندرويد من التطبيق، للهاتف و Android TV، مرخّصة بموجب GPL-3.0.
نص الرخصة في [LICENSE](LICENSE)، ويوضح [LICENSING.md](LICENSING.md) الرخصة التي تخضع لها كل نسخة وكل مجلد في هذا المستودع.

لا تمنح هذه الرخصة أي حق في استخدام اسم Fortiva VPN وشعاره كعلامة تجارية.
إذا نشرت نسخة معدّلة، فامنحها اسمها وأيقونتها و application ID الخاص بها، ولا تقدّمها على أنها تطبيقنا.
هذه شروط إضافية بموجب البند 7 من رخصة GPL، وهي مذكورة في [LICENSING.md](LICENSING.md).

</div>
