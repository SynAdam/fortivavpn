<p align="center">
  <img src="../assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN har kuni bepul ishlaydigan VPN: roʻyxatdan oʻtish, elektron pochta va reklama yoʻq, ulanish uchun bir marta bosish kifoya.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=uz&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="APK faylini yuklab olish"></a>
  <a href="https://t.me/fortivavpn_uz"><img src="https://img.shields.io/badge/Telegram-fortivavpn__uz-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Telegram kanali"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Eng soʻnggi reliz"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Litsenziya: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="../README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <b>Oʻzbekcha</b> · <a href="README.vi.md">Tiếng Việt</a></p>

## Fortiva VPN haqida

Fortiva VPN Android telefonlar va Android TV uchun moʻljallangan bepul VPN.
Roʻyxatdan oʻtish va elektron pochta kerak emas, reklama yoʻq, bir marta bosish bilan ulanasiz.
Har kuni bepul trafik olasiz va limitingiz har kuni yangilanadi. Premium kunlik limitni olib tashlaydi.
Fortiva oddiy VPNlar ulana olmaydigan tarmoqlar uchun yaratilgan. Serverlar ilovaga oʻrnatilgan va oʻz-oʻzidan yangilanadi, shuning uchun konfiguratsiya qidirishingiz yoki biror narsani joylashtirishingiz shart emas.
Ilova 18 tilda mavjud, jumladan oʻzbek tilida.

## Yuklab olish

- **APK (telefonlar va Android TV uchun):** [toʻgʻridan-toʻgʻri yuklab oling](https://fortivavpn.com/apk) yoki bu repozitoriyning [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) sahifasidan oling. [Lite APK](https://fortivavpn.com/apk/lite) hajmi kichikroq, u 32-bitli telefonlar uchun moʻljallangan va koʻpchilik 64-bitli telefonlarda ham ishlaydi.
- **Windows 10 va 11:** [oʻrnatish faylini toʻgʻridan-toʻgʻri yuklab oling](https://fortivavpn.com/windows) yoki bu repozitoriyning [Releases](https://github.com/SynAdam/fortivavpn/releases) sahifasidan oling. Oʻrnatish fayli imzolanmagan, shuning uchun Windows uni ishga tushirishdan oldin ogohlantirishi mumkin: avval «More info»ni, keyin «Run anyway»ni tanlang.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=uz&referrer=utm_source%3Dgithub)
- **Veb-sayt:** [fortivavpn.com/uz/](https://fortivavpn.com/uz/)
- **Telegram:** yangiliklar va yangi versiyalar oʻzbek tilidagi kanalimizda eʼlon qilinadi: [t.me/fortivavpn_uz](https://t.me/fortivavpn_uz).

Boshqa joydan APK oʻrnatishdan oldin u bizniki ekanini tekshiring.
Buni qanday qilish kerakligi inglizcha README faylining [Check a download](../README.md#check-a-download) boʻlimida yozilgan.

## Bu repozitoriy

Bu repozitoriyda ilovalarning 2.2.0 versiyasidan boshlab manba kodi saqlanadi.
Ilovalar yopiq repozitoriyda ishlab chiqiladi va u yerdagi har bir oʻzgarish bir necha daqiqada bu yerga bitta commit boʻlib keladi.
Har bir reliz oʻzi yigʻilgan commitda `vX.Y.Z` tegi bilan belgilanadi.
Ilova Flutter va Dart yordamida yozilgan, kodi `lib/` papkasida.

Issue va pull requestlarni mamnuniyat bilan qabul qilamiz.
Qabul qilingan oʻzgarish birlashtirilgandan keyin bir necha daqiqada bu yerga sizni hammuallif sifatida koʻrsatadigan commit boʻlib keladi va keyingi relizda chiqadi.

Ilova xizmatimizga ulanish uchun ishlatadigan baʼzi manzil va kalitlar bu repozitoriyda yoʻq, shuning uchun `lib/api/built_in.dart` va `assets/fallback/index.txt` fayllari bu yerda boʻsh.
Imzolash kalitlarimiz va doʻkon hisoblarimizni talab qiladigan reliz va doʻkon vositalari hamda ichki qaydlarimiz ham bu yerda yoʻq.
Backend xizmati ochiq manbali emas.
Bu manba koddan yigʻgan ilovangiz Google Play orqali oʻrnatilgan ilova bilan bir xil xizmatga, bir xil shartlar asosida ulanadi.

Ilovani manba koddan yigʻish uchun inglizcha README faylining [Build from source](../README.md#build-from-source) boʻlimiga qarang.

## Muammo haqida xabar berish

Muammo haqida xabar berish yoki taklif bildirish uchun [issue oching](https://github.com/SynAdam/fortivavpn/issues/new/choose) va shakllardan birini toʻldiring.
Imkoningiz boʻlsa, ingliz tilida yozganingiz maʼqul, lekin boshqa istalgan tilda ham yozishingiz mumkin.

Issuelar ommaga ochiq, ularni istalgan kishi oʻqiy oladi.
Shuning uchun quyidagilarni issue matnida ham, skrinshotda ham koʻrsatmang:

- «Havolani nusxalash» orqali olingan havola, Premium kaliti yoki «Doʻstga ulanishda yordam berish» boʻlimidan olingan kod. Ular kimning qoʻlida boʻlsa, oʻsha foydalana oladi.
- Server manzili yoki oʻz IP manzilingiz.
- Ismingiz yoki telefon raqamingiz, log yoki "IP manzilimni tekshirish" ekranining skrinshoti.

Hisob yoki toʻlov boʻyicha yordam kerak boʻlsa, ilovada «Sozlamalar»ni oching va «Biz bilan bogʻlanish»ni bosing.
Bu xabarlar ommaga ochiq emas.
Har bir turdagi savol bilan qayerga murojaat qilish kerakligi [SUPPORT.md](../SUPPORT.md) faylida yozilgan.

## Hissa qoʻshish

Pull request yuborish bosqichlari, oʻtishi shart boʻlgan tekshiruvlar va shartlar [CONTRIBUTING.md](../CONTRIBUTING.md) faylida berilgan.
Bu fayl ingliz tilida.

- **Nimadan boshlash kerak:** [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) yoki [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted) yorligʻi qoʻyilgan issuelar.
- **Tarjimalar:** ilova matni 18 tilda, [`lib/l10n/`](../lib/l10n/) papkasida har bir til uchun bittadan fayl bor. Oʻzbekcha matn `app_uz.arb` faylida, inglizcha asl matn esa `app_en.arb` faylida. `{query}` kabi jingalak qavs ichidagi narsalarni oʻzgartirmang. Tarjimadagi bitta gapni tuzatish birinchi pull request uchun yaxshi tanlov.
- **Kattaroq oʻzgarishlar:** yondashuvni kelishib olishimiz uchun ishni boshlashdan oldin issue oching.

Loyihada ishtirok etuvchi har bir kishi [xulq-atvor qoidalariga](../CODE_OF_CONDUCT.md) rioya qilishi kerak.

## Xavfsizlik

Agar xavfsizlik muammosini topsangiz, bu haqda issue yozmang, chunki issuelar ommaga ochiq.
[GitHub orqali maxfiy xabar bering](https://github.com/SynAdam/fortivavpn/security/advisories/new) yoki admin@fortivavpn.com manziliga mavzu qatorida Security deb yozib xat yuboring.
Batafsil maʼlumot [SECURITY.md](../SECURITY.md) faylida.

## Minnatdorchilik

Fortiva VPN quyidagi ochiq manbali loyihalar asosida yaratilgan.
Ularni yozgan va qoʻllab-quvvatlayotgan barchaga rahmat.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure), muallifi CluvexStudio: VPN va proksi mijozi. Yadromiz tarkibida CluvexStudio Xray-core uchun yozgan `autoselect` outbound bor, u [ularning Xray-core forkidan](https://github.com/CluvexStudio/Xray-core) olingan. Uni eʼlon qilganingiz uchun rahmat.
- [Xray-core](https://github.com/XTLS/Xray-core), muallifi XTLS: ilova asoslangan tarmoq yadrosi.
- [libXray](https://github.com/XTLS/libXray), muallifi XTLS: mobil ilovalarda Xray-core bilan ishlashni osonlashtiradigan oʻram.
- [v2rayNG](https://github.com/2dust/v2rayNG), muallifi 2dust: Xray-core uchun Android mijozi. Android native qatlamimiz shu loyiha asosida yaratilgan.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite), muallifi 2dust: Android ilovalariga Xray-core bilan ishlash imkonini beradigan binding.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core), muallifi Psiphon Inc.: Psiphon tunnel kutubxonasi.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android): Android mijozi. Android native qatlamimizdagi bir nechta fayl shu loyihadan olingan.
- [sing](https://github.com/SagerNet/sing) va [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks), muallifi SagerNet: Xray-core ishlatadigan Go kutubxonalari.
- [BadVPN](https://github.com/ambrop72/badvpn), muallifi ambrop72: Android ilovasi uning tun2socks qismidan foydalanadi.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat), muallifi Loyalsoldier: `geoip.dat` va `geosite.dat` maʼlumot fayllari.
- [MMKV](https://github.com/Tencent/MMKV), muallifi Tencent: Android native qatlami sozlamalarini saqlaydigan kalit-qiymat ombori.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit), muallifi EbrahimTahernejad: hev-socks5-tunnel uchun Swift paketi.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel), muallifi heiher: kichik va tez tun2socks tunneli.
- [Wintun](https://www.wintun.net), muallifi WireGuard LLC: Windows uchun tarmoq adapteri drayveri.
- [Flutter](https://flutter.dev) va [`pubspec.yaml`](../pubspec.yaml) faylida koʻrsatilgan Dart paketlari.

Har bir loyihaning litsenziyasi [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) faylida keltirilgan.

## Litsenziya

Ilovaning Android va Windows yigʻmalari GPL-3.0 litsenziyasi ostida.
Litsenziya matni [LICENSE](../LICENSE) faylida, har bir yigʻma va bu repozitoriyning har bir papkasi qaysi litsenziya ostida ekani esa [LICENSING.md](../LICENSING.md) faylida yozilgan.

Litsenziya Fortiva VPN nomi va logotipiga savdo belgisi sifatida hech qanday huquq bermaydi.
Agar oʻzgartirilgan versiyani eʼlon qilsangiz, unga alohida nom, ikonka va ilova identifikatori bering va uni bizniki deb koʻrsatmang.
[LICENSING.md](../LICENSING.md) faylida tushuntirilganidek, bular GPL 7-boʻlimiga muvofiq qoʻshimcha shartlardir.
