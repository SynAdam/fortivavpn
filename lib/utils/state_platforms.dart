/// The Iranian state platforms Fortiva never uses: Bale, Eitaa, Rubika,
/// Soroush Plus, Shad, iGap and Gap (decided 2026-10-13). The app sends no
/// one to them and never opens a connection to them by itself.
///
/// One place for both lists, so the share sheets and the site checks
/// cannot drift apart. The backend keeps the same lists.
class StatePlatforms {
  StatePlatforms._();

  /// Their Android packages, hidden from every share sheet
  /// (InviteShare.builtInExclude). The same list as the backend's default
  /// INVITE_SHARE_EXCLUDE_PACKAGES: Eitaa, Rubika (and its older package),
  /// Bale, Soroush Plus (and its older package), Shad and iGap.
  static const packages = <String>[
    'ir.eitaa.messenger',
    'app.rbmain.a',
    'ir.resaneh1.iptv',
    'ir.nasim',
    'mobi.mmdt.ottplus',
    'mobi.mmdt.ott',
    'ir.medu.shad',
    'net.iGap',
  ];

  /// Their web domains. A site on one of them, or on a subdomain of one,
  /// is never a site the app asks by itself (see [names]).
  static const domains = <String>[
    // Bale.
    'bale.ai',
    'bale.ir',
    'ble.ir',
    // Eitaa.
    'eitaa.com',
    'eitaa.ir',
    // Rubika, and the domain its app talks to.
    'rubika.ir',
    'iranlms.ir',
    // Soroush Plus.
    'splus.ir',
    'sapp.ir',
    // Shad.
    'shad.ir',
    // iGap.
    'igap.net',
    // Gap.
    'gap.im',
  ];

  /// Whether [url] points at one of [domains] or a subdomain of one. A
  /// bare host name counts too. Anything with no host name in it is not
  /// one of them.
  static bool names(String url) {
    final text = url.trim();
    var host = _host(text) ?? _host('https://$text') ?? '';
    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.isEmpty) return false;
    return domains.any((d) => host == d || host.endsWith('.$d'));
  }

  /// Whether the app may ask [url] by itself, as a site check, a mirror
  /// or a test address from the backend. It needs a host made only of
  /// ASCII letters, digits, dots and hyphens (or an IPv6 address), no
  /// backslash anywhere, and a host that is not on one of [domains].
  ///
  /// [names] alone is not enough, because other code reads a disguised
  /// address differently from Dart's Uri. The Go core maps a fullwidth
  /// dot or letter to the plain one, so it dials Bale for a host that Dart
  /// reads as web.bale%E3%80%82ai. Such an address is refused here, and
  /// so is one with a backslash, whatever it names.
  static bool mayAsk(String url) {
    if (url.contains('\\')) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_plainHost.hasMatch(uri.host)) return false;
    return !names(url);
  }

  static final _plainHost = RegExp(r'^[A-Za-z0-9.:-]+$');

  static String? _host(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return uri.host.toLowerCase();
  }
}
