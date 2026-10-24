import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/app_config_service.dart';
import '../core/form_factor.dart';
import '../data/models/psiphon_settings.dart';

/// The backup network's server list, kept on the phone for the tunnel
/// (clients #299).
///
/// The network's very first connection is faster when its library starts
/// with a list of servers. The backend serves one at
/// /app/psiphon/server-entries and names its sha256 in the config
/// ([PsiphonSettings.serverEntriesSha]). This downloads it when that sha
/// changes, checks it, and keeps it at `<files>/psiphon/server_entries`,
/// where `<files>` is the folder Android's `Context.getFilesDir` names.
/// The tunnel's own process reads it from there, and the app hands it the
/// path when it dials the network ([fileFor]).
///
/// [sync] runs in the background whenever the settings load and never
/// holds up a tap. A download that fails, or whose sha256 is not the one
/// the config named, leaves the file and the saved sha as they were. A try
/// that reached nothing is made again at the next settings load; one that
/// failed after the backend answered waits [retryAfter] first. A config
/// with no sha deletes the file and the saved sha.
///
/// Android only. The file's contents are never logged.
class PsiphonEntries {
  PsiphonEntries({
    Future<Uint8List> Function()? download,
    Future<Directory> Function()? filesDir,
    bool Function()? android,
    bool Function()? tv,
    DateTime Function()? now,
  }) : _download = download ?? AppConfigService().getPsiphonServerEntries,
       _filesDir = filesDir ?? getApplicationSupportDirectory,
       _android = android ?? _isAndroid,
       _tv = tv ?? _isTv,
       _now = now ?? DateTime.now;

  /// The one the app uses: AppConfigState keeps it in line with the
  /// settings, and VpnService asks it for the file.
  static final instance = PsiphonEntries();

  /// Where the sha256 of the kept file is saved. Set only once the file
  /// that has it is in place.
  static const shaKey = 'psiphon_entries_sha';

  /// Where a try that failed after the backend answered is noted: the sha
  /// it was for, a space, and when it failed in milliseconds since the
  /// epoch. Cleared once a list is in place, and with the list.
  static const failedKey = 'psiphon_entries_failed';

  /// How long the same list waits before it is tried again after a try
  /// that failed once the backend had answered: the answer was an error,
  /// the body was cut off or did not match its sha, or the file could not
  /// be written. Each of those can cost the phone's data, and a phone that
  /// cannot download the list would otherwise pay again at every settings
  /// load. A try that reached nothing downloaded nothing, and the next
  /// settings load tries again. A new sha is tried at once.
  static const retryAfter = Duration(hours: 1);

  /// The folder under `<files>` the file is kept in. The tunnel's process
  /// gives the network's library the same folder as its data root.
  static const folder = 'psiphon';

  static const fileName = 'server_entries';

  final Future<Uint8List> Function() _download;
  final Future<Directory> Function() _filesDir;
  final bool Function() _android;
  final bool Function() _tv;
  final DateTime Function() _now;

  static bool _isAndroid() => Platform.isAndroid;
  static bool _isTv() => FormFactor.isTv;

  /// Each [sync] runs after the one before it has ended, so two never
  /// write the file at once.
  Future<void> _queue = Future<void>.value();

  /// The settings of the newest [sync] asked for. A sync that waited
  /// behind another works with these, not the ones it was asked with.
  PsiphonSettings? _wanted;

  File? _file;

  /// Where the file is kept. Asked of the platform until it answers once.
  Future<File> _target() async =>
      _file ??= File('${(await _filesDir()).path}/$folder/$fileName');

  /// Bring the kept file in line with [settings], the settings now in
  /// force: download it when the sha has changed or the file is gone,
  /// delete it when there is no sha. Never throws.
  Future<void> sync(PsiphonSettings? settings) {
    _wanted = settings;
    return _queue = _queue.then((_) => _sync());
  }

  Future<void> _sync() async {
    try {
      if (!_android()) return;
      final settings = _wanted;
      final sha = settings == null || (_tv() && !settings.tv)
          ? null
          : settings.serverEntriesSha;
      final file = await _target();
      final prefs = await SharedPreferences.getInstance();
      if (sha == null) {
        await _delete(file);
        await prefs.remove(shaKey);
        await prefs.remove(failedKey);
        return;
      }
      if (prefs.getString(shaKey) == sha && await file.exists()) return;
      if (_waiting(prefs.getString(failedKey), sha)) {
        debugPrint(
          'PsiphonEntries: the last try for this server list failed; '
          'trying again later',
        );
        return;
      }
      final Uint8List body;
      try {
        body = await _download();
      } catch (e) {
        if (!_reachedNothing(e)) await _noteFailed(prefs, sha);
        rethrow;
      }
      if (sha256.convert(body).toString() != sha) {
        await _noteFailed(prefs, sha);
        debugPrint(
          'PsiphonEntries: the server list does not match its sha; '
          'keeping the one on the phone',
        );
        return;
      }
      try {
        await _write(file, body);
      } catch (_) {
        await _noteFailed(prefs, sha);
        rethrow;
      }
      await prefs.setString(shaKey, sha);
      await prefs.remove(failedKey);
    } catch (e) {
      // The bytes are never in the message: a failed download names the
      // route, and a failed write names the path.
      debugPrint('PsiphonEntries: could not update the server list ($e)');
    }
  }

  /// Whether a download that failed with [e] reached nothing: no route
  /// carried the call (ApiClient's status 0, or a timeout or socket error
  /// on every route), so nothing was downloaded.
  static bool _reachedNothing(Object e) =>
      e is ApiException && e.statusCode == 0 ||
      e is TimeoutException ||
      e is IOException;

  Future<void> _noteFailed(SharedPreferences prefs, String sha) =>
      prefs.setString(failedKey, '$sha ${_now().millisecondsSinceEpoch}');

  /// Whether [noted], what [failedKey] holds, says a try for [sha] failed
  /// less than [retryAfter] ago. A time ahead of the clock, as after the
  /// clock was set back, does not hold the list back.
  bool _waiting(String? noted, String sha) {
    final parts = noted?.split(' ');
    if (parts == null || parts.length != 2 || parts[0] != sha) return false;
    final at = int.tryParse(parts[1]);
    if (at == null) return false;
    final since = _now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    return !since.isNegative && since < retryAfter;
  }

  /// Writes [body] next to [file] and then moves it into place, so the
  /// tunnel never reads a list that is half written.
  static Future<void> _write(File file, Uint8List body) async {
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    try {
      await part.writeAsBytes(body, flush: true);
      await part.rename(file.path);
    } catch (_) {
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<void> _delete(File file) async {
    for (final f in [file, File('${file.path}.part')]) {
      if (await f.exists()) await f.delete();
    }
  }

  /// The absolute path of the kept file, for the tunnel to start the
  /// network with, when it is the list [settings] name: the file is there
  /// and its saved sha is the settings' sha. Null otherwise, and on
  /// anything that is not Android. Never throws.
  Future<String?> fileFor(PsiphonSettings settings) async {
    try {
      if (!_android()) return null;
      final sha = settings.serverEntriesSha;
      if (sha == null) return null;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(shaKey) != sha) return null;
      final file = await _target();
      return await file.exists() ? file.absolute.path : null;
    } catch (e) {
      debugPrint('PsiphonEntries: could not look for the server list ($e)');
      return null;
    }
  }
}
