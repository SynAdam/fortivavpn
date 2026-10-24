import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/services/tunnel_channels.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Payments and Premium offers follow one rule in every country (the
/// owner's decision, 2026-10-09).
///
/// The app never asks the phone where it is to decide an offer, a plan or
/// a price. Here the platform's `place` call answers with every kind of
/// reading: nothing at all, a SIM, a cell network or a time zone that an
/// older backend's lists named, all of them at once, and none of them. The
/// same backend answer must give the same offers each time, and billing
/// must never make the call.
///
/// Both copies of the app are checked: the one Google Play signed, which
/// may buy through Play, and one it did not, such as the channel APK,
/// which is offered nothing to buy wherever it is.

/// What the phone may say about where it is (the platform's `place`
/// answer), from nothing at all to every reading an older backend listed.
const _readings = <(String, Map<String, Object?>?)>[
  ('the phone says nothing about where it is', null),
  ('the SIM names a listed country', {'sim_country': 'ir'}),
  ('the SIM names another listed country', {'sim_country': 'AF'}),
  ('the cell network names a listed country', {'network_country': 'ir'}),
  ('the time zone is a listed one', {'time_zone': 'Asia/Tehran'}),
  (
    'the SIM, the cell network and the time zone are all listed',
    {
      'sim_country': 'ir',
      'network_country': 'ir',
      'roaming': false,
      'time_zone': 'Asia/Tehran',
      'other_vpn': true,
    },
  ),
  (
    'nothing about the phone is listed',
    {
      'sim_country': 'de',
      'network_country': 'de',
      'roaming': false,
      'time_zone': 'Europe/Berlin',
    },
  ),
];

/// The country and time zone lists older backends sent in the upsell
/// block. They name the places in [_readings].
const _olderLists = {
  'hide_phone_countries': ['IR', 'AF'],
  'hide_time_zones': ['Asia/Tehran', 'Asia/Kabul'],
};

/// The upsell block, with every surface on and the numbers each needs.
final _block = <String, Object?>{
  'surfaces': [for (final s in UpsellSurface.values) s.wire],
  'nudge_used_percent': 80,
  'prompt_every_hours': 168,
  'prompt_max': 3,
  'locked_servers': [
    {'id': 14, 'country_code': 'FI', 'city': 'Helsinki'},
  ],
};

/// The billing answer every copy gets, with the older lists in the block
/// when [olderLists] is set. Sales are on and the device has no Premium.
Map<String, dynamic> _answer({required bool olderLists}) => {
  'enabled': true,
  'premium': {'active': false},
  'plans': [
    {
      'code': 'unlimited_30d',
      'days': 30,
      'google': {'product_id': 'premium', 'base_plan_id': 'p30'},
    },
  ],
  'rails': {'google_play': true, 'codes': true, 'play_restore': true},
  'upsell': {..._block, if (olderLists) ..._olderLists},
};

/// How a test names a copy of the app.
String _copy(bool signed) =>
    signed ? 'the copy Google signed' : 'a copy Google did not sign';

/// A backend that answers GET .../billing with [answer] and takes offer
/// events.
ApiClient _backend(Map<String, dynamic> answer) => ApiClient.forTest(
  direct: MockClient((request) async {
    if (request.url.path.endsWith('/billing')) {
      return http.Response(
        jsonEncode(answer),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('', 204);
  }),
);

class _Play implements PlayBilling {
  @override
  Stream<List<PlayPurchase>> get purchases => const Stream.empty();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<PlayProduct>> products(Set<String> productIds) async => _prices;
  @override
  Future<bool> buy(PlayProduct product, {required String accountId}) async =>
      true;
  @override
  Future<void> complete(PlayPurchase purchase) async {}
  @override
  Future<List<PlayPurchase>> owned() async => const [];
}

const _prices = [
  PlayProduct(productId: 'premium', basePlanId: 'p30', price: 'EUR 4,99'),
];

/// Everything billing decides for this device that a screen reads.
Map<String, Object?> _decisions(BillingState billing) => {
  for (final s in UpsellSurface.values) s.wire: billing.upsellOn(s),
  'enabled': billing.enabled,
  'canBuy': billing.canBuy,
  'showUpsell': billing.showUpsell,
  'offersAllowed': billing.offersAllowed,
  'tile': billing.tile,
  'playBilling': billing.playBilling,
  'plans': [for (final p in billing.plans) p.code],
  'playPlans': [for (final p in billing.playPlans) p.code],
  'googlePlay': billing.rails.googlePlay,
  'codes': billing.rails.codes,
  'lockedServers': [
    for (final s in billing.upsell?.lockedServers ?? const <LockedServer>[])
      s.city,
  ],
};

/// What every phone is offered in the copy [signed] says: in the copy
/// Google signed, each surface, the Premium tile and the plans; in any
/// other, no offer and the "Enter a code" tile.
Map<String, Object?> _everything(bool signed) => {
  for (final s in UpsellSurface.values) s.wire: signed,
  'enabled': true,
  'canBuy': signed,
  'showUpsell': signed,
  'offersAllowed': signed,
  'tile': signed ? PremiumTile.premium : PremiumTile.enterCode,
  'playBilling': signed,
  'plans': ['unlimited_30d'],
  'playPlans': signed ? ['unlimited_30d'] : <String>[],
  'googlePlay': true,
  'codes': true,
  'lockedServers': ['Helsinki'],
};

/// Billing that holds the answer the backend gives, with the older lists
/// in its block, and never loads again. The Premium screen asks for a load
/// when it opens.
class _Loaded extends BillingState {
  _Loaded({required bool signed})
    : super(
        service: BillingService(client: _backend(const {})),
        playBilling: () => _Play(),
        deviceId: () async => 'DEV-1',
      ) {
    adoptForTest(
      BillingInfo.fromJson(_answer(olderLists: true)),
      products: _prices,
      googleSigned: signed,
    );
    adoptWorkedForTest();
  }

  @override
  Future<void> refresh() async {}
}

class _FakeDedicated extends DedicatedState {
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
}

Widget _app(BillingState billing, Widget home) => MultiProvider(
  providers: [
    ChangeNotifierProvider<BillingState>.value(value: billing),
    ChangeNotifierProvider<DedicatedState>.value(value: _FakeDedicated()),
  ],
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: const Locale('en'),
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the platform answers when asked where the phone is, and how
  /// many times it was asked.
  Map<String, Object?>? phonePlace;
  var placeCalls = 0;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
    phonePlace = null;
    placeCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TunnelChannels.method, (call) async {
          if (call.method != 'place') throw MissingPluginException();
          placeCalls++;
          return phonePlace;
        });
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(TunnelChannels.method, null);
  });

  /// A billing state for the copy [signed] says that loaded [answer] the
  /// way the app does at launch, after a working connection.
  Future<BillingState> started(bool signed, Map<String, dynamic> answer) async {
    final billing = BillingState(
      service: BillingService(client: _backend(answer)),
      playBilling: () => _Play(),
      googleSigned: () async => signed,
      deviceId: () async => 'DEV-1',
    );
    await billing.start();
    await billing.noteWorkingConnection();
    return billing;
  }

  group('reading the upsell block', () {
    test('reads the same with the older country lists and without them', () {
      final plain = Upsell.fromJson(_block)!;
      final older = Upsell.fromJson({..._block, ..._olderLists})!;
      expect(older.surfaces, plain.surfaces);
      expect(older.surfaces, UpsellSurface.values.toSet());
      expect(older.nudgeUsedPercent, plain.nudgeUsedPercent);
      expect(older.promptEveryHours, plain.promptEveryHours);
      expect(older.promptMax, plain.promptMax);
      expect(
        [for (final s in older.lockedServers) s.city],
        [for (final s in plain.lockedServers) s.city],
      );
    });

    test('older lists of any shape do not spoil the block', () {
      for (final lists in <Map<String, Object?>>[
        {'hide_phone_countries': 'IR', 'hide_time_zones': 7},
        {'hide_phone_countries': null, 'hide_time_zones': null},
        {
          'hide_phone_countries': [3, '', null],
          'hide_time_zones': [
            {'zone': 'Asia/Tehran'},
          ],
        },
      ]) {
        final upsell = Upsell.fromJson({..._block, ...lists});
        expect(
          upsell?.surfaces,
          UpsellSurface.values.toSet(),
          reason: '$lists',
        );
      }
    });

    test('the billing answer reads the same with the older lists and '
        'without them', () {
      final plain = BillingInfo.fromJson(_answer(olderLists: false));
      final older = BillingInfo.fromJson(_answer(olderLists: true));
      expect(older.upsell?.surfaces, plain.upsell?.surfaces);
      expect(older.rails.googlePlay, plain.rails.googlePlay);
    });
  });

  group('the same phone gets the same offers', () {
    for (final signed in [true, false]) {
      for (final olderLists in [false, true]) {
        final backend = olderLists
            ? 'an older backend that still sends country lists'
            : 'a backend that sends no country lists';
        test('in ${_copy(signed)}, from $backend, whatever the phone says '
            'about where it is', () async {
          for (final (name, reading) in _readings) {
            phonePlace = reading;
            final billing = await started(
              signed,
              _answer(olderLists: olderLists),
            );
            expect(_decisions(billing), _everything(signed), reason: name);
            billing.dispose();
          }
          // Billing never asked the phone where it is.
          expect(placeCalls, 0);
        });
      }
    }

    test(
      'a reading that changes while the app is away changes nothing',
      () async {
        phonePlace = _readings.last.$2;
        final billing = await started(true, _answer(olderLists: true));
        final before = _decisions(billing);
        expect(before, _everything(true));

        for (final (name, reading) in _readings) {
          phonePlace = reading;
          billing.resumed();
          await pumpEventQueue();
          expect(_decisions(billing), before, reason: name);
        }
        expect(placeCalls, 0);
        billing.dispose();
      },
    );
  });

  group('the Premium screen is the same everywhere', () {
    for (final (name, reading) in _readings) {
      testWidgets('in the copy Google signed when $name', (tester) async {
        phonePlace = reading;
        await tester.pumpWidget(
          _app(_Loaded(signed: true), const PremiumScreen()),
        );
        await tester.pump();

        expect(find.text('Choose a plan'), findsOneWidget);
        expect(find.text('EUR 4,99'), findsOneWidget);
        expect(find.text('Buy'), findsOneWidget);
        expect(find.text('Enter a code'), findsOneWidget);
        expect(placeCalls, 0);
      });

      testWidgets('in a copy Google did not sign when $name', (tester) async {
        phonePlace = reading;
        await tester.pumpWidget(
          _app(_Loaded(signed: false), const PremiumScreen()),
        );
        await tester.pump();

        expect(
          find.text(
            'To buy through Google Play, you need the Google Play version '
            'of Fortiva.',
          ),
          findsOneWidget,
        );
        expect(find.text('Enter a code'), findsOneWidget);
        expect(find.text('Buy'), findsNothing);
        expect(placeCalls, 0);
      });
    }
  });
}
