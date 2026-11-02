<p align="center">
  <img src="assets/icon/fortiva_icon.png" width="104" alt="Fortiva VPN">
</p>

<h1 align="center">Fortiva VPN</h1>

<p align="center">O Fortiva VPN é uma VPN grátis todos os dias: sem cadastro, sem e-mail e sem anúncios, e você conecta com um toque.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&amp;hl=pt-BR&amp;referrer=utm_source%3Dgithub"><img src="https://img.shields.io/badge/Google%20Play-install-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Google Play"></a>
  <a href="https://fortivavpn.com/apk"><img src="https://img.shields.io/badge/APK-download-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Baixar o APK"></a>
  <a href="https://t.me/fortivavpn_pt"><img src="https://img.shields.io/badge/Telegram-fortivavpn__pt-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Canal no Telegram"></a>
  <a href="https://github.com/SynAdam/fortivavpn/tags"><img src="https://img.shields.io/github/v/tag/SynAdam/fortivavpn?sort=semver&amp;label=release&amp;color=C8452B&amp;style=flat-square&amp;labelColor=0E1318" alt="Versão mais recente"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-GPL--3.0-C8452B?style=flat-square&amp;labelColor=0E1318" alt="Licença: GPL-3.0"></a>
  <a href="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml"><img src="https://github.com/SynAdam/fortivavpn/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.ar.md">العربية</a> · <a href="README.zh.md">简体中文</a> · <a href="README.fr.md">Français</a> · <a href="README.de.md">Deutsch</a> · <a href="README.hi.md">हिन्दी</a> · <a href="README.id.md">Bahasa Indonesia</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.fa.md">فارسی</a> · <b>Português</b> · <a href="README.ru.md">Русский</a> · <a href="README.es.md">Español</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.uk.md">Українська</a> · <a href="README.ur.md">اردو</a> · <a href="README.uz.md">Oʻzbekcha</a> · <a href="README.vi.md">Tiếng Việt</a></p>

## Sobre o Fortiva VPN

O Fortiva VPN é uma VPN grátis para celulares Android e Android TV.
Não há cadastro nem e-mail, não há anúncios, e basta um toque para conectar.
Você ganha dados grátis todos os dias, e a franquia reinicia todo dia. O Premium remove o limite diário.
O Fortiva foi feito para redes onde as VPNs comuns não conseguem conectar. Os servidores já vêm no app e se atualizam sozinhos, então não há configurações para procurar nem nada para colar.
O app está disponível em 18 idiomas, incluindo o português.

## Download

- **APK (para celulares e Android TV):** [baixe direto](https://fortivavpn.com/apk), ou pela página [Releases](https://github.com/SynAdam/fortivavpn/releases/latest) deste repositório. O [APK Lite](https://fortivavpn.com/apk/lite) é um download menor para celulares de 32 bits e também funciona na maioria dos de 64 bits.
- **Windows 10 e 11:** [baixe o instalador direto](https://fortivavpn.com/windows), ou pela página [Releases](https://github.com/SynAdam/fortivavpn/releases) deste repositório. O instalador não é assinado, então o Windows pode mostrar um aviso antes de executá-lo: escolha More info e depois Run anyway.
- **Google Play:** [Fortiva VPN](https://play.google.com/store/apps/details?id=com.vpn.fortivavpn&hl=pt-BR&referrer=utm_source%3Dgithub)
- **Site:** [fortivavpn.com/pt-br/](https://fortivavpn.com/pt-br/)
- **Telegram:** as novidades e as novas versões são publicadas no nosso canal em português, [t.me/fortivavpn_pt](https://t.me/fortivavpn_pt).

Antes de instalar um APK de qualquer outro lugar, confira se ele é nosso.
O README em inglês explica como, em [Check a download](README.md#check-a-download).

## Este repositório

Este repositório contém o código-fonte dos apps, a partir da versão 2.2.0.
Os apps são desenvolvidos em um repositório privado, e cada alteração feita lá chega aqui em poucos minutos, como um único commit.
Cada versão recebe a tag `vX.Y.Z` no commit a partir do qual foi compilada.
O app é escrito em Flutter e Dart, e o código dele está em `lib/`.

Issues e pull requests são bem-vindos.
Uma alteração aceita chega aqui poucos minutos depois do merge, em um commit que cita você como coautor, e sai na próxima versão.

Alguns endereços e chaves que o app usa para acessar nosso serviço não estão neste repositório, por isso `lib/api/built_in.dart` e `assets/fallback/index.txt` estão vazios aqui.
As ferramentas de lançamento e de loja, que precisam das nossas chaves de assinatura e contas de loja, e as nossas notas internas também não estão aqui.
O serviço de backend não é de código aberto.
Uma compilação feita por você a partir deste código se comunica com o mesmo serviço que o app do Google Play, nos mesmos termos.

Para compilar o app a partir do código-fonte, veja [Build from source](README.md#build-from-source) no README em inglês.

## Relatar um problema

Para relatar um problema ou sugerir algo, [abra uma issue](https://github.com/SynAdam/fortivavpn/issues/new/choose) e preencha um dos formulários.
Se puder, prefira inglês, mas qualquer outro idioma também serve.

As issues são públicas, e qualquer pessoa pode lê-las.
Por isso, não coloque nada disto em uma issue nem em uma captura de tela:

- Um link de "Copiar link", uma chave Premium ou um código de "Ajudar amigos a se conectar". Quem tiver um deles pode usá-lo.
- Um endereço de servidor ou o seu próprio endereço IP.
- Seu nome ou número de telefone, um log ou uma captura da tela "Informações de IP".

Para obter ajuda com uma conta ou um pagamento, abra Configurações no app e toque em Fale Conosco.
Essas mensagens não são públicas.
O [SUPPORT.md](SUPPORT.md) diz aonde ir para cada tipo de dúvida.

## Como contribuir

O [CONTRIBUTING.md](CONTRIBUTING.md) traz os passos para enviar um pull request, as verificações que precisam passar e os termos.
Esse arquivo está em inglês.

- **Por onde começar:** issues com a etiqueta [good first issue](https://github.com/SynAdam/fortivavpn/labels/good%20first%20issue) ou [help wanted](https://github.com/SynAdam/fortivavpn/labels/help%20wanted).
- **Traduções:** o texto do app está em 18 idiomas, com um arquivo para cada um em [`lib/l10n/`](lib/l10n/). O português está em `app_pt.arb`, e o original em inglês está em `app_en.arb`. Mantenha como está o que estiver entre chaves, como `{query}`. A correção de uma frase traduzida é um bom primeiro pull request.
- **Alterações maiores:** abra uma issue antes de começar, para combinarmos a abordagem.

Esperamos que todas as pessoas que participam deste projeto sigam o [código de conduta](CODE_OF_CONDUCT.md).

## Segurança

Se você encontrar um problema de segurança, não escreva sobre ele em uma issue, porque as issues são públicas.
[Relate em particular pelo GitHub](https://github.com/SynAdam/fortivavpn/security/advisories/new), ou envie um e-mail para admin@fortivavpn.com com a palavra Security no assunto.
O [SECURITY.md](SECURITY.md) traz os detalhes.

## Créditos

O Fortiva VPN é construído sobre o trabalho destes projetos de código aberto.
Obrigado a todas as pessoas que os escreveram e os mantêm.

- [ZedSecure](https://github.com/CluvexStudio/ZedSecure) da CluvexStudio, um cliente de VPN e proxy. Nosso núcleo inclui o outbound `autoselect` que a CluvexStudio escreveu para o Xray-core, tirado do [fork do Xray-core dela](https://github.com/CluvexStudio/Xray-core). Obrigado por publicá-lo.
- [Xray-core](https://github.com/XTLS/Xray-core) da XTLS, o núcleo de rede em que o app se baseia.
- [libXray](https://github.com/XTLS/libXray) da XTLS, um wrapper que facilita o uso do Xray-core em apps para celular.
- [v2rayNG](https://github.com/2dust/v2rayNG) de 2dust, um cliente Android para o Xray-core. Nossa camada nativa para Android deriva dele.
- [AndroidLibXrayLite](https://github.com/2dust/AndroidLibXrayLite) de 2dust, o binding que permite que apps Android usem o Xray-core.
- [psiphon-tunnel-core](https://github.com/Psiphon-Labs/psiphon-tunnel-core) da Psiphon Inc., a biblioteca de túnel do Psiphon.
- [shadowsocks-android](https://github.com/shadowsocks/shadowsocks-android), um cliente Android. Alguns arquivos da nossa camada nativa para Android vêm dele.
- [sing](https://github.com/SagerNet/sing) e [sing-shadowsocks](https://github.com/SagerNet/sing-shadowsocks) da SagerNet, bibliotecas em Go que o Xray-core usa.
- [BadVPN](https://github.com/ambrop72/badvpn) de ambrop72, cujo tun2socks é usado pelo app Android.
- [v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) de Loyalsoldier, os arquivos de dados `geoip.dat` e `geosite.dat`.
- [MMKV](https://github.com/Tencent/MMKV) da Tencent, um armazenamento de chave-valor que guarda as configurações da camada nativa para Android.
- [Tun2SocksKit](https://github.com/EbrahimTahernejad/Tun2SocksKit) de EbrahimTahernejad, um pacote Swift do hev-socks5-tunnel.
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) de heiher, um túnel tun2socks pequeno e rápido.
- [Wintun](https://www.wintun.net) da WireGuard LLC, um driver de adaptador de rede para Windows.
- [Flutter](https://flutter.dev) e os pacotes Dart listados em [`pubspec.yaml`](pubspec.yaml).

O [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) lista a licença de cada projeto.

## Licença

As versões do app para Android e Windows estão sob a GPL-3.0.
O [LICENSE](LICENSE) é o texto da licença, e o [LICENSING.md](LICENSING.md) diz sob qual licença está cada versão e cada pasta deste repositório.

A licença não dá nenhum direito sobre o nome e o logo do Fortiva VPN como marcas.
Se você publicar uma versão modificada, dê a ela nome, ícone e ID de aplicativo próprios, e não a apresente como nossa.
Estes são termos adicionais previstos na seção 7 da GPL, como explica o [LICENSING.md](LICENSING.md).
