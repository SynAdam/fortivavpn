<p align="center">
  <img src="../assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN est un VPN gratuit tous les jours : sans inscription, sans e-mail, sans publicité, avec une connexion en un clic.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=fr&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Télécharger l'APK"></a>
  <a href="https://t.me/fortivavpn"><img src="https://img.shields.io/badge/Telegram-fortivavpn-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Chaîne Telegram"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Dernière version"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Licence : GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="../README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <b>Français</b> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## À propos de Fortiva VPN

Fortiva VPN est un VPN gratuit pour les téléphones Android et Android TV.
Pas d'inscription, pas d'e-mail, pas de publicité, et un clic suffit pour vous connecter.
Vous recevez des données gratuites chaque jour, et votre quota se réinitialise tous les jours. Premium supprime la limite quotidienne.
Fortiva est conçu pour les réseaux où les VPN ordinaires n'arrivent pas à se connecter. Les serveurs sont intégrés à l'application et se mettent à jour tout seuls : aucune configuration à chercher, rien à coller.
L'application est disponible en 18 langues, dont le français.

## Téléchargement

- **APK (pour les téléphones et Android TV) :** [téléchargez-le directement](https://fortivavpn.com/apk), ou depuis la page [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) de ce dépôt. L'[APK Lite](https://fortivavpn.com/apk/lite) est un téléchargement plus léger pour les téléphones 32 bits, et il fonctionne aussi sur la plupart des téléphones 64 bits.
- **Windows 10 et 11 :** [téléchargez directement le programme d'installation](https://fortivavpn.com/windows), ou depuis la page [Releases](https://github.com/SynAdam/fortivavpn/releases) de ce dépôt. Le programme d'installation n'est pas signé, donc Windows peut afficher un avertissement avant de le lancer : choisissez More info, puis Run anyway.
- **Google Play :** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=fr&referrer=utm_source%3Dgithub)
- **Site web :** [fortivavpn.com/fr-fr/](https://fortivavpn.com/fr-fr/)
- **Telegram :** les actualités et les nouvelles versions sont publiées sur notre chaîne en anglais, [t.me/fortivavpn](https://t.me/fortivavpn).

Avant d'installer un APK trouvé ailleurs, vérifiez qu'il vient bien de nous.
Le README en anglais explique comment faire, à la section [Check a download](../README.md#check-a-download).

## Ce dépôt

Ce dépôt contient le code source des applications, à partir de la version 2.2.0.
Les applications sont développées dans un dépôt privé, et chaque modification faite là-bas arrive ici en quelques minutes, en un seul commit.
Chaque version porte le tag `vX.Y.Z` sur le commit à partir duquel elle a été compilée.
L'application est écrite en Flutter et Dart, et son code se trouve dans `lib/`.

Les issues et les pull requests sont les bienvenues.
Une modification acceptée arrive ici quelques minutes après sa fusion, dans un commit qui vous cite comme coauteur, et elle est livrée dans la version suivante.

Quelques adresses et clés que l'application utilise pour joindre notre service ne sont pas dans ce dépôt : `lib/api/built_in.dart` et `assets/fallback/index.txt` sont donc vides ici.
Les outils de publication et de gestion des boutiques d'applications, qui nécessitent nos clés de signature et nos comptes sur ces boutiques, ne sont pas ici non plus, tout comme nos notes internes.
Le service backend n'est pas open source.
Une version que vous compilez à partir de ce code communique avec le même service que l'application de Google Play, aux mêmes conditions.

Pour compiler l'application à partir du code source, consultez [Build from source](../README.md#build-from-source) dans le README en anglais.

## Signaler un problème

Pour signaler un problème ou suggérer quelque chose, [ouvrez une issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) et remplissez l'un des formulaires.
Écrivez de préférence en anglais si vous le pouvez, mais toute autre langue convient aussi.

Les issues sont publiques et tout le monde peut les lire.
Ne mettez donc aucun de ces éléments dans une issue ou dans une capture d'écran :

- Un lien obtenu avec « Copier le lien », une clé Premium ou un code obtenu avec « Aider vos amis à se connecter ». Toute personne qui en a un peut l'utiliser.
- Une adresse de serveur ou votre propre adresse IP.
- Votre nom ou votre numéro de téléphone, un journal (log) ou une capture de l'écran « Informations IP ».

Pour obtenir de l'aide sur un compte ou un paiement, ouvrez Paramètres dans l'application et touchez Nous contacter.
Ces messages ne sont pas publics.
[SUPPORT.md](../SUPPORT.md) indique où s'adresser pour chaque type de question.

## Contribuer

[CONTRIBUTING.md](../CONTRIBUTING.md) décrit les étapes pour envoyer une pull request, les vérifications qui doivent réussir et les conditions.
Ce fichier est en anglais.

- **Par où commencer :** les issues avec le label [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) ou [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Traductions :** le texte de l'application existe en 18 langues, avec un fichier par langue dans [`lib/l10n/`](../lib/l10n/). Le français se trouve dans `app_fr.arb`, et l'original anglais dans `app_en.arb`. Laissez tel quel ce qui est entre accolades, comme `{query}`. Corriger une phrase traduite est une bonne première pull request.
- **Changements plus importants :** ouvrez une issue avant de commencer, afin que nous puissions nous mettre d'accord sur l'approche.

Toute personne qui participe à ce projet est tenue de respecter le [code de conduite](../CODE_OF_CONDUCT.md).

## Sécurité

Si vous trouvez un problème de sécurité, ne le décrivez pas dans une issue, car les issues sont publiques.
[Signalez-le en privé via GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new), ou écrivez à admin@fortivavpn.com avec Security dans l'objet.
[SECURITY.md](../SECURITY.md) donne les détails.

## Remerciements

Fortiva VPN repose sur le travail de ces projets open source.
Merci à toutes les personnes qui les ont écrits et qui les maintiennent.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) de CluvexStudio, un client VPN et proxy. Notre noyau inclut l'outbound `autoselect` que CluvexStudio a écrit pour Xray-core, repris de [son fork de Xray-core](https://github.com/CluvexStudio/Xray-core). Merci de l'avoir publié.
- [Xray-core](https://github.com/XTLS/Xray-core) de XTLS, le noyau réseau sur lequel repose l'application.
- [libXray](https://github.com/XTLS/libXray) de XTLS, une surcouche qui facilite l'utilisation de Xray-core dans les applications mobiles.
- [v2rayNG](https://github.com/2dust/v2rayNG) de 2dust, un client Android pour Xray-core. Notre couche native Android en est dérivée.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) de 2dust, le binding qui permet aux applications Android d'utiliser Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) de Psiphon Inc., la bibliothèque de tunnel de Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), un client Android. Quelques fichiers de notre couche native Android en proviennent.
- [sing](https://github.com/SagerNet/sing) et [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) de SagerNet, des bibliothèques Go utilisées par Xray-core.
- [BadVPN](https://github.com/ambrop72/badvpn) d'ambrop72, dont l'application Android utilise le tun2socks.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) de Loyalsoldier, les fichiers de données `geoip.dat` et `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) de Tencent, un stockage clé-valeur qui conserve les paramètres de la couche native Android.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) d'EbrahimTahernejad, un paquet Swift de hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) de heiher, un tunnel tun2socks petit et rapide.
- [Wintun](https://www.wintun.net) de WireGuard LLC, un pilote de carte réseau pour Windows.
- [Flutter](https://flutter.dev) et les paquets Dart listés dans [`pubspec.yaml`](../pubspec.yaml).

[THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) indique la licence de chaque projet.

## Licence

Les versions Android et Windows de l'application sont sous licence GPL-3.0.
[LICENSE](../LICENSE) contient le texte de la licence, et [LICENSING.md](../LICENSING.md) indique la licence de chaque version et de chaque dossier de ce dépôt.

La licence ne donne aucun droit sur le nom et le logo Fortiva VPN en tant que marques.
Si vous publiez une version modifiée, donnez-lui son propre nom, sa propre icône et son propre identifiant d'application, et ne la présentez pas comme la nôtre.
Il s'agit de conditions supplémentaires au titre de la section 7 de la GPL, comme l'explique [LICENSING.md](../LICENSING.md).
