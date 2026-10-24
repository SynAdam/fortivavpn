import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/version_info.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/settings_screen.dart';
import 'package:fortiva_vpn/screens/support_screen.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every link to the Telegram channel opens the one the backend names in
/// GET /api/v1/app/config: Contact us in Settings while the chat is off,
/// the support chat's fallback and the update prompt.
///
/// force_update.android.channel_url is the channel APK's update link, old
/// builds included, so it always points at a page with the current APK.
/// Google Play does not let a Play app link to a page that could lead to
/// another way to pay, so the Play build opens play_channel_url instead
/// when the backend sends one, and the channel APK never does. Until the
/// backend says otherwise, nothing changes: every link still opens
/// https://t.me/fortiva_vpn, and a value that is not an https link to a
/// page on t.me is never opened.
///
/// The value is read while the whole app config is parsed, and one throw
/// there loses the config: feature flags, the TLS spec, relays and the
/// update rules. So no value of it may throw.

const _official = 'https://t.me/fortiva_vpn';

Map<String, dynamic> _configJson({
  Object? channelUrl,
  Object? playChannelUrl,
  Map<String, dynamic>? flags,
}) => {
  'privacy_policy_url': 'https://example.com/privacy',
  'terms_of_service_url': 'https://example.com/terms',
  'eula_url': 'https://example.com/eula',
  'support_email': 'support@example.com',
  'force_update': {
    for (final os in ['ios', 'android'])
      os: {
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'https://example.com/update',
        if (os == 'android' && channelUrl != null) 'channel_url': channelUrl,
        if (os == 'android' && playChannelUrl != null)
          'play_channel_url': playChannelUrl,
      },
  },
  'feature_flags': ?flags,
};

AppConfig _config({Object? channelUrl, Object? playChannelUrl}) =>
    AppConfig.fromJson(
      _configJson(channelUrl: channelUrl, playChannelUrl: playChannelUrl),
    );

/// Links whose path has a percent escape that is not UTF-8. Uri.tryParse
/// takes them, and Uri.pathSegments throws on them.
const _undecodable = ['https://t.me/%D8', 'https://t.me/fortiva%E2%80'];

Future<AppConfig> _unreachable() async => throw Exception('no route');

/// The config state after a fetch that answered [channelUrl], or none
/// when [channelUrl] is null.
Future<AppConfigState> _loaded(
  Object? channelUrl, {
  Object? playChannelUrl,
}) async {
  final state = AppConfigState(
    fetch: () async =>
        _config(channelUrl: channelUrl, playChannelUrl: playChannelUrl),
    retryGaps: const [],
  );
  await state.load();
  return state;
}

class _FakeDedicated extends DedicatedState {
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('which links count as the channel', () {
    for (final url in [
      _official,
      'https://t.me/fortiva_news',
      'https://t.me/fortiva_vpn/123',
      'https://t.me/+AbCdEf123',
      '  https://t.me/fortiva_vpn  ',
    ]) {
      test('opens $url', () => expect(PlatformVersion.isChannelUrl(url), true));
    }

    for (final url in [
      '',
      'https://t.me',
      'https://t.me/',
      'http://t.me/fortiva_vpn',
      'tg://resolve?domain=fortiva_vpn',
      'https://example.com/fortiva_vpn',
      'https://t.me.example.com/fortiva_vpn',
      'https://telegram.me/fortiva_vpn',
      'https://user@t.me/fortiva_vpn',
      'javascript:alert(1)',
      't.me/fortiva_vpn',
    ]) {
      test('never opens "$url"', () {
        expect(PlatformVersion.isChannelUrl(url), isFalse);
        expect(PlatformVersion.channelUrlFrom(url), _official);
      });
    }

    test('a value that is not text is the official channel', () {
      for (final value in <Object?>[
        null,
        42,
        true,
        const ['x'],
        const {},
      ]) {
        expect(PlatformVersion.channelUrlFrom(value), _official);
      }
    });

    test('the update prompt reads channel_url the same way', () {
      PlatformVersion android(Object? channel) => PlatformVersion.fromJson({
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'https://example.com/update',
        'channel_url': channel,
      });
      expect(
        android('https://t.me/fortiva_news').channelUrl,
        'https://t.me/fortiva_news',
      );
      expect(android('https://example.com/pay').channelUrl, _official);
      expect(android('http://t.me/fortiva_news').channelUrl, _official);
    });
  });

  group('a value that cannot be decoded', () {
    tearDown(() => StandbyDoors.enabled = false);

    for (final url in _undecodable) {
      test('"$url" is never opened, and never throws', () {
        expect(PlatformVersion.isChannelUrl(url), isFalse);
        expect(PlatformVersion.channelUrlFrom(url), _official);
      });

      test('"$url" leaves the rest of the config standing', () async {
        // The rest of the config is what a throw here would lose.
        final json = _configJson(
          channelUrl: url,
          playChannelUrl: url,
          flags: {'standby_doors': true},
        );
        final config = AppConfig.fromJson(json);
        expect(config.forceUpdate.android.channelUrl, _official);
        expect(config.forceUpdate.android.playChannelUrl, isNull);

        final state = AppConfigState(
          fetch: () async => AppConfig.fromJson(json),
          retryGaps: const [],
        );
        await state.load();
        expect(state.config, isNotNull);
        expect(state.flags.standbyDoors, isTrue);
        expect(StandbyDoors.enabled, isTrue);
        expect(state.channelUrl, Uri.parse(_official));
      });

      test('"$url" saved by an older build is the official channel', () async {
        final rules = _config().forceUpdate.toJson();
        (rules['android'] as Map)['channel_url'] = url;
        SharedPreferences.setMockInitialValues({
          AppConfigState.versionRulesKey: jsonEncode(rules),
        });
        final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
        await next.load();
        expect(next.versionRules, isNotNull);
        expect(next.channelUrl, Uri.parse(_official));
      });

      test('"$url" names no channel', () {
        expect(PlatformVersion.channelHandle(Uri.parse(url)), isNull);
      });
    }

    test('optional fields of the wrong type do not throw', () {
      final android = PlatformVersion.fromJson({
        'latest_version': '1.0.0',
        'minimum_version': '1.0.0',
        'update_url': 'https://example.com/update',
        'update_required': 'yes',
        'release_notes': 42,
        'channel_url': 7,
        'play_channel_url': const ['x'],
      });
      expect(android.updateRequired, isFalse);
      expect(android.releaseNotes, isNull);
      expect(android.channelUrl, _official);
      expect(android.playChannelUrl, isNull);
    });
  });

  // Every copy runs the same code as the one on Google Play, so every copy
  // opens play_channel_url when the backend sends one: it may point at a
  // page that sells nothing. channel_url stays the update link of every
  // channel APK.
  group('play_channel_url', () {
    const apkChannel = 'https://t.me/fortiva_vpn';
    const playChannel = 'https://t.me/fortiva_news';

    PlatformVersion android({Object? channel, Object? play}) =>
        PlatformVersion.fromJson({
          'latest_version': '1.0.0',
          'minimum_version': '1.0.0',
          'update_url': 'https://example.com/update',
          'channel_url': ?channel,
          'play_channel_url': ?play,
        });

    test('every copy opens it when the backend sends one', () {
      final v = android(channel: apkChannel, play: playChannel);
      expect(v.channelLink, playChannel);
      // channel_url is still read and kept, for the channel APK's update.
      expect(v.channelUrl, apkChannel);
    });

    // Only the APK posted on channel_url updates a copy Google did not sign.
    test('the update of a copy Google did not sign opens channel_url', () {
      final v = android(channel: apkChannel, play: playChannel);
      expect(v.updateChannelFor(googleSigned: false), apkChannel);
      expect(v.updateChannelFor(googleSigned: true), playChannel);

      final without = android(channel: apkChannel);
      expect(without.updateChannelFor(googleSigned: false), apkChannel);
      expect(without.updateChannelFor(googleSigned: true), apkChannel);
    });

    test('without it, every copy opens channel_url', () {
      final v = android(channel: apkChannel);
      expect(v.playChannelUrl, isNull);
      expect(v.channelLink, apkChannel);
    });

    test('a value that is not a channel link is ignored', () {
      for (final bad in <Object?>[
        'https://example.com/pay',
        'http://t.me/fortiva_news',
        '',
        42,
        ..._undecodable,
      ]) {
        final v = android(channel: apkChannel, play: bad);
        expect(v.playChannelUrl, isNull, reason: '$bad');
        expect(v.channelLink, apkChannel, reason: '$bad');
      }
    });

    test('is kept between launches, and left out when absent', () {
      final v = android(channel: apkChannel, play: playChannel);
      expect(PlatformVersion.fromJson(v.toJson()).playChannelUrl, playChannel);
      expect(
        android(channel: apkChannel).toJson(),
        isNot(contains('play_channel_url')),
      );
    });

    test('AppConfigState opens it', () async {
      final state = await _loaded(apkChannel, playChannelUrl: playChannel);
      expect(state.channelUrl, Uri.parse(playChannel));

      // And on a launch that cannot reach the backend.
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.channelUrl, Uri.parse(playChannel));
    });
  });

  group('the name shown next to Telegram', () {
    for (final (url, handle) in [
      (_official, '@fortiva_vpn'),
      ('https://t.me/fortiva_news', '@fortiva_news'),
      ('https://t.me/fortiva_vpn/123', '@fortiva_vpn'),
      ('https://t.me/+AbCdEf123', null),
      ('https://t.me/joinchat/AbCdEf', null),
      ('https://t.me/s/fortiva_vpn', null),
      ('https://t.me/abc', null),
    ]) {
      test('$url shows ${handle ?? 'no name'}', () {
        expect(PlatformVersion.channelHandle(Uri.parse(url)), handle);
      });
    }
  });

  group('AppConfigState.channelUrl', () {
    test('is the official channel before the backend has answered', () {
      final state = AppConfigState(fetch: _unreachable, retryGaps: const []);
      expect(state.channelUrl, Uri.parse(_official));
    });

    test('is the official channel when the backend sends none', () async {
      expect((await _loaded(null)).channelUrl, Uri.parse(_official));
    });

    test('is the channel the backend sends', () async {
      final state = await _loaded('https://t.me/fortiva_news');
      expect(state.channelUrl, Uri.parse('https://t.me/fortiva_news'));
    });

    test('ignores a value that is not a channel link', () async {
      for (final bad in ['https://example.com/pay', '', 7]) {
        final state = await _loaded(bad);
        expect(state.channelUrl, Uri.parse(_official), reason: '$bad');
      }
    });

    test('keeps the backend\'s channel for a launch that cannot reach '
        'it', () async {
      await _loaded('https://t.me/fortiva_news');
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.channelUrl, Uri.parse('https://t.me/fortiva_news'));
    });

    test('a value saved by an older build that is not a channel link is '
        'not opened', () async {
      final rules = _config().forceUpdate.toJson();
      (rules['android'] as Map)['channel_url'] = 'https://example.com/pay';
      SharedPreferences.setMockInitialValues({
        AppConfigState.versionRulesKey: jsonEncode(rules),
      });
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.versionRules, isNotNull);
      expect(next.channelUrl, Uri.parse(_official));
    });
  });

  group('Contact us in Settings, with the chat off', () {
    late List<String> launched;

    setUp(() {
      launched = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              if (call.method == 'launch') {
                launched.add((call.arguments as Map)['url'] as String);
              }
              return true;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          );
    });

    Future<void> pumpSettings(
      WidgetTester tester,
      AppConfigState config,
    ) => tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppConfigState>.value(value: config),
          ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          ChangeNotifierProvider<ReferralState>(create: (_) => ReferralState()),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: const SettingsScreen(),
        ),
      ),
    );

    Future<void> tapContact(WidgetTester tester) async {
      final tile = find.text('Contact Us');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // The list builds tiles a little past the bottom edge, so the tile
      // can be found and still be off the screen.
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pump();
    }

    testWidgets('opens the official channel, as before, until the backend '
        'names another', (tester) async {
      final config = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await pumpSettings(tester, config);
      await tester.pumpAndSettle();

      await tapContact(tester);
      expect(find.text('Telegram · @fortiva_vpn'), findsOneWidget);
      expect(launched, [_official]);
    });

    testWidgets('opens the channel the backend names', (tester) async {
      final config = (await tester.runAsync(
        () => _loaded('https://t.me/fortiva_news'),
      ))!;
      await pumpSettings(tester, config);
      await tester.pumpAndSettle();

      await tapContact(tester);
      expect(find.text('Telegram · @fortiva_news'), findsOneWidget);
      expect(find.textContaining('fortiva_vpn'), findsNothing);
      expect(launched, ['https://t.me/fortiva_news']);
    });

    testWidgets('names no channel for a link that has no name', (tester) async {
      final config = (await tester.runAsync(
        () => _loaded('https://t.me/+AbCdEf123'),
      ))!;
      await pumpSettings(tester, config);
      await tester.pumpAndSettle();

      await tapContact(tester);
      expect(find.text('Telegram'), findsOneWidget);
      expect(launched, ['https://t.me/+AbCdEf123']);
    });
  });

  group('the support chat, while it is off', () {
    Future<List<Uri>> tapTelegram(
      WidgetTester tester, {
      AppConfigState? config,
    }) async {
      final opened = <Uri>[];
      final screen = SupportScreen(open: (url) async => opened.add(url));
      final app = MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        home: screen,
      );
      await tester.pumpWidget(
        config == null
            ? app
            : ChangeNotifierProvider<AppConfigState>.value(
                value: config,
                child: app,
              ),
      );
      await tester.pump();
      await tester.tap(find.text('Message us on Telegram'));
      await tester.pump();
      return opened;
    }

    testWidgets('opens the channel the backend names', (tester) async {
      final config = (await tester.runAsync(
        () => _loaded('https://t.me/fortiva_news'),
      ))!;
      expect(await tapTelegram(tester, config: config), [
        Uri.parse('https://t.me/fortiva_news'),
      ]);
    });

    testWidgets('opens the official channel when the backend names none', (
      tester,
    ) async {
      final config = (await tester.runAsync(() => _loaded(null)))!;
      expect(await tapTelegram(tester, config: config), [Uri.parse(_official)]);
    });

    testWidgets('opens the official channel where the config is not '
        'provided', (tester) async {
      expect(await tapTelegram(tester), [Uri.parse(_official)]);
    });
  });
}
