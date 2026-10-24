/// The website's address for one of its pages, in the app's language.
///
/// The site serves English at its root and Persian under /fa/ (since
/// NimusAI/fortiva-vpn-backend#296). A Persian reader goes to /fa/, and
/// every other language to the English page, whose language menu offers
/// the rest. [path] starts with a slash: `/` for the home page.
Uri sitePage(String path, String languageCode) => Uri.parse(
  'https://fortivavpn.com${languageCode == 'fa' ? '/fa' : ''}$path',
);
