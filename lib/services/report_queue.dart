import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/device_service.dart';
import 'stored_from_background.dart';
import 'vpn_event_reporter.dart';

/// Rows of one small report, kept on the phone until the backend has them,
/// and sent to one device endpoint as `{"items": [...], "sent_at": ...}`.
/// The backend compares `sent_at` with its own clock and corrects each
/// row's `client_ts` by the gap, as it does for door checks and events,
/// because some phones' clocks are hours or days off.
///
/// Three reports use it: what the size probe measured (SizeProbeRunner),
/// what each connect tap did (ConnectTraces) and the record of the app's
/// own uploads (DeliveryLog). All three follow what the door checks
/// learned (see VpnEventReporter):
///
/// * every upload stays under [VpnEventReporter.probeUploadBytes], because
///   a line that cuts larger uploads can still carry small calls;
/// * rows wait up to [keptFor] for a route, are capped at [maxRows] with
///   the oldest dropped first, and are stored as they are added, so an app
///   closed mid-run keeps them;
/// * a flush sends the oldest rows first and stops at the first upload a
///   later try could fix; rows [addAndSend] could not send go before them,
///   the newest first ([sendFirst]); an upload the backend refuses for good is
///   dropped (VpnEventReporter.refusedForGood); a 404 registers the device
///   and tries once more;
/// * nothing is stored or sent once the user has turned sharing off, and
///   what is waiting is dropped then (VpnEventReporter.setSharing).
///
/// They ride the door checks' tries too: VpnEventReporter.flush sends
/// these after its own queues, so the cold start, the report timer and
/// every network change try them.
class ReportQueue {
  ReportQueue({
    required this.storageKey,
    required this.path,
    required this.keptFor,
    required this.maxRows,
    this.sendWhen,
    BackendPost? post,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    DateTime Function()? clock,
  }) : _post = post ?? _apiPost,
       _deviceId = deviceId ?? (() => DeviceService().getDeviceId()),
       _register =
           register ?? (() async => await DeviceService().registerDevice()),
       _clock = clock ?? DateTime.now;

  /// What the size probe measured, for POST /devices/{id}/size-probes.
  factory ReportQueue.sizeProbes({
    BackendPost? post,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    DateTime Function()? clock,
  }) => ReportQueue(
    storageKey: sizeProbesKey,
    path: 'size-probes',
    // The same wait as a door check that found every door closed, for the
    // same reason: the line a reading most needs to leave can hold it for
    // hours.
    keptFor: VpnEventReporter.closedProbesKeptFor,
    maxRows: VpnEventReporter.maxQueued,
    post: post,
    deviceId: deviceId,
    register: register,
    clock: clock,
  );

  /// The app's own upload tries, for POST /devices/{id}/delivery-log.
  ///
  /// Sent when a failed try is among them, or when the tries that worked
  /// fill more than one upload (see [failedOrFull]). A failure goes at
  /// once, with the tries around it that it is compared with (a 6 KB
  /// upload cut while a 1 KB one on the same route passed). Tries that
  /// worked go in full uploads, so they cost about one upload for every
  /// five the phone makes rather than one for each, and the backend still
  /// sees the phones whose uploads arrive: without them a share of failed
  /// uploads per carrier would count only phones that had a failure. The
  /// last few tries that worked wait for more to join them, and are
  /// dropped after [keptFor] if none do.
  factory ReportQueue.deliveryLog({
    BackendPost? post,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    DateTime Function()? clock,
  }) => ReportQueue(
    storageKey: deliveryLogKey,
    path: 'delivery-log',
    keptFor: VpnEventReporter.closedProbesKeptFor,
    maxRows: VpnEventReporter.maxQueued,
    sendWhen: failedOrFull,
    post: post,
    deviceId: deviceId,
    register: register,
    clock: clock,
  );

  /// What each connect tap did, for POST /devices/{id}/connect-traces. See
  /// ConnectTraces.
  ///
  /// Kept as long as a door check that found every door closed, for the
  /// same reason: the tap whose trace matters most is one that could not
  /// connect, from a line that may hold our uploads for hours. Each part of
  /// a trace is one row and is sent as it is stored, so a part sent again
  /// after a failed upload carries the same attempt id and part number.
  factory ReportQueue.connectTraces({
    BackendPost? post,
    Future<String> Function()? deviceId,
    Future<void> Function()? register,
    DateTime Function()? clock,
  }) => ReportQueue(
    storageKey: connectTracesKey,
    path: 'connect-traces',
    keptFor: VpnEventReporter.closedProbesKeptFor,
    maxRows: VpnEventReporter.maxQueued,
    post: post,
    deviceId: deviceId,
    register: register,
    clock: clock,
  );

  static const sizeProbesKey = 'fortiva_size_probes_queue';
  static const deliveryLogKey = 'fortiva_delivery_log_queue';
  static const connectTracesKey = 'fortiva_connect_traces_queue';

  /// Every queue's storage, for the sharing switch to drop.
  static const allKeys = [sizeProbesKey, deliveryLogKey, connectTracesKey];

  /// Where the rows are stored.
  final String storageKey;

  /// The endpoint under /api/v1/devices/{id}/.
  final String path;

  /// How long a row may wait for a route.
  final Duration keptFor;

  /// At most this many rows wait, the oldest dropped first.
  final int maxRows;

  /// Whether the waiting rows may be sent now. Null sends them always.
  final bool Function(List<Map<String, dynamic>> items)? sendWhen;

  final BackendPost _post;
  final Future<String> Function() _deviceId;
  final Future<void> Function() _register;
  final DateTime Function() _clock;

  /// For [deliveryLog]: whether any row is a try that failed, or the rows
  /// are more than one upload of at most
  /// [VpnEventReporter.probeUploadBytes] holds. A flush reads this again
  /// before every upload, so tries that worked go out in full uploads and
  /// the rest wait.
  static bool failedOrFull(List<Map<String, dynamic>> items) =>
      items.any((item) => item['ok'] == false) ||
      uploadBytes(items) > VpnEventReporter.probeUploadBytes;

  static Future<void> _apiPost(String path, Map<String, dynamic> body) async {
    await ApiClient().post(path, body: body);
  }

  /// Every change to any queue's storage, one at a time.
  static Future<void> _lock = Future.value();

  static Future<T> _serialized<T>(Future<T> Function() body) {
    final run = _lock.then((_) => body());
    _lock = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// The flush running now for each queue, in any instance, and the queues
  /// that had rows added while theirs ran. Shared by every instance for the
  /// same reason as VpnEventReporter's probe run: two flushes of one queue
  /// would both send the same upload.
  static final Map<String, Future<void>> _runs = {};
  static final Set<String> _again = {};

  /// Endpoints the backend answered 404 for after the device registered.
  /// That backend does not have them yet, so they are not tried again in
  /// this run of the app; the rows wait, in case a later run finds them.
  static final Set<String> _missing = {};

  /// The stored rows [addAndSend] is sending now, by id, in every queue. No
  /// flush sends them while it does, so a row is never in two uploads at
  /// once. The ids are made on this phone and are unique across queues.
  static final Set<String> _sendingNow = {};

  /// For each queue, the rows of each [addAndSend] call that could not send
  /// them all, one set of ids per call, the newest call last. [sendFirst]
  /// sends them, newest first, and only it does: a flush calls it before it
  /// sends the rest. Kept for this run of the app only. After a restart the
  /// rows are sent oldest first with the others.
  static final Map<String, List<Set<String>>> _first = {};

  static int _counter = 0;

  /// An id for one stored row, unique on this phone. It never leaves the
  /// phone: the row is sent without it.
  static String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  /// Store [items] at the end of the queue. Never throws.
  Future<void> add(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return Future.value();
    return addLater(() async => items);
  }

  /// Store what [build] returns, in the order this call was made.
  ///
  /// The place in line is taken now, before anything is awaited, and
  /// [build] runs when its turn comes. So rows added before a [flush] is
  /// called are read by that flush, even when building them waits on the
  /// platform. Never throws.
  Future<void> addLater(Future<List<Map<String, dynamic>>> Function() build) {
    return _serialized(() async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.get(VpnEventReporter.sharePrefKey) == false) return;
      final items = await build();
      if (items.isEmpty) return;
      final queue = _decode(await _stored(prefs));
      final at = _clock().toUtc().toIso8601String();
      for (final item in items) {
        queue.add({'id': _nextId(), 'at': at, 'item': item});
      }
      while (queue.length > maxRows) {
        queue.removeAt(0);
      }
      await _store(prefs, queue);
    }).catchError((Object e) {
      debugPrint('ReportQueue($path): could not store rows: $e');
    });
  }

  /// Store what [build] returns, as [addLater] does, and send those rows
  /// at once: in uploads of their own, ahead of the rows that were waiting
  /// already, and without waiting for a [flush] that is running. True when
  /// every one of them is done with (sent, refused for good, or dropped
  /// because sharing was turned off), false when some still wait.
  ///
  /// For a report that matters most the moment it is made, such as the
  /// trace of a tap that did not connect (ConnectTraces.send). A flush
  /// sends the oldest rows first and stops at the first upload no route
  /// carried. On 2026-10-23 a phone on a lossy line sent its waiting
  /// traces two or three at a time between timeouts, and the trace of one
  /// of its taps reached us 804 s after the tap.
  ///
  /// The rows are stored before they are sent, so an app closed during the
  /// send keeps them, and a flush leaves them alone until the send is done
  /// with them. The upload goes the way every call to the backend goes
  /// ([ApiClient.post]): the phone's own network, then the tunnel when one
  /// is up, then the relays. A row no route carried stays stored, and the
  /// next [sendFirst] sends it ahead of the rows that waited longer: a
  /// [flush] calls it before it sends the rest. The backend stores a row it
  /// already has once, so a send whose answer was lost costs nothing more
  /// when the row is sent again.
  Future<bool> addAndSend(
    Future<List<Map<String, dynamic>>> Function() build,
  ) async {
    Set<String> ids;
    try {
      ids = await _serialized(() async {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.get(VpnEventReporter.sharePrefKey) == false) {
          return const <String>{};
        }
        final items = await build();
        if (items.isEmpty) return const <String>{};
        final queue = _decode(await _stored(prefs));
        final at = _clock().toUtc().toIso8601String();
        final added = <String>{};
        for (final item in items) {
          final id = _nextId();
          added.add(id);
          queue.add({'id': id, 'at': at, 'item': item});
        }
        while (queue.length > maxRows) {
          queue.removeAt(0);
        }
        await _store(prefs, queue);
        // Inside the lock that stored them: no flush can read them before
        // they are marked.
        _sendingNow.addAll(added);
        return added;
      });
    } catch (e) {
      debugPrint('ReportQueue($path): could not store rows: $e');
      return false;
    }
    if (ids.isEmpty) return true;
    var done = false;
    try {
      return done = await _sendNow(ids);
    } catch (e) {
      debugPrint('ReportQueue($path): could not send rows now: $e');
      return false;
    } finally {
      // In one step with the release, so no flush can take them between.
      // A queue with [sendWhen] leaves them to it, in the flush's order.
      _sendingNow.removeAll(ids);
      if (!done && sendWhen == null) {
        final groups = _first.putIfAbsent(storageKey, () => []);
        groups.add(ids);
        while (groups.length > maxRows) {
          groups.removeAt(0);
        }
      }
    }
  }

  /// Send now the rows [addAndSend] could not send: the newest call's rows
  /// first, then the call's before it. It does not wait for a [flush] that
  /// is running, and it leaves alone rows another upload is sending now.
  /// It stops at the first upload no route carried. True when no such row
  /// is left to send, apart from rows another upload has. Never throws.
  ///
  /// So the trace of a tap whose own send failed is not put back behind
  /// the traces that waited longer. Before, a flush sent it after all of
  /// them and stopped at the first upload that failed. On 2026-10-23 40 of
  /// 139 taps that found every door closed had a failed upload try of
  /// their trace before it arrived, and one phone on a lossy line sent two
  /// or three uploads between 10 s timeouts. ConnectFlow calls this, through
  /// ConnectTraces.sendWaiting, before the config request of each try it
  /// makes after a wait, and every flush calls it before the other rows.
  Future<bool> sendFirst() async {
    final groups = _first[storageKey];
    if (groups == null || groups.isEmpty) return true;
    for (final group in groups.reversed.toList()) {
      // Sent by another call while this one sent a newer one.
      if (!groups.contains(group)) continue;
      // Another call is sending these now.
      if (group.any(_sendingNow.contains)) continue;
      _sendingNow.addAll(group);
      var done = false;
      try {
        done = await _sendNow(group);
      } catch (e) {
        debugPrint('ReportQueue($path): could not send rows first: $e');
      } finally {
        _sendingNow.removeAll(group);
      }
      if (!done) return false;
      groups.remove(group);
    }
    return true;
  }

  /// Send the stored rows [ids], oldest first, as [_flushOnce] sends the
  /// queue, and stop at the first upload no route carried. Rows that waited
  /// longer than [keptFor] are not sent: the next flush drops them.
  Future<bool> _sendNow(Set<String> ids) async {
    if (_missing.contains(path)) return false;
    final left = {...ids};
    while (left.isNotEmpty) {
      final now = _clock();
      final piece = await _serialized(() async {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.get(VpnEventReporter.sharePrefKey) == false) {
          await prefs.remove(storageKey);
          return const <Map<String, dynamic>>[];
        }
        final mine = [
          for (final entry in _decode(await _stored(prefs)))
            if (left.contains(entry['id']) && _youngerThan(entry['at'], now))
              entry,
        ];
        final when = sendWhen;
        if (mine.isNotEmpty &&
            when != null &&
            !when([for (final e in mine) _item(e)])) {
          return null;
        }
        return head(mine);
      });
      // Not now: they wait for a flush.
      if (piece == null) return false;
      // Gone from the queue: sharing was turned off, or newer rows pushed
      // them out.
      if (piece.isEmpty) return true;
      final sent = {for (final entry in piece) entry['id'] as String};
      left.removeAll(sent);
      if (!await _deliver([for (final e in piece) _item(e)])) return false;
      await _serialized(() async {
        final prefs = await SharedPreferences.getInstance();
        final queue = _decode(await _stored(prefs));
        await _store(prefs, [
          for (final entry in queue)
            if (!sent.contains(entry['id'])) entry,
        ]);
      });
    }
    return true;
  }

  /// Send what is waiting. One run at a time per queue, across instances;
  /// a call made while one runs waits for it, and a call that has just
  /// [queued] rows makes it go round once more. Never throws.
  Future<void> flush({bool queued = false}) {
    final running = _runs[storageKey];
    if (running != null) {
      if (queued) _again.add(storageKey);
      return running;
    }
    final run = _rounds();
    _runs[storageKey] = run;
    return run;
  }

  Future<void> _rounds() async {
    try {
      for (var round = 0; round < VpnEventReporter.maxRounds; round++) {
        _again.remove(storageKey);
        try {
          await _flushOnce();
        } catch (e) {
          debugPrint('ReportQueue($path): flush error: $e');
        }
        if (!_again.contains(storageKey)) return;
      }
    } finally {
      _runs.remove(storageKey);
    }
  }

  Future<void> _flushOnce() async {
    if (_missing.contains(path)) return;
    // The rows an [addAndSend] could not send go before the rows that
    // waited longer. When one of their uploads failed, so would the rest.
    if (!await sendFirst()) return;
    final sent = <String>{};
    while (true) {
      // Read again every round: rows added while the last upload was in
      // flight are in the stored queue, not in any copy of it.
      final now = _clock();
      final piece = await _serialized(() async {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.get(VpnEventReporter.sharePrefKey) == false) {
          await prefs.remove(storageKey);
          return null;
        }
        final queue = _decode(await _stored(prefs));
        final fresh = [
          for (final entry in queue)
            if (_youngerThan(entry['at'], now)) entry,
        ];
        if (fresh.length != queue.length) await _store(prefs, fresh);
        // Rows [addAndSend] is sending now are its own until it is done
        // with them, and the rows it could not send are [sendFirst]'s.
        final first = {...?_first[storageKey]?.expand((ids) => ids)};
        final waiting = [
          for (final entry in fresh)
            if (!sent.contains(entry['id']) &&
                !_sendingNow.contains(entry['id']) &&
                !first.contains(entry['id']))
              entry,
        ];
        if (waiting.isEmpty) return null;
        final when = sendWhen;
        if (when != null && !when([for (final e in waiting) _item(e)])) {
          return null;
        }
        return head(waiting);
      });
      if (piece == null) return;
      final ids = {for (final entry in piece) entry['id'] as String};
      sent.addAll(ids);
      if (!await _deliver([for (final e in piece) _item(e)])) return;
      await _serialized(() async {
        final prefs = await SharedPreferences.getInstance();
        final queue = _decode(await _stored(prefs));
        await _store(prefs, [
          for (final entry in queue)
            if (!ids.contains(entry['id'])) entry,
        ]);
      });
    }
  }

  /// The oldest of [waiting] that fit in one upload of at most
  /// [VpnEventReporter.probeUploadBytes]. A row that is larger on its own
  /// goes alone.
  @visibleForTesting
  static List<Map<String, dynamic>> head(List<Map<String, dynamic>> waiting) {
    final piece = <Map<String, dynamic>>[];
    for (final entry in waiting) {
      if (piece.isNotEmpty &&
          uploadBytes([...piece.map(_item), _item(entry)]) >
              VpnEventReporter.probeUploadBytes) {
        break;
      }
      piece.add(entry);
    }
    return piece;
  }

  /// The size of the body one upload of [items] has, with the longest
  /// `sent_at` the clock writes. ConnectTrace cuts a trace into parts by
  /// it.
  static int uploadBytes(List<Map<String, dynamic>> items) => utf8
      .encode(
        jsonEncode({'items': items, 'sent_at': '2026-10-07T10:17:41.123456Z'}),
      )
      .length;

  static Map<String, dynamic> _item(Map<String, dynamic> entry) =>
      (entry['item'] as Map).cast<String, dynamic>();

  /// Send one upload. True when it is done with: sent, or refused for good.
  Future<bool> _deliver(List<Map<String, dynamic>> items) async {
    final deviceId = await _deviceId();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _post('/api/v1/devices/$deviceId/$path', {
          'items': items,
          // Read on every try, so rows that waited say when they really
          // left.
          'sent_at': _clock().toUtc().toIso8601String(),
        });
        return true;
      } on ApiException catch (e) {
        if (VpnEventReporter.refusedForGood(e)) {
          debugPrint('ReportQueue($path): backend refused rows, dropped: $e');
          return true;
        }
        if (!e.isNotFound) return false;
        if (attempt > 0) {
          // Registered, and still not found: the endpoint is not there.
          _missing.add(path);
          return false;
        }
        try {
          await _register();
        } catch (e) {
          debugPrint('ReportQueue($path): could not register: $e');
          return false;
        }
      } catch (e) {
        debugPrint('ReportQueue($path): could not send: $e');
        return false;
      }
    }
    return false;
  }

  bool _youngerThan(Object? stamp, DateTime now) {
    final at = DateTime.tryParse(stamp?.toString() ?? '');
    return at != null && now.difference(at) < keptFor;
  }

  /// The queue as stored, not as this engine last saw it: the keeper's
  /// engine sends and removes rows too. See StoredFromBackground.current.
  Future<String?> _stored(SharedPreferences prefs) =>
      StoredFromBackground.current(prefs, storageKey);

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .where((m) => m['id'] is String && m['item'] is Map)
          .map((m) => m.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _store(
    SharedPreferences prefs,
    List<Map<String, dynamic>> queue,
  ) async {
    if (queue.isEmpty) {
      await prefs.remove(storageKey);
    } else {
      await prefs.setString(storageKey, jsonEncode(queue));
    }
  }

  /// The rows waiting, oldest first, as they will be sent, including rows
  /// whose [addLater] was called before this. For tests and diagnostics.
  Future<List<Map<String, dynamic>>> pending() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    return [for (final e in _decode(await _stored(prefs))) _item(e)];
  });

  /// Drop every row of the queues stored under [keys]. In line with every
  /// other change, so a row being added now cannot land after the drop.
  static Future<void> clear(Iterable<String> keys) => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in keys) {
      await prefs.remove(key);
    }
  });

  @visibleForTesting
  static void resetForTest() {
    _runs.clear();
    _again.clear();
    _missing.clear();
    _sendingNow.clear();
    _first.clear();
  }
}
