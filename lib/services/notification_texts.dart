import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import '../l10n/generated/app_localizations.dart';

/// The Android notification's two texts, saved in the language the person
/// chose in the app. NotificationService.kt reads them, because Android's
/// resources hold only English and the services run with the phone's language.
/// Nothing saved means English.
///
/// They have a small file of their own, because the tunnel's process must never
/// open Flutter's preferences file. Opening a preferences file puts its backup
/// back over the file when a backup exists, and one exists while the main
/// process is saving, so that open would undo the save. It would also parse the
/// whole file on that process's main thread, just before the foreground start.
class NotificationTexts {
  NotificationTexts._();

  /// The file and its keys. NotificationService.kt names the same three.
  static const fileName = 'notification_texts';
  static const connectingKey = 'connecting';
  static const stopKey = 'stop';

  /// The store to use on any platform (tests). Without it, only Android saves.
  @visibleForTesting
  static SharedPreferencesAsync? storeOverride;

  static final _android = SharedPreferencesAsync(
    options: const SharedPreferencesAsyncAndroidOptions(
      backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
      originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
        fileName: fileName,
      ),
    ),
  );

  static SharedPreferencesAsync? get _store =>
      storeOverride ?? (Platform.isAndroid ? _android : null);

  /// Saves both texts in [locale]. Android writes nothing to disk when a text
  /// has not changed. Never throws, because the app's language applies without
  /// this and the notification then stays in the language it had.
  static Future<void> save(Locale locale) async {
    try {
      final store = _store;
      if (store == null) return;
      final s = lookupS(locale);
      await store.setString(connectingKey, s.statusConnecting);
      await store.setString(stopKey, s.stop);
    } catch (e) {
      debugPrint('NotificationTexts: not saved ($e)');
    }
  }

  /// Removes both texts, so the notification is in English. Never throws.
  static Future<void> clear() async {
    try {
      final store = _store;
      if (store == null) return;
      await store.remove(connectingKey);
      await store.remove(stopKey);
    } catch (e) {
      debugPrint('NotificationTexts: not removed ($e)');
    }
  }
}
