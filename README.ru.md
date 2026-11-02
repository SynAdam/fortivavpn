<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN бесплатен каждый день: без регистрации, без электронной почты и без рекламы, подключение одним нажатием.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=ru&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Скачать APK"></a>
  <a href="https://t.me/fortivavpn_ru"><img src="https://img.shields.io/badge/Telegram-fortivavpn__ru-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Канал в Telegram"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Последняя версия"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Лицензия: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <b>Русский</b> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## О Fortiva VPN

Fortiva VPN (Фортива ВПН): бесплатный VPN для телефонов на Android и для Android TV.
Регистрация и электронная почта не нужны, рекламы нет, а для подключения достаточно одного нажатия.
Каждый день вы получаете бесплатный трафик, и его лимит сбрасывается ежедневно. Премиум снимает дневной лимит.
Fortiva создан для сетей, в которых обычные VPN не подключаются. Серверы встроены в приложение и обновляются сами, поэтому не нужно искать конфигурации и что-либо вставлять.
Приложение доступно на 18 языках, в том числе на русском.

## Скачать

- **APK (для телефонов и Android TV):** [скачайте напрямую](https://fortivavpn.com/apk) или со страницы [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) этого репозитория. [APK Lite](https://fortivavpn.com/apk/lite) меньше по размеру. Он рассчитан на 32-битные телефоны и работает также на большинстве 64-битных.
- **Windows 10 и 11:** [скачайте установщик напрямую](https://fortivavpn.com/windows) или со страницы [Releases](https://github.com/SynAdam/fortivavpn/releases) этого репозитория. Установщик не подписан, поэтому перед запуском Windows может показать предупреждение: выберите More info, затем Run anyway.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=ru&referrer=utm_source%3Dgithub)
- **Сайт:** [fortivavpn.com/ru/](https://fortivavpn.com/ru/)
- **Telegram:** новости и новые версии публикуются в нашем русскоязычном канале, [t.me/fortivavpn_ru](https://t.me/fortivavpn_ru).

Прежде чем устанавливать APK из другого источника, проверьте, что это наш файл.
Как это сделать, написано в README на английском языке, в разделе [Check a download](README.md#check-a-download).

## Этот репозиторий

В этом репозитории находится исходный код приложений, начиная с версии 2.2.0.
Приложения разрабатываются в закрытом репозитории, и каждое изменение оттуда попадает сюда в течение нескольких минут, одним коммитом.
Каждый релиз отмечен тегом `vX.Y.Z` на том коммите, из которого он собран.
Приложение написано на Flutter и Dart, его код находится в `lib/`.

Issue и pull request приветствуются.
Принятое изменение появляется здесь в течение нескольких минут после слияния, в коммите, где вы указаны как соавтор, и выходит в следующем релизе.

Нескольких адресов и ключей, с помощью которых приложение связывается с нашим сервисом, в этом репозитории нет, поэтому `lib/api/built_in.dart` и `assets/fallback/index.txt` здесь пусты.
Здесь также нет инструментов для релизов и работы с магазинами приложений, которым нужны наши ключи подписи и аккаунты в магазинах, и наших внутренних заметок.
Исходный код серверной части не открыт.
Сборка, которую вы сделаете из этого кода, работает с тем же сервисом, что и приложение из Google Play, и на тех же условиях.

Как собрать приложение из исходного кода, описано в разделе [Build from source](README.md#build-from-source) в README на английском языке.

## Сообщить о проблеме

Чтобы сообщить о проблеме или что-то предложить, [откройте issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) и заполните одну из форм.
Лучше писать на английском, если можете, но подойдёт и любой другой язык.

Issue публичны, и их может прочитать кто угодно.
Поэтому не указывайте в issue и не показывайте на скриншоте:

- Ссылку, скопированную кнопкой «Скопировать ссылку», ключ Премиум или код из пункта «Помочь другу подключиться». Любой, у кого они есть, может ими воспользоваться.
- Адрес сервера или ваш собственный IP-адрес.
- Ваше имя или номер телефона, журнал (лог) или снимок экрана «Информация об IP».

Чтобы получить помощь с аккаунтом или оплатой, откройте в приложении «Настройки» и нажмите «Связаться с нами».
Эти сообщения не публичны.
В [SUPPORT.md](SUPPORT.md) написано, куда обращаться по каждому виду вопросов.

## Участие в разработке

В [CONTRIBUTING.md](CONTRIBUTING.md) описано, как отправить pull request, какие проверки должны быть пройдены и какие условия действуют.
Этот файл на английском языке.

- **С чего начать:** issue с метками [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) или [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Переводы:** текст приложения есть на 18 языках, по одному файлу на язык в [`lib/l10n/`](lib/l10n/). Русский перевод находится в `app_ru.arb`, а английский оригинал в `app_en.arb`. То, что стоит в фигурных скобках, например `{query}`, оставляйте как есть. Для первого pull request хорошо подойдёт исправление одного переведённого предложения.
- **Крупные изменения:** откройте issue до начала работы, чтобы мы могли согласовать подход.

Все, кто участвует в этом проекте, должны соблюдать [кодекс поведения](CODE_OF_CONDUCT.md).

## Безопасность

Если вы нашли проблему безопасности, не пишите о ней в issue, потому что issue публичны.
[Сообщите о ней конфиденциально через GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new) или напишите на admin@fortivavpn.com и укажите в теме Security.
Подробности есть в [SECURITY.md](SECURITY.md).

## Благодарности

Fortiva VPN создан на основе этих проектов с открытым исходным кодом.
Спасибо всем, кто их написал и поддерживает.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) от CluvexStudio, клиент VPN и прокси. Наше ядро включает outbound `autoselect`, написанный CluvexStudio для Xray-core и взятый из [их форка Xray-core](https://github.com/CluvexStudio/Xray-core). Спасибо, что опубликовали его.
- [Xray-core](https://github.com/XTLS/Xray-core) от XTLS, сетевое ядро, на котором построено приложение.
- [libXray](https://github.com/XTLS/libXray) от XTLS, обёртка, которая упрощает использование Xray-core в мобильных приложениях.
- [v2rayNG](https://github.com/2dust/v2rayNG) от 2dust, клиент Xray-core для Android. Наш нативный слой для Android создан на его основе.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) от 2dust, привязка, которая позволяет приложениям для Android использовать Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) от Psiphon Inc., туннельная библиотека Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), клиент для Android. Несколько файлов нашего нативного слоя для Android взяты из него.
- [sing](https://github.com/SagerNet/sing) и [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) от SagerNet, библиотеки на Go, которые использует Xray-core.
- [BadVPN](https://github.com/ambrop72/badvpn) от ambrop72, чей tun2socks используется в приложении для Android.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) от Loyalsoldier, файлы данных `geoip.dat` и `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) от Tencent, хранилище «ключ-значение» для настроек нативного слоя для Android.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) от EbrahimTahernejad, пакет Swift с hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) от heiher, небольшой и быстрый туннель tun2socks.
- [Wintun](https://www.wintun.net) от WireGuard LLC, драйвер сетевого адаптера для Windows.
- [Flutter](https://flutter.dev) и пакеты Dart, перечисленные в [`pubspec.yaml`](pubspec.yaml).

В [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) указана лицензия каждого проекта.

## Лицензия

Сборки приложения для Android и Windows распространяются под лицензией GPL-3.0.
[LICENSE](LICENSE) содержит текст лицензии, а в [LICENSING.md](LICENSING.md) указано, какая лицензия действует для каждой сборки и каждой папки этого репозитория.

Лицензия не даёт никаких прав на название и логотип Fortiva VPN как товарные знаки.
Если вы публикуете изменённую версию, дайте ей собственное название, значок и идентификатор приложения и не выдавайте её за нашу.
Это дополнительные условия согласно разделу 7 GPL, как объясняется в [LICENSING.md](LICENSING.md).
