import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../api/device_identity.dart';
import '../../api/device_service.dart';
import '../../api/support_service.dart';
import '../../data/models/support_chat.dart';
import '../../services/connect_diagnostics.dart';
import '../../services/device_place.dart';
import '../../services/failure_verdict.dart';
import '../../services/vpn_event_reporter.dart';
import 'message_state.dart';

/// What became of a message the user sent.
enum SupportSendOutcome {
  /// The backend stored it.
  sent,

  /// No route reached us. It waits on the phone and goes out on its own.
  waiting,

  /// The backend, or this phone, would not take it. The code says why.
  refused,
}

class SupportSendResult {
  const SupportSendResult(this.outcome, [this.code]);

  final SupportSendOutcome outcome;
  final String? code;

  /// Whether the text left the input box for good: stored, or waiting on
  /// the phone. A refused text goes back to the box.
  bool get accepted => outcome != SupportSendOutcome.refused;
}

/// Why a message cannot be sent right now, and until when on the server's
/// clock. [until] is null when the backend did not say.
class SupportLimit {
  const SupportLimit(this.code, [this.until]);

  /// `quota_day`, `paused`, `slow_down` or `busy`. An older backend's
  /// `quota_conversation` arrives here as `quota_day`.
  final String code;
  final DateTime? until;
}

/// A line about the last thing the user tried, such as a refused message.
/// Lives until the next send and is never saved.
class SupportNotice {
  const SupportNotice(this.code, [this.retryAt]);

  /// One of the backend's codes, or `error` for a failure that has none.
  final String code;
  final DateTime? retryAt;
}

/// A message on the phone that the backend has not stored yet.
class SupportOutgoing {
  SupportOutgoing({
    required this.clientId,
    required this.text,
    required this.to,
    required this.lang,
    required this.createdAt,
    this.failed = false,
  });

  /// Sent with every try, so a POST that reached us twice is stored once.
  final String clientId;
  final String text;

  /// `assistant` or `staff`.
  final String to;
  final String lang;

  /// On the server's clock, in UTC.
  final DateTime createdAt;

  /// Whether the last try reached no route.
  bool failed;

  /// Whether a try is on its way now.
  bool sending = false;

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'text': text,
    'to': to,
    'lang': lang,
    'created_at': createdAt.toIso8601String(),
  };

  static SupportOutgoing? tryParse(Object? json) {
    if (json is! Map) return null;
    final clientId = json['client_id'];
    final text = json['text'];
    final to = json['to'];
    final lang = json['lang'];
    final at = json['created_at'];
    final createdAt = at is String ? DateTime.tryParse(at)?.toUtc() : null;
    if (clientId is! String ||
        text is! String ||
        (to != 'assistant' && to != 'staff') ||
        lang is! String ||
        createdAt == null) {
      return null;
    }
    // Saved by a run that could not send it, so it is waiting, not new.
    return SupportOutgoing(
      clientId: clientId,
      text: text,
      to: to as String,
      lang: lang,
      createdAt: createdAt,
      failed: true,
    );
  }
}

/// The support chat: whether it is on for this phone, the conversation,
/// the messages waiting to go, and the day's questions.
///
/// The day's questions are the only question limit. Once they are used up,
/// nothing asks the assistant until they come back. A message goes to our
/// team only when automatic answers are off for everyone, or when the
/// assistant itself handed the conversation to our team: then the user can
/// still answer them after the day's questions are used up.
///
/// Nothing here may get in the way of connecting. Every check is started
/// without awaiting it, every failure is caught and logged, and nothing
/// here touches the tunnel. The status check runs after the first frame,
/// and the entry points draw nothing until it says the chat is on.
///
/// A message is saved on the phone before it is posted, so one typed on a
/// network that cuts our calls is not lost: it waits, and goes out on the
/// next resume, connect or fetch that reaches us. It keeps its client id
/// across tries, which is what stops the backend storing it twice.
///
/// No request waits for the answer. After a question is stored, the
/// conversation is fetched at 2, 4, 7, 12 and 17 seconds, then every 10
/// seconds up to 3 minutes, then every 30 seconds while the chat is on
/// screen. While the chat is on screen and the question still waits, it
/// is fetched every 2 seconds for the first minute and every 4 seconds up
/// to 3 minutes instead, because the user is watching for the answer.
/// After a fetch that fails, the slower schedule applies until a fetch
/// gets through again, so a broken route is not asked every 2 seconds.
class SupportState extends ChangeNotifier {
  SupportState({
    SupportService? service,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    Future<bool> Function()? sharing,
    Future<Map<String, dynamic>> Function()? phone,
    Future<bool> Function()? playBilling,
    bool Function()? connected,
    String? Function()? problem,
    bool Function()? searching,
    List<Map<String, Object>> Function()? recentTaps,
    String Function()? language,
    DateTime Function()? clock,
    bool Function()? foreground,
    String Function()? newClientId,
    Future<SharedPreferences> Function()? prefs,
  }) : _service = service ?? SupportService(),
       _deviceId = deviceId ?? DeviceIdentity.instance.resolve,
       _register =
           register ?? (() async => await DeviceService().registerDevice()),
       _sharingCheck = sharing,
       _phone = phone ?? phoneFacts,
       _playBilling = playBilling ?? (() async => false),
       _connected = connected ?? (() => false),
       _problem = problem ?? (() => null),
       _searching = searching ?? (() => false),
       _recentTaps = recentTaps ?? (() => const []),
       _language = language ?? (() => MessageState.appLanguage(null)),
       _clock = clock ?? DateTime.now,
       _foreground = foreground ?? _appInForeground,
       _newClientId = newClientId ?? uuid4,
       _prefs = prefs ?? SharedPreferences.getInstance {
    _loaded = _load();
  }

  /// Whether the chat is on, the mode, the quota and the conversation, as
  /// the backend last said.
  static const statusKey = 'support_chat_status';

  /// The conversation as last fetched, with this phone's own marks.
  static const messagesKey = 'support_chat_messages';

  /// Messages waiting to be sent.
  static const outboxKey = 'support_chat_outbox';

  /// The newest reply the user has had on screen, for the dot on the icon.
  static const seenKey = 'support_chat_seen';

  /// The longest message, in Unicode code points, as the backend counts
  /// after it has cleaned the text up.
  static const maxRunes = 500;

  /// From this many code points the screen shows a counter.
  static const counterFrom = 400;

  /// A status check sooner than this after a good one is skipped unless
  /// forced.
  static const statusFreshFor = Duration(minutes: 5);

  /// How often the status is checked again while the app runs.
  static const statusEvery = Duration(hours: 6);

  /// When to fetch after a question is stored, in seconds.
  static const pollAfterSend = [2, 4, 7, 12, 17];
  static const pollEvery = Duration(seconds: 10);
  static const fastPollFor = Duration(seconds: 180);

  /// How often the conversation is fetched while it is on screen.
  static const openPollEvery = Duration(seconds: 30);

  /// The wait between fetches while the chat is on screen and a question
  /// waits for its answer: [onScreenPollEvery] until the question has
  /// waited [onScreenPollSlowerAfter], then [onScreenPollSlowerEvery] up
  /// to [fastPollFor]. The wait starts when the last fetch ends, so a slow
  /// route still gets a pause between fetches.
  static const onScreenPollEvery = Duration(seconds: 2);
  static const onScreenPollSlowerAfter = Duration(seconds: 60);
  static const onScreenPollSlowerEvery = Duration(seconds: 4);

  /// A question older than this is no longer taken as waiting for its
  /// answer. The backend gives up on one long before.
  static const inFlightFor = Duration(minutes: 30);

  /// A message that could not be sent for this long is not sent any more.
  /// A question from yesterday answered today is noise. It stays in the
  /// conversation with [notSent] under it.
  static const outboxKeepFor = Duration(hours: 24);

  /// The code of a message that waited too long on the phone. Only this
  /// phone uses it; the backend never sends it.
  static const notSent = 'not_sent';

  /// How long a send waits for the phone's own facts before it goes
  /// without them.
  static const phoneFactsWait = Duration(seconds: 1);

  static const maxKept = 200;
  static const maxPages = 4;

  final SupportService _service;
  final Future<String> Function() _deviceId;
  final Future<void> Function() _register;
  final Future<bool> Function()? _sharingCheck;
  final Future<Map<String, dynamic>> Function() _phone;

  /// Whether this copy can buy through Google Play on this phone
  /// (BillingState.checkPlayBilling). False when not given.
  final Future<bool> Function() _playBilling;
  final bool Function() _connected;
  final String? Function() _problem;

  /// Whether the app is still looking for a way to connect
  /// (ConnectFlow.searching, or a tunnel being checked). False when not
  /// given.
  final bool Function() _searching;

  /// How the latest taps ended (ConnectFlow.recentTaps). None when not
  /// given.
  final List<Map<String, Object>> Function() _recentTaps;
  final String Function() _language;
  final DateTime Function() _clock;
  final bool Function() _foreground;
  final String Function() _newClientId;
  final Future<SharedPreferences> Function() _prefs;

  late final Future<void> _loaded;

  bool _enabled = false;
  String _mode = 'off';
  SupportQuota? _quota;
  SupportThread? _thread;

  /// Whether the backend's last answer said a question of this phone is
  /// still being answered. Only holds back waiting messages, so they do not
  /// meet that question at the backend over and over. What the screen shows
  /// is [pending], read from the conversation.
  bool _backendPending = false;

  /// When the phone stored the question now waiting, by the phone's clock.
  /// The fetch schedule counts from here.
  DateTime? _sentAt;

  /// The waits the backend asked for with a short refusal, by recipient:
  /// `slow_down` or `busy` for the assistant, `slow_down` for our team
  /// (its cap on messages to them a day). Each holds only its own
  /// recipient, until its time runs out. Never saved.
  final Map<String, SupportLimit> _waits = {};

  /// The gap between the server's clock and the phone's.
  Duration _offset = Duration.zero;

  List<SupportMessage> _messages = const [];

  /// The newest id a fetch has returned. Fetches ask for what is after it.
  int _lastId = 0;

  /// How many fetches have come back. See [fetches].
  int _fetches = 0;
  int _seenId = 0;
  final List<SupportOutgoing> _outbox = [];
  SupportNotice? _notice;

  /// How many chat screens are open. One, in practice.
  int _screenOpen = 0;

  /// The phone's own facts for the open chat, read once per opening.
  Future<Map<String, dynamic>>? _phoneFacts;

  DateTime? _statusCheckedAt;
  bool _checkingStatus = false;
  bool _statusAgain = false;
  bool _polling = false;
  bool _pollAgain = false;

  /// Whether the last fetch failed. Until one gets through, the fast
  /// fetches while the chat is on screen give way to the slower schedule.
  bool _lastPollFailed = false;
  Timer? _pollTimer;
  Timer? _statusTimer;

  /// Bumped by [reset]. Anything that started before it drops what it gets
  /// back, because it belongs to an account that is gone.
  int _generation = 0;
  bool _disposed = false;

  /// Every write to the stored chat runs through this, one at a time.
  Future<void> _writeLock = Future.value();

  /// Sends run one at a time and in order, so two tries of the same
  /// message never race each other.
  Future<void> _sendLock = Future.value();

  Future<T> _serialized<T>(Future<T> Function() body) {
    final run = _writeLock.then((_) => body());
    _writeLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Whether the chat is on for this phone. The entry points show only
  /// then.
  bool get enabled => _enabled;

  /// `ai`, `staff` (answers come from our team only), `paused` or `off`.
  String get mode => _mode;
  SupportQuota? get quota => _quota;
  SupportThread? get thread => _thread;

  /// Whether a question is waiting for its answer: one stored as queued or
  /// being answered, asked within [inFlightFor]. Read from the conversation
  /// rather than kept as a flag, so a fetch that left before the question
  /// was stored cannot clear it, and a saved one cannot hold questions back
  /// for good on a phone that no longer reaches us.
  bool get pending => _inFlight().isNotEmpty;

  /// When the question waiting for its answer was asked, on the server's
  /// clock, or null when none waits. The chat screen counts the time it
  /// has been thinking from here.
  DateTime? get pendingSince {
    DateTime? since;
    for (final m in _inFlight()) {
      if (since == null || m.createdAt.isAfter(since)) since = m.createdAt;
    }
    return since;
  }

  /// How many fetches of the conversation have come back since the app
  /// started. The chat screen takes what it holds after the first fetch
  /// since it opened as history, shown at once; only later replies are
  /// typed out.
  int get fetches => _fetches;

  /// The questions still waiting for their answers.
  Iterable<SupportMessage> _inFlight() {
    final now = serverNow();
    return _messages.where(
      (m) =>
          m.id != null &&
          m.inFlight &&
          now.difference(m.createdAt) <= inFlightFor,
    );
  }

  /// Whether every message goes to our team, because automatic answers are
  /// off.
  bool get teamOnly => _mode == 'staff';

  /// The conversation, oldest first.
  List<SupportMessage> get messages => List.unmodifiable(_messages);

  /// Messages not stored yet, oldest first.
  List<SupportOutgoing> get outbox => List.unmodifiable(_outbox);

  SupportNotice? get notice => _notice;

  /// Replies that arrived since the chat was last on screen.
  int get unseenReplies => _messages
      .where(
        (m) =>
            (m.id ?? 0) > _seenId &&
            (m.role == 'assistant' || m.role == 'staff'),
      )
      .length;

  /// The phone's clock moved by the gap to the server's.
  DateTime serverNow() => _clock().toUtc().add(_offset);

  /// Why a question to the assistant would be refused now, or null when
  /// it would not. In [teamOnly] mode there is no assistant to limit.
  SupportLimit? get limit {
    if (!_enabled || teamOnly) return null;
    final now = serverNow();
    final quota = _quota;
    final paused = quota?.pausedUntil;
    if (paused != null && paused.isAfter(now)) {
      return SupportLimit('paused', paused);
    }
    if (_mode == 'paused') return const SupportLimit('paused');
    final resets = quota?.resetsAt;
    if (quota != null &&
        quota.remaining <= 0 &&
        (resets == null || resets.isAfter(now))) {
      return SupportLimit(quotaDay, resets);
    }
    return _wait('assistant');
  }

  /// Why a message to our team would be refused now, or null when it would
  /// not: the backend's cap on them for the day. It never holds back a
  /// question to the assistant.
  SupportLimit? get teamLimit => _enabled ? _wait('staff') : null;

  /// Whether a message goes to our team rather than the assistant. Always
  /// while automatic answers are off for everyone. Otherwise only when the
  /// day's questions are used up while our team has this conversation as
  /// an open ticket, which only the assistant opens: the user can then
  /// still answer our team, and nothing else.
  bool get writesToTeam {
    if (!_enabled) return false;
    if (teamOnly) return true;
    return (_thread?.ticketOpen ?? false) && limit?.code == quotaDay;
  }

  /// The code of the day's limit.
  static const quotaDay = 'quota_day';

  SupportLimit? _wait(String to) {
    final wait = _waits[to];
    final until = wait?.until;
    if (wait == null || until == null) return null;
    return until.isAfter(serverNow()) ? wait : null;
  }

  void _adoptServerTime(DateTime? serverTime) {
    if (serverTime == null) return;
    _offset = serverTime.difference(_clock().toUtc());
  }

  /// Once no question waits, the fetch schedule after one is over.
  void _settle() {
    if (!pending) _sentAt = null;
  }

  /// Ask the backend whether the chat is on for this phone. Never throws.
  ///
  /// Skipped within [statusFreshFor] of a good check unless [force]d. A
  /// failed check keeps what the last good one said. A phone the backend
  /// does not know yet is not registered from here: the register at launch
  /// is already on its way, and the app checks again once it lands. A call
  /// during a check that then fails runs one more check after it, so the
  /// one made when the register lands is not lost.
  Future<void> checkStatus({bool force = false}) async {
    try {
      if (_disposed) return;
      if (_checkingStatus) {
        _statusAgain = true;
        return;
      }
      final last = _statusCheckedAt;
      if (!force &&
          last != null &&
          _clock().difference(last) < statusFreshFor) {
        return;
      }
      _checkingStatus = true;
      _statusAgain = false;
      final generation = _generation;
      var answered = false;
      try {
        await _loaded;
        final status = await _service.status(await _deviceId());
        if (generation != _generation || _disposed) return;
        answered = true;
        _statusCheckedAt = _clock();
        _enabled = status.enabled;
        if (status.enabled) {
          _adoptServerTime(status.serverTime);
          _mode = status.mode;
          _quota = status.quota ?? _quota;
          _thread = status.thread ?? _thread;
          _backendPending = status.pending;
          _settle();
        } else {
          _mode = 'off';
        }
        _notify();
        if (_enabled &&
            (status.pending ||
                pending ||
                (_thread?.ticketOpen ?? false) ||
                _outbox.isNotEmpty)) {
          unawaited(poll());
        } else {
          _schedulePoll();
        }
        await _saveQuietly(generation);
      } on ApiException catch (e) {
        if (generation != _generation) return;
        if (SupportRefusal.fromBody(e.body)?.code == 'off') {
          answered = true;
          _statusCheckedAt = _clock();
          await _turnOff(generation);
        } else {
          debugPrint('SupportState: status check failed ($e)');
        }
      } finally {
        if (generation == _generation) {
          _checkingStatus = false;
          _scheduleStatus();
          if (_statusAgain && !answered && !_disposed) {
            _statusAgain = false;
            unawaited(checkStatus(force: true));
          }
          _statusAgain = false;
        }
      }
    } catch (e) {
      debugPrint('SupportState: could not check the chat status ($e)');
    }
  }

  Future<void> _turnOff(int generation) async {
    _enabled = false;
    _mode = 'off';
    _cancelPoll();
    _notify();
    await _saveQuietly(generation);
  }

  /// Fetch what is new in the conversation. Never throws.
  ///
  /// One fetch runs at a time; a call during one runs one more after it.
  Future<void> poll() async {
    try {
      if (_disposed || !_enabled) return;
      if (_polling) {
        _pollAgain = true;
        return;
      }
      _polling = true;
      final generation = _generation;
      try {
        do {
          _pollAgain = false;
          await _pollOnce(generation);
        } while (_pollAgain && generation == _generation && !_disposed);
      } finally {
        if (generation == _generation) {
          _polling = false;
          _schedulePoll();
        }
      }
    } catch (e) {
      debugPrint('SupportState: could not fetch the chat ($e)');
    }
  }

  Future<void> _pollOnce(int generation) async {
    try {
      await _loaded;
      var after = _cursor();
      var newest = _lastId;
      for (var page = 0; page < maxPages; page++) {
        final from = after;
        final answer = await _withRegister(
          generation,
          (id) => _service.fetch(id, from, _language()),
        );
        if (answer == null || generation != _generation || _disposed) return;
        _adoptServerTime(answer.serverTime);
        _mode = answer.mode;
        _quota = answer.quota ?? _quota;
        _thread = answer.thread ?? _thread;
        _backendPending = answer.pending;
        _merge(answer.messages);
        // A message whose post reached us though the answer to it did not
        // is stored already. It is no longer waiting to go.
        final stored = {for (final m in answer.messages) ?m.clientId};
        _outbox.removeWhere((o) => stored.contains(o.clientId));
        for (final m in answer.messages) {
          final id = m.id ?? 0;
          if (id > newest) newest = id;
          if (id > after) after = id;
        }
        if (answer.messages.length < SupportPage.pageSize) break;
      }
      _settle();
      _lastId = newest;
      _fetches++;
      _lastPollFailed = false;
      if (_screenOpen > 0) _markSeen();
      _notify();
      if (_outbox.any((o) => o.failed)) unawaited(flushOutbox());
      await _saveQuietly(generation);
    } on ApiException catch (e) {
      if (generation != _generation) return;
      if (SupportRefusal.fromBody(e.body)?.code == 'off') {
        await _turnOff(generation);
        return;
      }
      _lastPollFailed = true;
      debugPrint('SupportState: chat fetch failed ($e)');
    } catch (e) {
      if (generation != _generation) return;
      _lastPollFailed = true;
      // What is on screen stays: a cut network says nothing about the
      // conversation.
      debugPrint('SupportState: chat fetch failed ($e)');
    }
  }

  /// Where the next fetch starts: after the newest message seen, or, while
  /// a question waits for its answer, just before that question. Its
  /// status then comes back with every fetch, so a question the backend
  /// gave up on shows as failed instead of waiting for ever.
  int _cursor() {
    var cursor = _lastId;
    for (final m in _inFlight()) {
      final id = m.id!;
      if (id - 1 < cursor) cursor = id - 1;
    }
    return cursor < 0 ? 0 : cursor;
  }

  /// [call] for this phone, registering it once when the backend does not
  /// know it. Null when the account was deleted meanwhile, because
  /// registering then would bring its device back.
  Future<T?> _withRegister<T>(
    int generation,
    Future<T> Function(String deviceId) call,
  ) async {
    try {
      return await call(await _deviceId());
    } on ApiException catch (e) {
      if (!e.isNotFound) rethrow;
      if (generation != _generation) return null;
      await _register();
      if (generation != _generation) return null;
      return await call(await _deviceId());
    }
  }

  /// Put [incoming] into the conversation: a known id is replaced, a new
  /// one added. A rating made on this phone stays until the backend says
  /// otherwise.
  void _merge(Iterable<SupportMessage> incoming) {
    if (incoming.isEmpty) return;
    final list = [..._messages];
    final at = <int, int>{
      for (var i = 0; i < list.length; i++)
        if (list[i].id != null) list[i].id!: i,
    };
    for (final m in incoming) {
      final id = m.id;
      final known = id == null ? null : at[id];
      if (known == null) {
        if (id != null) at[id] = list.length;
        list.add(m);
      } else {
        final rating = list[known].rating;
        list[known] = m.rating == null && rating != null
            ? m.withRating(rating)
            : m;
      }
    }
    list.sort(_order);
    _messages = List.unmodifiable(
      list.length > maxKept ? list.sublist(list.length - maxKept) : list,
    );
  }

  static int _order(SupportMessage a, SupportMessage b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    if (byTime != 0) return byTime;
    // A mark of this phone's goes after the stored messages of its second.
    return (a.id ?? 0x7fffffff).compareTo(b.id ?? 0x7fffffff);
  }

  /// Send [text], to the assistant or, when [writesToTeam], to our team.
  /// Never throws.
  ///
  /// The text is saved on the phone before it is posted. The result says
  /// whether it was stored, is waiting for a route, or was refused; only a
  /// refused text should go back into the input box.
  Future<SupportSendResult> send(String text) async {
    final generation = _generation;
    SupportOutgoing item;
    try {
      await _loaded;
      final trimmed = text.trim();
      if (trimmed.isEmpty) return _refuse('empty');
      if (trimmed.runes.length > maxRunes) return _refuse('too_long');
      final to = writesToTeam ? 'staff' : 'assistant';
      if (to == 'assistant' && pending) return _refuse('wait_reply');
      item = SupportOutgoing(
        clientId: _newClientId(),
        text: trimmed,
        to: to,
        lang: _language(),
        createdAt: serverNow(),
      );
    } catch (e) {
      debugPrint('SupportState: could not take a message ($e)');
      return _refuse('error');
    }
    _outbox.add(item);
    _notice = null;
    _notify();
    try {
      await _saveOutbox(generation);
    } catch (e) {
      // It still goes out now; it just would not survive the app closing.
      debugPrint('SupportState: could not keep a message ($e)');
    }
    return _deliverInTurn(item, generation, byUser: true);
  }

  SupportSendResult _refuse(String code) {
    _notice = SupportNotice(code);
    _notify();
    return SupportSendResult(SupportSendOutcome.refused, code);
  }

  Future<SupportSendResult> _deliverInTurn(
    SupportOutgoing item,
    int generation, {
    required bool byUser,
  }) {
    final run = _sendLock.then(
      (_) => _deliver(item, generation, byUser: byUser),
    );
    _sendLock = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Post one waiting message. Never throws.
  ///
  /// [byUser] is true for the try made when the user tapped Send: a refusal
  /// then goes back to the input box. A refusal on a later try, which the
  /// user did not start, is kept in the conversation with its reason.
  Future<SupportSendResult> _deliver(
    SupportOutgoing item,
    int generation, {
    required bool byUser,
  }) async {
    // Already stored or dropped by an earlier try.
    if (generation != _generation || !_outbox.contains(item)) {
      return const SupportSendResult(SupportSendOutcome.sent);
    }
    item.sending = true;
    _notify();
    try {
      final body = {
        'client_id': item.clientId,
        'text': item.text,
        'lang': item.lang,
        'to': item.to,
        'context': await _context(),
      };
      final reply = await _withRegister(
        generation,
        (id) => _service.send(id, body),
      );
      if (reply == null || generation != _generation) {
        return const SupportSendResult(SupportSendOutcome.refused);
      }
      _outbox.remove(item);
      _adoptServerTime(reply.serverTime);
      _quota = reply.quota ?? _quota;
      _thread = reply.thread ?? _thread;
      _mode = reply.mode ?? _mode;
      final message = reply.message;
      if (message != null) {
        _merge([message]);
        if (message.inFlight) {
          _backendPending = true;
          _sentAt = _clock();
        }
      }
      _notify();
      _schedulePoll();
      await _saveQuietly(generation);
      return const SupportSendResult(SupportSendOutcome.sent);
    } on ApiException catch (e) {
      if (generation != _generation) {
        return const SupportSendResult(SupportSendOutcome.refused);
      }
      final refusal = SupportRefusal.fromBody(e.body);
      final refused =
          (e.statusCode >= 400 && e.statusCode < 500) || refusal?.code == 'off';
      if (refused) return _refused(item, generation, e, refusal, byUser);
      debugPrint('SupportState: message kept for later (${e.statusCode})');
    } catch (e) {
      debugPrint('SupportState: message kept for later ($e)');
    } finally {
      item.sending = false;
    }
    if (generation != _generation) {
      return const SupportSendResult(SupportSendOutcome.refused);
    }
    item.failed = true;
    _notify();
    try {
      await _saveOutbox(generation);
    } catch (e) {
      debugPrint('SupportState: could not keep a message ($e)');
    }
    return const SupportSendResult(SupportSendOutcome.waiting);
  }

  Future<SupportSendResult> _refused(
    SupportOutgoing item,
    int generation,
    ApiException e,
    SupportRefusal? refusal,
    bool byUser,
  ) async {
    var code = refusal?.code ?? (e.statusCode == 413 ? 'too_long' : 'error');
    // An older backend also limits questions per conversation. A limit is a
    // limit: it reads, and holds, like the day's.
    if (code == 'quota_conversation') code = quotaDay;
    final retryAt = refusal?.retryAt;
    if (code == 'wait_reply') {
      // Another question is still being answered. Find out where it is.
      _backendPending = true;
      unawaited(poll());
      if (!byUser && _outbox.contains(item)) {
        // Not refused: it goes once that question has its answer.
        item.failed = true;
        _notify();
        try {
          await _saveOutbox(generation);
        } catch (e) {
          debugPrint('SupportState: could not keep a message ($e)');
        }
        return const SupportSendResult(
          SupportSendOutcome.waiting,
          'wait_reply',
        );
      }
    }
    _outbox.remove(item);
    _quota = refusal?.quota ?? _quota;
    _notice = SupportNotice(code, retryAt);
    if (retryAt != null && (code == 'slow_down' || code == 'busy')) {
      _waits[item.to] = SupportLimit(code, retryAt);
    }
    // A day's limit the quota does not show, as an older backend's limit on
    // the conversation, holds until the time the refusal named.
    if (code == quotaDay && item.to == 'assistant' && limit == null) {
      final until = retryAt ?? _quota?.resetsAt;
      if (until != null) _waits['assistant'] = SupportLimit(quotaDay, until);
    }
    if (code == 'off') {
      _enabled = false;
      _mode = 'off';
    }
    if (!byUser) {
      _merge([
        SupportMessage(
          clientId: item.clientId,
          role: 'user',
          status: 'refused',
          code: code,
          text: item.text,
          createdAt: item.createdAt,
        ),
      ]);
    }
    await _saveQuietly(generation);
    _notify();
    _schedulePoll();
    return SupportSendResult(SupportSendOutcome.refused, code);
  }

  /// Try the waiting messages again, oldest first. Stops at the first one
  /// that still finds no route. A question waits while another is being
  /// answered, because the backend takes one at a time. A message that
  /// waited longer than [outboxKeepFor] is not sent; it stays in the
  /// conversation marked [notSent]. Never throws.
  Future<void> flushOutbox() async {
    try {
      await _loaded;
      final generation = _generation;
      final now = serverNow();
      final stale = _outbox
          .where((o) => now.difference(o.createdAt) > outboxKeepFor)
          .toList();
      if (stale.isNotEmpty) {
        _outbox.removeWhere(stale.contains);
        _merge([
          for (final o in stale)
            SupportMessage(
              clientId: o.clientId,
              role: 'user',
              status: 'failed',
              code: notSent,
              text: o.text,
              createdAt: o.createdAt,
            ),
        ]);
        _notify();
        await _saveQuietly(generation);
      }
      for (final item in [..._outbox]) {
        if (generation != _generation || _disposed || !_enabled) return;
        if (item.sending) continue;
        if (item.to == 'assistant' && (pending || _backendPending)) return;
        final result = await _deliverInTurn(item, generation, byUser: false);
        if (result.outcome == SupportSendOutcome.waiting) return;
      }
    } catch (e) {
      debugPrint('SupportState: could not send waiting messages ($e)');
    }
  }

  /// Rate an answer. Shown at once, and put back when the backend could
  /// not be told. Never throws.
  Future<bool> rate(int messageId, {required bool up}) async {
    final generation = _generation;
    final value = up ? 'up' : 'down';
    try {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index < 0 || _messages[index].role != 'assistant') return false;
      final before = _messages[index].rating;
      if (before == value) return true;
      _setRating(messageId, value);
      _notify();
      try {
        final done = await _withRegister(generation, (id) async {
          await _service.rate(id, messageId, value);
          return true;
        });
        if (done != true || generation != _generation) return false;
      } catch (e) {
        debugPrint('SupportState: rating not sent ($e)');
        if (generation == _generation) {
          _setRating(messageId, before);
          _notify();
        }
        return false;
      }
      await _saveQuietly(generation);
      return true;
    } catch (e) {
      debugPrint('SupportState: could not rate ($e)');
      return false;
    }
  }

  void _setRating(int messageId, String? value) {
    _messages = List.unmodifiable([
      for (final m in _messages) m.id == messageId ? m.withRating(value) : m,
    ]);
  }

  /// End the conversation, so the assistant starts again without what was
  /// said before. It gives no questions back: the day's count stays as it
  /// is. Never throws.
  Future<bool> startNewConversation() async {
    final generation = _generation;
    try {
      await _loaded;
      final reply = await _withRegister(
        generation,
        (id) => _service.startNew(id),
      );
      if (reply == null || generation != _generation) return false;
      _adoptServerTime(reply.serverTime);
      _quota = reply.quota ?? _quota;
      _thread = reply.thread ?? _thread;
      _notice = null;
      final last = _messages.isEmpty ? null : _messages.last;
      if (last != null && last.role != SupportMessage.divider) {
        // After everything already shown, whatever the clocks say.
        final now = serverNow();
        final at = now.isAfter(last.createdAt)
            ? now
            : last.createdAt.add(const Duration(milliseconds: 1));
        _merge([SupportMessage(role: SupportMessage.divider, createdAt: at)]);
      }
      _notify();
      await _saveQuietly(generation);
      return true;
    } on ApiException catch (e) {
      if (generation == _generation &&
          SupportRefusal.fromBody(e.body)?.code == 'off') {
        await _turnOff(generation);
      }
      debugPrint('SupportState: no new conversation ($e)');
      return false;
    } catch (e) {
      debugPrint('SupportState: no new conversation ($e)');
      return false;
    }
  }

  /// The chat screen opened: fetch at once, send what waits, read the
  /// phone's facts afresh, and count every reply as seen.
  void attach() {
    _screenOpen++;
    _phoneFacts = null;
    _markSeen();
    unawaited(poll());
    unawaited(flushOutbox());
  }

  /// The chat screen closed. Fetching goes on only while a question waits.
  void detach() {
    if (_screenOpen > 0) _screenOpen--;
    _schedulePoll();
  }

  /// The app came back to the foreground.
  void resumed() {
    try {
      unawaited(checkStatus());
      if (!_enabled) return;
      if (pending || (_thread?.ticketOpen ?? false) || _screenOpen > 0) {
        unawaited(poll());
      } else {
        _schedulePoll();
      }
      if (_outbox.isNotEmpty) unawaited(flushOutbox());
    } catch (e) {
      debugPrint('SupportState: resume check failed ($e)');
    }
  }

  /// A tunnel came up and was checked. A phone whose network cuts our
  /// calls often reaches us only now.
  void connectVerified() {
    try {
      if (!_enabled) return;
      final waiting = _outbox.isNotEmpty;
      if (pending || (_thread?.ticketOpen ?? false) || waiting) {
        unawaited(poll());
      }
      if (waiting) unawaited(flushOutbox());
    } catch (e) {
      debugPrint('SupportState: connect check failed ($e)');
    }
  }

  void _markSeen() {
    var newest = _seenId;
    for (final m in _messages) {
      if (m.role != 'assistant' && m.role != 'staff') continue;
      final id = m.id ?? 0;
      if (id > newest) newest = id;
    }
    if (newest == _seenId) return;
    _seenId = newest;
    _notify();
    final generation = _generation;
    unawaited(
      _serialized(() async {
        if (generation != _generation) return;
        final prefs = await _prefs();
        await prefs.setInt(seenKey, newest);
      }).catchError((Object e) {
        debugPrint('SupportState: could not save what was seen ($e)');
      }),
    );
  }

  /// How long until the next fetch, or null for none. While the chat is on
  /// screen and a question waits, the fast fetches of [onScreenPollEvery];
  /// otherwise, or after a fetch that failed, the schedule after a
  /// question; then every [openPollEvery] while the chat is on screen.
  @visibleForTesting
  Duration? nextPollDelay() {
    if (_screenOpen > 0 && pending && !_lastPollFailed) {
      final waited = _waited();
      if (waited < onScreenPollSlowerAfter) return onScreenPollEvery;
      if (waited < fastPollFor) return onScreenPollSlowerEvery;
    }
    final sent = _sentAt;
    if (pending && sent != null) {
      final elapsed = _clock().difference(sent);
      for (final s in pollAfterSend) {
        final at = Duration(seconds: s);
        if (elapsed < at) return at - elapsed;
      }
      if (elapsed < fastPollFor) {
        final last = Duration(seconds: pollAfterSend.last);
        final steps =
            (elapsed - last).inMicroseconds ~/ pollEvery.inMicroseconds + 1;
        final next = last + pollEvery * steps;
        return (next < fastPollFor ? next : fastPollFor) - elapsed;
      }
    }
    return _screenOpen > 0 ? openPollEvery : null;
  }

  /// How long the question now waiting has waited: since this phone stored
  /// it, or, when this run did not send it, since the backend says it was
  /// asked.
  Duration _waited() {
    final sent = _sentAt;
    if (sent != null) return _clock().difference(sent);
    final since = pendingSince;
    return since == null ? fastPollFor : serverNow().difference(since);
  }

  void _schedulePoll() {
    _cancelPoll();
    if (_disposed || !_enabled || !_foreground()) return;
    final delay = nextPollDelay();
    if (delay == null) return;
    _pollTimer = Timer(delay, () {
      _pollTimer = null;
      unawaited(poll());
    });
  }

  void _cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleStatus() {
    _statusTimer?.cancel();
    if (_disposed) return;
    _statusTimer = Timer(statusEvery, () {
      _statusTimer = null;
      unawaited(checkStatus(force: true));
    });
  }

  static bool _appInForeground() {
    try {
      final state = WidgetsBinding.instance.lifecycleState;
      return state == null ||
          state == AppLifecycleState.resumed ||
          state == AppLifecycleState.inactive;
    } catch (_) {
      return true;
    }
  }

  /// What the phone says about itself with a message. Only whether the
  /// tunnel is up, whether the app is still looking for a way to connect,
  /// and whether this copy can buy through Google Play when the user has
  /// turned diagnostics sharing off.
  ///
  /// `searching` is true while the app looks for a way in: a search, a
  /// wait before the next try, a dial, or a tunnel being checked. With it
  /// the assistant is told the phone is connecting rather than off. From
  /// 2026-10-20 to 10-23 it was told "connecting" 0 times, while 6 of 9
  /// phones that complained were in a search. `recent_taps` is how the
  /// taps of the last hour ended (ConnectFlow.recentTaps), sent only with
  /// sharing on, like the connection reports: the backend counts them
  /// beside the traces, which a stuck phone sends late.
  ///
  /// `play_billing` says whether this copy can buy through Google Play
  /// here, so the assistant does not point a user of the channel APK, where
  /// Play cannot sell, to a Buy button it does not have. It is about this
  /// copy of the app, not about the phone's settings, so it goes with
  /// every message. The backend files it with the phone's facts
  /// (phone.play_billing).
  Future<Map<String, dynamic>> _context() async {
    var connected = false;
    try {
      connected = _connected();
    } catch (_) {}
    var searching = false;
    try {
      searching = _searching();
    } catch (_) {}
    // Asked while the phone facts are read, so the two waits overlap.
    final playCheck = _playBillingNow();
    Map<String, dynamic>? facts;
    String? problem;
    var taps = const <Map<String, Object>>[];
    try {
      if (await _sharing()) {
        facts = await (_phoneFacts ??= _phone()).timeout(
          phoneFactsWait,
          onTimeout: () => const <String, dynamic>{},
        );
        problem = _problem();
        taps = _recentTaps();
      }
    } catch (e) {
      debugPrint('SupportState: message sent without the phone facts ($e)');
      facts = null;
    }
    final play = await playCheck;
    return {
      'connected': connected,
      'searching': searching,
      'play_billing': play,
      if (facts != null) ...{
        'problem': problem,
        if (taps.isNotEmpty) 'recent_taps': taps,
        ...facts,
      },
    };
  }

  /// [_playBilling], or false when it fails or does not answer within
  /// [phoneFactsWait]. Never throws.
  Future<bool> _playBillingNow() {
    // A future of this function's own, so a failure is caught here and
    // the wait applies whatever kind of future the check returns.
    Future<bool> ask() async {
      try {
        return await _playBilling();
      } catch (e) {
        debugPrint('SupportState: could not tell whether Play can sell ($e)');
        return false;
      }
    }

    return ask().timeout(phoneFactsWait, onTimeout: () => false);
  }

  Future<bool> _sharing() async {
    final check = _sharingCheck;
    if (check != null) return check();
    // Unset means on, as for the connection reports.
    final prefs = await _prefs();
    return prefs.get(VpnEventReporter.sharePrefKey) != false;
  }

  /// The facts the platform has about the phone, read the way a failure
  /// report reads them. Never throws.
  static Future<Map<String, dynamic>> phoneFacts() async {
    try {
      const channel = MethodChannel('com.vpn.fortivavpn/tunnel');
      final report = ConnectDiagnostics(channel: channel).platformReport();
      final place = DevicePlace(channel: channel).read();
      return factsFrom(await report, await place);
    } catch (e) {
      debugPrint('SupportState: could not read the phone facts ($e)');
      return const {};
    }
  }

  /// The part of a platform report a message carries: the network, the
  /// carrier, the Android version and the settings that stop a tunnel.
  /// Nothing else in the report leaves the phone with a message.
  @visibleForTesting
  static Map<String, dynamic> factsFrom(
    Map<String, dynamic> report,
    Map<String, dynamic>? place,
  ) {
    String? text(Object? value) {
      if (value is! String || value.trim().isEmpty) return null;
      final t = value.trim();
      return t.length > 64 ? t.substring(0, 64) : t;
    }

    bool? flag(Object? value) => value is bool ? value : null;
    final network = switch (report['network']) {
      'wifi' => 'wifi',
      'mobile' => 'mobile',
      null || 'none' => null,
      _ => 'other',
    };
    final sdk = report['sdk_int'];
    final phone = <String, dynamic>{
      'vpn_permission': ?flag(report['vpn_permission']),
      'other_vpn': ?flag(place?['other_vpn']),
      'battery_optimized': ?flag(report['battery_optimized']),
      'background_restricted': ?flag(report['background_restricted']),
      if (report.containsKey('private_dns'))
        'private_dns_on': text(report['private_dns']) != null,
    };
    return {
      'network': network,
      'carrier': text(report['carrier']) ?? text(report['sim_carrier']),
      if (sdk is int) 'android': ?androidRelease(sdk),
      if (phone.isNotEmpty) 'phone': phone,
    };
  }

  /// The Android version an SDK level belongs to, as a number the backend
  /// keeps, or null for a level this build does not know. 12L is sent as
  /// 12, because the backend takes only digits.
  static String? androidRelease(int sdk) => const {
    21: '5.0',
    22: '5.1',
    23: '6',
    24: '7.0',
    25: '7.1',
    26: '8.0',
    27: '8.1',
    28: '9',
    29: '10',
    30: '11',
    31: '12',
    32: '12',
    33: '13',
    34: '14',
    35: '15',
    36: '16',
    37: '17',
  }[sdk];

  /// What kind of problem a failure on screen is, in the backend's words
  /// for it. The verdict's own name, which says more than the user needs,
  /// stays on the phone.
  static String problemCategory(FailureVerdict? verdict) => switch (verdict) {
    FailureVerdict.noInternet => 'phone_offline',
    // A word the backend already knows: a cut way abroad is trouble with
    // the network, not a phone with no connection.
    FailureVerdict.cutOff => 'network_trouble',
    FailureVerdict.needsPermission => 'phone_permission',
    FailureVerdict.serverUnreachable ||
    FailureVerdict.blockedTls ||
    FailureVerdict.throttled => 'network_trouble',
    FailureVerdict.unknown || null => 'unclear',
  };

  static final _random = Random.secure();

  /// A random version 4 UUID.
  static String uuid4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Forget the chat after the account was deleted: the conversation, the
  /// waiting messages, the status. Anything still in flight drops what it
  /// gets back.
  Future<void> reset() async {
    _generation++;
    _cancelPoll();
    _statusTimer?.cancel();
    _statusTimer = null;
    _enabled = false;
    _mode = 'off';
    _quota = null;
    _thread = null;
    _backendPending = false;
    _sentAt = null;
    _waits.clear();
    _offset = Duration.zero;
    _messages = const [];
    _lastId = 0;
    _seenId = 0;
    _outbox.clear();
    _notice = null;
    _phoneFacts = null;
    _statusCheckedAt = null;
    _checkingStatus = false;
    _statusAgain = false;
    _polling = false;
    _pollAgain = false;
    _lastPollFailed = false;
    _notify();
    try {
      await _serialized(() async {
        final prefs = await _prefs();
        for (final key in const [statusKey, messagesKey, outboxKey, seenKey]) {
          await prefs.remove(key);
        }
      });
    } catch (e) {
      debugPrint('SupportState: could not clear the chat ($e)');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPoll();
    _statusTimer?.cancel();
    super.dispose();
  }

  /// [_saveAll], for a caller that has already done what the save records:
  /// a failed write costs the saved copy, not the result.
  Future<void> _saveQuietly(int generation) async {
    try {
      await _saveAll(generation);
    } catch (e) {
      debugPrint('SupportState: could not save the chat ($e)');
    }
  }

  Future<void> _saveAll(int generation) async {
    await _saveStatus(generation);
    await _saveMessages(generation);
    await _saveOutbox(generation);
  }

  Future<void> _saveStatus(int generation) async {
    final status = jsonEncode({
      'enabled': _enabled,
      'mode': _mode,
      'quota': _quota?.toJson(),
      'thread': _thread?.toJson(),
      'offset_ms': _offset.inMilliseconds,
    });
    await _serialized(() async {
      if (generation != _generation) return;
      final prefs = await _prefs();
      await prefs.setString(statusKey, status);
    });
  }

  Future<void> _saveMessages(int generation) async {
    final messages = jsonEncode({
      'last_id': _lastId,
      'messages': [for (final m in _messages) m.toJson()],
    });
    await _serialized(() async {
      if (generation != _generation) return;
      final prefs = await _prefs();
      await prefs.setString(messagesKey, messages);
    });
  }

  Future<void> _saveOutbox(int generation) async {
    final outbox = jsonEncode([for (final o in _outbox) o.toJson()]);
    await _serialized(() async {
      if (generation != _generation) return;
      final prefs = await _prefs();
      if (_outbox.isEmpty) {
        await prefs.remove(outboxKey);
      } else {
        await prefs.setString(outboxKey, outbox);
      }
    });
  }

  Future<void> _load() async {
    try {
      final prefs = await _prefs();
      final status = _decode(prefs, statusKey);
      if (status is Map) {
        _enabled = status['enabled'] == true;
        final mode = status['mode'];
        if (mode is String) _mode = mode;
        _quota = SupportQuota.tryParse(status['quota']);
        _thread = SupportThread.tryParse(status['thread']);
        final offset = status['offset_ms'];
        if (offset is int) _offset = Duration(milliseconds: offset);
      }
      final saved = _decode(prefs, messagesKey);
      if (saved is Map) {
        final lastId = saved['last_id'];
        if (lastId is int) _lastId = lastId;
        final list = saved['messages'];
        if (list is List) {
          _messages = List.unmodifiable([
            for (final e in list) ?SupportMessage.tryParse(e),
          ]);
        }
      }
      final outbox = _decode(prefs, outboxKey);
      if (outbox is List) {
        // Anything added before the saved copy was read stays after it.
        _outbox.insertAll(0, [
          for (final e in outbox) ?SupportOutgoing.tryParse(e),
        ]);
      }
      final seen = prefs.get(seenKey);
      if (seen is int) _seenId = seen;
      _notify();
    } catch (e) {
      debugPrint('SupportState: could not read the saved chat ($e)');
    }
  }

  static Object? _decode(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.get(key);
      if (raw is! String || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
