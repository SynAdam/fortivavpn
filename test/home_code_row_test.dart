import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:fortiva_vpn/services/vpn_service.dart';
import 'package:fortiva_vpn/widgets/message_dialog.dart';
import 'package:fortiva_vpn/widgets/update_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/invite_home.dart';

/// "Have an invite code?" on the home screen (clients #271), for a friend
/// who installed the APK and got the code in a message. It never loads the
/// referral status, because the first load mints a code.
void main() {
  final row = find.byKey(const Key('home-have-code'));
  late List<MethodCall> calls;
  late List<http.Request> requests;
  late NoticePermissionPrompt originalNotice;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    requests = [];
    mockTunnel(calls);
    UpdateDialog.resetForTest();
    MessageDialog.resetForTest();
    originalNotice = NoticePermissionPrompt.instance;
    NoticePermissionPrompt.instance = NoticePermissionPrompt(
      permission: () async => NoticePermission.granted,
      isTv: () => false,
    );
  });

  tearDown(() {
    FormFactor.isTvForTest = false;
    NoticePermissionPrompt.instance = originalNotice;
    unmockTunnel();
  });

  /// A referral state whose claim answers 200 with [claimBody].
  ReferralState referrals({Object? claimBody}) => ReferralState(
    service: ReferralService.forTest(
      client: ApiClient.forTest(
        direct: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/claim')) {
            return http.Response(
              jsonEncode(claimBody ?? {'claimed': true}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'code': 'ZZ9Q2M'}), 200);
        }),
      ),
    ),
    deviceId: () async => 'DEV-1',
    register: () async {},
  );

  Future<InvitePrompt> pump(
    WidgetTester tester, {
    DateTime? openUntil,
    ReferralState? state,
    bool referralsOn = true,
  }) async {
    final invite = InvitePrompt();
    await pumpInviteHome(
      tester,
      vpn: FakeVpn(VpnStatus.disconnected),
      invite: invite,
      device: await registeredDevice(
        inviteDevice(
          claimOpenUntil:
              openUntil ?? DateTime.now().add(const Duration(hours: 10)),
        ),
      ),
      config: await inviteConfig(referrals: referralsOn),
      billing: FixedBilling(),
      referrals: state ?? referrals(),
    );
    await tester.pump();
    return invite;
  }

  testWidgets('shows only after the first verified connect', (tester) async {
    final invite = await pump(tester);
    expect(invite.hadGoodDay, isFalse);
    expect(row, findsNothing);
    invite.record(VpnEventType.connected);
    await tester.pump();
    expect(row, findsOneWidget);
    expect(find.text('Have an invite code?'), findsOneWidget);
    expect(requests, isEmpty);
    await inviteHomeDone(tester);
  });

  testWidgets('a quiet row in the look of the card and the shortcuts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    await pump(tester);
    await tester.pump();
    expect(row, findsOneWidget);
    // The hairline edge of the server card and the shortcuts.
    final material = tester.widget<Material>(
      find.ancestor(of: row, matching: find.byType(Material)).first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.side.color, AppDesign.hairline);
    expect(material.color, AppDesign.surfaceLow);
    // Steel, not the brand color, which is for the main actions and offers.
    final icon = tester.widget<Icon>(
      find.descendant(of: row, matching: find.byIcon(Icons.redeem_outlined)),
    );
    expect(icon.color, AppDesign.steelLight);
    expect(icon.size, 20);
    final label = tester.widget<Text>(find.text('Have an invite code?'));
    expect(label.style!.color, AppDesign.textSecondary);
    // 8 under the server card, on the 4dp grid.
    final card = find
        .ancestor(of: find.text('OUR SERVER'), matching: find.byType(InkWell))
        .first;
    expect(
      tester.getRect(row).top - tester.getRect(card).bottom,
      moreOrLessEquals(8),
    );
    await inviteHomeDone(tester);
  });

  testWidgets('shows after good days from an earlier run', (tester) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    await pump(tester);
    await tester.pump();
    expect(row, findsOneWidget);
    await inviteHomeDone(tester);
  });

  testWidgets('a claim from it names the days from the answer, loads no '
      'status, and hides it', (tester) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    await pump(
      tester,
      state: referrals(
        claimBody: {
          'claimed': true,
          'claimed_code': 'AB3D7K',
          'already': false,
          'confirm_active_days': 2,
        },
      ),
    );
    await tester.pump();
    await tester.tap(row);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Paste'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('invite-code-field')),
      'AB3D7K',
    );
    // Apply turns on with the frame after the field gets text.
    await tester.pump();
    await tester.tap(find.text('Apply'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text(
        'Invite accepted. It counts once you have used the VPN on 2 '
        'different days, starting today.',
      ),
      findsOneWidget,
    );
    expect(row, findsNothing);
    expect(
      [for (final r in requests) r.url.path],
      ['/api/v1/devices/DEV-1/referral/claim'],
    );
    expect(jsonDecode(requests.single.body), {
      'code': 'AB3D7K',
      'source': 'manual',
    });
    await tester.pump(const Duration(seconds: 6));
    await inviteHomeDone(tester);
  });

  testWidgets('Paste claims what the clipboard holds, as paste', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return {
              'text':
                  'یه فیلترشکن رایگان\nhttps://fortivavpn.com/fa/i/AB۳D۷K\nکد دعوت من: AB۳D۷K',
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    await pump(tester);
    await tester.pump();
    await tester.tap(row);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Nothing read from the clipboard until the tap.
    expect(requests, isEmpty);
    await tester.tap(find.byKey(const Key('invite-paste')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(jsonDecode(requests.single.body), {
      'code': 'AB3D7K',
      'source': 'paste',
    });
    await tester.pump(const Duration(seconds: 6));
    await inviteHomeDone(tester);
  });

  testWidgets('hidden once the claim window is over', (tester) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    await pump(
      tester,
      openUntil: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    await tester.pump();
    expect(row, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('hidden when the device has claimed', (tester) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    final state = referrals()
      ..adoptForTest(
        const ReferralStatus(
          code: 'ZZ9Q2M',
          shareUrl: 'https://fortivavpn.com/i/ZZ9Q2M',
          invitedCount: 0,
          confirmedCount: 0,
          bonusBytes: 0,
          claimedCode: 'AB3D7K',
        ),
      );
    await pump(tester, state: state);
    await tester.pump();
    expect(row, findsNothing);
    await inviteHomeDone(tester);
  });

  testWidgets('hidden with invites off and on a TV', (tester) async {
    SharedPreferences.setMockInitialValues({...inviteRecord(goodDays: 1)});
    await pump(tester, referralsOn: false);
    await tester.pump();
    expect(row, findsNothing);
    await inviteHomeDone(tester);

    FormFactor.isTvForTest = true;
    await pump(tester);
    await tester.pump();
    expect(row, findsNothing);
    await inviteHomeDone(tester);
  });
}
