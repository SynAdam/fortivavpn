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

/// The links to the Telegram channel, which the backend names in
/// GET /api/v1/app/config.
///
/// The update prompt opens the channel of the app's language, from
/// force_update.android.channel_urls. A language with no channel of its own
/// gets the English channel, and only Persian ever gets the Persian one.
///
/// The two ways to message us, Contact us in Settings while the chat is off and
/// the support chat's fallback, keep force_update.android.channel_url in every
/// language, because only that channel's direct messages reach the support
/// bot. channel_url is also the update link of older builds.
///
/// Google Play does not let a Play app link to a page that could lead to
/// another way to pay, so every link opens play_channel_url when the backend
/// sends one, except the update button of a copy Google did not sign. A value
/// that is not an https link to a page on t.me is never opened.
///
/// The value is read while the whole app config is parsed, and one throw
/// there loses the config: feature flags, the TLS spec, relays and the
/// update rules. So no value of it may throw.

const _english = 'https://t.me/fortivavpn';
const _support = 'https://t.me/fortiva_vpn';

Map<String, dynamic> _configJson({
  Object? channelUrl,
  Object? playChannelUrl,
  Object? channelUrls,
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
        if (os == 'android' && channelUrls != null) 'channel_urls': channelUrls,
      },
  },
  'feature_flags': ?flags,
};

AppConfig _config({
  Object? channelUrl,
  Object? playChannelUrl,
  Object? channelUrls,
}) => AppConfig.fromJson(
  _configJson(
    channelUrl: channelUrl,
    playChannelUrl: playChannelUrl,
    channelUrls: channelUrls,
  ),
);

/// One platform's rules as the backend sends them.
PlatformVersion _android({Object? channel, Object? play, Object? channels}) =>
    PlatformVersion.fromJson({
      'latest_version': '1.0.0',
      'minimum_version': '1.0.0',
      'update_url': 'https://example.com/update',
      'channel_url': ?channel,
      'play_channel_url': ?play,
      'channel_urls': ?channels,
    });

/// Links whose path has a percent escape that is not UTF-8. Uri.tryParse
/// takes them, and Uri.pathSegments throws on them.
const _undecodable = ['https://t.me/%D8', 'https://t.me/fortiva%E2%80'];

Future<AppConfig> _unreachable() async => throw Exception('no route');

/// The config state after a fetch that answered [channelUrl], or none
/// when [channelUrl] is null.
Future<AppConfigState> _loaded(
  Object? channelUrl, {
  Object? playChannelUrl,
  Object? channelUrls,
}) async {
  final state = AppConfigState(
    fetch: () async => _config(
      channelUrl: channelUrl,
      playChannelUrl: playChannelUrl,
      channelUrls: channelUrls,
    ),
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
      _english,
      _support,
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
        expect(_android(channel: url).channelUrl, isNull);
      });
    }

    test('a value that is not text is no channel', () {
      for (final value in <Object?>[
        42,
        true,
        const ['x'],
        const {},
      ]) {
        expect(_android(channel: value).channelUrl, isNull);
      }
    });

    test('channel_url is read when it is a channel link', () {
      expect(
        _android(channel: 'https://t.me/fortiva_news').channelUrl,
        'https://t.me/fortiva_news',
      );
      expect(_android(channel: 'https://example.com/pay').channelUrl, isNull);
      expect(_android(channel: 'http://t.me/fortiva_news').channelUrl, isNull);
    });
  });

  group('the channels compiled into the app', () {
    test('the default is the English channel', () {
      expect(PlatformVersion.defaultChannelUrl, _english);
    });

    test('with no channel from the backend, every language gets it', () {
      for (final code in LocaleState.supportedLanguages.keys) {
        expect(_android().channelFor(code), _english, reason: code);
      }
    });

    test('a language the app does not have gets it', () {
      expect(_android().channelFor('sv'), _english);
    });
  });

  group('channel_urls', () {
    const russian = 'https://t.me/made_up_ru';
    const persian = 'https://t.me/made_up_fa';
    const english = 'https://t.me/made_up_en';

    test('a language opens its own channel', () {
      final v = _android(
        channel: _support,
        channels: {'ru': russian, 'fa': persian, 'en': english},
      );
      expect(v.channelFor('ru'), russian);
      expect(v.channelFor('fa'), persian);
      expect(v.channelFor('en'), english);
    });

    test('a language that is absent opens the English channel', () {
      final v = _android(channels: {'ru': russian, 'en': english});
      expect(v.channelFor('de'), english);
      expect(v.channelFor('sv'), english);
    });

    test('with no English entry, that is the compiled-in one', () {
      expect(_android(channels: {'ru': russian}).channelFor('de'), _english);
    });

    test('Persian that is absent opens the English channel too', () {
      final v = _android(channel: _support, channels: {'ru': russian});
      expect(v.channelFor('fa'), _english);
    });

    test('a value that fails the check is dropped', () {
      final v = _android(
        channels: {
          'ru': 'https://example.com/pay',
          'de': 'http://t.me/made_up_de',
          'ko': '',
          'ja': 42,
          'es': null,
          'tr': const ['x'],
          for (final (i, url) in _undecodable.indexed) 'x$i': url,
          'pt': 'https://t.me/made_up_pt',
        },
      );
      expect(v.channelUrls, {'pt': 'https://t.me/made_up_pt'});
      expect(v.channelFor('ru'), _english);
    });

    test('a value is trimmed', () {
      expect(
        _android(channels: {'ru': ' $russian '}).channelFor('ru'),
        russian,
      );
    });

    test('a value of the wrong type never throws', () {
      for (final bad in <Object?>[
        42,
        'x',
        true,
        const ['x'],
      ]) {
        final v = _android(channels: bad);
        expect(v.channelUrls, isEmpty, reason: '$bad');
        expect(v.channelFor('ru'), _english, reason: '$bad');
      }
    });

    test('a bad value leaves the rest of the config standing', () async {
      final state = await _loaded(
        _support,
        channelUrls: {'ru': _undecodable.first},
      );
      expect(state.config, isNotNull);
      expect(state.versionRules!.android.channelUrls, isEmpty);
    });

    test('is kept between launches, and left out when absent', () {
      final v = _android(channels: {'ru': russian});
      expect(PlatformVersion.fromJson(v.toJson()).channelUrls, {'ru': russian});
      expect(_android().toJson(), isNot(contains('channel_urls')));
    });

    test('AppConfigState keeps it for a launch that cannot reach the '
        'backend', () async {
      await _loaded(_support, channelUrls: {'ru': russian});
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.versionRules!.android.channelFor('ru'), russian);
    });

    group('a backend that sends only channel_url', () {
      final v = _android(channel: _support);

      test('never gives another language the Persian channel', () {
        for (final code in LocaleState.supportedLanguages.keys) {
          if (code == 'fa') continue;
          expect(v.channelFor(code), _english, reason: code);
          expect(
            v.updateChannelFor(googleSigned: false, language: code),
            _english,
            reason: code,
          );
        }
      });

      // These people follow that channel today, and rules saved by an older
      // build look the same until the backend answers again.
      test('leaves Persian on that channel', () {
        expect(v.channelFor('fa'), _support);
      });

      test('with no channel_url either, Persian gets the default', () {
        expect(_android().channelFor('fa'), _english);
      });
    });

    test('play_channel_url beats every language', () {
      const page = 'https://t.me/fortiva_news';
      final v = _android(play: page, channels: {'ru': russian, 'fa': persian});
      for (final code in ['ru', 'fa', 'en', 'de']) {
        expect(v.channelFor(code), page, reason: code);
      }
    });

    group('the update prompt', () {
      const page = 'https://t.me/fortiva_news';
      final v = _android(play: page, channels: {'ru': russian});

      test('in a copy Google signed follows play_channel_url', () {
        expect(v.updateChannelFor(googleSigned: true, language: 'ru'), page);
      });

      // Only a release posted on the channel updates this copy in place.
      test('in any other copy opens the channel of the language', () {
        expect(
          v.updateChannelFor(googleSigned: false, language: 'ru'),
          russian,
        );
        expect(
          v.updateChannelFor(googleSigned: false, language: 'de'),
          _english,
        );
      });
    });
  });

  group('a value that cannot be decoded', () {
    tearDown(() => StandbyDoors.enabled = false);

    for (final url in _undecodable) {
      test('"$url" is never opened, and never throws', () {
        expect(PlatformVersion.isChannelUrl(url), isFalse);
        expect(_android(channel: url).channelUrl, isNull);
      });

      test('"$url" leaves the rest of the config standing', () async {
        // The rest of the config is what a throw here would lose.
        final json = _configJson(
          channelUrl: url,
          playChannelUrl: url,
          flags: {'standby_doors': true},
        );
        final config = AppConfig.fromJson(json);
        expect(config.forceUpdate.android.channelUrl, isNull);
        expect(config.forceUpdate.android.playChannelUrl, isNull);

        final state = AppConfigState(
          fetch: () async => AppConfig.fromJson(json),
          retryGaps: const [],
        );
        await state.load();
        expect(state.config, isNotNull);
        expect(state.flags.standbyDoors, isTrue);
        expect(StandbyDoors.enabled, isTrue);
        expect(state.contactChannel, Uri.parse(_support));
      });

      test('"$url" saved by an older build is not opened', () async {
        final rules = _config().forceUpdate.toJson();
        (rules['android'] as Map)['channel_url'] = url;
        SharedPreferences.setMockInitialValues({
          AppConfigState.versionRulesKey: jsonEncode(rules),
        });
        final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
        await next.load();
        expect(next.versionRules, isNotNull);
        expect(next.contactChannel, Uri.parse(_support));
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
      expect(android.channelUrl, isNull);
      expect(android.playChannelUrl, isNull);
    });
  });

  // Every copy runs the same code as the one on Google Play, so every copy
  // opens play_channel_url when the backend sends one: it may point at a
  // page that sells nothing. channel_url stays the update link of older builds.
  group('play_channel_url', () {
    const apkChannel = 'https://t.me/fortiva_vpn';
    const playChannel = 'https://t.me/fortiva_news';

    PlatformVersion android({Object? channel, Object? play}) =>
        _android(channel: channel, play: play);

    test('every copy opens it when the backend sends one', () {
      final v = android(channel: apkChannel, play: playChannel);
      expect(v.channelFor('en'), playChannel);
      expect(v.channelFor('fa'), playChannel);
      expect(v.contactChannel, playChannel);
      // channel_url is still read and kept.
      expect(v.channelUrl, apkChannel);
    });

    // Only a release posted on the channel updates a copy Google did not sign.
    test('the update of a copy Google did not sign ignores it', () {
      final v = android(channel: apkChannel, play: playChannel);
      expect(
        v.updateChannelFor(googleSigned: false, language: 'fa'),
        apkChannel,
      );
      expect(
        v.updateChannelFor(googleSigned: true, language: 'fa'),
        playChannel,
      );

      final without = android(channel: apkChannel);
      expect(
        without.updateChannelFor(googleSigned: false, language: 'fa'),
        apkChannel,
      );
      expect(
        without.updateChannelFor(googleSigned: true, language: 'fa'),
        apkChannel,
      );
    });

    test('without it, Contact us opens channel_url', () {
      final v = android(channel: apkChannel);
      expect(v.playChannelUrl, isNull);
      expect(v.contactChannel, apkChannel);
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
        expect(v.contactChannel, apkChannel, reason: '$bad');
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
      expect(state.contactChannel, Uri.parse(playChannel));

      // And on a launch that cannot reach the backend.
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.contactChannel, Uri.parse(playChannel));
    });
  });

  group('the name shown next to Telegram', () {
    for (final (url, handle) in [
      (_support, '@fortiva_vpn'),
      (_english, '@fortivavpn'),
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

  // The one link that keeps a single channel in every language, because only
  // that channel's direct messages reach the support bot.
  group('AppConfigState.contactChannel', () {
    test('is the support channel before the backend has answered', () {
      final state = AppConfigState(fetch: _unreachable, retryGaps: const []);
      expect(state.contactChannel, Uri.parse(_support));
    });

    test('is the support channel when the backend sends none', () async {
      expect((await _loaded(null)).contactChannel, Uri.parse(_support));
    });

    test('is the channel the backend sends', () async {
      final state = await _loaded('https://t.me/fortiva_news');
      expect(state.contactChannel, Uri.parse('https://t.me/fortiva_news'));
    });

    test('does not read channel_urls', () async {
      final state = await _loaded(
        'https://t.me/fortiva_news',
        channelUrls: {'en': 'https://t.me/made_up_en'},
      );
      expect(state.contactChannel, Uri.parse('https://t.me/fortiva_news'));
    });

    test('ignores a value that is not a channel link', () async {
      for (final bad in ['https://example.com/pay', '', 7]) {
        final state = await _loaded(bad);
        expect(state.contactChannel, Uri.parse(_support), reason: '$bad');
      }
    });

    test('keeps the backend\'s channel for a launch that cannot reach '
        'it', () async {
      await _loaded('https://t.me/fortiva_news');
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.contactChannel, Uri.parse('https://t.me/fortiva_news'));
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
      expect(next.contactChannel, Uri.parse(_support));
    });

    // An older build saved the link it opened, so these people still reach
    // the same channel after they update.
    test('reads what an older build saved as the backend\'s link', () async {
      final rules = _config().forceUpdate.toJson();
      (rules['android'] as Map)['channel_url'] = 'https://t.me/fortiva_news';
      SharedPreferences.setMockInitialValues({
        AppConfigState.versionRulesKey: jsonEncode(rules),
      });
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.contactChannel, Uri.parse('https://t.me/fortiva_news'));
    });

    test('with no channel from the backend, saving does not move it to the '
        'English channel', () async {
      await _loaded(null);
      final next = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await next.load();
      expect(next.versionRules, isNotNull);
      expect(next.contactChannel, Uri.parse(_support));
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

    testWidgets('opens the support channel, as before, until the backend '
        'names another', (tester) async {
      final config = AppConfigState(fetch: _unreachable, retryGaps: const []);
      await pumpSettings(tester, config);
      await tester.pumpAndSettle();

      await tapContact(tester);
      expect(find.text('Telegram · @fortiva_vpn'), findsOneWidget);
      expect(launched, [_support]);
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

    testWidgets('does not follow channel_urls', (tester) async {
      final config = (await tester.runAsync(
        () => _loaded(
          'https://t.me/fortiva_news',
          channelUrls: {'en': 'https://t.me/made_up_en'},
        ),
      ))!;
      await pumpSettings(tester, config);
      await tester.pumpAndSettle();

      await tapContact(tester);
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

    testWidgets('does not follow channel_urls', (tester) async {
      final config = (await tester.runAsync(
        () => _loaded(
          'https://t.me/fortiva_news',
          channelUrls: {'en': 'https://t.me/made_up_en'},
        ),
      ))!;
      expect(await tapTelegram(tester, config: config), [
        Uri.parse('https://t.me/fortiva_news'),
      ]);
    });

    testWidgets('opens the support channel when the backend names none', (
      tester,
    ) async {
      final config = (await tester.runAsync(() => _loaded(null)))!;
      expect(await tapTelegram(tester, config: config), [Uri.parse(_support)]);
    });

    testWidgets('opens the support channel where the config is not '
        'provided', (tester) async {
      expect(await tapTelegram(tester), [Uri.parse(_support)]);
    });
  });
}
