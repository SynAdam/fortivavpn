import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/update_check.dart';
import '../data/models/in_app_message.dart';
import 'bootstrap.dart';

/// One message from the Fortiva team as the notices file carries it: in
/// every app language, with who it is for.
///
/// The backend's in-app messages that go to everyone, or to whole
/// countries or versions. Never a test or anything aimed at one phone: the
/// file is public, and it must not say who our users are.
class Notice {
  const Notice({
    required this.id,
    required this.sentAt,
    required this.endsAt,
    this.link,
    this.countries = const [],
    this.minVersion,
    this.maxVersion,
    this.texts = const {},
  });

  /// The in-app message's id, so a notice and the message the backend
  /// serves are one message on the phone.
  final int id;
  final DateTime sentAt;
  final DateTime endsAt;
  final String? link;

  /// Upper-case country codes. Empty means every country.
  final List<String> countries;

  /// Inclusive bounds, compared as numbers.
  final String? minVersion;
  final String? maxVersion;

  /// Per language code: title, body, button and fallback.
  final Map<String, Map<String, dynamic>> texts;

  static Notice? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sentAt = _time(json['sent_at']);
    final endsAt = _time(json['ends_at']);
    final texts = json['texts'];
    if (id is! int || sentAt == null || endsAt == null || texts is! Map) {
      return null;
    }
    final link = json['link'];
    final low = json['min_version'];
    final high = json['max_version'];
    return Notice(
      id: id,
      sentAt: sentAt,
      endsAt: endsAt,
      link: link is String && link.isNotEmpty ? link : null,
      countries: [
        for (final c in json['countries'] as List? ?? const [])
          if (c is String && c.length == 2) c.toUpperCase(),
      ],
      minVersion: low is String && low.isNotEmpty ? low : null,
      maxVersion: high is String && high.isNotEmpty ? high : null,
      texts: {
        for (final e in texts.entries)
          if (e.key is String && e.value is Map)
            e.key as String: (e.value as Map).cast<String, dynamic>(),
      },
    );
  }

  /// Whether this notice is for a phone in [country] running [version],
  /// by the rule the backend uses for its own answers: in one of its
  /// countries when it names any, inside its version bounds when it has
  /// any. A phone whose country or version is not known is left out of a
  /// notice that names countries or versions. A bound that does not parse
  /// is no bound, as on the backend.
  bool reaches({String? country, String? version}) {
    if (countries.isNotEmpty &&
        (country == null || !countries.contains(country.toUpperCase()))) {
      return false;
    }
    final low = _bound(minVersion);
    final high = _bound(maxVersion);
    if (low == null && high == null) return true;
    if (!_parses(version)) return false;
    return (low == null || UpdateCheck.compare(version, low)! >= 0) &&
        (high == null || UpdateCheck.compare(version, high)! <= 0);
  }

  static bool _parses(String? version) =>
      UpdateCheck.compare(version, version) != null;

  static String? _bound(String? version) => _parses(version) ? version : null;

  /// The notice in language [code], the way the backend would serve it
  /// (`served` there): that language's text, else English. A language the
  /// team chose to show in English says `en`. Null when there is no text
  /// to show.
  InAppMessage? inLanguage(String code) {
    var language = code;
    var text = texts[code];
    if (text == null) {
      text = texts['en'];
      language = 'en';
    }
    if (text == null) return null;
    if (text['fallback'] == true) language = 'en';
    final button = text['button'];
    final hasButton = button is String && button.trim().isNotEmpty;
    return InAppMessage.tryParse({
      'id': id,
      'language': language,
      'title': text['title'] is String ? text['title'] : '',
      'body': text['body'],
      'button': hasButton && link != null ? button : null,
      'link': hasButton ? link : null,
      'sent_at': sentAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
    });
  }

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// The notices file, opened: the broadcast messages, for a phone that
/// cannot reach the backend.
///
/// Published next to the fallback file (data/notices.txt beside
/// data/index.txt) on the same public hosts, sealed and signed the same way
/// with the same keys, under its own [context] so neither file can stand in
/// for the other ([openSealed]).
class NoticesFile {
  const NoticesFile({
    required this.issuedAt,
    required this.notices,
    required this.text,
  });

  static const context = 'fortiva-notices/1';

  /// When the backend built it, on the backend's clock.
  final DateTime issuedAt;

  /// Newest first, as the backend listed them.
  final List<Notice> notices;

  /// The line as it was read, so it can be saved and opened again.
  final String text;

  static Future<NoticesFile?> open(
    String text, {
    required List<int> publicKey,
    required List<int> sealKey,
  }) async {
    final json = await openSealed(
      text,
      context: context,
      publicKey: publicKey,
      sealKey: sealKey,
    );
    if (json == null) return null;
    final seconds = json['issued_at'];
    final list = json['notices'];
    if (seconds is! int || list is! List) return null;
    return NoticesFile(
      issuedAt: DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ),
      notices: [for (final n in list) ?Notice.fromJson(n)],
      text: text.trim(),
    );
  }

  /// The notices for this phone that run at [now], as messages in
  /// [language], newest first.
  List<InAppMessage> forPhone({
    required String language,
    required DateTime now,
    String? country,
    String? version,
  }) => [
    for (final n in notices)
      if (n.endsAt.isAfter(now) &&
          n.reaches(country: country, version: version))
        ?n.inLanguage(language),
  ];
}

/// Reads the notices file ([NoticesFile]) from the public hosts and keeps
/// the newest one that opens.
///
/// Only when the backend cannot be reached: a phone that reaches it gets
/// every message there, and its own as well. Each read is one request to
/// each host, from a phone that may share its address with many others
/// behind its carrier's NAT, so reads are spaced out ([freshFor],
/// [quietAfterNothing]), and GitHub's API, which allows 60 reads an hour
/// per address, is read only when no other host gave a file.
class NoticesReader {
  NoticesReader({
    required List<String> Function() indexUrls,
    http.Client Function()? client,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
    List<int>? publicKey,
    List<int>? sealKey,
    Duration grace = Bootstrap.grace,
  }) : _indexUrls = indexUrls,
       _client = client ?? http.Client.new,
       _prefs = prefs ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _publicKey = publicKey ?? Bootstrap.publicKey,
       _sealKey = sealKey ?? Bootstrap.sealKey,
       _grace = grace;

  static const savedKey = 'notices_file';
  static const readAtKey = 'notices_file_read_at';
  static const quietUntilKey = 'notices_file_quiet_until';
  static const apiReadAtKey = 'notices_file_api_read_at';

  /// No new read this long after one that got a file. A little under the
  /// backend's 10 minute rebuild, so a phone that checks every 10 minutes
  /// reads every new file. jsDelivr is told to drop its copy each time the
  /// file changes.
  static const freshFor = Duration(minutes: 9);

  /// No new read this long after one that found no file anywhere.
  static const quietAfterNothing = Duration(minutes: 5);

  /// GitHub's API allows 60 reads an hour per address, shared by every
  /// phone behind the same carrier address, so it is read at most this
  /// often, and only when no other host gave a file.
  static const apiFreshFor = Duration(minutes: 30);

  /// The biggest answer read as a file. Five notices in every language,
  /// sealed, come to well under this.
  static const maxBytes = 512 * 1024;

  final List<String> Function() _indexUrls;
  final http.Client Function() _client;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final List<int> _publicKey;
  final List<int> _sealKey;
  final Duration _grace;

  /// Where the notices file is, for each place the fallback file is: the
  /// same path with notices.txt for index.txt. A place whose path does not
  /// end in index.txt has no notices file beside it.
  static List<String> urlsFrom(Iterable<String> indexUrls) => [
    for (final url in indexUrls)
      if (url.endsWith('/index.txt'))
        '${url.substring(0, url.length - 'index.txt'.length)}notices.txt',
  ];

  /// The newest file this phone has: read now from the hosts unless one was
  /// read lately, else the one saved by an earlier read. Null when there is
  /// neither. Never throws.
  Future<NoticesFile?> read() async {
    try {
      final prefs = await _prefs();
      final saved = await _open(prefs.getString(savedKey));
      final now = _now().toUtc();
      final readAt = DateTime.tryParse(prefs.getString(readAtKey) ?? '');
      final quietUntil = DateTime.tryParse(
        prefs.getString(quietUntilKey) ?? '',
      );
      final recent =
          readAt != null &&
          !readAt.isAfter(now) &&
          now.difference(readAt) < freshFor;
      final quiet = quietUntil != null && now.isBefore(quietUntil);
      if (recent || quiet) return saved;

      final urls = urlsFrom(_indexUrls());
      bool isApi(String u) => Uri.tryParse(u)?.host == 'api.github.com';
      var found = await _readAll(urls.where((u) => !isApi(u)).toList());
      if (found == null) {
        final apiAt = DateTime.tryParse(prefs.getString(apiReadAtKey) ?? '');
        final apiRecent =
            apiAt != null &&
            !apiAt.isAfter(now) &&
            now.difference(apiAt) < apiFreshFor;
        final api = urls.where(isApi).toList();
        if (!apiRecent && api.isNotEmpty) {
          await prefs.setString(apiReadAtKey, now.toIso8601String());
          found = await _readAll(api);
        }
      }
      if (found == null) {
        await prefs.setString(
          quietUntilKey,
          now.add(quietAfterNothing).toIso8601String(),
        );
        return saved;
      }
      await prefs.setString(readAtKey, now.toIso8601String());
      if (saved != null && !found.issuedAt.isAfter(saved.issuedAt)) {
        return saved;
      }
      await prefs.setString(savedKey, found.text);
      return found;
    } catch (e) {
      debugPrint('NoticesReader: could not read the notices file ($e)');
      return null;
    }
  }

  Future<NoticesFile?> _open(String? text) async => text == null
      ? null
      : NoticesFile.open(text, publicKey: _publicKey, sealKey: _sealKey);

  /// Read [urls] all at once. Once one has given a file that opens, the
  /// others have [_grace] to give a newer one: a CDN can hold an older
  /// copy.
  Future<NoticesFile?> _readAll(List<String> urls) async {
    if (urls.isEmpty) return null;
    final client = _client();
    final done = Completer<void>();
    var left = urls.length;
    Timer? graceTimer;
    NoticesFile? best;
    for (final url in urls) {
      unawaited(
        _readOne(client, url)
            .then((opened) {
              if (opened == null) return;
              if (best == null || opened.issuedAt.isAfter(best!.issuedAt)) {
                best = opened;
              }
              graceTimer ??= Timer(_grace, () {
                if (!done.isCompleted) done.complete();
              });
            })
            .whenComplete(() {
              if (--left == 0 && !done.isCompleted) done.complete();
            }),
      );
    }
    await done.future;
    graceTimer?.cancel();
    client.close();
    return best;
  }

  Future<NoticesFile?> _readOne(http.Client client, String url) async {
    try {
      final response = await client
          .get(Uri.parse(url), headers: Bootstrap.headersFor(url))
          .timeout(Bootstrap.readTimeout);
      if (response.statusCode != 200 || response.bodyBytes.length > maxBytes) {
        return null;
      }
      return await _open(utf8.decode(response.bodyBytes, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }
}
