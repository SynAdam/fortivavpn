import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/services/notification_texts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A store whose save never answers.
final class _NeverAnswers extends InMemorySharedPreferencesAsync {
  _NeverAnswers() : super.empty();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => Completer<bool>().future;
}

/// A store whose save fails.
final class _Broken extends InMemorySharedPreferencesAsync {
  _Broken() : super.empty();

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => Future.error(StateError('no disk'));
}

/// The Android notification follows the language the person chose in the app.
/// Android's resources hold English, and Flutter saves the two translated
/// texts in a small file of their own, where NotificationService.kt reads them.
void main() {
  void useStore(SharedPreferencesAsyncPlatform platform) {
    SharedPreferencesAsyncPlatform.instance = platform;
    NotificationTexts.storeOverride = SharedPreferencesAsync();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    useStore(InMemorySharedPreferencesAsync.empty());
  });

  tearDown(() => NotificationTexts.storeOverride = null);

  /// The text under [key] in one language's translation file.
  String arb(String code, String key) =>
      (jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
              as Map)[key]
          as String;

  /// What is saved, once the saves LocaleState does not wait for have ended.
  Future<(String?, String?)> saved() async {
    await pumpEventQueue();
    final store = SharedPreferencesAsync();
    return (
      await store.getString(NotificationTexts.connectingKey),
      await store.getString(NotificationTexts.stopKey),
    );
  }

  group('setting the language', () {
    for (final code in LocaleState.supportedLanguages.keys) {
      test('saves the two texts in $code', () async {
        await LocaleState().setLocale(Locale(code));
        expect(await saved(), (
          arb(code, 'statusConnecting'),
          arb(code, 'stop'),
        ));
      });
    }

    test('replaces the texts of the language before', () async {
      final state = LocaleState();
      await state.setLocale(const Locale('fa'));
      await state.setLocale(const Locale('de'));
      expect(await saved(), (arb('de', 'statusConnecting'), arb('de', 'stop')));
    });

    test('twice at once ends on the last language', () async {
      final state = LocaleState();
      await state.setLocale(const Locale('en'));
      await saved();
      unawaited(state.setLocale(const Locale('fa')));
      unawaited(state.setLocale(const Locale('en')));
      expect(await saved(), (arb('en', 'statusConnecting'), arb('en', 'stop')));
    });

    test('in a language the app does not have still sets it', () async {
      final state = LocaleState();
      await state.setLocale(const Locale('sv'));
      expect(state.locale, const Locale('sv'));
      expect(await saved(), (null, null));
    });

    test('a store that fails still sets the language', () async {
      useStore(_Broken());
      final state = LocaleState();
      await state.setLocale(const Locale('ru'));
      await pumpEventQueue();
      expect(state.locale, const Locale('ru'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleState.prefKey), 'ru');
    });
  });

  group('at startup', () {
    test('a saved language saves the two texts', () async {
      SharedPreferences.setMockInitialValues({LocaleState.prefKey: 'ru'});
      await LocaleState().loadLocale();
      expect(await saved(), (arb('ru', 'statusConnecting'), arb('ru', 'stop')));
    });

    test('a text changed in a new build replaces the old one', () async {
      SharedPreferences.setMockInitialValues({LocaleState.prefKey: 'ru'});
      await SharedPreferencesAsync().setString(
        NotificationTexts.connectingKey,
        'an older text',
      );
      await SharedPreferencesAsync().setString(
        NotificationTexts.stopKey,
        'an older text',
      );
      await LocaleState().loadLocale();
      expect(await saved(), (arb('ru', 'statusConnecting'), arb('ru', 'stop')));
    });

    test('no choice yet saves nothing, so the notification is in '
        'English', () async {
      await LocaleState().loadLocale();
      expect(await saved(), (null, null));
    });

    // main() waits for loadLocale before the first frame.
    test('a store that never answers does not hold the app back', () async {
      SharedPreferences.setMockInitialValues({LocaleState.prefKey: 'ru'});
      useStore(_NeverAnswers());
      final state = LocaleState();
      await state.loadLocale().timeout(const Duration(seconds: 5));
      expect(state.isLoading, isFalse);
      expect(state.locale, const Locale('ru'));
    });

    test('a store that fails does not stop the app', () async {
      SharedPreferences.setMockInitialValues({LocaleState.prefKey: 'ru'});
      useStore(_Broken());
      final state = LocaleState();
      await state.loadLocale();
      await pumpEventQueue();
      expect(state.locale, const Locale('ru'));
      expect(state.hasChosen, isTrue);
    });
  });

  test('resetting the language removes the texts', () async {
    final state = LocaleState();
    await state.setLocale(const Locale('fa'));
    await saved();
    await state.resetToSystem();
    expect(await saved(), (null, null));
  });

  group('the Android side', () {
    final kotlin = File(
      'android/app/src/main/java/com/vpn/fortivavpn/service/'
      'NotificationService.kt',
    ).readAsStringSync();

    test('reads the file and the keys Flutter saves', () {
      expect(kotlin, contains('"${NotificationTexts.fileName}"'));
      expect(kotlin, contains('"${NotificationTexts.connectingKey}"'));
      expect(kotlin, contains('"${NotificationTexts.stopKey}"'));
      expect(kotlin, contains('getSharedPreferences(TEXTS_FILE'));
    });

    // The services run in the tunnel's process. Opening that file there can
    // undo a save the main process is making.
    test('never opens Flutter\'s own preferences file', () {
      expect(kotlin, isNot(contains('"FlutterSharedPreferences"')));
    });

    test('res/values is English, with no Arabic script in it', () {
      final strings = File(
        'android/app/src/main/res/values/strings.xml',
      ).readAsStringSync();
      expect(strings, isNot(contains(RegExp('[؀-ۿ]'))));
      expect(strings, contains('>${arb('en', 'statusConnecting')}<'));
      expect(strings, contains('>${arb('en', 'stop')}<'));
    });
  });
}
