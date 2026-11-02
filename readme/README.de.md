<p align="center">
  <img src="../assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN ist ein VPN, das jeden Tag kostenlos ist: keine Registrierung, keine E-Mail, keine Werbung, und zum Verbinden genügt ein Fingertipp.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=de&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="APK herunterladen"></a>
  <a href="https://t.me/fortivavpn"><img src="https://img.shields.io/badge/Telegram-fortivavpn-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Telegram-Kanal"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Neueste Version"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Lizenz: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="../README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <b>Deutsch</b> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Über Fortiva VPN

Fortiva VPN ist ein kostenloses VPN für Android-Handys und Android TV.
Du brauchst keine Registrierung und keine E-Mail, es gibt keine Werbung, und mit einem Fingertipp bist du verbunden.
Du bekommst jeden Tag kostenloses Datenvolumen, und das Volumen wird jeden Tag zurückgesetzt. Premium hebt das Tageslimit auf.
Fortiva ist für Netzwerke gemacht, in denen normale VPNs keine Verbindung bekommen. Die Server sind in die App eingebaut und aktualisieren sich selbst. Du musst also keine Konfigurationen suchen und nichts einfügen.
Die App gibt es in 18 Sprachen, darunter Deutsch.

## Download

- **APK (für Handys und Android TV):** [direkt herunterladen](https://fortivavpn.com/apk) oder über die Seite [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) dieses Repositorys. Die [Lite-APK](https://fortivavpn.com/apk/lite) ist ein kleinerer Download für 32-Bit-Handys und läuft auch auf den meisten 64-Bit-Handys.
- **Windows 10 und 11:** [Installer direkt herunterladen](https://fortivavpn.com/windows) oder über die Seite [Releases](https://github.com/SynAdam/fortivavpn/releases) dieses Repositorys. Der Installer ist nicht signiert, deshalb warnt Windows möglicherweise, bevor er startet: Wähle More info und dann Run anyway.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=de&referrer=utm_source%3Dgithub)
- **Website:** [fortivavpn.com](https://fortivavpn.com)
- **Telegram:** Neuigkeiten und neue Versionen erscheinen in unserem englischsprachigen Kanal, [t.me/fortivavpn](https://t.me/fortivavpn).

Bevor du eine APK aus einer anderen Quelle installierst, prüfe, ob sie wirklich von uns ist.
Wie das geht, steht im englischen README unter [Check a download](../README.md#check-a-download).

## Dieses Repository

Dieses Repository enthält den Quellcode der Apps ab Version 2.2.0.
Die Apps werden in einem privaten Repository entwickelt. Jede Änderung von dort kommt innerhalb weniger Minuten als einzelner Commit hierher.
Jedes Release ist als `vX.Y.Z` auf dem Commit getaggt, aus dem es gebaut wurde.
Die App ist in Flutter und Dart geschrieben, ihr Code liegt in `lib/`.

Issues und Pull Requests sind willkommen.
Eine angenommene Änderung kommt wenige Minuten nach dem Merge hierher, in einem Commit, der dich als Co-Autor nennt, und erscheint im nächsten Release.

Einige Adressen und Schlüssel, mit denen die App unseren Dienst erreicht, sind nicht in diesem Repository. Deshalb sind `lib/api/built_in.dart` und `assets/fallback/index.txt` hier leer.
Auch die Werkzeuge für Releases und Stores, die unsere Signaturschlüssel und Store-Konten brauchen, und unsere internen Notizen sind nicht hier.
Der Backend-Dienst ist nicht Open Source.
Ein Build, den du aus diesem Quellcode erstellst, kommuniziert mit demselben Dienst wie die App aus Google Play, und es gelten dieselben Bedingungen.

Wie du die App aus dem Quellcode baust, steht im englischen README unter [Build from source](../README.md#build-from-source).

## Ein Problem melden

Um ein Problem zu melden oder etwas vorzuschlagen, [öffne ein Issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) und fülle eines der Formulare aus.
Am besten schreibst du auf Englisch, wenn du kannst, aber jede andere Sprache ist auch in Ordnung.

Issues sind öffentlich, und jeder kann sie lesen.
Das hier gehört deshalb nicht in ein Issue und auch nicht auf einen Screenshot:

- Ein Link aus »Link kopieren«, ein Premium-Schlüssel oder ein Code aus »Freunden beim Verbinden helfen«. Wer so etwas hat, kann es nutzen.
- Eine Serveradresse oder deine eigene IP-Adresse.
- Deinen Namen oder deine Telefonnummer, ein Log oder einen Screenshot des Bildschirms »IP-Informationen«.

Wenn du Hilfe zu einem Konto oder einer Zahlung brauchst, öffne in der App die Einstellungen und tippe auf Kontakt.
Diese Nachrichten sind nicht öffentlich.
In [SUPPORT.md](../SUPPORT.md) steht, an wen du dich mit welcher Frage wendest.

## Mitwirken

In [CONTRIBUTING.md](../CONTRIBUTING.md) stehen die Schritte für einen Pull Request, die Prüfungen, die bestanden werden müssen, und die Bedingungen.
Diese Datei ist auf Englisch.

- **Wo du anfangen kannst:** Issues mit dem Label [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) oder [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Übersetzungen:** Die Texte der App gibt es in 18 Sprachen, je eine Datei in [`lib/l10n/`](../lib/l10n/). Deutsch steht in `app_de.arb`, das englische Original in `app_en.arb`. Lass alles in geschweiften Klammern, etwa `{query}`, unverändert. Die Korrektur eines einzelnen übersetzten Satzes ist ein guter erster Pull Request.
- **Größere Änderungen:** Öffne ein Issue, bevor du anfängst, damit wir uns auf das Vorgehen einigen können.

Von allen, die an diesem Projekt teilnehmen, wird erwartet, dass sie den [Verhaltenskodex](../CODE_OF_CONDUCT.md) einhalten.

## Sicherheit

Wenn du ein Sicherheitsproblem findest, schreibe es nicht in ein Issue, denn Issues sind öffentlich.
[Melde es vertraulich über GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new) oder schreibe eine E-Mail an admin@fortivavpn.com mit Security im Betreff.
Details stehen in [SECURITY.md](../SECURITY.md).

## Danksagung

Fortiva VPN baut auf der Arbeit dieser Open-Source-Projekte auf.
Danke an alle, die sie geschrieben haben und pflegen.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) von CluvexStudio, ein VPN- und Proxy-Client. Unser Kern enthält den Outbound `autoselect`, den CluvexStudio für Xray-core geschrieben hat, übernommen aus [ihrem Xray-core-Fork](https://github.com/CluvexStudio/Xray-core). Danke für die Veröffentlichung.
- [Xray-core](https://github.com/XTLS/Xray-core) von XTLS, der Netzwerkkern, auf dem die App aufbaut.
- [libXray](https://github.com/XTLS/libXray) von XTLS, ein Wrapper, der Xray-core in mobilen Apps leichter nutzbar macht.
- [v2rayNG](https://github.com/2dust/v2rayNG) von 2dust, ein Android-Client für Xray-core. Unsere native Android-Schicht ist davon abgeleitet.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) von 2dust, das Binding, mit dem Android-Apps Xray-core nutzen können.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) von Psiphon Inc., die Tunnel-Bibliothek von Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), ein Android-Client. Einige Dateien unserer nativen Android-Schicht stammen daraus.
- [sing](https://github.com/SagerNet/sing) und [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) von SagerNet, Go-Bibliotheken, die Xray-core verwendet.
- [BadVPN](https://github.com/ambrop72/badvpn) von ambrop72, dessen tun2socks die Android-App verwendet.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) von Loyalsoldier, die Datendateien `geoip.dat` und `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) von Tencent, ein Key-Value-Speicher, der die Einstellungen der nativen Android-Schicht aufbewahrt.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) von EbrahimTahernejad, ein Swift-Paket von hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) von heiher, ein kleiner und schneller tun2socks-Tunnel.
- [Wintun](https://www.wintun.net) von WireGuard LLC, ein Netzwerkadapter-Treiber für Windows.
- [Flutter](https://flutter.dev) und die Dart-Pakete, die in [`pubspec.yaml`](../pubspec.yaml) aufgeführt sind.

In [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) steht die Lizenz jedes Projekts.

## Lizenz

Die Android- und Windows-Builds der App stehen unter der GPL-3.0.
[LICENSE](../LICENSE) ist der Lizenztext. In [LICENSING.md](../LICENSING.md) steht, unter welcher Lizenz jeder Build und jeder Ordner dieses Repositorys steht.

Die Lizenz gewährt keine Markenrechte am Namen und Logo von Fortiva VPN.
Wenn du eine geänderte Version veröffentlichst, gib ihr einen eigenen Namen, ein eigenes Icon und eine eigene Application ID und gib sie nicht als unsere aus.
Das sind zusätzliche Bedingungen nach Abschnitt 7 der GPL, wie [LICENSING.md](../LICENSING.md) erklärt.
