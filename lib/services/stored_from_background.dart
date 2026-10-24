import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// Values the background engine writes (NoticeJobService runs NoticePull
/// while the app is off screen), read again in the app's own engine.
///
/// Each engine keeps its own copy of the stored values.
/// SharedPreferences.reload replaced the app's whole copy with the
/// platform's, and a value the app saved while that read was on its way was
/// dropped from the copy, then from storage at the next save of the same
/// key. On 2026-10-16 the in-app messages check reloaded about three
/// seconds after every connect, and the connected event saved at that
/// moment was lost that way. This reads only the keys asked for and puts
/// them in the app's copy, so nothing else the app saved is touched.
class StoredFromBackground {
  StoredFromBackground._();

  /// Reads one stored string as the platform holds it (tests).
  @visibleForTesting
  static Future<String?> Function(String key)? readOverride;

  /// The file the app's SharedPreferences keep their values in, with the
  /// prefix they put on every key.
  static final _android = SharedPreferencesAsync(
    options: const SharedPreferencesAsyncAndroidOptions(
      backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
      originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
        fileName: 'FlutterSharedPreferences',
      ),
    ),
  );

  /// Bring the string values of [keys] in [prefs] up to what the platform
  /// holds. Only Android has a background engine; elsewhere nothing
  /// changes. A key the platform does not hold is left as it is. Never
  /// throws.
  static Future<void> refresh(
    SharedPreferences prefs,
    Iterable<String> keys,
  ) async {
    final read =
        readOverride ??
        (Platform.isAndroid
            ? (String k) => _android.getString('flutter.$k')
            : null);
    if (read == null) return;
    for (final key in keys) {
      try {
        final value = await read(key);
        if (value != null && prefs.getString(key) != value) {
          await prefs.setString(key, value);
        }
      } catch (e) {
        debugPrint('StoredFromBackground: could not read $key ($e)');
      }
    }
  }
}
