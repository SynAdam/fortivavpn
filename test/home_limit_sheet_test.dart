import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/connect_flow.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/screens/home_screen.dart';
import 'package:fortiva_vpn/services/connect_trace.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/power_button.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';
import 'helpers/invite_tree.dart';
import 'helpers/limit_sheet.dart';

/// The limit sheet from the home screen once the daily data is used up: on
/// every tap that finds it used up, on a late answer that the tap's search
/// gave up waiting for, and from the invite link on the spent server card.
void main() {
  final sheet = find.text("Today's data is used up");
  final link = find.byKey(const Key('server-card-invite'));
  late NoticePermissionPrompt originalNotice;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  ReferralStatus tree() => ReferralStatus.fromJson(treeAnswer());

  /// Let a sheet open or close. The power button under it animates for as
  /// long as it is on screen, so the screen never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('limit-sheet-not-now')));
    await settle(tester);
  }

  testWidgets('each tap on a spent phone opens the sheet, with the invite '
      'card', (tester) async {
    screenFor(tester);
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      config: await inviteConfig(),
      billing: FixedBilling(),
      referrals: heldStatus(tree()),
      dedicated: FakeDedicated(inviteQuota(blocked: true)),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(PowerButton));
      await settle(tester);
      expect(sheet, findsOneWidget, reason: 'tap ${i + 1}');
      expect(find.byKey(const Key('limit-sheet-invite-card')), findsOneWidget);
      await closeSheet(tester);
    }
    await inviteHomeDone(tester);
  });

  group('a late answer', () {
    /// A tap's search that ends at once with no tunnel, as one does that
    /// gave up waiting for the allowance answer. While [hold] is set the
    /// search waits for it.
    late _QuickFlow flow;

    Future<FakeDedicated> pumpLate(WidgetTester tester) async {
      screenFor(tester);
      final quota = inviteQuota();
      final dedicated = FakeDedicated(quota);
      final vpn = FakeVpn(VpnStatus.disconnected);
      flow = _QuickFlow(vpn);
      await pumpInviteHome(
        tester,
        vpn: vpn,
        config: await inviteConfig(),
        billing: FixedBilling(),
        referrals: heldStatus(tree()),
        dedicated: dedicated,
        flow: flow,
      );
      return dedicated;
    }

    QuotaStatus spent(FakeDedicated dedicated) {
      final q = dedicated.quota!;
      return QuotaStatus(
        unlimited: false,
        limitBytes: q.limitBytes,
        usedBytes: q.limitBytes,
        remainingBytes: 0,
        blocked: true,
        resetsAt: q.resetsAt,
      );
    }

    testWidgets('within the window opens the sheet at once, once', (
      tester,
    ) async {
      final dedicated = await pumpLate(tester);
      final open = dedicated.quota!;
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(flow.runs, 1);
      expect(sheet, findsNothing);

      await tester.pump(const Duration(seconds: 3));
      dedicated.become(spent(dedicated));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sheet, findsOneWidget);
      await closeSheet(tester);

      // The same tap's answer again opens nothing more.
      dedicated.become(open);
      await tester.pump();
      dedicated.become(spent(dedicated));
      await tester.pump(const Duration(milliseconds: 300));
      expect(sheet, findsNothing);
      // Nor by itself later: the tap noted this refill as shown.
      await waitSeconds(tester, 7);
      expect(sheet, findsNothing);
      await inviteHomeDone(tester);
    });

    testWidgets('after the window it is left to the sheet that opens by '
        'itself', (tester) async {
      final dedicated = await pumpLate(tester);
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await waitSeconds(tester, HomeScreen.tapSheetLate.inSeconds + 1);
      dedicated.become(spent(dedicated));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sheet, findsNothing);
      // The sheet that opens by itself, after its wait.
      await waitSeconds(tester, 6);
      await settle(tester);
      expect(sheet, findsOneWidget);
      await closeSheet(tester);
      await inviteHomeDone(tester);
    });

    testWidgets('a newer tap still searching takes it over', (tester) async {
      final dedicated = await pumpLate(tester);
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      flow.hold = Completer<void>();
      await tester.tap(find.byType(PowerButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(flow.runs, 2);
      dedicated.become(spent(dedicated));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(sheet, findsNothing);
      // The newer tap's own end finds the data used up: its sheet.
      flow.hold!.complete();
      await settle(tester);
      expect(sheet, findsOneWidget);
      await closeSheet(tester);
      await inviteHomeDone(tester);
    });
  });

  group('the invite link on the spent server card', () {
    testWidgets('opens the sheet and notes server_card', (tester) async {
      screenFor(tester);
      final events = keptEvents();
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        events: events,
        config: await inviteConfig(),
        billing: FixedBilling(),
        referrals: heldStatus(tree()),
        dedicated: FakeDedicated(inviteQuota(blocked: true)),
      );
      expect(link, findsOneWidget);
      expect(find.text('Invite friends'), findsWidgets);
      await tester.tap(link);
      await settle(tester);
      expect(sheet, findsOneWidget);
      expect(
        [for (final e in events.queued) '${e['surface']}/${e['action']}'],
        ['server_card/shown', 'limit_sheet_offer/shown'],
      );
      await closeSheet(tester);
      await inviteHomeDone(tester);
    });

    for (final (name, invitesOn, status, blocked) in [
      ('data left', true, ReferralStatus.fromJson(treeAnswer()), false),
      ('invites off', false, ReferralStatus.fromJson(treeAnswer()), true),
      (
        'invites at the most',
        true,
        ReferralStatus.fromJson(oldAnswer()..['bonus_bytes'] = 10 << 30),
        true,
      ),
      (
        'no next amount under the tree',
        true,
        ReferralStatus.fromJson(treeAnswer(nextInviteBytes: null)),
        true,
      ),
    ]) {
      testWidgets('is not there with $name', (tester) async {
        screenFor(tester);
        await pumpInviteHome(
          tester,
          vpn: FakeVpn(VpnStatus.disconnected),
          config: await inviteConfig(referrals: invitesOn),
          billing: FixedBilling(),
          referrals: heldStatus(status),
          dedicated: FakeDedicated(inviteQuota(blocked: blocked)),
        );
        expect(link, findsNothing);
        await inviteHomeDone(tester);
      });
    }

    testWidgets('is not there while the sheet is switched off', (tester) async {
      screenFor(tester);
      await pumpInviteHome(
        tester,
        vpn: FakeVpn(VpnStatus.disconnected),
        config: await inviteConfig(limitSheet: false),
        billing: FixedBilling(),
        referrals: heldStatus(tree()),
        dedicated: FakeDedicated(inviteQuota(blocked: true)),
      );
      expect(link, findsNothing);
      await inviteHomeDone(tester);
    });
  });

  test('the late window is app-side timing, longer than the allowance '
      'question waits', () {
    expect(HomeScreen.tapSheetLate, greaterThan(const Duration(seconds: 4)));
  });
}

/// A connect flow whose shared search ends at once with no tunnel, or,
/// while [hold] is set, when it completes. [runs] counts the searches.
class _QuickFlow extends ConnectFlow {
  _QuickFlow(VpnService vpn) : super(vpn: vpn);

  int runs = 0;
  Completer<void>? hold;

  @override
  Future<void> connectShared(
    Server picked, {
    required Future<List<Server>> Function() shared,
    List<Server> Function()? own,
    Server? Function()? preferredOwn,
    Server? Function()? selection,
    bool pickIsChoice = false,
    bool pickByFallback = false,
    bool Function()? blocked,
    void Function(Server server)? onSwitchedServer,
    void Function(Server server)? onShared,
    Future<bool> Function()? allowanceSpent,
    Future<void> Function()? beforeRetry,
    bool afterStall = false,
    TraceTrigger trigger = TraceTrigger.tap,
  }) async {
    runs++;
    final wait = hold;
    if (wait != null) await wait.future;
  }
}
