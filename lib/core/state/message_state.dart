import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../api/device_identity.dart';
import '../../api/device_service.dart';
import '../../api/message_service.dart';
import '../../data/models/in_app_message.dart';
import '../../services/notice_pull.dart';
import '../../services/stored_from_background.dart';
import '../../services/vpn_event_reporter.dart';
import 'locale_state.dart';

/// What the app tells the backend about one message. Each is sent at most
/// once per message. The names are the wire values.
enum ReceiptKind { received, shown, clicked, dismissed }

/// Fetches the messages for a device in one language.
typedef MessagesFetch =
    Future<MessagesPage> Function(String deviceId, String lang);

/// Posts one batch of receipts for a device.
typedef ReceiptsPost =
    Future<void> Function(String deviceId, Map<String, dynamic> body);

/// The messages the Fortiva team sent to this phone, and what the phone
/// reports back about them.
///
/// Nothing here may get in the way of connecting. Every call is started
/// without awaiting it, every failure (network, a bad answer, a bug in this
/// file) is caught and logged, and nothing here touches the tunnel, the
/// config, the update check or the session history. A phone that cannot
/// reach us keeps the last list it got.
///
/// The server filters the list by country and version, so the list is
/// shown as it arrives. The phone's clock is only trusted after it has
/// been corrected by the gap to the server's clock, because some phones'
/// clocks are hours or days off and a message would then expire early or
/// never.
class MessageState extends ChangeNotifier {
  MessageState({
    MessagesFetch? fetch,
    ReceiptsPost? post,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    Future<bool> Function()? sharing,
    String Function()? language,
    bool Function()? languageChosen,
    DateTime Function()? clock,
    Future<SharedPreferences> Function()? prefs,
    this.flushDelay = const Duration(seconds: 10),
  }) : _fetch = fetch ?? MessageService().fetch,
       _post = post ?? MessageService().sendReceipts,
       _deviceId = deviceId ?? DeviceIdentity.instance.resolve,
       _register =
           register ?? (() async => await DeviceService().registerDevice()),
       _sharingCheck = sharing,
       _language = language ?? (() => appLanguage(null)),
       _languageChosen = languageChosen ?? (() => true),
       _clock = clock ?? DateTime.now,
       _prefs = prefs ?? SharedPreferences.getInstance {
    _loaded = _load();
  }

  /// The last list that arrived, and the gap between the server's clock
  /// and the phone's when it did.
  static const cacheKey = 'in_app_messages_cache';

  /// Messages that were shown as a popup, with when each one ends.
  static const poppedKey = 'in_app_messages_popped';

  /// Messages seen in the inbox, with when each one ends.
  static const readKey = 'in_app_messages_read';

  /// `id:kind` pairs already queued, with when the message ends, so each
  /// receipt is sent once.
  static const reportedKey = 'in_app_messages_reported';

  /// Receipts waiting to be sent.
  static const receiptsKey = 'in_app_messages_receipts';

  /// The send time of the newest message that popped up. Nothing older
  /// pops up after it.
  static const lastPoppedKey = 'in_app_messages_last_popped_sent_at';

  /// A check sooner than this after a good one is skipped unless forced.
  static const freshFor = Duration(minutes: 5);

  static const maxQueued = 200;
  static const batchSize = 50; // what the backend accepts in one batch

  /// How long after the last new receipt the queue is sent, so a message
  /// that is received, shown and closed in quick succession goes as one
  /// batch.
  final Duration flushDelay;

  final MessagesFetch _fetch;
  final ReceiptsPost _post;
  final Future<String> Function() _deviceId;
  final Future<void> Function() _register;
  final Future<bool> Function()? _sharingCheck;
  final String Function() _language;
  final bool Function() _languageChosen;
  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _prefs;

  late final Future<void> _loaded;

  List<InAppMessage> _list = const [];

  /// The list from a check made by this run of the app, or null before
  /// one has worked. Only these may pop up: a saved list can be days old,
  /// and a popup about something the team sent last week is noise.
  List<InAppMessage>? _fresh;

  Duration _offset = Duration.zero;

  /// When the list was current, on the server's clock: the time of the
  /// check that brought it. What the background check found is taken up
  /// only when it is newer ([adoptBackground]).
  DateTime? _listAt;

  /// Messages that got a notification while the app was off screen
  /// (NoticePull), with when each one ends. They do not pop up as well.
  Map<String, DateTime> _notified = {};

  /// The language of the last check started, so a change is noticed.
  String? _askedLanguage;
  DateTime? _lastSuccess;
  bool _lastAttemptFailed = false;
  bool _fetching = false;
  bool _fetchAgain = false;

  Map<String, DateTime> _popped = {};
  Map<String, DateTime> _read = {};
  DateTime? _lastPoppedSentAt;
  bool _poppedThisRun = false;

  Timer? _flushTimer;
  Future<void>? _flushing;

  /// Bumped by [reset]. A fetch or a send that started before it drops
  /// what it gets back, because it belongs to an account that is gone.
  int _generation = 0;
  bool _disposed = false;

  /// Every change to the stored receipts runs through this, one at a time,
  /// the same way VpnEventReporter guards its queue: a receipt queued while
  /// a batch was in flight would otherwise be written over by the flush.
  /// Per instance, because the app holds one MessageState.
  Future<void> _queueLock = Future.value();

  Future<T> _serialized<T>(Future<T> Function() body) {
    final run = _queueLock.then((_) => body());
    _queueLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// The language the app is showing: the one the user chose, else the
  /// phone's when the app has it, else English. Messages are fetched in
  /// this language, and only a message in it may pop up.
  static String appLanguage(Locale? chosen, [Locale? system]) {
    const supported = LocaleState.supportedLanguages;
    final code = chosen?.languageCode;
    if (code != null && supported.containsKey(code)) return code;
    Locale? phone = system;
    if (phone == null) {
      try {
        phone = PlatformDispatcher.instance.locale;
      } catch (_) {}
    }
    final phoneCode = phone?.languageCode;
    if (phoneCode != null && supported.containsKey(phoneCode)) {
      return phoneCode;
    }
    return 'en';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// The phone's clock moved by the gap to the server's.
  DateTime _serverNow() => _clock().toUtc().add(_offset);

  /// The messages to list, newest first as the server sent them, without
  /// those that have ended.
  List<InAppMessage> get messages {
    final now = _serverNow();
    return [
      for (final m in _list)
        if (m.endsAt.isAfter(now)) m,
    ];
  }

  /// Listed messages the user has neither seen in the inbox nor had pop up.
  int get unreadCount => messages
      .where(
        (m) => !_read.containsKey('${m.id}') && !_popped.containsKey('${m.id}'),
      )
      .length;

  /// Whether the last check failed. The next connect then checks again
  /// at once, because a phone often reaches us only through the tunnel.
  bool get lastAttemptFailed => _lastAttemptFailed;

  /// The message to pop up now, or null.
  ///
  /// At most one per run of the app, only from a list this run fetched,
  /// never one already seen, never one older than the last that popped up,
  /// and only one written in the language the app is showing: a popup in
  /// another language than the rest of the screen reads like a mistake. A
  /// message that does not pop up still waits in the inbox.
  /// Whether a message has popped up in this run. One popup per run: the
  /// rating card does not follow a message.
  bool get poppedThisRun => _poppedThisRun;

  InAppMessage? get pendingPopup {
    final fresh = _fresh;
    if (_poppedThisRun || fresh == null) return null;
    final now = _serverNow();
    final language = _language();
    final after = _lastPoppedSentAt;
    InAppMessage? newest;
    for (final m in fresh) {
      if (_popped.containsKey('${m.id}') ||
          _read.containsKey('${m.id}') ||
          _notified.containsKey('${m.id}')) {
        continue;
      }
      if (after != null && !m.sentAt.isAfter(after)) continue;
      if (!m.endsAt.isAfter(now) || m.language != language) continue;
      if (newest == null || m.sentAt.isAfter(newest.sentAt)) newest = m;
    }
    return newest;
  }

  /// Check for messages. Never throws.
  ///
  /// Waits until the user has chosen the app language, because a message
  /// fetched in the wrong one would be the first thing they see. Skipped
  /// within [freshFor] of a good check unless [force]d. One check runs at a
  /// time; a forced call during one runs one more check after it, so what
  /// the caller wanted to see is not missed. A change of app language
  /// counts as forced.
  Future<void> refresh({bool force = false}) async {
    try {
      if (_disposed || !_languageChosen()) return;
      if (_language() != _askedLanguage) force = true;
      if (_fetching) {
        if (force) _fetchAgain = true;
        return;
      }
      final last = _lastSuccess;
      if (!force && last != null && _clock().difference(last) < freshFor) {
        return;
      }
      _fetching = true;
      final generation = _generation;
      try {
        do {
          _fetchAgain = false;
          _askedLanguage = _language();
          await _fetchOnce(generation, _askedLanguage!);
        } while (_fetchAgain && generation == _generation && !_disposed);
      } finally {
        if (generation == _generation) _fetching = false;
      }
    } catch (e) {
      debugPrint('MessageState: could not check for messages ($e)');
    }
  }

  Future<void> _fetchOnce(int generation, String lang) async {
    try {
      await _loaded;
      MessagesPage page;
      try {
        page = await _fetch(await _deviceId(), lang);
      } on ApiException catch (e) {
        if (!e.isNotFound) rethrow;
        // A reset since this check started means the account was deleted,
        // and registering now would bring its device back.
        if (generation != _generation) return;
        // The backend has never seen this device. Register it and ask
        // once more, under the id the register used.
        await _register();
        if (generation != _generation) return;
        page = await _fetch(await _deviceId(), lang);
      }
      if (generation != _generation || _disposed) return;

      final phoneNow = _clock().toUtc();
      final serverTime = page.serverTime;
      _offset = serverTime == null
          ? Duration.zero
          : serverTime.difference(phoneNow);
      _list = List.unmodifiable(page.messages);
      _fresh = _list;
      _listAt = serverTime ?? phoneNow;
      _lastSuccess = _clock();
      _lastAttemptFailed = false;
      _notify();

      await _saveCache(generation);
      for (final m in _list) {
        if (generation != _generation) return;
        await _report(m, ReceiptKind.received, generation);
      }
      // Receipts left over from a check that could not send them.
      _scheduleFlush();
    } catch (e) {
      if (generation != _generation) return;
      // The saved list stays: a 503 or a cut network says nothing about
      // which messages are current.
      _lastAttemptFailed = true;
      debugPrint('MessageState: check for messages failed ($e)');
    }
  }

  /// Take up what the background check for messages (NoticePull) learned
  /// while the app was off screen: the messages it got, when they are newer
  /// than this list, and which of them got a notification. Called on launch
  /// and resume, before a check of the app's own, and when a notification
  /// is tapped. The background check writes from another engine, so its
  /// values are read again first. Never throws.
  Future<void> adoptBackground() async {
    try {
      await _loaded;
      final prefs = await _prefs();
      // Only these keys: a reload of every stored value dropped what this
      // engine saved meanwhile (StoredFromBackground).
      await StoredFromBackground.refresh(prefs, const [
        NoticePull.notifiedKey,
        NoticePull.foundKey,
      ]);
      _notified = _stamps(prefs, NoticePull.notifiedKey);
      final found = _decode(prefs, NoticePull.foundKey);
      if (found is Map) {
        final at = found['at'] is String
            ? DateTime.tryParse(found['at'] as String)?.toUtc()
            : null;
        final listAt = _listAt;
        final list = found['messages'];
        if (at != null &&
            list is List &&
            (listAt == null || at.isAfter(listAt))) {
          final known = {for (final m in _list) m.id};
          final added = [
            for (final e in list) ?InAppMessage.tryParse(e),
          ].where((m) => !known.contains(m.id)).toList();
          if (added.isNotEmpty) {
            _list = List.unmodifiable(
              [...added, ..._list]
                ..sort((a, b) => b.sentAt.compareTo(a.sentAt)),
            );
          }
        }
      }
      _notify();
    } catch (e) {
      debugPrint('MessageState: could not read the background check ($e)');
    }
  }

  /// The listed message with [id], ended or not, or null.
  InAppMessage? byId(int id) => _find(id);

  /// Mark every listed message as seen. Called when the inbox opens.
  Future<void> markAllRead() async {
    try {
      final unseen = messages.where((m) => !_read.containsKey('${m.id}'));
      if (unseen.isEmpty) return;
      for (final m in unseen.toList()) {
        _read['${m.id}'] = m.endsAt;
      }
      _notify();
      final generation = _generation;
      final read = _encodeStamps(_read);
      await _serialized(() async {
        if (generation != _generation) return;
        final prefs = await _prefs();
        await prefs.setString(readKey, read);
      });
    } catch (e) {
      debugPrint('MessageState: could not save what was read ($e)');
    }
  }

  /// Record that message [id] popped up, so it does not again, and nothing
  /// sent before it does either.
  Future<void> markPopped(int id) async {
    _poppedThisRun = true;
    try {
      final message = _find(id);
      if (message != null) {
        _popped['$id'] = message.endsAt;
        final last = _lastPoppedSentAt;
        if (last == null || message.sentAt.isAfter(last)) {
          _lastPoppedSentAt = message.sentAt;
        }
      }
      _notify();
      if (message != null) await _savePopped();
    } catch (e) {
      debugPrint('MessageState: could not save the popup ($e)');
    }
  }

  /// Undo [markPopped] for a popup the app closed before the user could
  /// read it, so it counts as unread in the inbox. It does not pop up
  /// again: the time of the last popup stays.
  Future<void> returnToInbox(int id) async {
    try {
      if (_popped.remove('$id') == null) return;
      _notify();
      await _savePopped();
    } catch (e) {
      debugPrint('MessageState: could not save the popup ($e)');
    }
  }

  Future<void> _savePopped() async {
    final generation = _generation;
    final popped = _encodeStamps(_popped);
    final last = _lastPoppedSentAt?.toIso8601String();
    await _serialized(() async {
      if (generation != _generation) return;
      final prefs = await _prefs();
      await prefs.setString(poppedKey, popped);
      if (last != null) await prefs.setString(lastPoppedKey, last);
    });
  }

  InAppMessage? _find(int id) {
    for (final m in [...?_fresh, ..._list]) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Queue one receipt and send the queue a little later. Never throws.
  ///
  /// Follows the diagnostics switch in Settings, like the connection
  /// reports: with it off nothing is queued.
  Future<void> report(InAppMessage message, ReceiptKind kind) =>
      _report(message, kind, _generation);

  /// [report] for the account of [generation]. Read before any await, so a
  /// receipt that was on its way when [reset] ran is dropped rather than
  /// queued for the next account.
  Future<void> _report(
    InAppMessage message,
    ReceiptKind kind,
    int generation,
  ) async {
    try {
      if (!await _sharing()) return;
      final added = await _serialized(() async {
        if (generation != _generation) return false;
        final prefs = await _prefs();
        final reported = _stamps(prefs, reportedKey);
        final pair = '${message.id}:${kind.name}';
        if (reported.containsKey(pair)) return false;
        reported[pair] = message.endsAt;
        final queue = _loadQueue(prefs)
          ..add({
            'message_id': message.id,
            'kind': kind.name,
            'at': _clock().toUtc().toIso8601String(),
            'language': message.language,
          });
        while (queue.length > maxQueued) {
          queue.removeAt(0);
        }
        await prefs.setString(reportedKey, _encodeStamps(reported));
        await prefs.setString(receiptsKey, jsonEncode(queue));
        return true;
      });
      if (added) _scheduleFlush();
    } catch (e) {
      debugPrint('MessageState: could not queue a receipt ($e)');
    }
  }

  void _scheduleFlush() {
    if (_disposed) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(flushDelay, () => unawaited(flush()));
  }

  /// Send the queued receipts, oldest first, in batches. Stops at the
  /// first batch that fails and keeps the rest. A batch answered 404
  /// registers the device and is sent once more; one answered 413 or 422
  /// can never be accepted, so it is dropped rather than holding back the
  /// rest. With diagnostics sharing off the queue is cleared instead.
  /// Never throws. A call made while a send is running awaits that run.
  Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    late final Future<void> run;
    run = _flushNow().whenComplete(() {
      if (identical(_flushing, run)) _flushing = null;
    });
    return _flushing = run;
  }

  Future<void> _flushNow() async {
    final generation = _generation;
    try {
      if (!await _sharing()) {
        await _serialized(() async {
          final prefs = await _prefs();
          await prefs.remove(receiptsKey);
        });
        return;
      }
      var registerTried = false;
      while (generation == _generation) {
        final queue = await _serialized(() async => _loadQueue(await _prefs()));
        if (queue.isEmpty) return;
        final batch = queue.take(batchSize).toList();
        try {
          await _post(await _deviceId(), {
            'receipts': batch,
            // Read on every attempt, so a batch sent again later says when
            // it really left. The server corrects each `at` by the gap
            // between this and its own clock.
            'sent_at': _clock().toUtc().toIso8601String(),
          });
        } on ApiException catch (e) {
          if (generation != _generation) return;
          if (e.isNotFound && !registerTried) {
            registerTried = true;
            await _register();
            continue;
          }
          if (e.statusCode != 413 && !e.isValidationError) {
            debugPrint('MessageState: receipts not sent, kept ($e)');
            return;
          }
          debugPrint('MessageState: backend refused receipts, dropped ($e)');
        }
        if (generation != _generation) return;
        await _serialized(() async {
          final sent = {for (final r in batch) jsonEncode(r)};
          final prefs = await _prefs();
          final left = [
            for (final r in _loadQueue(prefs))
              if (!sent.contains(jsonEncode(r))) r,
          ];
          if (left.isEmpty) {
            await prefs.remove(receiptsKey);
          } else {
            await prefs.setString(receiptsKey, jsonEncode(left));
          }
        });
      }
    } catch (e) {
      debugPrint('MessageState: receipts not sent ($e)');
    }
  }

  /// How many receipts are waiting. For tests.
  @visibleForTesting
  Future<int> pendingReceipts() async =>
      _serialized(() async => _loadQueue(await _prefs()).length);

  /// Forget everything about this account's messages, after it was
  /// deleted: the list, the badge, the receipts waiting to go. A check or
  /// a send still in flight drops what it gets back.
  Future<void> reset() async {
    _generation++;
    _flushTimer?.cancel();
    _flushTimer = null;
    _flushing = null;
    _fetching = false;
    _fetchAgain = false;
    _list = const [];
    _fresh = null;
    _offset = Duration.zero;
    _listAt = null;
    _notified = {};
    _askedLanguage = null;
    _lastSuccess = null;
    _lastAttemptFailed = false;
    _popped = {};
    _read = {};
    _lastPoppedSentAt = null;
    _notify();
    try {
      await _serialized(() async {
        final prefs = await _prefs();
        for (final key in const [
          cacheKey,
          poppedKey,
          readKey,
          reportedKey,
          receiptsKey,
          lastPoppedKey,
          ...NoticePull.keys,
        ]) {
          await prefs.remove(key);
        }
      });
    } catch (e) {
      debugPrint('MessageState: could not clear messages ($e)');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    super.dispose();
  }

  Future<bool> _sharing() async {
    final check = _sharingCheck;
    if (check != null) return check();
    // Unset means on, as for the connection reports.
    final prefs = await _prefs();
    return prefs.get(VpnEventReporter.sharePrefKey) != false;
  }

  Future<void> _load() async {
    try {
      final prefs = await _prefs();
      final cache = _decode(prefs, cacheKey);
      if (cache is Map) {
        final offset = cache['offset_ms'];
        if (offset is int) _offset = Duration(milliseconds: offset);
        final at = cache['at'];
        if (at is String) _listAt = DateTime.tryParse(at)?.toUtc();
        final list = cache['messages'];
        if (list is List) {
          _list = List.unmodifiable([
            for (final e in list) ?InAppMessage.tryParse(e),
          ]);
        }
      }
      _popped = _stamps(prefs, poppedKey);
      _read = _stamps(prefs, readKey);
      _notified = _stamps(prefs, NoticePull.notifiedKey);
      final last = _decodedString(prefs, lastPoppedKey);
      _lastPoppedSentAt = DateTime.tryParse(last ?? '')?.toUtc();
      _notify();
      if (_loadQueue(prefs).isNotEmpty) _scheduleFlush();
    } catch (e) {
      debugPrint('MessageState: could not read saved messages ($e)');
    }
  }

  Future<void> _saveCache(int generation) async {
    final cache = jsonEncode({
      'messages': [for (final m in _list) m.toJson()],
      'offset_ms': _offset.inMilliseconds,
      'at': _listAt?.toIso8601String(),
    });
    await _serialized(() async {
      if (generation != _generation) return;
      final prefs = await _prefs();
      await prefs.setString(cacheKey, cache);
    });
  }

  /// The stored string under [key], or null for anything else. Read with
  /// `get` rather than `getString`, which throws when the stored value has
  /// another type.
  static String? _decodedString(SharedPreferences prefs, String key) {
    try {
      final value = prefs.get(key);
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  static Object? _decode(SharedPreferences prefs, String key) {
    final raw = _decodedString(prefs, key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// A stored map of name to end time, without what has ended. Anything
  /// unreadable counts as empty.
  Map<String, DateTime> _stamps(SharedPreferences prefs, String key) {
    final decoded = _decode(prefs, key);
    if (decoded is! Map) return {};
    final now = _serverNow();
    final stamps = <String, DateTime>{};
    decoded.forEach((name, end) {
      final at = end is String ? DateTime.tryParse(end)?.toUtc() : null;
      if (name is String && at != null && at.isAfter(now)) stamps[name] = at;
    });
    return stamps;
  }

  /// [stamps] as stored. Entries for messages that have ended are left
  /// out, which is the only way these sets shrink: an id must not be
  /// forgotten just because a later list did not include it.
  String _encodeStamps(Map<String, DateTime> stamps) {
    final now = _serverNow();
    return jsonEncode({
      for (final e in stamps.entries)
        if (e.value.isAfter(now)) e.key: e.value.toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> _loadQueue(SharedPreferences prefs) {
    final decoded = _decode(prefs, receiptsKey);
    if (decoded is! List) return [];
    return [
      for (final r in decoded)
        if (r is Map && r['message_id'] is int && r['kind'] is String)
          r.cast<String, dynamic>(),
    ];
  }
}
