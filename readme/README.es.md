<p align="center">
  <img src="../assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">Fortiva VPN es una VPN gratis todos los días: sin registro, sin correo electrónico, sin anuncios y con un solo toque para conectarte.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=es&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Descargar el APK"></a>
  <a href="https://t.me/fortivavpn_es"><img src="https://img.shields.io/badge/Telegram-fortivavpn__es-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Canal de Telegram"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Última versión"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Licencia: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="../README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <a href="README.pt.md">Português</a> · <a href="README.ru.md">Русский</a> · <b>Español</b> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Acerca de Fortiva VPN

Fortiva VPN es una VPN gratis para teléfonos Android y Android TV.
No necesitas registrarte ni dar un correo electrónico, no hay anuncios y te conectas con un solo toque.
Tienes datos gratis todos los días, y tus datos diarios se reinician cada día. Premium quita el límite diario.
Fortiva está hecha para redes donde las VPN comunes no logran conectarse. Los servidores vienen dentro de la app y se actualizan solos, así que no tienes que buscar configuraciones ni pegar nada.
La app está disponible en 18 idiomas, incluido el español.

## Descarga

- **APK (para teléfonos y Android TV):** [descárgalo directamente](https://fortivavpn.com/apk), o desde la página [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) de este repositorio. El [APK Lite](https://fortivavpn.com/apk/lite) es una descarga más pequeña para teléfonos de 32 bits, y también funciona en la mayoría de los de 64 bits.
- **Windows 10 y 11:** [descarga el instalador directamente](https://fortivavpn.com/windows), o desde la página [Releases](https://github.com/SynAdam/fortivavpn/releases) de este repositorio. El instalador no está firmado, así que Windows puede mostrar una advertencia antes de ejecutarlo: elige More info y luego Run anyway.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=es&referrer=utm_source%3Dgithub)
- **Sitio web:** [fortivavpn.com/es/](https://fortivavpn.com/es/)
- **Telegram:** las noticias y las nuevas versiones se publican en nuestro canal en español, [t.me/fortivavpn_es](https://t.me/fortivavpn_es).

Antes de instalar un APK que venga de otro lugar, verifica que sea nuestro.
El README en inglés explica cómo hacerlo, en la sección [Check a download](../README.md#check-a-download).

## Este repositorio

Este repositorio contiene el código fuente de las apps, desde la versión 2.2.0.
Las apps se desarrollan en un repositorio privado, y cada cambio que se hace allí llega aquí en pocos minutos, como un solo commit.
Cada versión lleva la etiqueta `vX.Y.Z` en el commit desde el que se compiló.
La app está escrita en Flutter y Dart, y su código está en `lib/`.

Los issues y los pull requests son bienvenidos.
Un cambio aceptado llega aquí pocos minutos después de fusionarse, en un commit que te nombra como coautor, y se incluye en la siguiente versión.

Algunas direcciones y claves que la app usa para conectarse a nuestro servicio no están en este repositorio, así que `lib/api/built_in.dart` y `assets/fallback/index.txt` están vacíos aquí.
Tampoco están aquí las herramientas de publicación y de las tiendas de apps, que necesitan nuestras claves de firma y nuestras cuentas en las tiendas, ni nuestras notas internas.
El servicio de backend no es de código abierto.
Una compilación que hagas a partir de este código fuente se comunica con el mismo servicio que la app de Google Play, en las mismas condiciones.

Para compilar la app desde el código fuente, consulta [Build from source](../README.md#build-from-source) en el README en inglés.

## Reportar un problema

Para reportar un problema o sugerir algo, [abre un issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) y completa uno de los formularios.
Si puedes, lo mejor es escribir en inglés, pero cualquier otro idioma también está bien.

Los issues son públicos y cualquiera puede leerlos.
Por eso, no pongas nada de esto en un issue ni en una captura de pantalla:

- Un enlace de «Copiar enlace», una clave Premium o un código de «Ayudar a tus amigos a conectarse». Cualquiera que tenga uno puede usarlo.
- La dirección de un servidor o tu propia dirección IP.
- Tu nombre o tu número de teléfono, un registro (log) o una captura de la pantalla «Ver mi IP».

Si necesitas ayuda con una cuenta o un pago, abre Configuración en la app y toca Contáctanos.
Esos mensajes no son públicos.
[SUPPORT.md](../SUPPORT.md) indica a dónde acudir para cada tipo de pregunta.

## Contribuir

[CONTRIBUTING.md](../CONTRIBUTING.md) tiene los pasos para enviar un pull request, las verificaciones que deben pasar y las condiciones.
Ese archivo está en inglés.

- **Por dónde empezar:** los issues con la etiqueta [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) o [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Traducciones:** el texto de la app está en 18 idiomas, con un archivo para cada uno en [`lib/l10n/`](../lib/l10n/). El español está en `app_es.arb`, y el original en inglés está en `app_en.arb`. Deja tal como está lo que va entre llaves, como `{query}`. Corregir una frase traducida es un buen primer pull request.
- **Cambios más grandes:** abre un issue antes de empezar, para que podamos ponernos de acuerdo sobre cómo hacerlo.

Esperamos que todas las personas que participan en este proyecto sigan el [código de conducta](../CODE_OF_CONDUCT.md).

## Seguridad

Si encuentras un problema de seguridad, no lo escribas en un issue, porque los issues son públicos.
[Repórtalo en privado a través de GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new), o escribe a admin@fortivavpn.com con la palabra Security en el asunto.
[SECURITY.md](../SECURITY.md) tiene los detalles.

## Créditos

Fortiva VPN se basa en el trabajo de estos proyectos de código abierto.
Gracias a todas las personas que los escribieron y los mantienen.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) de CluvexStudio, un cliente de VPN y proxy. Nuestro núcleo incluye el outbound `autoselect` que CluvexStudio escribió para Xray-core, tomado de [su fork de Xray-core](https://github.com/CluvexStudio/Xray-core). Gracias por publicarlo.
- [Xray-core](https://github.com/XTLS/Xray-core) de XTLS, el núcleo de red sobre el que está construida la app.
- [libXray](https://github.com/XTLS/libXray) de XTLS, un wrapper que facilita el uso de Xray-core en apps móviles.
- [v2rayNG](https://github.com/2dust/v2rayNG) de 2dust, un cliente de Xray-core para Android. Nuestra capa nativa de Android se deriva de él.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) de 2dust, el binding que permite a las apps de Android usar Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) de Psiphon Inc., la biblioteca de túnel de Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), un cliente para Android. Algunos archivos de nuestra capa nativa de Android provienen de él.
- [sing](https://github.com/SagerNet/sing) y [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) de SagerNet, bibliotecas de Go que usa Xray-core.
- [BadVPN](https://github.com/ambrop72/badvpn) de ambrop72, cuyo tun2socks usa la app de Android.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) de Loyalsoldier, los archivos de datos `geoip.dat` y `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) de Tencent, un almacén de clave-valor que guarda la configuración de la capa nativa de Android.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) de EbrahimTahernejad, un paquete de Swift con hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) de heiher, un túnel tun2socks pequeño y rápido.
- [Wintun](https://www.wintun.net) de WireGuard LLC, un controlador de adaptador de red para Windows.
- [Flutter](https://flutter.dev) y los paquetes de Dart que aparecen en [`pubspec.yaml`](../pubspec.yaml).

[THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md) indica la licencia de cada proyecto.

## Licencia

Las compilaciones de la app para Android y Windows están bajo la GPL-3.0.
[LICENSE](../LICENSE) es el texto de la licencia, y [LICENSING.md](../LICENSING.md) indica bajo qué licencia está cada compilación y cada carpeta de este repositorio.

La licencia no da ningún derecho sobre el nombre y el logotipo de Fortiva VPN como marcas comerciales.
Si publicas una versión modificada, ponle su propio nombre, ícono e ID de aplicación, y no la presentes como nuestra.
Estos son términos adicionales conforme a la sección 7 de la GPL, como explica [LICENSING.md](../LICENSING.md).
