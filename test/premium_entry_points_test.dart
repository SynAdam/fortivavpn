import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/my_servers_screen.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/screens/settings_screen.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/widgets/premium_offers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The ways into the Premium screen: a tile in Settings > Account, and
/// "Get unlimited" on the quota card and on the spent-allowance notice.
///
/// Payments ship dark. A backend with sales off (the default) or one that
/// cannot be reached shows nothing new, with one exception: a device that
/// has Premium always gets the tile, so a paying user can read and copy
/// their key whatever the backend has done to sales.
///
/// "Get unlimited" shows only when this copy can buy something here, and
/// never to a device that has Premium. The backend can turn sales on and
/// offer only the code box. Then the tile reads "Enter a code" and opens
/// the code dialog straight away, with no price and no word about buying.
/// So does a copy that cannot buy through Google Play (googleSigned false
/// here), such as the APK posted in the Telegram channel: it is offered
/// nothing to buy anywhere, and the code box stays one tap away.
///
/// The offers the backend turns on one by one (BillingInfo.upsell) add a
/// Premium card on My servers once invites can add no more data, and
/// locked Premium locations under this device's own servers. Each
/// shows with sales on and its surface named, and hides for sales off, a
/// Premium device and the codes-only answer.
///
/// Every way in, old and new, needs the backend's offer block
/// (BillingState.offersAllowed), and with no block nobody is offered
/// Premium. Where the phone is plays no part, see
/// test/offers_every_country_test.dart.

/// Billing with a fixed answer. [googleSigned] is what the signature check
/// said: true for the copy Google Play signed, which has a Play to sell
/// through, and false for any other copy.
class _FixedBilling extends BillingState {
  _FixedBilling(
    BillingInfo info, {
    PlayBilling? play,
    Set<String> owned = const {},
    bool googleSigned = true,
  }) : super(
         service: BillingService(
           client: ApiClient.forTest(
             direct: MockClient((_) async => throw http.ClientException('no')),
           ),
         ),
         playBilling: () => play ?? _IdlePlay(),
         deviceId: () async => 'DEV-1',
       ) {
    adoptForTest(info, owned: owned, googleSigned: googleSigned);
    adoptWorkedForTest();
  }

  @override
  Future<void> refresh() async {}
}

/// A plan Google Play sells.
const _playPlan = Plan(
  code: 'unlimited_30d',
  google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
);

/// Sales on, with something to buy through Google Play, and the backend's
/// offer block.
const _on = BillingInfo(
  enabled: true,
  plans: [_playPlan],
  rails: Rails(googlePlay: true, codes: true),
  upsell: Upsell(),
);

/// [_on] without the offer block. Nothing offers Premium.
const _onNoBlock = BillingInfo(
  enabled: true,
  plans: [_playPlan],
  rails: Rails(googlePlay: true, codes: true),
);

const _off = BillingInfo(enabled: false);
const _onAndPremium = BillingInfo(
  enabled: true,
  premium: Premium(active: true),
  plans: [_playPlan],
  rails: Rails(googlePlay: true, codes: true),
);

/// What the backend answers when it sells nothing to this device: sales
/// on, no plans, and only the code box.
const _codesOnly = BillingInfo(enabled: true, rails: Rails(codes: true));

/// Sales on and nothing at all on offer, not even the code box.
const _nothing = BillingInfo(enabled: true);

/// Sales off, on a device that bought Premium earlier.
const _offAndPremium = BillingInfo(
  enabled: false,
  premium: Premium(active: true, source: 'voucher', code: _key),
);

const _key = 'K7QD-3MWX-9TZB-H2CF';

/// Sales off, and the backend lets the phone restore from Play.
const _offButRestores = BillingInfo(
  enabled: false,
  rails: Rails(playRestore: true),
);

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

class _FakeDedicated extends DedicatedState {
  _FakeDedicated(this._fixed);

  final QuotaStatus _fixed;

  @override
  QuotaStatus? get quota => _fixed;

  @override
  bool get isBlocked => _fixed.blocked;

  @override
  bool get isLoading => false;

  @override
  Server? get selectedServer => null;

  @override
  bool get hasServers => false;

  @override
  Future<void> refresh({bool? viaTunnel}) async {}
}

/// With one server of its own.
class _WithServer extends _FakeDedicated {
  _WithServer() : super(_quota());

  @override
  bool get hasServers => true;

  @override
  List<Server> get servers => const [_own];

  @override
  int? pingFor(String serverId) => null;

  @override
  bool isPinging(String serverId) => false;
}

const _own = Server(
  id: 'dedicated-0',
  name: 'Fortiva DE',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
  isDedicated: true,
);

const _helsinki = LockedServer(id: 14, countryCode: 'FI', city: 'Helsinki');

/// [info] with the upsell block naming [surfaces].
BillingInfo _with(
  BillingInfo info,
  Set<UpsellSurface> surfaces, {
  List<LockedServer> locked = const [_helsinki],
}) => BillingInfo(
  enabled: info.enabled,
  premium: info.premium,
  plans: info.plans,
  rails: info.rails,
  upsell: Upsell(surfaces: surfaces, lockedServers: locked),
);

QuotaStatus _quota({bool blocked = false}) => QuotaStatus(
  unlimited: false,
  limitBytes: 5 << 30,
  usedBytes: blocked ? 5 << 30 : 1 << 30,
  remainingBytes: blocked ? 0 : 4 << 30,
  blocked: blocked,
);

const _languages = [
  'ar',
  'de',
  'en',
  'es',
  'fa',
  'fr',
  'hi',
  'id',
  'ja',
  'ko',
  'pt',
  'ru',
  'tr',
  'uk',
  'ur',
  'uz',
  'vi',
  'zh',
];

final _digit = RegExp(r'\p{Nd}', unicode: true);

Widget _app(
  Widget home, {
  BillingState? billing,
  DedicatedState? dedicated,
  AppConfigState? config,
  ReferralState? referrals,
  String locale = 'en',
}) => MultiProvider(
  providers: [
    if (billing != null)
      ChangeNotifierProvider<BillingState>.value(value: billing),
    ChangeNotifierProvider<DedicatedState>.value(
      value: dedicated ?? _FakeDedicated(_quota()),
    ),
    if (config != null)
      ChangeNotifierProvider<AppConfigState>.value(value: config)
    else
      ChangeNotifierProvider<AppConfigState>(
        create: (_) => AppConfigState(
          fetch: () async => throw StateError('no fetch in tests'),
        ),
      ),
    ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
    if (referrals != null)
      ChangeNotifierProvider<ReferralState>.value(value: referrals)
    else
      ChangeNotifierProvider<ReferralState>(create: (_) => ReferralState()),
  ],
  child: MaterialApp(
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: Locale(locale),
    home: home,
  ),
);

/// The app config as it arrives, with invites on or off.
Future<AppConfigState> _config({required bool invites}) async {
  final config = AppConfigState(
    fetch: () async => AppConfig.fromJson({
      'privacy_policy_url': 'https://example.com/privacy',
      'terms_of_service_url': 'https://example.com/terms',
      'eula_url': 'https://example.com/eula',
      'support_email': 'support@example.com',
      'force_update': {
        for (final os in ['ios', 'android'])
          os: {
            'latest_version': '1.6.11',
            'minimum_version': '1.6.9',
            'update_url': 'https://example.com/update',
          },
      },
      'feature_flags': {'enable_referrals': invites},
    }),
  );
  await config.load();
  return config;
}

/// This device's invites, as the invite screen loaded them.
ReferralState _invited({required int bonus, int? most}) =>
    ReferralState()..adoptForTest(
      ReferralStatus(
        code: 'ABC',
        shareUrl: 'https://example.com/i/ABC',
        invitedCount: 0,
        confirmedCount: 0,
        bonusBytes: bonus,
        maxBonusBytes: most,
      ),
    );

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

/// Tap a tile found after scrolling to another one. The list builds tiles
/// a little past the bottom edge, so a tile can be found and still be off
/// the screen. Bring it on screen first.
Future<void> _tapTile(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Settings > Account', () {
    final deleteTile = find.text('Delete account');

    testWidgets('no Premium tile while sales are off', (tester) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_off)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('with sales off, no tile shows where the backend lets the '
        'phone restore, even when the Google account pays for a '
        'subscription', (tester) async {
      // The subscription is restored in the background, and the tile then
      // shows because the device has Premium.
      await tester.pumpWidget(
        _app(
          const SettingsScreen(),
          billing: _FixedBilling(
            _offButRestores,
            play: _IdlePlay(),
            owned: const {'premium'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('no Premium tile on a build without payments state', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SettingsScreen()));
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('the tile opens the Premium screen while sales are on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_on)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Unlimited data with no daily limit'), findsOneWidget);

      await _tapTile(tester, find.text('Premium'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets('with no offer block, the tile reads Enter a code', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_onNoBlock)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('in a copy that cannot buy through Google Play, the tile '
        'reads Enter a code and opens the code dialog', (tester) async {
      await tester.pumpWidget(
        _app(
          const SettingsScreen(),
          billing: _FixedBilling(_on, googleSigned: false),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text('Premium'), findsNothing);
      expect(find.text('Unlimited data with no daily limit'), findsNothing);

      await _tapTile(tester, find.text('Enter a code'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('where Play says it cannot sell, the tile reads Enter a '
        'code', (tester) async {
      final billing = _FixedBilling(_on)
        ..adoptForTest(_on, playAvailable: false);
      await tester.pumpWidget(_app(const SettingsScreen(), billing: billing));
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('a Premium device keeps its tile in a copy that cannot buy '
        'through Google Play', (tester) async {
      await tester.pumpWidget(
        _app(
          const SettingsScreen(),
          billing: _FixedBilling(_onAndPremium, googleSigned: false),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Premium is on'), findsOneWidget);
    });

    testWidgets('turning off diagnostics drops the offer events waiting', (
      tester,
    ) async {
      final billing = _FixedBilling(_on)
        ..logUpsell(UpsellSurface.topChip, UpsellAction.shown);
      expect(billing.pendingUpsellEvents, hasLength(1));
      await tester.pumpWidget(_app(const SettingsScreen(), billing: billing));
      await tester.pumpAndSettle();
      final share = find.byType(Switch);
      await _scrollTo(tester, share);

      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(billing.pendingUpsellEvents, isEmpty);
      billing.logUpsell(UpsellSurface.topChip, UpsellAction.tapped);
      expect(billing.pendingUpsellEvents, isEmpty);
      await tester.pumpWidget(const SizedBox());
      billing.dispose();
    });

    testWidgets('a Premium device sees that it is on', (tester) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_onAndPremium)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium is on'), findsOneWidget);
    });

    testWidgets('a Premium device keeps the tile and its key while sales '
        'are off', (tester) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_offAndPremium)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Premium is on'), findsOneWidget);

      await _tapTile(tester, find.text('Premium'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text(_key), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      // Nothing is offered for sale.
      expect(find.text('Buy'), findsNothing);
      expect(find.text('Choose a plan'), findsNothing);
    });

    testWidgets('with only the code box on offer, the tile reads Enter a '
        'code and opens the code dialog', (tester) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_codesOnly)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Enter a code'), findsOneWidget);
      expect(find.text('A Premium key or a gift code'), findsOneWidget);
      expect(find.text('Premium'), findsNothing);
      expect(find.text('Unlimited data with no daily limit'), findsNothing);

      await _tapTile(tester, find.text('Enter a code'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a Premium device with only the code box on offer still '
        'opens the Premium screen', (tester) async {
      const premiumCodesOnly = BillingInfo(
        enabled: true,
        premium: Premium(active: true, code: _key),
        rails: Rails(codes: true),
      );
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(premiumCodesOnly)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium is on'), findsOneWidget);
      await _tapTile(tester, find.text('Premium'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text(_key), findsOneWidget);
    });

    // Every copy sends store=play, so the backend's codes rail decides the
    // key box in every copy (BILLING_PLAY_CODES on the backend). The channel
    // APKs of 1.6.16 and 1.6.17 sent store=direct and got the box whatever
    // that setting said.
    for (final signed in [true, false]) {
      final copy = signed
          ? 'the copy Google signed'
          : 'a copy Google did not sign';
      for (final codes in [true, false]) {
        testWidgets('in $copy the Enter a code tile follows the codes rail '
            '(codes: $codes)', (tester) async {
          // Sales on with a Play plan, and no offer block.
          final info = BillingInfo(
            enabled: true,
            plans: const [_playPlan],
            rails: Rails(googlePlay: true, codes: codes),
          );
          await tester.pumpWidget(
            _app(
              const SettingsScreen(),
              billing: _FixedBilling(info, googleSigned: signed),
            ),
          );
          await tester.pumpAndSettle();
          await _scrollTo(tester, deleteTile);

          expect(
            find.text('Enter a code'),
            codes ? findsOneWidget : findsNothing,
          );
          expect(find.text('Premium'), findsNothing);
        });
      }
    }

    testWidgets('with nothing on offer and no code box, there is no tile', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const SettingsScreen(), billing: _FixedBilling(_nothing)),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, deleteTile);

      expect(find.text('Premium'), findsNothing);
      expect(find.text('Enter a code'), findsNothing);
    });

    for (final lang in _languages) {
      testWidgets('[$lang] the Enter a code tile names no number and no '
          'price', (tester) async {
        await tester.pumpWidget(
          _app(
            const SettingsScreen(),
            billing: _FixedBilling(_codesOnly),
            locale: lang,
          ),
        );
        await tester.pumpAndSettle();
        final s = lookupS(Locale(lang));
        final tile = find.text(s.premiumEnterCode);
        await _scrollTo(tester, tile);

        expect(tile, findsOneWidget);
        expect(find.text(s.redeemSubtitle), findsOneWidget);
        for (final text in [s.premiumEnterCode, s.redeemSubtitle]) {
          expect(_digit.hasMatch(text), isFalse, reason: text);
        }
        // Neither the buy texts nor the sales pitch are on the screen.
        for (final text in [
          s.premiumBuy,
          s.premiumGetUnlimited,
          s.premiumTileSubtitle,
          s.premiumTitle,
        ]) {
          expect(find.text(text), findsNothing, reason: text);
        }
      });
    }
  });

  group('the quota card', () {
    testWidgets('offers Get unlimited while sales are on', (tester) async {
      await tester.pumpWidget(
        _app(const MyServersScreen(), billing: _FixedBilling(_on)),
      );
      await tester.pump();

      expect(find.text('Get unlimited'), findsOneWidget);
      await tester.tap(find.text('Get unlimited'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    for (final (name, info) in [
      ('sales are off', _off),
      ('the device has Premium', _onAndPremium),
      ('only the code box is on offer', _codesOnly),
      ('nothing is on offer', _nothing),
      ('sales are off on a Premium device', _offAndPremium),
      ('the backend sent no offer block', _onNoBlock),
      // No copy shows these rails, so they offer nothing.
      (
        'an older backend sells only through crypto and Telegram',
        BillingInfo.fromJson({
          'enabled': true,
          'plans': [
            {'code': 'p', 'usdt': '4.99', 'stars': 350},
          ],
          'rails': {'crypto': true, 'telegram': true, 'codes': true},
          'networks': [
            {'id': 'ton_usdt', 'label': 'USDT on TON'},
          ],
          'upsell': <String, Object?>{},
        }),
      ),
    ]) {
      testWidgets('has no Get unlimited when $name', (tester) async {
        await tester.pumpWidget(
          _app(const MyServersScreen(), billing: _FixedBilling(info)),
        );
        await tester.pump();

        expect(find.text('Get unlimited'), findsNothing);
      });
    }

    testWidgets('has no Get unlimited in a copy that cannot buy through '
        'Google Play', (tester) async {
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: _FixedBilling(_on, googleSigned: false),
        ),
      );
      await tester.pump();

      expect(find.text('Get unlimited'), findsNothing);
    });

    testWidgets('has no Get unlimited without payments state', (tester) async {
      await tester.pumpWidget(_app(const MyServersScreen()));
      await tester.pump();

      expect(find.text('Get unlimited'), findsNothing);
    });

    testWidgets('leads the Premium screen with no daily limit', (tester) async {
      await tester.pumpWidget(
        _app(const MyServersScreen(), billing: _FixedBilling(_on)),
      );
      await tester.pump();
      await tester.tap(find.text('Get unlimited'));
      await tester.pumpAndSettle();
      expect(find.text('No daily limit'), findsOneWidget);
    });
  });

  group('the Premium next-step card', () {
    final title = find.text('The next step is Premium');

    testWidgets('shows when invites are off', (tester) async {
      final billing = _FixedBilling(_with(_on, {UpsellSurface.myServersCard}));
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: billing,
          dedicated: _WithServer(),
          config: await _config(invites: false),
        ),
      );
      await tester.pump();

      expect(title, findsOneWidget);
      expect(
        find.text(
          'You already have the most free data. Premium has no daily limit.',
        ),
        findsOneWidget,
      );
      // Its own Get unlimited, next to the quota card's.
      expect(find.text('Get unlimited'), findsNWidgets(2));
      await tester.tap(find.text('Get unlimited').at(1));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(
        [for (final e in billing.pendingUpsellEvents) e['action']],
        ['shown', 'tapped'],
      );
      // Stops the wait before the events are sent.
      await tester.pumpWidget(const SizedBox());
      billing.dispose();
    });

    for (final (name, info) in [
      ('sales are off', _off),
      ('the device has Premium', _onAndPremium),
      ('only the code box is on offer', _codesOnly),
    ]) {
      testWidgets('is not there when $name', (tester) async {
        await tester.pumpWidget(
          _app(
            const MyServersScreen(),
            billing: _FixedBilling(_with(info, {UpsellSurface.myServersCard})),
            dedicated: _WithServer(),
            config: await _config(invites: false),
          ),
        );
        await tester.pump();
        expect(title, findsNothing);
      });
    }

    // The card says the user already has the most free data. While invites
    // can still add some, that is not true, and invites come first.
    testWidgets('is not there while invites can still add data', (
      tester,
    ) async {
      final config = await _config(invites: true);
      for (final referrals in [
        // The invite screen has not loaded the invites yet.
        ReferralState(),
        _invited(bonus: 2 << 30, most: 10 << 30),
        // The backend did not say how much invites give at most.
        _invited(bonus: 2 << 30),
      ]) {
        await tester.pumpWidget(
          _app(
            const MyServersScreen(),
            billing: _FixedBilling(_with(_on, {UpsellSurface.myServersCard})),
            dedicated: _WithServer(),
            config: config,
            referrals: referrals,
          ),
        );
        await tester.pump();
        expect(title, findsNothing);
      }
    });

    testWidgets('is not there before the config says whether invites are '
        'on', (tester) async {
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: _FixedBilling(_with(_on, {UpsellSurface.myServersCard})),
          dedicated: _WithServer(),
        ),
      );
      await tester.pump();
      expect(title, findsNothing);
    });

    testWidgets('is there once invites have given all they can', (
      tester,
    ) async {
      final billing = _FixedBilling(_with(_on, {UpsellSurface.myServersCard}));
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: billing,
          dedicated: _WithServer(),
          config: await _config(invites: true),
          referrals: _invited(bonus: 10 << 30, most: 10 << 30),
        ),
      );
      await tester.pump();
      expect(title, findsOneWidget);
      // Stops the wait before the events are sent.
      await tester.pumpWidget(const SizedBox());
      billing.dispose();
    });
  });

  group('locked Premium locations', () {
    final tile = find.byType(LockedServerTile);

    testWidgets('show under this device\'s servers, and a tap explains '
        'them', (tester) async {
      final billing = _FixedBilling(_with(_on, {UpsellSurface.lockedServers}));
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: billing,
          dedicated: _WithServer(),
        ),
      );
      await tester.pump();

      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('Helsinki')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text('Premium')),
        findsOneWidget,
      );
      // Below the device's own server.
      expect(
        tester.getTopLeft(tile).dy,
        greaterThan(tester.getTopLeft(find.text('Fortiva DE')).dy),
      );

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Unlock Helsinki with Premium'), findsOneWidget);
      expect(
        find.text(
          'This location is for Premium. Your free servers stay the same.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock Helsinki with Premium'), findsNothing);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get unlimited').last);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      // The Premium screen leads with the place.
      expect(find.text('Unlock Helsinki with Premium'), findsOneWidget);
      expect(
        [for (final e in billing.pendingUpsellEvents) e['action']],
        ['shown', 'dismissed', 'tapped'],
      );
      await tester.pumpWidget(const SizedBox());
      billing.dispose();
    });

    for (final (name, info) in [
      ('sales are off', _off),
      ('the device has Premium', _onAndPremium),
      ('only the code box is on offer', _codesOnly),
    ]) {
      testWidgets('are not there when $name', (tester) async {
        await tester.pumpWidget(
          _app(
            const MyServersScreen(),
            billing: _FixedBilling(_with(info, {UpsellSurface.lockedServers})),
            dedicated: _WithServer(),
          ),
        );
        await tester.pump();
        expect(tile, findsNothing);
      });
    }

    testWidgets('are not there in a copy that cannot buy through Google '
        'Play', (tester) async {
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: _FixedBilling(
            _with(_on, {
              UpsellSurface.lockedServers,
              UpsellSurface.myServersCard,
            }),
            googleSigned: false,
          ),
          dedicated: _WithServer(),
          config: await _config(invites: false),
        ),
      );
      await tester.pump();
      expect(tile, findsNothing);
      expect(find.text('The next step is Premium'), findsNothing);
    });

    testWidgets('are not there when the backend lists none', (tester) async {
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: _FixedBilling(
            _with(_on, {UpsellSurface.lockedServers}, locked: const []),
          ),
          dedicated: _WithServer(),
        ),
      );
      await tester.pump();
      expect(tile, findsNothing);
    });

    testWidgets('are not there while the surface is off', (tester) async {
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: _FixedBilling(_with(_on, {UpsellSurface.topChip})),
          dedicated: _WithServer(),
        ),
      );
      await tester.pump();
      expect(tile, findsNothing);
    });
  });

  group('the spent-allowance notice', () {
    testWidgets('offers Get unlimited too', (tester) async {
      await tester.pumpWidget(
        _app(
          const MyServersScreen(),
          billing: _FixedBilling(_on),
          dedicated: _FakeDedicated(_quota(blocked: true)),
        ),
      );
      await tester.pump();

      expect(find.text('You have used today\'s data'), findsOneWidget);
      // One on the card, one on the notice.
      expect(find.text('Get unlimited'), findsNWidgets(2));
    });

    for (final (name, info, signed) in [
      ('sales are off', _off, true),
      ('only the code box is on offer', _codesOnly, true),
      ('the backend sent no offer block', _onNoBlock, true),
      ('this copy cannot buy through Google Play', _on, false),
    ]) {
      testWidgets('stays as it was when $name', (tester) async {
        await tester.pumpWidget(
          _app(
            const MyServersScreen(),
            billing: _FixedBilling(info, googleSigned: signed),
            dedicated: _FakeDedicated(_quota(blocked: true)),
          ),
        );
        await tester.pump();

        expect(find.text('You have used today\'s data'), findsOneWidget);
        expect(find.text('Get unlimited'), findsNothing);
      });
    }
  });
}
