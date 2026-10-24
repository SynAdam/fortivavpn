import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/services/vpn_event_reporter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The invite card's events for the backend's Invites page (clients #271).
/// They follow the Premium offer events: nothing is kept while "Share
/// connection diagnostics" is off.
void main() {
  late List<http.Request> calls;
  late int answer;

  setUp(() {
    calls = [];
    answer = 204;
    SharedPreferences.setMockInitialValues({});
  });

  InviteEvents make({Future<bool> Function()? sharing}) => InviteEvents(
    service: ReferralService.forTest(
      client: ApiClient.forTest(
        direct: MockClient((request) async {
          calls.add(request);
          return http.Response('', answer);
        }),
      ),
    ),
    deviceId: () async => 'DEV-1',
    sharing: sharing,
    clock: () => DateTime.utc(2026, 10, 20, 10),
  );

  test('the batch shape', () async {
    final events = make(sharing: () async => true);
    await Future<void>.delayed(Duration.zero);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    events.log(InviteSurface.afterConnect, InviteAction.telegram);
    events.log(InviteSurface.homeButton, InviteAction.shown);
    events.log(InviteSurface.inviteScreen, InviteAction.copyLink);
    events.log(InviteSurface.limitSheet, InviteAction.shown);
    events.log(InviteSurface.inviteScreen, InviteAction.otherApps);
    await events.send();
    final call = calls.single;
    expect(call.url.path, '/api/v1/devices/DEV-1/invite-events');
    expect(call.method, 'POST');
    final body = jsonDecode(call.body) as Map<String, dynamic>;
    expect(body['sent_at'], '2026-10-20T10:00:00.000Z');
    expect(body['events'], [
      {
        'surface': 'after_connect',
        'action': 'shown',
        'at': '2026-10-20T10:00:00.000Z',
      },
      {
        'surface': 'after_connect',
        'action': 'telegram',
        'at': '2026-10-20T10:00:00.000Z',
      },
      {
        'surface': 'home_button',
        'action': 'shown',
        'at': '2026-10-20T10:00:00.000Z',
      },
      {
        'surface': 'invite_screen',
        'action': 'copy_link',
        'at': '2026-10-20T10:00:00.000Z',
      },
      {
        'surface': 'limit_sheet',
        'action': 'shown',
        'at': '2026-10-20T10:00:00.000Z',
      },
      {
        'surface': 'invite_screen',
        'action': 'other_apps',
        'at': '2026-10-20T10:00:00.000Z',
      },
    ]);
    expect(events.queued, isEmpty);
    events.dispose();
  });

  test('nothing is queued while diagnostics are off', () async {
    SharedPreferences.setMockInitialValues({
      VpnEventReporter.sharePrefKey: false,
    });
    final events = make();
    await Future<void>.delayed(Duration.zero);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    expect(events.queued, isEmpty);
    await events.send();
    expect(calls, isEmpty);
    events.dispose();
  });

  test('unset means on', () async {
    final events = make();
    await Future<void>.delayed(Duration.zero);
    events.log(InviteSurface.afterConnect, InviteAction.dismissed);
    expect(events.queued, hasLength(1));
    events.dispose();
  });

  test('turning diagnostics off drops the queue', () async {
    final events = make(sharing: () async => true);
    await Future<void>.delayed(Duration.zero);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    events.log(InviteSurface.afterConnect, InviteAction.whatsapp);
    events.sharingChanged(false);
    expect(events.queued, isEmpty);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    expect(events.queued, isEmpty);
    events.dispose();
  });

  test('off by the time of the send sends nothing', () async {
    var on = true;
    final events = make(sharing: () async => on);
    await Future<void>.delayed(Duration.zero);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    on = false;
    await events.send();
    expect(calls, isEmpty);
    expect(events.queued, isEmpty);
    events.dispose();
  });

  test('a failed send keeps the batch; a missing route drops it', () async {
    final events = make(sharing: () async => true);
    await Future<void>.delayed(Duration.zero);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    answer = 503;
    await events.send();
    expect(events.queued, hasLength(1));
    answer = 404;
    await events.send();
    expect(events.queued, isEmpty);
    events.log(InviteSurface.afterConnect, InviteAction.shown);
    answer = 405;
    await events.send();
    expect(events.queued, isEmpty);
    events.dispose();
  });

  test('keeps at most the batch the backend takes', () async {
    final events = make(sharing: () async => true);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < InviteEvents.maxQueued + 7; i++) {
      events.log(InviteSurface.afterConnect, InviteAction.shown);
    }
    expect(events.queued, hasLength(InviteEvents.maxQueued));
    events.dispose();
  });
}
