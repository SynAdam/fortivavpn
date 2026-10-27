import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/premium_prompt.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/in_app_message.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/screens/premium_screen.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/utils/number_localizer.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/premium_offers.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The offers on the home screen: the Premium chip in the top bar, "Get
/// unlimited" on the spent server card and after the data line, the
/// limit sheet, the calm card after a working connection, and the
/// reminder before Premium ends.
///
/// Each one shows only through BillingState.upsellOn (see
/// test/upsell_gate_test.dart), never while a connect is under way or an
/// error is on screen, and never on a TV. A copy that cannot buy through
/// Google Play, such as the APK posted in the Telegram channel, shows none
/// of them. The home screen with no BillingState above it is the one the
/// other home tests draw, and it is unchanged.

const _shared = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

const _plan = Plan(
  code: 'unlimited_30d',
  google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
);

/// Every billing state a test made, disposed when the test is done so
/// the wait before offer events are sent stops with it.
final _made = <BillingState>[];

/// Billing with a fixed answer. [googleSigned] is what the signature check
/// said: true for the copy Google Play signed, false for any other, such
/// as the channel APK.
class _FixedBilling extends BillingState {
  _FixedBilling(BillingInfo info, {bool googleSigned = true})
    : super(
        service: BillingService(
          client: ApiClient.forTest(
            direct: MockClient((_) async => throw http.ClientException('no')),
          ),
        ),
        playBilling: () => _IdlePlay(),
        deviceId: () async => 'DEV-1',
      ) {
    adoptForTest(info, googleSigned: googleSigned);
    adoptWorkedForTest();
    _made.add(this);
  }

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

/// A button whose type is FilledButton or one made by FilledButton.icon.
Finder _filled(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

BillingInfo _on(
  Set<UpsellSurface> surfaces, {
  int? nudge,
  int? every,
  int? most,
  Renewal? renewal,
  Premium premium = Premium.none,
  bool olderLists = false,
}) => BillingInfo(
  enabled: true,
  premium: premium,
  plans: const [_plan],
  rails: const Rails(googlePlay: true, codes: true),
  upsell: olderLists
      ? _olderBlock(surfaces)
      : Upsell(
          surfaces: surfaces,
          nudgeUsedPercent: nudge,
          promptEveryHours: every,
          promptMax: most,
        ),
  renewal: renewal,
);

const _off = BillingInfo(enabled: false);

BillingInfo _onAndPremium(
  Set<UpsellSurface> surfaces, {
  bool olderLists = false,
}) => BillingInfo(
  enabled: true,
  premium: const Premium(active: true),
  plans: const [_plan],
  rails: const Rails(googlePlay: true),
  upsell: olderLists ? _olderBlock(surfaces) : Upsell(surfaces: surfaces),
);

/// An upsell block naming [surfaces] as an older backend sent it, with
/// country and time zone lists the app no longer reads. They name the
/// places in [_readings].
Upsell _olderBlock(Set<UpsellSurface> surfaces) => Upsell.fromJson({
  'surfaces': [for (final s in surfaces) s.wire],
  'hide_phone_countries': ['IR', 'AF'],
  'hide_time_zones': ['Asia/Tehran', 'Asia/Kabul'],
})!;

/// What the phone may say about where it is (the platform's `place`
/// answer). Offers never depend on it.
const _readings = <(String, Map<String, Object?>?)>[
  ('the phone says nothing about where it is', null),
  ('the SIM names a listed country', {'sim_country': 'ir'}),
  ('the cell network names a listed country', {'network_country': 'af'}),
  ('the time zone is a listed one', {'time_zone': 'Asia/Tehran'}),
  (
    'the SIM, the cell network and the time zone are all listed',
    {
      'sim_country': 'ir',
      'network_country': 'ir',
      'roaming': false,
      'time_zone': 'Asia/Tehran',
    },
  ),
  (
    'nothing about the phone is listed',
    {
      'sim_country': 'de',
      'network_country': 'de',
      'time_zone': 'Europe/Berlin',
    },
  ),
];

/// The codes-only answer, as if the backend had still sent a block.
BillingInfo _codesOnly(Set<UpsellSurface> surfaces) => BillingInfo(
  enabled: true,
  rails: const Rails(codes: true),
  upsell: Upsell(surfaces: surfaces),
);

/// What the backend answers a device it wants no offer on: sales on, only
/// the code box, and no upsell block at all.
const _noBlock = BillingInfo(enabled: true, rails: Rails(codes: true));

/// A loaded app config with the limit sheet's switch.
Future<AppConfigState> _config({bool limitSheet = true}) async {
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
      'feature_flags': {'limit_sheet': limitSheet},
    }),
  );
  await config.load();
  return config;
}

QuotaStatus _quota({int used = 10, bool blocked = false, bool reset = true}) =>
    QuotaStatus(
      unlimited: false,
      limitBytes: 100 << 20,
      usedBytes: blocked ? 100 << 20 : used << 20,
      remainingBytes: blocked ? 0 : (100 - used) << 20,
      blocked: blocked,
      resetsAt: reset ? DateTime.now().add(const Duration(hours: 3)) : null,
    );

class _Dedicated extends DedicatedState {
  _Dedicated(this._fixed);

  QuotaStatus _fixed;

  void become(QuotaStatus quota) {
    _fixed = quota;
    notifyListeners();
  }

  @override
  QuotaStatus? get quota => _fixed;

  @override
  bool get isBlocked => _fixed.blocked;

  @override
  Server? get selectedServer => null;

  @override
  bool get hasServers => false;

  /// What the next refresh finds, as the backend would answer it.
  QuotaStatus? onRefresh;

  @override
  Future<void> refresh({bool? viaTunnel}) async {
    final next = onRefresh;
    if (next != null) become(next);
  }

  @override
  int? pingFor(String serverId) => null;

  @override
  Future<void> pingServer(Server server) async {}
}

/// A connect flow whose busy state a test sets.
class _Flow extends ConnectFlow {
  _Flow({required super.vpn});

  bool _busy = false;

  void busy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  bool get isBusy => _busy;
}

class _Servers extends ServerState {
  @override
  Server? get selectedServer => _shared;

  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}

  @override
  int? getPingResult(String serverId) => 42;

  @override
  Future<void> pingServer(Server server) async {}
}

class _Vpn extends VpnService {
  _Vpn(this._fake) : _since = DateTime.now().subtract(const Duration(hours: 1));

  VpnStatus _fake;
  final DateTime _since;

  void become(VpnStatus status) {
    _fake = status;
    notifyListeners();
  }

  @override
  VpnStatus get status => _fake;

  @override
  bool get isConnected => _fake == VpnStatus.connected;

  @override
  bool get isConnecting => _fake == VpnStatus.connecting;

  @override
  bool get isVerifying => false;

  @override
  ConnectionInfo? get currentConnection => _fake == VpnStatus.connected
      ? ConnectionInfo(startTime: _since, serverId: 'x', serverName: 'DE')
      : null;

  @override
  Future<void> connect(
    Server server, {
    String? attemptId,
    List<Server> standby = const [],
    LinkSource? source,
  }) async {}

  @override
  Future<void> disconnect() async => become(VpnStatus.disconnected);
}

void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  const statusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

  /// What the platform answers when asked where the phone is.
  Map<String, Object?>? phonePlace;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    phonePlace = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, (call) async {
      return switch (call.method) {
        'getStatus' => 'disconnected',
        'place' => phonePlace,
        _ => null,
      };
    });
    messenger.setMockStreamHandler(
      statusChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(tunnel, null);
    messenger.setMockStreamHandler(statusChannel, null);
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    BillingState? billing,
    _Dedicated? dedicated,
    _Vpn? vpn,
    PremiumPrompt? prompt,
    MessageState? messages,
    AppConfigState? config,
    ConnectFlow Function(VpnService vpn)? flow,
    String locale = 'en',
  }) async {
    final tunnelVpn = vpn ?? _Vpn(VpnStatus.disconnected);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DedicatedState>.value(
            value: dedicated ?? _Dedicated(_quota()),
          ),
          ChangeNotifierProvider<ServerState>.value(value: _Servers()),
          ChangeNotifierProvider<VpnService>.value(value: tunnelVpn),
          ChangeNotifierProvider<ConnectFlow>(
            create: (_) => flow?.call(tunnelVpn) ?? ConnectFlow(vpn: tunnelVpn),
          ),
          ChangeNotifierProvider<LocaleState>(create: (_) => LocaleState()),
          if (config != null)
            ChangeNotifierProvider<AppConfigState>.value(value: config)
          else
            ChangeNotifierProvider<AppConfigState>(
              create: (_) => AppConfigState(
                fetch: () async => throw StateError('no fetch in tests'),
              ),
            ),
          if (billing != null)
            ChangeNotifierProvider<BillingState>.value(value: billing),
          if (prompt != null)
            ChangeNotifierProvider<PremiumPrompt>.value(value: prompt),
          if (messages != null)
            ChangeNotifierProvider<MessageState>(
              lazy: false,
              create: (_) => messages,
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Take the screen away, which stops its timers, and let the tunnel
  /// service's first status poll run.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    for (final billing in _made) {
      billing.dispose();
    }
    _made.clear();
  }

  Future<void> wait(WidgetTester tester, Duration time) async {
    for (var i = 0; i < time.inSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  /// Let a sheet or a dialog open or close. The power button under it
  /// animates for as long as it is on screen, so the screen never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final chip = find.widgetWithIcon(InkWell, Icons.workspace_premium_outlined);
  final premiumPill = find.widgetWithIcon(InkWell, Icons.all_inclusive_rounded);

  group('the top bar chip', () {
    testWidgets('offers Premium when the backend turns it on', (tester) async {
      final billing = _FixedBilling(_on({UpsellSurface.topChip}));
      await pumpHome(tester, billing: billing);
      expect(chip, findsOneWidget);
      expect(
        billing.pendingUpsellEvents.single,
        containsPair('action', 'shown'),
      );

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text('Get unlimited data'), findsOneWidget);
      expect(
        [for (final e in billing.pendingUpsellEvents) e['action']],
        ['shown', 'tapped'],
      );
      await done(tester);
    });

    for (final (name, info) in [
      ('sales are off', _off),
      ('the device has Premium', _onAndPremium({UpsellSurface.topChip})),
      ('only the code box is on offer', _codesOnly({UpsellSurface.topChip})),
      ('the block names another surface', _on({UpsellSurface.quotaLine})),
    ]) {
      testWidgets('offers nothing when $name', (tester) async {
        await pumpHome(tester, billing: _FixedBilling(info));
        expect(chip, findsNothing);
        await done(tester);
      });
    }

    testWidgets('offers Premium whatever the phone says about where it is, '
        'and whatever an older backend\'s lists name', (tester) async {
      for (final (name, reading) in _readings) {
        phonePlace = reading;
        await pumpHome(
          tester,
          billing: _FixedBilling(
            _on({UpsellSurface.topChip}, olderLists: true),
          ),
        );
        expect(chip, findsOneWidget, reason: name);
        await done(tester);
      }
    });

    testWidgets('says Premium is on, in teal, on a Premium device', (
      tester,
    ) async {
      // The backend sends no upsell block to a Premium device, so the pill
      // follows Premium itself.
      await pumpHome(tester, billing: _FixedBilling(_onAndPremium(const {})));
      expect(chip, findsNothing);
      expect(premiumPill, findsOneWidget);
      final text = tester.widget<Text>(
        find.descendant(of: premiumPill, matching: find.text('Premium')),
      );
      expect(text.style?.color, AppDesign.accentTeal);
      await tester.tap(premiumPill);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      await done(tester);
    });

    testWidgets('the pill stays through a purchase, whatever the block '
        'says', (tester) async {
      // Right after a purchase the phone still holds the old block until
      // the next load. The pill must not flash on and off.
      await pumpHome(
        tester,
        billing: _FixedBilling(_onAndPremium({UpsellSurface.topChip})),
      );
      expect(premiumPill, findsOneWidget);
      expect(chip, findsNothing);
      await done(tester);
    });

    testWidgets('a Premium phone sees the pill, and behind it the plans, '
        'whatever it says about where it is', (tester) async {
      for (final (name, reading) in _readings) {
        phonePlace = reading;
        await pumpHome(
          tester,
          billing: _FixedBilling(_onAndPremium(const {}, olderLists: true)),
        );
        expect(premiumPill, findsOneWidget, reason: name);
        await tester.tap(premiumPill);
        await tester.pumpAndSettle();
        expect(find.text('Premium is on'), findsOneWidget, reason: name);
        expect(find.text('Choose a plan'), findsOneWidget, reason: name);
        await done(tester);
      }
    });

    testWidgets('a phone without Premium gets no pill', (tester) async {
      await pumpHome(tester, billing: _FixedBilling(_on(const {})));
      expect(chip, findsNothing);
      expect(premiumPill, findsNothing);
      await done(tester);
    });

    testWidgets('hides while a connect is under way', (tester) async {
      final vpn = _Vpn(VpnStatus.connecting);
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.topChip})),
        vpn: vpn,
      );
      expect(chip, findsNothing);
      vpn.become(VpnStatus.disconnected);
      await tester.pump();
      expect(chip, findsOneWidget);
      await done(tester);
    });

    testWidgets('is a full tap target, taller than the pill it draws', (
      tester,
    ) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.topChip})),
      );
      final pill = tester.getRect(chip);
      expect(pill.height, lessThan(48));
      // Just above the pill, inside its 48dp target.
      await tester.tapAt(Offset(pill.center.dx, pill.top - 6));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      await done(tester);
    });

    for (final locale in ['en', 'fa']) {
      testWidgets('[$locale] does not move the power button on the narrowest '
          'phone', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pumpHome(tester, billing: _FixedBilling(_off), locale: locale);
        final without = tester.getRect(find.byType(PowerButton));
        await done(tester);

        await pumpHome(
          tester,
          billing: _FixedBilling(_on({UpsellSurface.topChip})),
          locale: locale,
        );
        expect(chip, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(find.byType(PowerButton)), without);
        // The chip sits at the start of the bar, inside it.
        expect(tester.getRect(chip).right, lessThanOrEqualTo(320));
        await done(tester);
      });
    }
  });

  group('the spent server card', () {
    final button = _filled('Get unlimited');

    testWidgets('offers Get unlimited, which leads with no daily limit', (
      tester,
    ) async {
      final billing = _FixedBilling(_on({UpsellSurface.serverCard}));
      await pumpHome(
        tester,
        billing: billing,
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
      );
      expect(find.text('Daily limit reached'), findsOneWidget);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text('No daily limit'), findsOneWidget);
      await done(tester);
    });

    for (final (name, info) in [
      ('sales are off', _off),
      ('the device has Premium', _onAndPremium({UpsellSurface.serverCard})),
      ('only the code box is on offer', _codesOnly({UpsellSurface.serverCard})),
      ('the surface is off', _on(const {})),
    ]) {
      testWidgets('has no button when $name', (tester) async {
        await pumpHome(
          tester,
          billing: _FixedBilling(info),
          dedicated: _Dedicated(_quota(blocked: true, reset: false)),
        );
        expect(find.text('Daily limit reached'), findsOneWidget);
        expect(button, findsNothing);
        await done(tester);
      });
    }

    testWidgets('in Persian says when the data refills in Persian digits', (
      tester,
    ) async {
      await pumpHome(
        tester,
        dedicated: _Dedicated(_quota(blocked: true)),
        locale: 'fa',
      );
      // _quota refills in a little under 3 hours.
      final latin = lookupS(const Locale('fa')).quotaResetsInHours(2);
      expect(latin, contains('2'));
      expect(
        find.text(NumberLocalizer.localizeForLocale(latin, 'fa')),
        findsOneWidget,
      );
      expect(find.text(latin), findsNothing);
      await done(tester);
    });

    testWidgets('has no button on a TV', (tester) async {
      FormFactor.isTvForTest = true;
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.serverCard})),
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
      );
      expect(button, findsNothing);
      await done(tester);
    });
  });

  group('the data line', () {
    final link = find.text('Get unlimited');

    testWidgets('offers Get unlimited once the backend\'s share is used', (
      tester,
    ) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.quotaLine}, nudge: 80)),
        dedicated: _Dedicated(_quota(used: 85)),
      );
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.text('No daily limit'), findsOneWidget);
      await done(tester);
    });

    testWidgets('a tap on the amounts opens nothing', (tester) async {
      final billing = _FixedBilling(_on({UpsellSurface.quotaLine}, nudge: 80));
      await pumpHome(
        tester,
        billing: billing,
        dedicated: _Dedicated(_quota(used: 85)),
      );
      expect(link, findsOneWidget);
      final amounts = find.textContaining('used today');
      expect(amounts, findsOneWidget);
      await tester.tap(amounts);
      await tester.pumpAndSettle();
      expect(find.text('No daily limit'), findsNothing);
      expect([
        for (final e in billing.pendingUpsellEvents) e['action'],
      ], isNot(contains('tapped')));
      await done(tester);
    });

    testWidgets('says nothing more below the share', (tester) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.quotaLine}, nudge: 80)),
        dedicated: _Dedicated(_quota(used: 79)),
      );
      expect(link, findsNothing);
      await done(tester);
    });

    testWidgets('says nothing more when the backend sent no share', (
      tester,
    ) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.quotaLine})),
        dedicated: _Dedicated(_quota(used: 99)),
      );
      expect(link, findsNothing);
      await done(tester);
    });

    for (final (name, info) in [
      ('sales are off', _off),
      ('the device has Premium', _onAndPremium({UpsellSurface.quotaLine})),
      ('only the code box is on offer', _codesOnly({UpsellSurface.quotaLine})),
    ]) {
      testWidgets('says nothing more when $name', (tester) async {
        await pumpHome(
          tester,
          billing: _FixedBilling(info),
          dedicated: _Dedicated(_quota(used: 99)),
        );
        expect(link, findsNothing);
        await done(tester);
      });
    }
  });

  group('the limit sheet', () {
    final sheet = find.text('Today\'s data is used up');
    final premiumRow = find.text('Premium has no daily limit.');

    testWidgets('opens on a tap while the allowance is spent', (tester) async {
      final billing = _FixedBilling(_on({UpsellSurface.limitSheet}));
      await pumpHome(
        tester,
        billing: billing,
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
      );
      expect(sheet, findsNothing);

      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      // The reset line, under the title. The server card under the sheet
      // says the same.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(
            'Your allowance resets automatically. Check back soon.',
          ),
        ),
        findsOneWidget,
      );
      expect(premiumRow, findsOneWidget);

      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(sheet, findsNothing);
      expect(
        [for (final e in billing.pendingUpsellEvents) e['action']],
        ['shown', 'dismissed'],
      );

      // Every tap.
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      await tester.tap(premiumRow);
      await settle(tester);
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text('No daily limit'), findsOneWidget);
      await done(tester);
    });

    testWidgets('makes Premium its one filled button, under the wait', (
      tester,
    ) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.limitSheet})),
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
        config: await _config(),
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      final sheet = find.byType(BottomSheet);
      final filled = find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(filled, findsOneWidget);
      expect(find.descendant(of: filled, matching: premiumRow), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('limit-sheet-reset'))).dy,
        lessThan(tester.getTopLeft(premiumRow).dy),
      );
      await done(tester);
    });

    testWidgets('with no offer block it opens, says when the data refills, '
        'and has no Premium row', (tester) async {
      // The codes-only answer has no upsell block, so the block cannot be
      // what opens the sheet there.
      final billing = _FixedBilling(_noBlock);
      await pumpHome(
        tester,
        billing: billing,
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
        config: await _config(),
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      // The reset line, under the title. The server card under the sheet
      // says the same.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(
            'Your allowance resets automatically. Check back soon.',
          ),
        ),
        findsOneWidget,
      );
      expect(premiumRow, findsNothing);
      expect(find.text('Get unlimited'), findsNothing);
      await tester.tap(find.text('Not now'));
      await settle(tester);
      // Nothing about an offer is noted: none was shown.
      expect(billing.pendingUpsellEvents, isEmpty);
      await done(tester);
    });

    testWidgets('with no offer block it opens by itself once per refill too', (
      tester,
    ) async {
      final dedicated = _Dedicated(_quota());
      await pumpHome(
        tester,
        billing: _FixedBilling(_noBlock),
        dedicated: dedicated,
        config: await _config(),
      );
      dedicated.become(_quota(blocked: true));
      await wait(tester, const Duration(seconds: 6));
      await settle(tester);
      expect(sheet, findsOneWidget);
      expect(premiumRow, findsNothing);
      await done(tester);
    });

    testWidgets('stays shut when the config turns it off', (tester) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.limitSheet})),
        dedicated: _Dedicated(_quota(blocked: true)),
        config: await _config(limitSheet: false),
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      await wait(tester, const Duration(seconds: 10));
      await settle(tester);
      expect(sheet, findsNothing);
      await done(tester);
    });

    testWidgets('has the Premium row whatever the phone says about where it '
        'is, and whatever an older backend\'s lists name', (tester) async {
      for (final (name, reading) in _readings) {
        phonePlace = reading;
        await pumpHome(
          tester,
          billing: _FixedBilling(
            _on({UpsellSurface.limitSheet}, olderLists: true),
          ),
          dedicated: _Dedicated(_quota(blocked: true, reset: false)),
        );
        await tester.tap(find.byType(PowerButton));
        await settle(tester);
        expect(sheet, findsOneWidget, reason: name);
        expect(premiumRow, findsOneWidget, reason: name);
        await done(tester);
      }
    });

    testWidgets('it opens without the backend\'s block, and the Premium row '
        'needs the block', (tester) async {
      final config = await _config();
      await pumpHome(
        tester,
        billing: _FixedBilling(_on(const {})),
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
        config: config,
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      expect(premiumRow, findsNothing);
      await done(tester);

      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.limitSheet})),
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
        config: config,
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(premiumRow, findsOneWidget);
      await done(tester);
    });

    testWidgets('opens nothing on a TV', (tester) async {
      FormFactor.isTvForTest = true;
      await pumpHome(
        tester,
        billing: _FixedBilling(_noBlock),
        dedicated: _Dedicated(_quota(blocked: true)),
        config: await _config(),
      );
      await wait(tester, const Duration(seconds: 10));
      await settle(tester);
      expect(sheet, findsNothing);
      await done(tester);
    });

    testWidgets('opens with sales off and with no payments at all', (
      tester,
    ) async {
      // A config that never loaded leaves the switch on too.
      await pumpHome(
        tester,
        billing: _FixedBilling(_off),
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      expect(premiumRow, findsNothing);
      await done(tester);

      await pumpHome(
        tester,
        dedicated: _Dedicated(_quota(blocked: true, reset: false)),
      );
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      await done(tester);
    });

    testWidgets('opens on the tap that finds the allowance spent', (
      tester,
    ) async {
      // The quota on screen still has data left; the look the tap makes
      // before dialling finds it spent. Nothing is dialled, and until
      // 2026-10-08 nothing was shown either, because the sheet followed
      // only a tap that started with no server.
      final dedicated = _Dedicated(_quota(used: 99));
      await pumpHome(
        tester,
        billing: _FixedBilling(_noBlock),
        dedicated: dedicated,
      );
      // After the look the screen takes at launch.
      dedicated.onRefresh = _quota(blocked: true);
      expect(dedicated.isBlocked, isFalse);
      expect(sheet, findsNothing);
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget);
      expect(premiumRow, findsNothing);
      await done(tester);
    });

    testWidgets('opens by itself once a page that was on top at the time '
        'is closed', (tester) async {
      // Until 2026-10-08 the wait ran once: if the screen was covered when
      // it ended (another page, the update dialog at launch, a connect),
      // the sheet waited for the allowance or the payments to change, and
      // on a quiet screen they did not.
      final dedicated = _Dedicated(_quota());
      await pumpHome(
        tester,
        billing: _FixedBilling(_noBlock),
        dedicated: dedicated,
      );
      final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another page')),
          ),
        ),
      );
      await settle(tester);
      dedicated.become(_quota(blocked: true));
      await wait(tester, const Duration(seconds: 12));
      expect(sheet, findsNothing);

      navigator.pop();
      await settle(tester);
      await wait(tester, const Duration(seconds: 6));
      await settle(tester);
      expect(sheet, findsOneWidget);
      expect(premiumRow, findsNothing);
      await done(tester);
    });

    testWidgets('opens by itself once a connect that held it back ends', (
      tester,
    ) async {
      late _Flow flow;
      final dedicated = _Dedicated(_quota());
      await pumpHome(
        tester,
        billing: _FixedBilling(_noBlock),
        dedicated: dedicated,
        flow: (vpn) => flow = _Flow(vpn: vpn),
      );
      flow.busy(true);
      dedicated.become(_quota(blocked: true));
      await wait(tester, const Duration(seconds: 12));
      expect(sheet, findsNothing);

      // The flow ends, as it does when the tunnel is taken down for the
      // spent allowance.
      flow.busy(false);
      await wait(tester, const Duration(seconds: 6));
      await settle(tester);
      expect(sheet, findsOneWidget);
      await done(tester);
    });

    testWidgets('opens by itself once per refill', (tester) async {
      final dedicated = _Dedicated(_quota());
      await pumpHome(
        tester,
        billing: _FixedBilling(_on({UpsellSurface.limitSheet})),
        dedicated: dedicated,
      );
      await wait(tester, const Duration(seconds: 10));
      expect(sheet, findsNothing);

      // The allowance runs out while the app is in front.
      final spent = _quota(blocked: true);
      dedicated.become(spent);
      await wait(tester, const Duration(seconds: 6));
      await settle(tester);
      expect(sheet, findsOneWidget);
      await tester.tap(find.text('Not now'));
      await settle(tester);

      // The same refill never opens it again by itself.
      dedicated.become(spent);
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await wait(tester, const Duration(seconds: 10));
      await settle(tester);
      expect(sheet, findsNothing);

      // The next one does.
      dedicated.become(
        QuotaStatus(
          unlimited: false,
          limitBytes: spent.limitBytes,
          usedBytes: spent.usedBytes,
          remainingBytes: 0,
          blocked: true,
          resetsAt: spent.resetsAt!.add(const Duration(hours: 24)),
        ),
      );
      await wait(tester, const Duration(seconds: 6));
      await settle(tester);
      expect(sheet, findsOneWidget);
      await done(tester);
    });
  });

  group('the calm card', () {
    final card = find.text('Want no daily limit?');

    PremiumPrompt promptFor(BillingState billing) =>
        PremiumPrompt(billing: billing);

    BillingInfo calmOn() => _on({UpsellSurface.calmCard}, every: 168, most: 3);

    testWidgets('shows once the tunnel has been up and the screen calm', (
      tester,
    ) async {
      final billing = _FixedBilling(calmOn());
      final prompt = promptFor(billing);
      await pumpHome(
        tester,
        billing: billing,
        prompt: prompt,
        vpn: _Vpn(VpnStatus.connected),
      );
      await wait(tester, const Duration(seconds: 10));
      expect(card, findsNothing);
      await wait(tester, const Duration(seconds: 6));
      expect(card, findsOneWidget);
      expect(prompt.shownThisRun, isTrue);

      await tester.tap(find.text('Not now'));
      await tester.pump();
      expect(card, findsNothing);
      expect(
        [for (final e in billing.pendingUpsellEvents) e['action']],
        ['shown', 'dismissed'],
      );
      await done(tester);
    });

    testWidgets('Get unlimited opens the Premium screen', (tester) async {
      final billing = _FixedBilling(calmOn());
      await pumpHome(
        tester,
        billing: billing,
        prompt: promptFor(billing),
        vpn: _Vpn(VpnStatus.connected),
      );
      await wait(tester, const Duration(seconds: 16));
      await tester.tap(_filled('Get unlimited'));
      await settle(tester);
      expect(find.byType(PremiumScreen), findsOneWidget);
      await done(tester);
    });

    testWidgets('never with the tunnel down', (tester) async {
      final billing = _FixedBilling(calmOn());
      await pumpHome(tester, billing: billing, prompt: promptFor(billing));
      await wait(tester, const Duration(seconds: 30));
      expect(card, findsNothing);
      await done(tester);
    });

    testWidgets('goes away when the tunnel does', (tester) async {
      final billing = _FixedBilling(calmOn());
      final vpn = _Vpn(VpnStatus.connected);
      await pumpHome(
        tester,
        billing: billing,
        prompt: promptFor(billing),
        vpn: vpn,
      );
      await wait(tester, const Duration(seconds: 16));
      expect(card, findsOneWidget);
      vpn.become(VpnStatus.disconnected);
      await tester.pump();
      expect(card, findsNothing);
      await done(tester);
    });

    testWidgets('goes away when the device gets Premium another way', (
      tester,
    ) async {
      final billing = _FixedBilling(calmOn());
      await pumpHome(
        tester,
        billing: billing,
        prompt: promptFor(billing),
        vpn: _Vpn(VpnStatus.connected),
      );
      await wait(tester, const Duration(seconds: 16));
      expect(card, findsOneWidget);

      // Bought through the top chip, say, while the card was up.
      billing.adoptForTest(
        _on(
          {UpsellSurface.calmCard},
          every: 168,
          most: 3,
          premium: const Premium(active: true, source: 'google_play'),
        ),
      );
      await tester.pump();
      expect(card, findsNothing);
      await done(tester);
    });

    testWidgets('never without the backend\'s numbers', (tester) async {
      final billing = _FixedBilling(_on({UpsellSurface.calmCard}));
      await pumpHome(
        tester,
        billing: billing,
        prompt: promptFor(billing),
        vpn: _Vpn(VpnStatus.connected),
      );
      await wait(tester, const Duration(seconds: 30));
      expect(card, findsNothing);
      await done(tester);
    });

    testWidgets('never in a run a message popped up in', (tester) async {
      final sent = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final messages = MessageState(
        fetch: (_, _) async => MessagesPage.fromJson({
          'server_time': DateTime.now().toUtc().toIso8601String(),
          'messages': [
            {
              'id': 1,
              'language': 'en',
              'title': 'News',
              'body': 'Body',
              'button': null,
              'link': null,
              'sent_at': sent.toIso8601String(),
              'ends_at': sent.add(const Duration(days: 7)).toIso8601String(),
            },
          ],
        }),
        post: (_, _) async {},
        deviceId: () async => 'DEV-1',
        register: () async {},
        language: () => 'en',
        flushDelay: const Duration(days: 1),
      );
      await messages.refresh();
      final billing = _FixedBilling(calmOn());
      await pumpHome(
        tester,
        billing: billing,
        prompt: promptFor(billing),
        messages: messages,
        vpn: _Vpn(VpnStatus.connected),
      );
      await wait(tester, const Duration(seconds: 6));
      expect(find.text('Body'), findsOneWidget);
      await tester.tap(find.byType(TextButton).last);
      await settle(tester);
      await wait(tester, const Duration(seconds: 30));
      expect(card, findsNothing);
      await done(tester);
    });
  });

  // No copy has a Renew button: a Google Play subscription is turned back
  // on in Google Play, and a key is bought outside the app.
  group('the reminder before Premium ends', () {
    final now = DateTime.now();

    BillingInfo ending({
      bool? autoRenewing,
      Duration left = const Duration(hours: 10),
      String source = 'voucher',
    }) => BillingInfo(
      enabled: true,
      premium: Premium(
        active: true,
        until: now.add(left),
        source: source,
        autoRenewing: autoRenewing,
      ),
      plans: const [_plan],
      rails: const Rails(googlePlay: true),
      renewal: Renewal(until: now.add(left), noticeHours: 72),
    );

    final renew = find.widgetWithText(TextButton, 'Renew');
    final askToRenew = find.textContaining('Renew to keep unlimited data');

    for (final signed in [true, false]) {
      testWidgets('names the end and nothing else (signed by Google: '
          '$signed)', (tester) async {
        for (final source in ['voucher', 'stars', 'crypto']) {
          await pumpHome(
            tester,
            billing: _FixedBilling(
              ending(source: source),
              googleSigned: signed,
            ),
          );
          await tester.pump();
          expect(
            find.textContaining('Premium ends on'),
            findsOneWidget,
            reason: source,
          );
          expect(renew, findsNothing, reason: source);
          expect(askToRenew, findsNothing, reason: source);
          await done(tester);
        }
      });
    }

    testWidgets('an older backend that says the phone may renew changes '
        'nothing', (tester) async {
      final until = now.add(const Duration(hours: 10));
      await pumpHome(
        tester,
        billing: _FixedBilling(
          BillingInfo.fromJson({
            'enabled': true,
            'premium': {
              'active': true,
              'until': until.toUtc().toIso8601String(),
              'source': 'stars',
            },
            'plans': [
              {'code': 'p', 'stars': 350},
            ],
            'rails': {'telegram': true, 'codes': true},
            'renewal': {
              'until': until.toUtc().toIso8601String(),
              'notice_hours': 72,
              'can_renew': true,
            },
          }),
          googleSigned: false,
        ),
      );
      await tester.pump();
      expect(find.textContaining('Premium ends on'), findsOneWidget);
      expect(renew, findsNothing);
      expect(askToRenew, findsNothing);
      await done(tester);
    });

    testWidgets('a Play subscription that will not renew sees the end '
        'alone', (tester) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(
          ending(source: 'google_play', autoRenewing: false),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Premium ends on'), findsOneWidget);
      expect(renew, findsNothing);
      expect(askToRenew, findsNothing);
      await done(tester);
    });

    testWidgets('is not shown for Premium made by hand', (tester) async {
      await pumpHome(tester, billing: _FixedBilling(ending(source: 'manual')));
      await tester.pump();
      expect(find.textContaining('Premium ends on'), findsNothing);
      await done(tester);
    });

    testWidgets('is not shown before the notice hours', (tester) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(ending(left: const Duration(hours: 100))),
      );
      await tester.pump();
      expect(find.textContaining('Premium ends on'), findsNothing);
      await done(tester);
    });

    testWidgets('is not shown for a Play subscription that renews', (
      tester,
    ) async {
      await pumpHome(
        tester,
        billing: _FixedBilling(
          ending(source: 'google_play', autoRenewing: true),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Premium ends on'), findsNothing);
      await done(tester);
    });

    testWidgets('the note after the end shows once per end, with no '
        'Renew', (tester) async {
      final ended = DateTime.utc(2026, 11, 8, 10);
      BillingInfo lapsed(DateTime at) => BillingInfo(
        enabled: true,
        plans: const [_plan],
        rails: const Rails(googlePlay: true),
        renewal: Renewal(endedAt: at, noticeHours: 72),
      );
      final note = find.textContaining('Your free plan is back.');

      await pumpHome(tester, billing: _FixedBilling(lapsed(ended)));
      await tester.pump();
      expect(note, findsOneWidget);
      expect(renew, findsNothing);
      await done(tester);

      // The next run of the app.
      await pumpHome(tester, billing: _FixedBilling(lapsed(ended)));
      await tester.pump();
      expect(note, findsNothing);
      await done(tester);

      // Another end shows again, and its close button puts it away.
      await pumpHome(
        tester,
        billing: _FixedBilling(lapsed(ended.add(const Duration(days: 40)))),
      );
      await tester.pump();
      expect(note, findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(note, findsNothing);
      await done(tester);
    });
  });

  // With no upsell block, or in a copy that cannot buy through Google Play
  // with every offer turned on, the home screen is the one drawn with no
  // payments at all.
  group('where no offer may show, the home screen offers nothing new', () {
    /// What a screen shows and what can be pressed on it, apart from the
    /// teal pill of a Premium device, which is status and follows Premium
    /// alone.
    List<String> drawn(WidgetTester tester) {
      bool outside(Element e) =>
          e.findAncestorWidgetOfExactType<PremiumTopChip>() == null;
      Iterable<T> all<T extends Widget>() => [
        for (final e in find.byType(T).evaluate())
          if (outside(e)) e.widget as T,
      ];
      return [
        for (final w in all<Text>())
          'text ${w.data ?? w.textSpan?.toPlainText()}',
        for (final w in all<Icon>()) 'icon ${w.icon}',
        'buttons ${find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate().where(outside).length}',
        'taps ${find.byType(InkWell).evaluate().where(outside).length}',
      ];
    }

    for (final (name, info, signed) in [
      ('sales off', _off, true),
      (
        'sales on with no block',
        const BillingInfo(
          enabled: true,
          plans: [_plan],
          rails: Rails(googlePlay: true, codes: true),
        ),
        true,
      ),
      (
        'a Premium device with no block',
        BillingInfo(
          enabled: true,
          premium: Premium(
            active: true,
            until: DateTime.now().add(const Duration(hours: 5)),
          ),
          plans: const [_plan],
          rails: const Rails(googlePlay: true),
        ),
        true,
      ),
      (
        'a copy that cannot buy through Google Play, with every offer on',
        _on(UpsellSurface.values.toSet(), nudge: 1, every: 1, most: 9),
        false,
      ),
    ]) {
      for (final (state, quota) in [
        ('with data left', _quota(used: 95)),
        ('with the allowance spent', _quota(blocked: true)),
      ]) {
        testWidgets('$name, $state', (tester) async {
          await pumpHome(tester, dedicated: _Dedicated(quota));
          final before = drawn(tester);
          await done(tester);

          final billing = _FixedBilling(info, googleSigned: signed);
          await pumpHome(
            tester,
            billing: billing,
            dedicated: _Dedicated(quota),
          );
          expect(drawn(tester), before);
          expect(chip, findsNothing);
          expect(
            premiumPill,
            info.premium.active ? findsOneWidget : findsNothing,
          );
          if (quota.blocked) {
            // The limit sheet opens for every phone, and offers nothing.
            await tester.tap(find.byType(PowerButton));
            await settle(tester);
            expect(find.text('Today\'s data is used up'), findsOneWidget);
            expect(find.text('Premium has no daily limit.'), findsNothing);
          }
          await wait(tester, const Duration(seconds: 20));
          expect(billing.pendingUpsellEvents, isEmpty);
          await done(tester);
        });
      }
    }
  });

  testWidgets('on a TV nothing new is drawn', (tester) async {
    FormFactor.isTvForTest = true;
    await pumpHome(
      tester,
      billing: _FixedBilling(
        _on(UpsellSurface.values.toSet(), nudge: 1, every: 1, most: 9),
      ),
      dedicated: _Dedicated(_quota(used: 99)),
    );
    expect(chip, findsNothing);
    expect(find.text('Get unlimited'), findsNothing);
    await done(tester);
  });

  // The offer card's buttons sit at its end, "Get unlimited" last, in
  // either direction.
  for (final locale in ['en', 'fa']) {
    testWidgets('[$locale] the offer card\'s buttons sit at its end', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: Scaffold(
            body: PremiumOfferCard(
              title: 'Want no daily limit?',
              body: 'Premium has no daily limit.',
              onGetUnlimited: () {},
              onNotNow: () {},
            ),
          ),
        ),
      );
      final card = tester.getRect(find.byType(PremiumOfferCard));
      final buy = tester.getRect(
        find.ancestor(
          of: find.byIcon(Icons.all_inclusive_rounded),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      final notNow = tester.getRect(
        find.byWidgetPredicate((w) => w is TextButton),
      );
      // The card's 1dp edge and its 16dp padding.
      if (locale == 'en') {
        expect(buy.right, closeTo(card.right - 17, 0.5));
        expect(notNow.right, lessThanOrEqualTo(buy.left));
      } else {
        expect(buy.left, closeTo(card.left + 17, 0.5));
        expect(notNow.left, greaterThanOrEqualTo(buy.right));
      }
    });
  }
}
