<p align="center">
  <img src="../assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN, her gün ücretsiz bir VPN'dir: kayıt yok, e-posta yok, reklam yok ve bağlanmak için tek dokunuş yeterli.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=tr&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="APK'yı indirin"></a>
  <a href="https://t.me/fortivavpn_tr"><img src="https://img.shields.io/badge/Telegram-fortivavpn__tr-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Telegram kanalı"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Son sürüm"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Lisans: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="../README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <b>Türkçe</b> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Fortiva VPN hakkında

Fortiva VPN, Android telefonlar ve Android TV için ücretsiz bir VPN'dir.
Kayıt ve e-posta gerekmez, reklam yoktur ve tek dokunuşla bağlanırsınız.
Her gün ücretsiz veri alırsınız ve kotanız her gün yenilenir. Premium günlük sınırı kaldırır.
Fortiva, sıradan VPN'lerin bağlanamadığı ağlar için geliştirildi. Sunucular uygulamanın içinde hazır gelir ve kendiliğinden güncellenir, bu yüzden yapılandırma aramanız veya bir şey yapıştırmanız gerekmez.
Uygulama, Türkçe dahil 18 dilde kullanılabilir.

## İndirme

- **APK (telefonlar ve Android TV için):** [doğrudan indirin](https://fortivavpn.com/apk) ya da bu deponun [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) sayfasından alın. [Lite APK](https://fortivavpn.com/apk/lite), 32 bit telefonlar için daha küçük bir dosyadır ve çoğu 64 bit telefonda da çalışır.
- **Windows 10 ve 11:** [yükleyiciyi doğrudan indirin](https://fortivavpn.com/windows) ya da bu deponun [Releases](https://github.com/SynAdam/fortivavpn/releases) sayfasından alın. Yükleyici imzalı değildir, bu yüzden Windows çalıştırmadan önce uyarı verebilir: More info'ya, ardından Run anyway'e tıklayın.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=tr&referrer=utm_source%3Dgithub)
- **Web sitesi:** [fortivavpn.com/tr/](https://fortivavpn.com/tr/)
- **Telegram:** haberler ve yeni sürümler Türkçe kanalımızda paylaşılır: [t.me/fortivavpn_tr](https://t.me/fortivavpn_tr).

Başka bir yerden APK yüklemeden önce bize ait olup olmadığını kontrol edin.
Bunun nasıl yapılacağı İngilizce README'nin [Check a download](../README.md#check-a-download) bölümünde anlatılıyor.

## Bu depo

Bu depoda, 2.2.0 sürümünden itibaren uygulamaların kaynak kodu bulunur.
Uygulamalar özel bir depoda geliştirilir ve orada yapılan her değişiklik birkaç dakika içinde tek bir commit olarak buraya gelir.
Her sürüm, derlendiği commit üzerinde `vX.Y.Z` etiketiyle işaretlenir.
Uygulama Flutter ve Dart ile yazılmıştır, kodu `lib/` klasöründedir.

Issue ve pull request'lerinizi bekliyoruz.
Kabul edilen bir değişiklik, birleştirildikten sonra birkaç dakika içinde, sizi ortak yazar olarak gösteren bir commit ile buraya gelir ve bir sonraki sürümde yayımlanır.

Uygulamanın hizmetimize ulaşmak için kullandığı birkaç adres ve anahtar bu depoda yoktur, bu yüzden `lib/api/built_in.dart` ve `assets/fallback/index.txt` burada boştur.
İmzalama anahtarlarımızı ve mağaza hesaplarımızı gerektiren sürüm ve mağaza araçları ile iç notlarımız da burada değildir.
Arka uç hizmeti açık kaynak değildir.
Bu kaynak koddan yaptığınız bir derleme, Google Play'deki uygulamayla aynı hizmete aynı koşullarla bağlanır.

Uygulamayı kaynak koddan derlemek için İngilizce README'nin [Build from source](../README.md#build-from-source) bölümüne bakın.

## Sorun bildirme

Bir sorun bildirmek veya öneride bulunmak için [issue açın](https://github.com/SynAdam/fortivavpn/issues/new/choose) ve formlardan birini doldurun.
Yapabiliyorsanız İngilizce yazmanız en iyisi, ama başka bir dilde yazmanız da sorun değil.

Issue'lar herkese açıktır ve herkes okuyabilir.
Bu yüzden aşağıdakilerin hiçbirini bir issue'ya ya da ekran görüntüsüne koymayın:

- "Bağlantıyı kopyala" ile alınan bir bağlantı, bir Premium anahtarı veya "Arkadaşının bağlanmasına yardım et" ile alınan bir kod. Bunlardan birine sahip olan herkes onu kullanabilir.
- Bir sunucu adresi veya kendi IP adresiniz.
- Adınız veya telefon numaranız, günlük (log) kaydı ya da "IP Bilgisi" ekranının görüntüsü.

Hesap veya ödemeyle ilgili yardım için uygulamada Ayarlar'ı açın ve Bize Ulaşın seçeneğine dokunun.
Bu mesajlar herkese açık değildir.
Hangi soru için nereye başvuracağınızı [SUPPORT.md](../SUPPORT.md) dosyasında bulabilirsiniz.

## Katkıda bulunma

Pull request gönderme adımları, geçmesi gereken kontroller ve koşullar [CONTRIBUTING.md](../CONTRIBUTING.md) dosyasındadır.
Bu dosya İngilizcedir.

- **Nereden başlamalı:** [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) veya [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted) etiketli issue'lar.
- **Çeviriler:** uygulamanın metinleri 18 dildedir ve her dil için bir dosya [`lib/l10n/`](../lib/l10n/) klasöründedir. Türkçe `app_tr.arb` dosyasında, İngilizce asıl metin ise `app_en.arb` dosyasındadır. `{query}` gibi süslü parantez içindekileri olduğu gibi bırakın. Çevrilmiş tek bir cümleyi düzeltmek, ilk pull request için iyi bir başlangıçtır.
- **Daha büyük değişiklikler:** yaklaşım üzerinde anlaşabilmemiz için başlamadan önce bir issue açın.

Bu projeye katılan herkesin [davranış kurallarına](../CODE_OF_CONDUCT.md) uyması beklenir.

## Güvenlik

Bir güvenlik sorunu bulursanız bunu bir issue'ya yazmayın, çünkü issue'lar herkese açıktır.
[GitHub üzerinden gizli olarak bildirin](https://github.com/SynAdam/fortivavpn/security/advisories/new) veya konu satırına Security yazarak admin@fortivavpn.com adresine e-posta gönderin.
Ayrıntılar [SECURITY.md](../SECURITY.md) dosyasındadır.

## Teşekkürler

Fortiva VPN, aşağıdaki açık kaynak projelerin emeği üzerine kuruludur.
Bunları yazan ve bakımını yapan herkese teşekkür ederiz.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure): CluvexStudio'nun geliştirdiği bir VPN ve proxy istemcisi. Çekirdeğimiz, CluvexStudio'nun Xray-core için yazdığı `autoselect` outbound'unu içerir. Bu kod, onların [Xray-core fork'undan](https://github.com/CluvexStudio/Xray-core) alınmıştır. Yayımladıkları için teşekkür ederiz.
- [Xray-core](https://github.com/XTLS/Xray-core): XTLS'in geliştirdiği, uygulamanın üzerine kurulu olduğu ağ çekirdeği.
- [libXray](https://github.com/XTLS/libXray): XTLS'in geliştirdiği, Xray-core'u mobil uygulamalarda kullanmayı kolaylaştıran bir sarmalayıcı.
- [v2rayNG](https://github.com/2dust/v2rayNG): 2dust'ın geliştirdiği, Xray-core için bir Android istemcisi. Android yerel katmanımız bundan türetilmiştir.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite): 2dust'ın geliştirdiği, Android uygulamalarının Xray-core'u kullanmasını sağlayan bağlayıcı kitaplık.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core): Psiphon Inc.'in geliştirdiği, Psiphon'un tünel kitaplığı.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android): bir Android istemcisi. Android yerel katmanımızdaki birkaç dosya buradan alınmıştır.
- [sing](https://github.com/SagerNet/sing) ve [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks): SagerNet'in geliştirdiği, Xray-core'un kullandığı Go kitaplıkları.
- [BadVPN](https://github.com/ambrop72/badvpn): ambrop72'nin projesi. Android uygulaması bunun tun2socks bileşenini kullanır.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat): Loyalsoldier'ın hazırladığı `geoip.dat` ve `geosite.dat` veri dosyaları.
- [MMKV](https://github.com/Tencent/MMKV): Tencent'in geliştirdiği, Android yerel katmanının ayarlarını saklayan bir anahtar-değer deposu.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit): EbrahimTahernejad'ın geliştirdiği, hev-socks5-tunnel için bir Swift paketi.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel): heiher'in geliştirdiği, küçük ve hızlı bir tun2socks tüneli.
- [Wintun](https://www.wintun.net): WireGuard LLC'nin geliştirdiği, Windows için bir ağ bağdaştırıcısı sürücüsü.
- [Flutter](https://flutter.dev) ve [`pubspec.yaml`](../pubspec.yaml) dosyasında listelenen Dart paketleri.

Her projenin lisansı [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) dosyasında listelenir.

## Lisans

Uygulamanın Android ve Windows derlemeleri GPL-3.0 lisansı altındadır.
Lisans metni [LICENSE](../LICENSE) dosyasındadır. Her derlemenin ve bu deponun her klasörünün hangi lisans altında olduğu ise [LICENSING.md](../LICENSING.md) dosyasında yazılıdır.

Lisans, Fortiva VPN adı ve logosu üzerinde ticari marka olarak hiçbir hak vermez.
Değiştirilmiş bir sürüm yayımlarsanız ona kendi adını, simgesini ve uygulama kimliğini verin ve onu bizimmiş gibi sunmayın.
[LICENSING.md](../LICENSING.md) dosyasında açıklandığı gibi, bunlar GPL'in 7. bölümü kapsamındaki ek koşullardır.
