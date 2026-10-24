import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/apn_guide.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/utils/carrier_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The APN guide shows Samsung phones on Hamrah Aval and Irancell mobile
/// data how to give the SIM IPv6. Far fewer Samsung phones there have IPv6
/// than other makers' phones, and a phone with IPv6 connects more often.
/// These tests pin who sees the card, and that nobody does until the
/// backend turns it on.

/// The block the backend sends once the owner has tried the steps.
const _block = {
  'enabled': true,
  'brands': ['samsung'],
  'carriers': ['Hamrah Aval', 'Irancell'],
};

final _settings = ApnGuideSettings.fromJson(_block)!;

final _now = DateTime.utc(2026, 10, 13, 9);

/// [ApnGuide.shouldShow] for a phone that should see the card, with the
/// one fact a test changes.
bool _shows({
  ApnGuideSettings? settings,
  bool noSettings = false,
  bool android = true,
  bool tv = false,
  String? manufacturer = 'samsung',
  String? network = 'mobile',
  String? carrier = 'IR-MCI',
  bool? ipv6Route = false,
  DateTime? dismissedAt,
  bool connecting = false,
}) => ApnGuide.shouldShow(
  settings: noSettings ? null : settings ?? _settings,
  android: android,
  tv: tv,
  manufacturer: manufacturer,
  network: network,
  carrier: carrier,
  ipv6Route: ipv6Route,
  dismissedAt: dismissedAt,
  now: _now,
  connecting: connecting,
);

/// The settings app_config.dart parses from [block], through a whole
/// config, as the app reads it.
ApnGuideSettings? _parsed(Object? block) => AppConfig.fromJson({
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
      },
  },
  'apn_guide': ?block,
}).apnGuide;

void main() {
  group('carrier names', () {
    test('every spelling of Hamrah Aval is one operator', () {
      for (final name in [
        'MCI',
        'IR-MCI',
        'IR MCI',
        'IRMCI',
        'MCCI',
        'Hamrah Aval',
        'HAMRAHE AVAL',
        'HAMRAHE AVVAL',
        '  ir-mci  ',
      ]) {
        expect(CarrierName.normalise(name), 'Hamrah Aval', reason: name);
      }
    });

    test('every spelling of Irancell is one operator', () {
      for (final name in [
        'Irancell',
        'IRANCELL',
        'MTN Irancell',
        'MTN IRANCELL',
        'MTN-Irancell',
        'IR-MTN',
      ]) {
        expect(CarrierName.normalise(name), 'Irancell', reason: name);
      }
    });

    test('an unknown name is kept as it came, without the spaces around '
        'it, and no name is null', () {
      expect(CarrierName.normalise(' Vodafone DE '), 'Vodafone DE');
      expect(CarrierName.normalise(null), isNull);
      expect(CarrierName.normalise(''), isNull);
      expect(CarrierName.normalise('   '), isNull);
    });
  });

  group('the apn_guide block', () {
    test('the backend\'s block is read', () {
      final settings = _parsed(_block)!;
      expect(settings.brands, {'samsung'});
      expect(settings.carriers, {'hamrah aval', 'irancell'});
    });

    test('is off when it is missing, as from every older backend', () {
      expect(_parsed(null), isNull);
    });

    test('is off when it says so, or names no brand or no carrier', () {
      for (final block in <Object>[
        {..._block, 'enabled': false},
        {'brands': _block['brands'], 'carriers': _block['carriers']},
        {..._block, 'enabled': 'true'},
        {..._block, 'brands': <String>[]},
        {..._block, 'carriers': <String>[]},
        {..._block, 'brands': null},
        {..._block, 'carriers': 'Irancell'},
        {
          ..._block,
          'brands': [3, ''],
        },
      ]) {
        expect(_parsed(block), isNull, reason: '$block');
      }
    });

    test('a value of the wrong type turns the guide off and keeps the rest '
        'of the config', () {
      for (final block in <Object>['on', true, 1, const <String>[]]) {
        expect(_parsed(block), isNull, reason: '$block');
      }
    });

    test('brands match whatever case Android uses, and carriers match '
        'every spelling', () {
      final settings = ApnGuideSettings.fromJson({
        'enabled': true,
        'brands': [' Samsung ', 7],
        'carriers': ['MCI', 'MTN Irancell', null],
      })!;
      expect(settings.coversBrand('samsung'), isTrue);
      expect(settings.coversBrand('SAMSUNG'), isTrue);
      expect(settings.coversBrand('Xiaomi'), isFalse);
      expect(settings.coversBrand(null), isFalse);
      expect(settings.coversCarrier('Hamrah Aval'), isTrue);
      expect(settings.coversCarrier('IR-MTN'), isTrue);
      expect(settings.coversCarrier('Rightel'), isFalse);
      expect(settings.coversCarrier(null), isFalse);
    });

    test('a saved copy reads back as the same settings', () {
      final back = ApnGuideSettings.fromJson(_settings.toJson())!;
      expect(back.brands, _settings.brands);
      expect(back.carriers, _settings.carriers);
    });
  });

  group('who sees the card', () {
    test('a Samsung on Hamrah Aval mobile data with no IPv6 route', () {
      expect(_shows(), isTrue);
      expect(_shows(carrier: 'MTN Irancell'), isTrue);
      expect(_shows(manufacturer: 'Samsung'), isTrue);
    });

    test('nobody while the backend has the guide off', () {
      expect(_shows(noSettings: true), isFalse);
    });

    test('not on iOS or Windows', () {
      expect(_shows(android: false), isFalse);
    });

    test('not on a TV', () {
      expect(_shows(tv: true), isFalse);
    });

    test('not a phone of another maker, or one that did not say', () {
      expect(_shows(manufacturer: 'Xiaomi'), isFalse);
      expect(_shows(manufacturer: null), isFalse);
    });

    test('not on wifi, or when the network is not known', () {
      for (final network in ['wifi', 'ethernet', 'none', 'other', null]) {
        expect(_shows(network: network), isFalse, reason: network);
      }
    });

    test('not on another carrier, or when the phone names none', () {
      expect(_shows(carrier: 'Rightel'), isFalse);
      expect(_shows(carrier: null), isFalse);
      final mciOnly = ApnGuideSettings.fromJson({
        ..._block,
        'carriers': ['Hamrah Aval'],
      });
      expect(_shows(settings: mciOnly, carrier: 'Irancell'), isFalse);
    });

    test('not on a phone that has IPv6, or that cannot tell', () {
      expect(_shows(ipv6Route: true), isFalse);
      expect(_shows(ipv6Route: null), isFalse);
    });

    test('not for 14 days after "Not now"', () {
      expect(
        _shows(dismissedAt: _now.subtract(const Duration(days: 13))),
        isFalse,
      );
      expect(
        _shows(dismissedAt: _now.subtract(const Duration(days: 14))),
        isTrue,
      );
    });

    test('not while a connect is under way', () {
      expect(_shows(connecting: true), isFalse);
    });
  });

  group('the guide on a phone', () {
    late int reads;
    late DateTime now;
    late String? carrier;
    late bool? route;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      reads = 0;
      now = _now;
      carrier = 'IR-MCI';
      route = false;
    });

    tearDown(() => FormFactor.isTvForTest = false);

    ApnGuide guide({bool android = true, Future<bool> Function()? open}) =>
        ApnGuide(
          android: android,
          manufacturer: () async {
            reads++;
            return 'samsung';
          },
          network: () async {
            reads++;
            return (network: 'mobile', carrier: carrier);
          },
          ipv6Route: () async {
            reads++;
            return route;
          },
          openSettings: open,
          clock: () => now,
        );

    test('reads nothing while the guide is off', () async {
      final g = guide();
      await g.refresh(null);
      expect(g.shows(connecting: false), isFalse);
      expect(reads, 0);
    });

    test('reads nothing where it cannot show', () async {
      final ios = guide(android: false);
      await ios.refresh(_settings);
      expect(ios.shows(connecting: false), isFalse);

      FormFactor.isTvForTest = true;
      final tv = guide();
      await tv.refresh(_settings);
      expect(tv.shows(connecting: false), isFalse);
      expect(reads, 0);
    });

    test('shows once the phone is read, and names the access point', () async {
      final g = guide();
      expect(g.shows(connecting: false), isFalse);
      await g.refresh(_settings);
      expect(g.shows(connecting: false), isTrue);
      expect(g.shows(connecting: true), isFalse);
      expect(g.apn, 'mcinet');

      carrier = 'MTN Irancell';
      await g.refresh(_settings);
      expect(g.apn, 'mtnirancell');
    });

    test('names no access point for an operator it does not know', () async {
      carrier = 'Rightel';
      final g = guide();
      await g.refresh(
        ApnGuideSettings.fromJson({
          ..._block,
          'carriers': ['Rightel'],
        }),
      );
      expect(g.shows(connecting: false), isTrue);
      expect(g.apn, isNull);
    });

    test('goes once the phone has an IPv6 route', () async {
      final g = guide();
      await g.refresh(_settings);
      expect(g.shows(connecting: false), isTrue);

      route = true;
      await g.refresh(_settings);
      expect(g.shows(connecting: false), isFalse);
    });

    test('goes when the backend turns it off', () async {
      final g = guide();
      await g.refresh(_settings);
      await g.refresh(null);
      expect(g.shows(connecting: false), isFalse);
    });

    test('asks for the maker once', () async {
      final g = guide();
      await g.refresh(_settings);
      await g.refresh(_settings);
      // The maker once, then the network and the route on each refresh.
      expect(reads, 5);
    });

    test('"Not now" puts it away for 14 days, across launches', () async {
      final g = guide();
      await g.refresh(_settings);
      await g.dismiss();
      expect(g.shows(connecting: false), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(ApnGuide.apnGuideDismissedKey),
        _now.toIso8601String(),
      );

      // The next launch.
      now = _now.add(const Duration(days: 13));
      final next = guide();
      await next.refresh(_settings);
      expect(next.shows(connecting: false), isFalse);

      now = _now.add(const Duration(days: 14));
      expect(next.shows(connecting: false), isTrue);
    });

    test('a saved "Not now" that cannot be read is none', () async {
      SharedPreferences.setMockInitialValues({
        ApnGuide.apnGuideDismissedKey: 'yesterday',
      });
      final g = guide();
      await g.refresh(_settings);
      expect(g.shows(connecting: false), isTrue);
    });

    test('a read that a later one overtook is dropped', () async {
      final slow = Completer<bool?>();
      var first = true;
      final g = ApnGuide(
        android: true,
        manufacturer: () async => 'samsung',
        network: () async => (network: 'mobile', carrier: 'IR-MCI'),
        ipv6Route: () {
          if (!first) return Future.value(true);
          first = false;
          return slow.future;
        },
        clock: () => now,
      );
      final older = g.refresh(_settings);
      // The older read is waiting on the route before the newer starts.
      await pumpEventQueue();
      expect(first, isFalse);
      await g.refresh(_settings);
      expect(g.shows(connecting: false), isFalse);

      // The older read ends last, with the phone as it was before.
      slow.complete(false);
      await older;
      expect(g.shows(connecting: false), isFalse);
    });

    test('a read that fails keeps the card away', () async {
      final g = ApnGuide(
        android: true,
        manufacturer: () async => 'samsung',
        network: () async => throw StateError('no network facts'),
        ipv6Route: () async => false,
        clock: () => now,
      );
      await g.refresh(_settings);
      expect(g.shows(connecting: false), isFalse);
    });

    test('says whether the APN screen opened, and never throws', () async {
      expect(await guide(open: () async => true).openApnSettings(), isTrue);
      expect(await guide(open: () async => false).openApnSettings(), isFalse);
      expect(
        await guide(
          open: () async => throw StateError('no activity'),
        ).openApnSettings(),
        isFalse,
      );
    });
  });
}
