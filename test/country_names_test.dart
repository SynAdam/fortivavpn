import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/country_names.dart';
import 'package:fortiva_vpn/data/models/ip_info.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/utils/countries.dart';
import 'package:fortiva_vpn/utils/server_sort.dart';
import 'package:fortiva_vpn/widgets/server_card.dart';
import 'package:fortiva_vpn/widgets/server_title.dart';

/// Every country a server can be in has a name in each of the app's
/// languages, and the screens use the app's language for it. The app held
/// 56 English names before: a Persian or German card said "United States",
/// and rows showed bare codes such as BY, PE and IQ.
void main() {
  final languages = [
    for (final f in Directory('lib/l10n').listSync().whereType<File>())
      if (RegExp(r'app_([a-z]+)\.arb$').firstMatch(f.path) case final m?)
        m.group(1)!,
  ]..sort();

  group('the tables', () {
    test('one for each of the 18 app languages, and no other', () {
      expect(languages, hasLength(18));
      expect(countryNameTables.keys.toList()..sort(), languages);
    });

    test('every table names the same 250 codes', () {
      final codes = countryNameTables['en']!.keys.toSet();
      expect(codes, hasLength(250));
      for (final code in ['BY', 'PE', 'IQ', 'XK', 'US', 'DE', 'IR']) {
        expect(codes, contains(code));
      }
      for (final code in ['EU', 'UN', 'ZZ', 'QO']) {
        expect(codes, isNot(contains(code)));
      }
      for (final language in languages) {
        expect(
          countryNameTables[language]!.keys.toSet(),
          codes,
          reason: language,
        );
      }
    });

    test('every name is real text, with none of the marks the app does not '
        'use', () {
      for (final MapEntry(key: language, value: table)
          in countryNameTables.entries) {
        for (final MapEntry(key: code, value: name) in table.entries) {
          expect(name.trim(), isNotEmpty, reason: '$language:$code');
          expect(name, isNot(code), reason: '$language:$code');
          for (final mark in ['–', '—', '‘', '’', '“', '”', '…']) {
            expect(name.contains(mark), isFalse, reason: '$language:$code');
          }
        }
      }
    });

    test('a language other than English has its own names', () {
      expect(CountryNames.nameOf('US', 'fa'), 'ایالات متحده');
      expect(CountryNames.nameOf('US', 'de'), 'Vereinigte Staaten');
      expect(CountryNames.nameOf('BY', 'en'), 'Belarus');
      expect(CountryNames.nameOf('pe', 'ru'), 'Перу');
      expect(CountryNames.nameOf('HK', 'en'), 'Hong Kong');
    });

    test('a language with no table falls back to English', () {
      expect(CountryNames.nameOf('DE', 'xx'), 'Germany');
    });

    test('Iran is a country, never a server\'s', () {
      expect(CountryNames.isCountry('IR'), isTrue);
      expect(CountryNames.isServerCountry('IR'), isFalse);
      expect(CountryNames.isServerCountry('ir'), isFalse);
      expect(CountryNames.isServerCountry('DE'), isTrue);
      expect(CountryNames.isServerCountry('EU'), isFalse);
    });

    test('an English name stored earlier reads back as its code', () {
      expect(CountryNames.codeOfEnglishName('Germany'), 'DE');
      expect(CountryNames.codeOfEnglishName('Turkey'), 'TR');
      expect(CountryNames.codeOfEnglishName('Nuremberg'), isNull);
    });
  });

  group('a server', () {
    Server community(String label, {int index = 0}) => Server.fromConnectionUri(
      'vless://u@203.0.113.9:443?security=tls#$label',
      index: index,
    );

    test('a community link with a flag the old table lacked is named', () {
      final belarus = community('\u{1F1E7}\u{1F1FE} @someone');
      expect(belarus.country, 'Belarus');
      expect(belarus.countryCode, 'BY');
      expect(belarus.countryIn('fa'), 'بلاروس');
      expect(belarus.countryIn('de'), 'Belarus');
    });

    test('an Iranian flag names no country and draws the globe', () {
      final relay = community('\u{1F1EE}\u{1F1F7} relay', index: 4);
      expect(relay.country, isEmpty);
      expect(relay.countryCode, isNull);
      expect(relay.flagEmoji, '🌍');
      expect(relay.name, Server.communityFallbackName(5));
    });

    test('a flag that is no country\'s keeps its letters, as before', () {
      final eu = community('\u{1F1EA}\u{1F1FA} somewhere');
      expect(eu.country, 'EU');
      expect(eu.countryCode, isNull);
      expect(eu.countryIn('fa'), 'EU');
    });

    test('one of ours names its country in the app language', () {
      final ours = Server.fromDedicatedUri(
        'vless://u@198.51.100.7:443?type=tcp#DE%20Nuremberg',
      );
      expect(ours.country, 'Germany');
      expect(ours.countryIn('de'), 'Deutschland');
      expect(ours.countryIn('fa'), 'آلمان');
      expect(ServerCard.subtitleFor(ours, language: 'fa'), 'آلمان · Nuremberg');
    });

    test('an Iranian region on a server of the list names no country', () {
      final listed = Server.fromApiJson({
        'id': 3,
        'uri': 'vless://u@198.51.100.8:443',
        'country_code': 'IR',
      });
      expect(listed.country, isEmpty);
      expect(listed.flagEmoji, '🌍');
    });

    test('the flag spells the code', () {
      expect(Server.codeOfFlag('\u{1F1E9}\u{1F1EA}'), 'DE');
      expect(Server.codeOfFlag('🌍'), isNull);
      expect(Server.codeOfFlag(''), isNull);
    });
  });

  test('the IP screen names the country in the app language', () {
    final info = IpInfo.fromBackend({'ip': '192.0.2.1', 'country': 'de'});
    expect(info.country, 'Germany');
    expect(info.countryIn('fa'), 'آلمان');
    final unknown = IpInfo.fromBackend({'ip': '192.0.2.1', 'country': 'zz'});
    expect(unknown.countryIn('fa'), 'ZZ');
  });

  test('the community list groups countries in the alphabet shown', () {
    Server flagged(String id, String flag) => Server.fromConnectionUri(
      'vless://u@203.0.113.9:443?security=tls#$flag $id',
    ).copyWith(id: id);
    final servers = [
      flagged('us', '\u{1F1FA}\u{1F1F8}'),
      flagged('de', '\u{1F1E9}\u{1F1EA}'),
      flagged('at', '\u{1F1E6}\u{1F1F9}'),
    ];
    List<String> ids(String language) => [
      for (final s in sortForDisplay(
        servers,
        (_) => null,
        countryOf: (s) => s.countryIn(language),
      ))
        s.id,
    ];
    // Austria, Germany, United States; Allemagne, Autriche, États-Unis.
    expect(ids('en'), ['at', 'de', 'us']);
    expect(ids('fr'), ['de', 'at', 'us']);
  });

  group('on screen', () {
    Future<String> textIn(
      WidgetTester tester,
      Locale locale,
      String Function(BuildContext) build,
    ) async {
      late String out;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Builder(
            builder: (context) {
              out = build(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return out;
    }

    final peru = Server.fromConnectionUri(
      'vless://u@203.0.113.9:443?security=tls#\u{1F1F5}\u{1F1EA}',
    );

    testWidgets('a community link is its country, in German', (tester) async {
      expect(
        await textIn(tester, const Locale('de'), (c) => serverTitle(c, peru)),
        'Peru',
      );
      expect(
        await textIn(
          tester,
          const Locale('de'),
          (c) => serverTitle(
            c,
            Server.fromConnectionUri(
              'vless://u@203.0.113.9:443#\u{1F1FA}\u{1F1F8}',
            ),
          ),
        ),
        'Vereinigte Staaten',
      );
    });

    testWidgets('and in Persian', (tester) async {
      expect(
        await textIn(tester, const Locale('fa'), (c) => serverTitle(c, peru)),
        'پرو',
      );
      expect(
        await textIn(tester, const Locale('fa'), (c) => serverCountry(c, peru)),
        'پرو',
      );
    });

    testWidgets('a stored country name is shown in the app language', (
      tester,
    ) async {
      expect(
        await textIn(
          tester,
          const Locale('fa'),
          (c) => storedServerTitle(c, 'Turkey'),
        ),
        'ترکیه',
      );
      expect(
        await textIn(
          tester,
          const Locale('de'),
          (c) => storedServerTitle(c, 'United States'),
        ),
        'Vereinigte Staaten',
      );
    });
  });
}
