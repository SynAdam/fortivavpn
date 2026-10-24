import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant, Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/bootstrap.dart';
import '../api/device_identity.dart';
import '../api/message_service.dart';
import '../api/notices_file.dart';
import '../core/state/locale_state.dart';
import '../core/state/message_state.dart';
import '../data/models/in_app_message.dart';
import '../l10n/generated/app_localizations.dart';
import 'notice_channel.dart';
import 'vpn_event_reporter.dart';

/// The background check for messages, started by NoticeJobService on
/// Android with no screen. Runs one [NoticePull] and tells the service it
/// is done, whatever happens.
@pragma('vm:entry-point')
Future<void> noticePullMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await ApiConfig.readAppBuild();
    // The relays the fallback file named, which the calls below try after
    // the direct route. Read from what earlier runs saved; nothing here
    // reads the fallback file from the hosts.
    await Bootstrap.instance.restore();
    ApiClient.tunnelSocksPort = NoticeChannel.socksPort;
    await NoticePull().run().timeout(NoticePull.budget);
  } catch (e) {
    debugPrint('NoticePull: the check failed ($e)');
  } finally {
    await NoticeChannel.done();
  }
}

/// Where one check got its messages.
enum NoticeSource {
  /// Nowhere: neither the backend nor any host answered.
  none,

  /// The backend, directly, through the tunnel or through a relay.
  backend,

  /// The public notices file ([NoticesFile]).
  file,
}

/// One check for messages from the Fortiva team with the app off screen,
/// and a notification for the newest one the user has not seen.
///
/// Three ways to the messages, the first that answers wins:
///
/// 1. the backend, the same call the app makes on launch
///    ([MessageService.fetch]), through every route [ApiClient] has: the
///    tunnel while one is up, the phone's own network, the relays;
/// 2. the notices file on the public hosts ([NoticesReader]), which holds
///    only the messages that go to everyone, countries or versions;
/// 3. nothing: what was seen stays seen, and the next check tries again.
///
/// A message gets a notification once, ever, and only when it has not
/// popped up or been read in the app, is newer than anything that did, and
/// is in the language the app is set to, the same rules as the in-app
/// popup (MessageState.pendingPopup). One notification per check, the
/// newest; anything older waits in the inbox. Receipts (received, shown)
/// are kept here and sent the next time a check reaches the backend.
///
/// Never registers the phone and never makes it an id: a check before the
/// app has registered reads the public file only. Nothing it does can
/// throw out of [run].
class NoticePull {
  NoticePull({
    Future<SharedPreferences> Function()? prefs,
    Future<String?> Function()? deviceId,
    MessagesFetch? fetch,
    ReceiptsPost? post,
    Future<NoticesFile?> Function()? readFile,
    Future<String?> Function()? country,
    String? Function()? version,
    Future<bool> Function(InAppMessage message, String language)? show,
    DateTime Function()? clock,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _deviceId = deviceId ?? DeviceIdentity.instance.existing,
       _fetch =
           fetch ??
           ((id, lang) => MessageService().fetch(id, lang, background: true)),
       _post = post ?? MessageService().sendReceipts,
       _readFile =
           readFile ??
           NoticesReader(indexUrls: () => Bootstrap.instance.mirrors).read,
       _country = country ?? NoticeChannel.country,
       _version = version ?? (() => ApiConfig.appVersion),
       _show = show ?? _notify,
       _clock = clock ?? DateTime.now;

  /// The longest one check takes before it gives up. Short, because Android
  /// gives a background app only so much running time a day, and Google
  /// Play flags an app whose background work keeps the phone awake for
  /// hours. The service stops the engine 30 s after this in any case.
  static const budget = Duration(seconds: 60);

  /// How long the backend gets, over all its routes, before the public
  /// file is read instead. Each route that does not answer costs 10 s, so
  /// this covers the direct route and one or two more.
  static const backendBudget = Duration(seconds: 25);

  /// When the backend last failed a background check.
  static const backendFailedKey = 'notices_backend_failed_at';

  /// How long a failure counts: the next checks read the file at once and
  /// give the backend [retryBudget].
  static const failureMemory = Duration(minutes: 30);
  static const retryBudget = Duration(seconds: 12);

  /// When a background check last ran, whatever it found. The Messages
  /// screen offers the phone's battery settings when this is old
  /// (BackgroundCard), because then something on the phone stops the
  /// checks.
  static const lastCheckKey = 'notices_last_check_at';

  /// What the checks learned: the server time and the messages, for the
  /// app to show when the backend is out of its reach (MessageState).
  static const foundKey = 'notices_found';

  /// Messages that got a notification, with when each one ends.
  static const notifiedKey = 'notices_notified';

  /// The send time of the newest message that got a notification. Nothing
  /// older gets one after it.
  static const lastNotifiedKey = 'notices_last_sent_at';

  /// `id:kind` pairs already queued, with when the message ends.
  static const reportedKey = 'notices_reported';

  /// Receipts waiting to be sent.
  static const receiptsKey = 'notices_receipts';

  /// The keys about this account's messages, cleared when it is deleted.
  /// The saved notices file stays (AccountService.keptPrefKeys).
  static const keys = [
    foundKey,
    notifiedKey,
    lastNotifiedKey,
    reportedKey,
    receiptsKey,
  ];

  static const maxQueued = MessageState.maxQueued;
  static const batchSize = MessageState.batchSize;

  final Future<SharedPreferences> Function() _prefs;
  final Future<String?> Function() _deviceId;
  final MessagesFetch _fetch;
  final ReceiptsPost _post;
  final Future<NoticesFile?> Function() _readFile;
  final Future<String?> Function() _country;
  final String? Function() _version;
  final Future<bool> Function(InAppMessage message, String language) _show;
  final DateTime Function() _clock;

  /// Run one check. Returns where the messages came from and the id of the
  /// message that got a notification, if one did. Never throws.
  Future<({NoticeSource source, int? notified})> run() async {
    const nothing = (source: NoticeSource.none, notified: null);
    try {
      final prefs = await _prefs();
      await prefs.setString(lastCheckKey, _clock().toUtc().toIso8601String());
      final language = _string(prefs, LocaleState.prefKey);
      // The app asks for a language before anything else, and a message in
      // the wrong one would be the first thing the user sees of us.
      if (language == null ||
          !LocaleState.supportedLanguages.containsKey(language)) {
        return nothing;
      }

      final id = await _deviceId();
      List<InAppMessage>? messages;
      DateTime? now;
      var source = NoticeSource.none;
      // Each check starts afresh, so it would wait out the whole budget on a
      // backend that failed minutes ago. After a failure, the public file is
      // read at the same time and the backend gets less time.
      final failedAt = _time(_string(prefs, backendFailedKey));
      final failedLately =
          failedAt != null &&
          !failedAt.isAfter(_clock().toUtc()) &&
          _clock().toUtc().difference(failedAt) < failureMemory;
      final fileRead = failedLately ? _readFile() : null;
      if (id != null) {
        try {
          final page = await _fetch(
            id,
            language,
          ).timeout(failedLately ? retryBudget : backendBudget);
          messages = page.messages;
          now = page.serverTime ?? _clock().toUtc();
          source = NoticeSource.backend;
          await prefs.remove(backendFailedKey);
        } catch (e) {
          debugPrint('NoticePull: the backend did not answer ($e)');
          await prefs.setString(
            backendFailedKey,
            _clock().toUtc().toIso8601String(),
          );
        }
      }
      if (messages == null) {
        final file = await (fileRead ?? _readFile());
        if (file == null) return nothing;
        // The file's build time is on the backend's clock. A phone whose
        // clock is behind it would show a notice past its end.
        final phone = _clock().toUtc();
        now = phone.isBefore(file.issuedAt) ? file.issuedAt : phone;
        messages = file.forPhone(
          language: language,
          now: now,
          country: await _country(),
          version: _version(),
        );
        source = NoticeSource.file;
      }

      await _keepFound(prefs, messages, now!);
      final pick = _pick(prefs, messages, language, now);
      int? notified;
      if (pick != null && await _show(pick, language)) {
        notified = pick.id;
        await _noteNotified(prefs, pick, now);
      }
      await _queue(prefs, messages, notified == null ? null : pick, now);
      if (source == NoticeSource.backend) await _flush(prefs, id!);
      return (source: source, notified: notified);
    } catch (e) {
      debugPrint('NoticePull: check failed ($e)');
      return nothing;
    }
  }

  /// Keep what this check learned, for the app to merge into its list.
  Future<void> _keepFound(
    SharedPreferences prefs,
    List<InAppMessage> messages,
    DateTime now,
  ) async {
    await prefs.setString(
      foundKey,
      jsonEncode({
        'at': now.toIso8601String(),
        'messages': [
          for (final m in messages)
            if (m.endsAt.isAfter(now)) m.toJson(),
        ],
      }),
    );
  }

  /// The newest message that may get a notification, or null.
  InAppMessage? _pick(
    SharedPreferences prefs,
    List<InAppMessage> messages,
    String language,
    DateTime now,
  ) {
    final seen = {
      ..._stamps(prefs, notifiedKey, now).keys,
      ..._stamps(prefs, MessageState.poppedKey, now).keys,
      ..._stamps(prefs, MessageState.readKey, now).keys,
    };
    final after = _later(
      _time(_string(prefs, lastNotifiedKey)),
      _time(_string(prefs, MessageState.lastPoppedKey)),
    );
    InAppMessage? newest;
    for (final m in messages) {
      if (seen.contains('${m.id}')) continue;
      if (!m.endsAt.isAfter(now) || m.language != language) continue;
      if (after != null && !m.sentAt.isAfter(after)) continue;
      if (newest == null || m.sentAt.isAfter(newest.sentAt)) newest = m;
    }
    return newest;
  }

  Future<void> _noteNotified(
    SharedPreferences prefs,
    InAppMessage message,
    DateTime now,
  ) async {
    final notified = _stamps(prefs, notifiedKey, now)
      ..['${message.id}'] = message.endsAt;
    await prefs.setString(notifiedKey, _encodeStamps(notified, now));
    final last = _time(_string(prefs, lastNotifiedKey));
    if (last == null || message.sentAt.isAfter(last)) {
      await prefs.setString(lastNotifiedKey, message.sentAt.toIso8601String());
    }
  }

  /// Queue `received` for every message this check got and `shown` for
  /// the one that got a notification, each once per message. With
  /// diagnostics sharing off nothing is queued and the queue is cleared,
  /// as for the app's own receipts.
  Future<void> _queue(
    SharedPreferences prefs,
    List<InAppMessage> messages,
    InAppMessage? shown,
    DateTime now,
  ) async {
    if (prefs.get(VpnEventReporter.sharePrefKey) == false) {
      await prefs.remove(receiptsKey);
      return;
    }
    final reported = _stamps(prefs, reportedKey, now);
    final queue = _loadQueue(prefs);
    final at = _clock().toUtc().toIso8601String();
    void add(InAppMessage m, ReceiptKind kind) {
      final pair = '${m.id}:${kind.name}';
      if (reported.containsKey(pair)) return;
      reported[pair] = m.endsAt;
      queue.add({
        'message_id': m.id,
        'kind': kind.name,
        'at': at,
        'language': m.language,
      });
    }

    for (final m in messages) {
      add(m, ReceiptKind.received);
    }
    if (shown != null) add(shown, ReceiptKind.shown);
    while (queue.length > maxQueued) {
      queue.removeAt(0);
    }
    await prefs.setString(reportedKey, _encodeStamps(reported, now));
    await prefs.setString(receiptsKey, jsonEncode(queue));
  }

  /// Send the queued receipts in batches, oldest first. Stops at the first
  /// batch that fails and keeps the rest; a batch the backend can never
  /// take (413, 422) is dropped. Never registers the phone on a 404.
  Future<void> _flush(SharedPreferences prefs, String deviceId) async {
    if (prefs.get(VpnEventReporter.sharePrefKey) == false) {
      await prefs.remove(receiptsKey);
      return;
    }
    var queue = _loadQueue(prefs);
    while (queue.isNotEmpty) {
      final batch = queue.take(batchSize).toList();
      try {
        await _post(deviceId, {
          'receipts': batch,
          'sent_at': _clock().toUtc().toIso8601String(),
        });
      } on ApiException catch (e) {
        if (e.statusCode != 413 && !e.isValidationError) return;
        debugPrint('NoticePull: backend refused receipts, dropped ($e)');
      } catch (e) {
        debugPrint('NoticePull: receipts not sent, kept ($e)');
        return;
      }
      queue = queue.sublist(batch.length);
      if (queue.isEmpty) {
        await prefs.remove(receiptsKey);
      } else {
        await prefs.setString(receiptsKey, jsonEncode(queue));
      }
    }
  }

  /// Post the notification, titled and with its channel named in the
  /// app's language.
  static Future<bool> _notify(InAppMessage message, String language) async {
    S? s;
    try {
      s = lookupS(Locale(language));
    } catch (_) {
      s = null;
    }
    return NoticeChannel.show(
      id: message.id,
      title: message.title.isNotEmpty ? message.title : 'Fortiva',
      body: message.body,
      channelName: s?.noticeChannelName ?? 'Messages from Fortiva',
      channelDescription:
          s?.noticeChannelDescription ?? 'News and messages from the team',
    );
  }

  static String? _string(SharedPreferences prefs, String key) {
    try {
      final value = prefs.get(key);
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  static DateTime? _time(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toUtc();

  static DateTime? _later(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  /// A stored map of name to end time, as MessageState keeps them, without
  /// what has ended. Anything unreadable counts as empty.
  static Map<String, DateTime> _stamps(
    SharedPreferences prefs,
    String key,
    DateTime now,
  ) {
    final raw = _string(prefs, key);
    if (raw == null || raw.isEmpty) return {};
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return {};
    }
    if (decoded is! Map) return {};
    final stamps = <String, DateTime>{};
    decoded.forEach((name, end) {
      final at = end is String ? DateTime.tryParse(end)?.toUtc() : null;
      if (name is String && at != null && at.isAfter(now)) stamps[name] = at;
    });
    return stamps;
  }

  static String _encodeStamps(Map<String, DateTime> stamps, DateTime now) =>
      jsonEncode({
        for (final e in stamps.entries)
          if (e.value.isAfter(now)) e.key: e.value.toIso8601String(),
      });

  static List<Map<String, dynamic>> _loadQueue(SharedPreferences prefs) {
    final raw = _string(prefs, receiptsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final r in decoded)
          if (r is Map && r['message_id'] is int && r['kind'] is String)
            r.cast<String, dynamic>(),
      ];
    } catch (_) {
      return [];
    }
  }
}
