import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/billing_service.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/app_config_state.dart';
import 'package:fortiva_vpn/core/state/billing_state.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/core/state/device_state.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/locale_state.dart';
import 'package:fortiva_vpn/core/state/message_state.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/core/state/premium_prompt.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/core/state/review_prompt.dart';
import 'package:fortiva_vpn/core/state/server_state.dart';
import 'package:fortiva_vpn/data/models/app_config.dart';
import 'package:fortiva_vpn/data/models/billing.dart';
import 'package:fortiva_vpn/data/models/connection_info.dart';
import 'package:fortiva_vpn/data/models/device.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/play_billing.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/premium_offers.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// What the home screen tests of the invite card share (clients #271).
/// The numbers here are the tests' own, never the backend's start values.

const inviteRulesJson = {
  'min_good_days': 3,
  'min_session_minutes': 5,
  'quiet_after_failure_hours': 24,
  'every_days': 14,
  'max_shows': 3,
  'earns': true,
  'reward_premium_days': 3,
};

/// A saved invite record with enough good days, as SharedPreferences
/// holds it.
Map<String, Object> inviteRecord({int goodDays = 3, String? lastShownDay}) => {
  InvitePrompt.inviteStateKey: jsonEncode({
    'good_days': goodDays,
    'last_good_day': '2026-01-01',
    'shows': lastShownDay == null ? 0 : 1,
    'last_shown_day': ?lastShownDay,
    'done': false,
    'seeded': true,
  }),
};

/// A saved rating record with enough good days for an ask.
Map<String, Object> reviewRecord({DateTime? askedAt}) => {
  ReviewPrompt.stateKey: jsonEncode({
    'days': ['2026-01-01', '2026-01-02', '2026-01-03'],
    'asks': askedAt == null ? 0 : 1,
    if (askedAt != null) 'asked_at': askedAt.millisecondsSinceEpoch,
  }),
};

const sharedServer = Server(
  id: 'official-1',
  name: 'DE Falkenstein',
  country: 'Germany',
  city: 'Falkenstein',
  connectionUri: 'vless://u@198.51.100.201:443?security=reality#DE',
  flagEmoji: '\u{1F1E9}\u{1F1EA}',
);

Device inviteDevice({
  Map<String, Object?>? rules = inviteRulesJson,
  DateTime? claimOpenUntil,
}) => Device.fromJson({
  'id': 42,
  'device_id': 'DEV-1',
  'platform': 'android',
  'app_version': '1.9.0',
  'is_premium': false,
  'created_at': '2026-10-20T08:00:00Z',
  'invite_prompt': rules,
  'referral_claim_open_until': claimOpenUntil?.toUtc().toIso8601String(),
});

/// A registered device whose register answer is [device].
Future<DeviceState> registeredDevice(Device device) async {
  final state = DeviceState(register: () async => device, retryGaps: const []);
  await state.registerDevice();
  return state;
}

/// A loaded app config with invites on. [inviteNudge] is the share of
/// the allowance after which the data line offers invites, left out of the
/// config when null, as a backend that sends none.
Future<AppConfigState> inviteConfig({
  bool referrals = true,
  bool reviewPrompt = false,
  bool limitSheet = true,
  int? inviteNudge,
}) async {
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
      'feature_flags': {
        'enable_referrals': referrals,
        'review_prompt': reviewPrompt,
        'limit_sheet': limitSheet,
        'invite_nudge_percent': ?inviteNudge,
      },
    }),
  );
  await config.load();
  return config;
}

final madeBilling = <BillingState>[];

/// Billing with a fixed answer.
class FixedBilling extends BillingState {
  FixedBilling([BillingInfo info = const BillingInfo(enabled: false)])
    : super(
        service: BillingService(
          client: ApiClient.forTest(
            direct: MockClient((_) async => throw http.ClientException('no')),
          ),
        ),
        playBilling: () => _IdlePlay(),
        deviceId: () async => 'DEV-1',
      ) {
    adoptForTest(info);
    adoptWorkedForTest();
    madeBilling.add(this);
  }

  @override
  Future<void> refresh() async {}
}

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

QuotaStatus inviteQuota({bool blocked = false}) => QuotaStatus(
  unlimited: false,
  limitBytes: 100 << 20,
  usedBytes: blocked ? 100 << 20 : 10 << 20,
  remainingBytes: blocked ? 0 : 90 << 20,
  blocked: blocked,
  resetsAt: DateTime.now().add(const Duration(hours: 3)),
);

class FakeDedicated extends DedicatedState {
  FakeDedicated([QuotaStatus? quota]) : _fixed = quota ?? inviteQuota();

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
  @override
  Future<void> refresh({bool? viaTunnel}) async {}
  @override
  int? pingFor(String serverId) => null;
  @override
  Future<void> pingServer(Server server) async {}
}

class FakeServers extends ServerState {
  @override
  Server? get selectedServer => sharedServer;
  @override
  Future<void> loadServers({bool forceRefresh = false}) async {}
  @override
  int? getPingResult(String serverId) => 42;
  @override
  Future<void> pingServer(Server server) async {}
}

class FakeVpn extends VpnService {
  FakeVpn(this._fake, {Duration upFor = const Duration(hours: 1)})
    : _since = DateTime.now().subtract(upFor);

  VpnStatus _fake;
  DateTime _since;

  void become(VpnStatus status) {
    if (status == VpnStatus.connected && _fake != VpnStatus.connected) {
      _since = DateTime.now().subtract(const Duration(hours: 1));
    }
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

final madeEvents = <InviteEvents>[];

/// Invite events that keep what they hear until the minute's send.
InviteEvents keptEvents() {
  final events = InviteEvents(
    service: ReferralService.forTest(
      client: ApiClient.forTest(
        direct: MockClient((_) async => http.Response('', 204)),
      ),
    ),
    deviceId: () async => 'DEV-1',
    sharing: () async => true,
  );
  madeEvents.add(events);
  return events;
}

/// A referral state that loads [status] (or fails without one), counting
/// its status reads.
class CountingReferral extends ReferralState {
  CountingReferral({this.answer, this.claimAnswer})
    : super(
        service: ReferralService.forTest(
          client: ApiClient.forTest(
            direct: MockClient((_) async => throw http.ClientException('no')),
          ),
        ),
        deviceId: () async => 'DEV-1',
        register: () async {},
      );

  final ReferralStatus? answer;
  final ReferralClaimResult? claimAnswer;
  int reads = 0;

  @override
  Future<void> refresh() async {
    reads++;
    final status = answer;
    if (status != null) adoptForTest(status);
  }

  @override
  Future<ReferralClaimResult> claim(
    String code, {
    String source = 'manual',
  }) async => claimAnswer ?? const ReferralClaimResult.ok();
}

const shareStatus = ReferralStatus(
  code: 'AB3D7K',
  shareUrl: 'https://fortivavpn.com/fa/i/AB3D7K',
  invitedCount: 0,
  confirmedCount: 0,
  bonusBytes: 0,
  shareExcludePackages: ['ir.eitaa.messenger'],
);

/// Draw the home screen with whichever providers are given. A provider
/// left out is not there at all, as in the screen's other tests.
Future<void> pumpInviteHome(
  WidgetTester tester, {
  required VpnService vpn,
  InvitePrompt? invite,
  InviteEvents? events,
  DeviceState? device,
  AppConfigState? config,
  BillingState? billing,
  ReferralState? referrals,
  ReviewPrompt? review,
  PremiumPrompt? premium,
  MessageState? messages,
  DedicatedState? dedicated,
  ServerState? servers,
  ConnectFlow? flow,
  String locale = 'en',
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DedicatedState>.value(
          value: dedicated ?? FakeDedicated(),
        ),
        ChangeNotifierProvider<ServerState>.value(
          value: servers ?? FakeServers(),
        ),
        ChangeNotifierProvider<VpnService>.value(value: vpn),
        ChangeNotifierProvider<ConnectFlow>(
          create: (_) => flow ?? ConnectFlow(vpn: vpn),
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
        if (device != null)
          ChangeNotifierProvider<DeviceState>.value(value: device),
        if (billing != null)
          ChangeNotifierProvider<BillingState>.value(value: billing),
        if (referrals != null)
          ChangeNotifierProvider<ReferralState>.value(value: referrals),
        if (invite != null)
          ChangeNotifierProvider<InvitePrompt>.value(value: invite),
        if (events != null) Provider<InviteEvents>.value(value: events),
        if (review != null)
          ChangeNotifierProvider<ReviewPrompt>.value(value: review),
        if (premium != null)
          ChangeNotifierProvider<PremiumPrompt>.value(value: premium),
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
        theme: appThemeFor(Locale(locale)),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Take the screen away, which stops its timers, and let the tunnel
/// service's first status poll run.
Future<void> inviteHomeDone(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
  for (final billing in madeBilling) {
    billing.dispose();
  }
  madeBilling.clear();
  for (final events in madeEvents) {
    events.dispose();
  }
  madeEvents.clear();
}

Future<void> waitSeconds(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// The tunnel channel the screen and the share method talk to.
const tunnelChannel = MethodChannel('com.vpn.fortivavpn/tunnel');
const tunnelStatusChannel = EventChannel('com.vpn.fortivavpn/tunnel/status');

/// Mock the tunnel channels. [calls] hears every method call.
void mockTunnel(List<MethodCall> calls, {Object? share = 'sheet'}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(tunnelChannel, (call) async {
    calls.add(call);
    return switch (call.method) {
      'getStatus' => 'disconnected',
      'shareInvite' => share,
      _ => null,
    };
  });
  messenger.setMockStreamHandler(
    tunnelStatusChannel,
    MockStreamHandler.inline(onListen: (_, _) {}),
  );
}

void unmockTunnel() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(tunnelChannel, null);
  messenger.setMockStreamHandler(tunnelStatusChannel, null);
}

/// Load the fonts the app ships under the family its text styles name
/// (Inter), so text is as wide as on a phone rather than the test font's
/// squares. [rtl] loads Vazirmatn in its place, and also under its own
/// name: in Persian, Arabic and Urdu the app's styles name Vazirmatn first
/// (AppDesign.activeLocale) with Inter as the fallback, and a style that
/// names a family the test has not loaded draws some glyphs in the test
/// font, which is far wider than any real one.
Future<void> loadShippedFonts({required bool rtl}) async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  final folder = rtl ? 'Vazirmatn' : 'Inter';
  for (final family in ['Inter', if (rtl) 'Vazirmatn']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(bytes('assets/fonts/$folder/$folder-$weight.ttf'));
    }
    await loader.load();
  }
}

/// The power button is inside the screen and inside the area it scrolls
/// in, so none of it is cut off.
void expectPowerButtonOnScreen(WidgetTester tester, Size screen, String why) {
  final button = tester.getRect(find.byType(PowerButton));
  final area = tester.getRect(
    find
        .ancestor(
          of: find.byType(PowerButton),
          matching: find.byType(SingleChildScrollView),
        )
        .first,
  );
  expect(button.top, greaterThanOrEqualTo(area.top - 0.5), reason: why);
  expect(button.bottom, lessThanOrEqualTo(area.bottom + 0.5), reason: why);
  expect(button.top, greaterThanOrEqualTo(0), reason: why);
  expect(button.bottom, lessThanOrEqualTo(screen.height), reason: why);
  expect(button.right, lessThanOrEqualTo(screen.width), reason: why);
}

/// The home screen layout with the invite card, for [locales]: the power
/// button always stays wholly on screen. Where the card would push it out
/// of sight, the card gives way and is not counted; on a tall phone the
/// card is up beside it. Also with the renewal reminder, which the card
/// gives way to.
void inviteLayoutTests(List<String> locales) {
  late NoticePermissionPrompt originalNotice;

  setUp(() {
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    originalNotice = NoticePermissionPrompt.instance;
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.granted,
      isTv: () => false,
    );
  });

  tearDown(() {
    NoticePermissionPrompt.instance = originalNotice;
    unmockTunnel();
  });

  Future<Map<String, dynamic>> saved() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString(InvitePrompt.inviteStateKey)!)
        as Map<String, dynamic>;
  }

  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(320, 640), 1.3),
    (const Size(412, 915), 1.0),
  ]) {
    final tall = size.height > 800;
    for (final locale in locales) {
      final name =
          '[$locale ${size.width.toInt()}x${size.height.toInt()} at $scale]';
      testWidgets('$name the power button stays on screen with the card', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        SharedPreferences.setMockInitialValues({...inviteRecord()});
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.connected),
          invite: InvitePrompt(),
          events: keptEvents(),
          device: await registeredDevice(
            inviteDevice(
              claimOpenUntil: DateTime.now().add(const Duration(hours: 5)),
            ),
          ),
          config: await inviteConfig(),
          billing: FixedBilling(),
          referrals: CountingReferral(answer: shareStatus),
          locale: locale,
        );
        await waitSeconds(tester, 21);
        expect(tester.takeException(), isNull);
        final up = find.byKey(const Key('invite-card')).evaluate().isNotEmpty;
        expectPowerButtonOnScreen(tester, size, up ? 'card up' : 'gave way');
        if (tall) expect(up, isTrue, reason: 'a tall phone has room');
        // A card that gave way was never drawn, so it was not counted.
        expect((await saved())['shows'], up ? 1 : 0);
        // Beside the card the code row gives it the room.
        expect(
          find.byKey(const Key('home-have-code')),
          findsNWidgets(up ? 0 : 1),
        );
        await inviteHomeDone(tester);
      });

      testWidgets('$name with the renewal reminder the invite card and the '
          'code row take no room', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final now = DateTime.now();
        BillingState ending() => FixedBilling(
          BillingInfo(
            enabled: true,
            premium: Premium(
              active: true,
              until: now.add(const Duration(hours: 10)),
              source: 'voucher',
            ),
            rails: const Rails(codes: true),
            renewal: Renewal(
              until: now.add(const Duration(hours: 10)),
              noticeHours: 72,
            ),
          ),
        );
        Rect area() => tester.getRect(
          find
              .ancestor(
                of: find.byType(PowerButton),
                matching: find.byType(SingleChildScrollView),
              )
              .first,
        );

        // The screen as it was before the invite card: no invite parts.
        SharedPreferences.setMockInitialValues({...inviteRecord()});
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.connected),
          config: await inviteConfig(),
          billing: ending(),
          locale: locale,
        );
        await waitSeconds(tester, 21);
        final before = area();
        await inviteHomeDone(tester);

        SharedPreferences.setMockInitialValues({...inviteRecord()});
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.connected),
          invite: InvitePrompt(),
          events: keptEvents(),
          device: await registeredDevice(
            inviteDevice(claimOpenUntil: now.add(const Duration(hours: 5))),
          ),
          config: await inviteConfig(),
          billing: ending(),
          referrals: CountingReferral(answer: shareStatus),
          locale: locale,
        );
        await waitSeconds(tester, 21);
        expect(find.byKey(const Key('invite-card')), findsNothing);
        // The reminder is drawn (its text is in the screen's language).
        expect(
          tester.getSize(find.byKey(const ValueKey('renewal'))).height,
          greaterThan(0),
        );
        // The code row gives way to the reminder too.
        expect(find.byKey(const Key('home-have-code')), findsNothing);
        expect(tester.takeException(), isNull);
        expect(area(), before);
        await inviteHomeDone(tester);
      });
    }
  }
}

/// Billing that offers "Get unlimited" on the data line from the first
/// share of the allowance used, so the device in [inviteQuota] (a tenth
/// used) sees it.
BillingInfo quotaOfferBilling() => BillingInfo(
  enabled: true,
  premium: Premium.none,
  plans: const [
    Plan(
      code: 'unlimited_30d',
      google: PlayProductRef(productId: 'premium', basePlanId: 'p30'),
    ),
  ],
  rails: const Rails(googlePlay: true, codes: true),
  upsell: const Upsell(
    surfaces: {UpsellSurface.quotaLine},
    nudgeUsedPercent: 5,
  ),
);

/// The home screen at its fullest on a small phone, for [locales] at
/// [sizes]: connected, the invite code row showing and the data line
/// offering "Get unlimited". The power button stays wholly on screen.
///
/// The offer used to put a 48dp link on a second row under the data line,
/// and on a 320 wide phone at 1.3 text that row pushed the button out of
/// view in every language (the invite_layout tests never turn it on).
void quotaOfferLayoutTests(List<String> locales, List<(Size, double)> sizes) {
  setUp(() {
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
  });
  tearDown(unmockTunnel);

  for (final (size, scale) in sizes) {
    for (final locale in locales) {
      testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
          '$scale] the power button stays on screen with the data offer', (
        tester,
      ) async {
        final (:link, :amounts, :target) = await _pumpQuotaOffer(
          tester,
          locale,
          size,
          scale,
        );
        // In every layout here the link is beside the amounts, on one line
        // or two, after them in reading order, and its target is the
        // line's full 48dp height without covering them. Under the amounts
        // its target is smaller, so that is only for a narrower phone or a
        // larger text size than these (see quotaOfferUnderTest).
        expect(
          (tester.getCenter(link).dy - tester.getCenter(amounts).dy).abs(),
          lessThan(1),
          reason: 'the link beside the amounts',
        );
        final box = tester.getRect(target);
        final words = tester.getRect(amounts);
        expect(box.height, greaterThanOrEqualTo(48));
        expect(box.width, greaterThanOrEqualTo(48));
        if (const ['fa', 'ar', 'ur'].contains(locale)) {
          expect(box.right, lessThanOrEqualTo(words.left + 0.5));
        } else {
          expect(box.left, greaterThanOrEqualTo(words.right - 0.5));
        }
        expectPowerButtonOnScreen(tester, size, 'with the data offer');
        await inviteHomeDone(tester);
      });
    }
  }
}

/// The data line's offer in [locale] at [size] and [scale], where neither
/// one line nor two fit beside the amounts: the link goes under them, still
/// the only target, with 2dp of its target above and below its words. The
/// power button is not checked here; at these sizes the column scrolls.
void quotaOfferUnderTest(String locale, Size size, double scale) {
  setUp(() {
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
  });
  tearDown(unmockTunnel);

  testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
      '$scale] the data offer goes under the amounts', (tester) async {
    final (:link, :amounts, :target) = await _pumpQuotaOffer(
      tester,
      locale,
      size,
      scale,
    );
    final box = tester.getRect(target);
    expect(box.top, greaterThanOrEqualTo(tester.getRect(amounts).bottom - 0.5));
    expect(
      box.height,
      greaterThanOrEqualTo(tester.getSize(link).height + 4 - 0.5),
    );
    await inviteHomeDone(tester);
  });
}

/// Pumps the home screen with the data line's offer, and checks what holds
/// in every layout: only "Get unlimited" is a tap target, and the amounts
/// are not inside any.
Future<({Finder link, Finder amounts, Finder target})> _pumpQuotaOffer(
  WidgetTester tester,
  String locale,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  SharedPreferences.setMockInitialValues({...inviteRecord()});
  await pumpInviteHome(
    tester,
    vpn: FakeVpn(VpnStatus.connected),
    invite: InvitePrompt(),
    events: keptEvents(),
    device: await registeredDevice(
      inviteDevice(
        claimOpenUntil: DateTime.now().add(const Duration(hours: 5)),
      ),
    ),
    config: await inviteConfig(),
    billing: FixedBilling(quotaOfferBilling()),
    referrals: CountingReferral(answer: shareStatus),
    locale: locale,
  );
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);

  final linkWords = lookupS(Locale(locale)).premiumGetUnlimited;
  final link = find.text(linkWords);
  expect(link, findsOneWidget);
  expect(find.byKey(const Key('home-have-code')), findsOneWidget);
  // Only the link is a tap target, as before the redesign. The amounts are
  // not inside any.
  final amounts = find.descendant(
    of: find.byType(UpsellShown),
    matching: find.byWidgetPredicate((w) => w is Text && w.data != linkWords),
  );
  expect(amounts, findsOneWidget);
  expect(
    find.ancestor(of: amounts, matching: find.byType(InkWell)),
    findsNothing,
  );
  final target = find.ancestor(of: link, matching: find.byType(InkWell)).first;
  expect(
    find.descendant(of: target, matching: find.byType(Text)),
    findsOneWidget,
  );
  return (link: link, amounts: amounts, target: target);
}

/// The home screen at its fullest on a phone with the invite link on the
/// data line: connected, the invite code row showing, and the data line
/// offering invites, with [premium] also "Get unlimited". For [locales] at
/// [sizes], with the shipped fonts:
///
/// * the power button stays wholly on screen;
/// * every link is a target the full 48dp tall and 48 wide, and the amounts
///   are inside none of them;
/// * with both links, the invite link comes first in reading order, on the
///   same row as Get unlimited, and the invite code row gives way.
void inviteLinkLayoutTests(
  List<String> locales,
  List<(Size, double)> sizes, {
  required bool premium,
}) {
  setUp(() {
    mockTunnel([]);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
  });
  tearDown(unmockTunnel);

  for (final (size, scale) in sizes) {
    for (final locale in locales) {
      final what = premium ? 'both links' : 'the invite link';
      testWidgets('[$locale ${size.width.toInt()}x${size.height.toInt()} at '
          '$scale] the power button stays on screen with $what', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        SharedPreferences.setMockInitialValues({...inviteRecord()});
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.connected),
          invite: InvitePrompt(),
          events: keptEvents(),
          device: await registeredDevice(
            inviteDevice(
              claimOpenUntil: DateTime.now().add(const Duration(hours: 5)),
            ),
          ),
          // The device in inviteQuota has used a tenth.
          config: await inviteConfig(inviteNudge: 5),
          billing: premium ? FixedBilling(quotaOfferBilling()) : null,
          referrals: CountingReferral(answer: shareStatus),
          locale: locale,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        // Beside both links the code row gives way: they take a row more.
        expect(
          find.byKey(const Key('home-have-code')),
          premium ? findsNothing : findsOneWidget,
        );

        final l10n = lookupS(Locale(locale));
        final rtl = const ['fa', 'ar', 'ur'].contains(locale);
        final invite = find.byKey(const Key('quota-line-invite'));
        final unlimited = find.byKey(const Key('quota-line-unlimited'));
        expect(invite, findsOneWidget);
        expect(unlimited, premium ? findsOneWidget : findsNothing);
        // The amounts: the line's one text that is no link's words.
        final amounts = find.descendant(
          of: find.byKey(const Key('quota-line')),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != l10n.premiumLimitInvite &&
                w.data != l10n.premiumGetUnlimited &&
                w.data != '\u00B7',
          ),
        );
        expect(amounts, findsOneWidget);
        expect(
          find.ancestor(of: amounts, matching: find.byType(InkWell)),
          findsNothing,
        );
        final words = tester.getRect(amounts);
        for (final target in [invite, if (premium) unlimited]) {
          final box = tester.getRect(target);
          expect(box.height, greaterThanOrEqualTo(48), reason: '$target');
          expect(box.width, greaterThanOrEqualTo(48), reason: '$target');
          expect(box.overlaps(words), isFalse, reason: 'over the amounts');
          expect(
            find.descendant(of: target, matching: find.byType(Text)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(
            of: invite,
            matching: find.text(l10n.premiumLimitInvite),
          ),
          findsOneWidget,
        );
        if (premium) {
          final a = tester.getRect(invite);
          final b = tester.getRect(unlimited);
          expect(
            (a.center.dy - b.center.dy).abs(),
            lessThan(1),
            reason: 'one row',
          );
          if (rtl) {
            expect(a.left, greaterThanOrEqualTo(b.right - 0.5));
          } else {
            expect(a.right, lessThanOrEqualTo(b.left + 0.5));
          }
        }
        expectPowerButtonOnScreen(tester, size, 'with $what');
        await inviteHomeDone(tester);
      });
    }
  }
}
