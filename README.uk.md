<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN безкоштовний щодня: без реєстрації, без електронної пошти, без реклами, підключення одним дотиком.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=uk&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Завантажити APK"></a>
  <a href="https://t.me/fortivavpn_ua"><img src="https://img.shields.io/badge/Telegram-fortivavpn__ua-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Канал у Telegram"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Останній реліз"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Ліцензія: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <b>Українська</b> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Про Fortiva VPN

Fortiva VPN: безкоштовний VPN для телефонів на Android і для Android TV.
Не потрібні ні реєстрація, ні електронна пошта, реклами немає, а для підключення досить одного дотику.
Щодня ви отримуєте безкоштовний трафік, а ліміт скидається кожного дня. Преміум знімає денний ліміт.
Fortiva створено для мереж, де звичайні VPN не можуть підключитися. Сервери вбудовані в застосунок і оновлюються самі, тож не треба шукати конфігурації чи щось вставляти.
Застосунок доступний 18 мовами, зокрема українською.

## Завантаження

- **APK (для телефонів та Android TV):** [завантажте напряму](https://fortivavpn.com/apk) або зі сторінки [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) цього репозиторію. [Lite APK](https://fortivavpn.com/apk/lite) менший за розміром. Він призначений для 32-бітних телефонів, але працює й на більшості 64-бітних.
- **Windows 10 і 11:** [завантажте інсталятор напряму](https://fortivavpn.com/windows) або зі сторінки [Releases](https://github.com/SynAdam/fortivavpn/releases) цього репозиторію. Інсталятор не підписаний, тому Windows може показати попередження перед запуском: виберіть More info, а потім Run anyway.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=uk&referrer=utm_source%3Dgithub)
- **Вебсайт:** [fortivavpn.com/uk/](https://fortivavpn.com/uk/)
- **Telegram:** новини та нові версії публікуються в нашому українському каналі, [t.me/fortivavpn_ua](https://t.me/fortivavpn_ua).

Якщо встановлюєте APK з іншого джерела, спершу перевірте, що він справді наш.
Як це зробити, описано в англійському README, у розділі [Check a download](README.md#check-a-download).

## Цей репозиторій

У цьому репозиторії зберігається вихідний код застосунків, починаючи з версії 2.2.0.
Застосунки розробляються в приватному репозиторії, і кожна зміна звідти потрапляє сюди за кілька хвилин, одним комітом.
Кожен реліз позначено тегом `vX.Y.Z` на коміті, з якого його зібрано.
Застосунок написаний на Flutter і Dart, а його код лежить у `lib/`.

Ми раді вашим issues і pull requests.
Прийнята зміна потрапляє сюди за кілька хвилин після злиття, у коміті, де ви вказані як співавтор, і виходить у наступному релізі.

Кількох адрес і ключів, які застосунок використовує для зв'язку з нашим сервісом, у цьому репозиторії немає, тому `lib/api/built_in.dart` і `assets/fallback/index.txt` тут порожні.
Тут також немає інструментів для релізів і магазинів застосунків, яким потрібні наші ключі підпису та облікові записи в магазинах, і наших внутрішніх нотаток.
Код бекенд-сервісу закритий.
Збірка, яку ви зробите з цього коду, працює з тим самим сервісом, що й застосунок із Google Play, і на тих самих умовах.

Як зібрати застосунок із вихідного коду, описано в англійському README, у розділі [Build from source](README.md#build-from-source).

## Повідомити про проблему

Щоб повідомити про проблему або щось запропонувати, [відкрийте issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) і заповніть одну з форм.
Найкраще писати англійською, якщо можете, але підійде й будь-яка інша мова.

Issues публічні, і їх може прочитати будь-хто.
Тому не вказуйте нічого з цього в issue чи на знімку екрана:

- Посилання з «Копіювати посилання», ключ Преміум або код із «Допомогти другові підключитися». Скористатися ними може кожен, у кого вони є.
- Адресу сервера або власну IP-адресу.
- Ваше ім'я чи номер телефону, журнал (лог) або знімок екрана «Перевірити мою IP-адресу».

Щоб отримати допомогу з обліковим записом чи оплатою, відкрийте в застосунку «Налаштування» і натисніть «Зв'язатися з нами».
Ці повідомлення не є публічними.
У [SUPPORT.md](SUPPORT.md) написано, куди звертатися з кожним видом запитань.

## Участь у проєкті

У [CONTRIBUTING.md](CONTRIBUTING.md) описано, як надіслати pull request, які перевірки мають пройти та на яких умовах.
Цей файл написаний англійською.

- **З чого почати:** issues з мітками [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) або [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Переклади:** текст застосунку є 18 мовами, по одному файлу на мову в [`lib/l10n/`](lib/l10n/). Український переклад у файлі `app_uk.arb`, а англійський оригінал у `app_en.arb`. Те, що у фігурних дужках, наприклад `{query}`, залишайте без змін. Виправлення одного перекладеного речення добре підходить для першого pull request.
- **Більші зміни:** перш ніж починати, відкрийте issue, щоб ми могли домовитися про підхід.

Усі учасники цього проєкту мають дотримуватися [кодексу поведінки](CODE_OF_CONDUCT.md).

## Безпека

Якщо ви знайшли проблему безпеки, не пишіть про неї в issue, бо issues публічні.
[Повідомте про неї приватно через GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new) або напишіть на admin@fortivavpn.com зі словом Security в темі листа.
Подробиці в [SECURITY.md](SECURITY.md).

## Подяки

Fortiva VPN створено на основі роботи цих проєктів із відкритим кодом.
Дякуємо всім, хто їх написав і підтримує.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) від CluvexStudio, клієнт VPN і проксі. Наше ядро містить outbound `autoselect`, який CluvexStudio написали для Xray-core, узятий із [їхнього форку Xray-core](https://github.com/CluvexStudio/Xray-core). Дякуємо, що опублікували його.
- [Xray-core](https://github.com/XTLS/Xray-core) від XTLS, мережеве ядро, на якому побудовано застосунок.
- [libXray](https://github.com/XTLS/libXray) від XTLS, обгортка, яка спрощує використання Xray-core у мобільних застосунках.
- [v2rayNG](https://github.com/2dust/v2rayNG) від 2dust, клієнт Xray-core для Android. Наш нативний шар Android створено на його основі.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) від 2dust, прив'язка, яка дає застосункам Android змогу використовувати Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) від Psiphon Inc., тунельна бібліотека Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), клієнт для Android. Кілька файлів нашого нативного шару Android узято з нього.
- [sing](https://github.com/SagerNet/sing) і [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) від SagerNet, бібліотеки Go, які використовує Xray-core.
- [BadVPN](https://github.com/ambrop72/badvpn) від ambrop72, чий tun2socks використовує застосунок для Android.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) від Loyalsoldier, файли даних `geoip.dat` і `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) від Tencent, сховище ключ-значення, у якому зберігаються налаштування нативного шару Android.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) від EbrahimTahernejad, пакет Swift із hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) від heiher, невеликий і швидкий тунель tun2socks.
- [Wintun](https://www.wintun.net) від WireGuard LLC, драйвер мережевого адаптера для Windows.
- [Flutter](https://flutter.dev) і пакети Dart, перелічені в [`pubspec.yaml`](pubspec.yaml).

У [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) вказано ліцензію кожного проєкту.

## Ліцензія

Збірки застосунку для Android і Windows поширюються за ліцензією GPL-3.0.
[LICENSE](LICENSE) містить текст ліцензії, а в [LICENSING.md](LICENSING.md) вказано, за якою ліцензією поширюється кожна збірка й кожна тека цього репозиторію.

Ліцензія не дає жодних прав на назву та логотип Fortiva VPN як торговельні марки.
Якщо ви публікуєте змінену версію, дайте їй власну назву, значок та ідентифікатор застосунку й не видавайте її за нашу.
Це додаткові умови згідно з розділом 7 GPL, як пояснено в [LICENSING.md](LICENSING.md).
