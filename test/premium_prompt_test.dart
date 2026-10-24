import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/premium_prompt.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The calm Premium card's record: how often it may show, how many times
/// ever, and never again once the device has had Premium. The numbers come
/// from the backend (Upsell.promptEveryHours and promptMax), and without
/// either the card never shows.

class _FixedBilling extends BillingState {
  _FixedBilling(BillingInfo info)
    : super(
        service: BillingService(
          client: ApiClient.forTest(
            direct: MockClient((_) async => throw http.ClientException('no')),
          ),
        ),
        // The copy Google Play signed, which can buy through Play.
        playBilling: () => _IdlePlay(),
        deviceId: () async => 'DEV-1',
      ) {
    adoptForTest(info);
    adoptWorkedForTest();
  }

  void become(BillingInfo info) => adoptForTest(info);

  @override
  Future<void> refresh() async {}
}

/// A Play that is there and is never used by these tests.
class _IdlePlay implements PlayBilling {
  @override
  Stream<List<PlayPurchase>> get purchases => const Stream.empty();
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<PlayProduct>> products(Set<String> productIds) async => const [];
  @override
  Future<bool> buy(PlayProduct product, {required String accountId}) async =>
      true;
  @override
  Future<void> complete(PlayPurchase purchase) async {}
  @override
  Future<List<PlayPurchase>> owned() async => const [];
}

const _plan = Plan(
  code: 'unlimited_30d',
  google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
);

BillingInfo _on({
  int? every = 168,
  int? most = 3,
  Set<UpsellSurface> surfaces = const {UpsellSurface.calmCard},
  bool premium = false,
}) => BillingInfo(
  enabled: true,
  premium: Premium(active: premium),
  plans: const [_plan],
  rails: const Rails(googlePlay: true),
  upsell: Upsell(surfaces: surfaces, promptEveryHours: every, promptMax: most),
);

void main() {
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 10, 8, 12);
  });

  PremiumPrompt prompt(BillingState billing) =>
      PremiumPrompt(billing: billing, clock: () => now);

  Future<Map<String, dynamic>?> saved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PremiumPrompt.premiumStateKey);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  test('is due with the card on and both numbers set', () async {
    final billing = _FixedBilling(_on());
    expect(await prompt(billing).due(billing), isTrue);
  });

  for (final (name, info) in [
    ('the gap is missing', _on(every: null)),
    ('the most is missing', _on(most: null)),
    ('the card is not on', _on(surfaces: const {UpsellSurface.topChip})),
    ('the device has Premium', _on(premium: true)),
    ('sales are off', const BillingInfo(enabled: false)),
  ]) {
    test('is never due when $name', () async {
      final billing = _FixedBilling(info);
      expect(await prompt(billing).due(billing), isFalse);
    });
  }

  test('shows once per run, and counts at once', () async {
    final billing = _FixedBilling(_on());
    final card = prompt(billing);
    await card.shown();
    expect(card.shownThisRun, isTrue);
    expect(await card.due(billing), isFalse);
    expect(await saved(), {
      'last': now.toIso8601String(),
      'count': 1,
      'done': false,
    });
    // A second call in the same run counts nothing.
    await card.shown();
    expect((await saved())?['count'], 1);
  });

  test('waits the backend\'s gap between two cards', () async {
    final billing = _FixedBilling(_on(every: 168));
    await prompt(billing).shown();

    now = now.add(const Duration(hours: 167));
    expect(await prompt(billing).due(billing), isFalse);
    now = now.add(const Duration(hours: 1));
    expect(await prompt(billing).due(billing), isTrue);
  });

  test('stops at the backend\'s most', () async {
    final billing = _FixedBilling(_on(every: 1, most: 2));
    await prompt(billing).shown();
    now = now.add(const Duration(hours: 2));
    await prompt(billing).shown();
    now = now.add(const Duration(hours: 2));
    expect(await prompt(billing).due(billing), isFalse);
  });

  test('never again once the device has had Premium, even after it '
      'ended', () async {
    final billing = _FixedBilling(_on());
    final card = prompt(billing);
    billing.become(_on(premium: true));
    await pumpEventQueue();
    expect((await saved())?['done'], isTrue);

    billing.become(_on());
    now = now.add(const Duration(days: 400));
    expect(await prompt(billing).due(billing), isFalse);
    card.dispose();
  });

  test('a record it cannot read starts over', () async {
    SharedPreferences.setMockInitialValues({
      PremiumPrompt.premiumStateKey: 'not json',
    });
    final billing = _FixedBilling(_on());
    expect(await prompt(billing).due(billing), isTrue);
  });
}
