/// The site's home page for each app language that has its own, by the prefix
/// the site serves it under. A language not listed here (de, ja) has no page
/// on the site and opens the English page at the root.
const _homePrefixes = {
  'ar': 'ar-ae',
  'fr': 'fr-fr',
  'pt': 'pt-br',
  'zh': 'zh-hans',
  'es': 'es',
  'fa': 'fa',
  'hi': 'hi',
  'id': 'id',
  'ko': 'ko',
  'ru': 'ru',
  'tr': 'tr',
  'uk': 'uk',
  'ur': 'ur',
  'uz': 'uz',
  'vi': 'vi',
};

/// The website's address for one of its pages, in the app's language.
///
/// The site serves English at its root, and the address alone decides the
/// page's language, so the app has to name it. The home page exists in the
/// languages in [_homePrefixes]. The other page the app opens, /privacy, exists
/// only in English and Persian, and an address under another prefix is a 404,
/// so a reader of any other language gets the English page. [path] starts with
/// a slash: `/` for the home page.
Uri sitePage(String path, String languageCode) {
  final prefix = path == '/'
      ? _homePrefixes[languageCode]
      : (languageCode == 'fa' ? 'fa' : null);
  return Uri.parse(
    'https://fortivavpn.com${prefix == null ? '' : '/$prefix'}$path',
  );
}
