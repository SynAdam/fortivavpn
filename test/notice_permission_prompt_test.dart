import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/core/state/notice_permission_prompt.dart';
import 'package:fortiva_vpn/services/notice_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the app asks Android to allow message notifications, and how a user
/// turns them on later (lib/core/state/notice_permission_prompt.dart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NoticePermission state;
  late NoticePermission answer;
  late bool rationale;
  late int asked;
  late int opened;
  late int permissionReads;
  late DateTime now;

  NoticePermissionPrompt make({bool tv = false}) => NoticePermissionPrompt(
    permission: () async {
      permissionReads++;
      return state;
    },
    ask: () async {
      asked++;
      state = answer;
      return answer;
    },
    rationale: () async => rationale,
    openSettings: () async {
      opened++;
      return true;
    },
    isTv: () => tv,
    now: () => now,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state = NoticePermission.ask;
    answer = NoticePermission.granted;
    rationale = false;
    asked = 0;
    opened = 0;
    permissionReads = 0;
    now = DateTime.utc(2026, 10, 13, 12);
  });

  group('the app asking by itself', () {
    test(
      'due while Android can still ask; allowed ends the asking for good',
      () async {
        final prompt = make();
        expect(await prompt.due(), isTrue);
        expect(await prompt.ask(), NoticePermission.granted);
        expect(asked, 1);
        expect(prompt.askedThisRun, isTrue);
        expect(await prompt.due(), isFalse);

        // Later runs, any day.
        now = now.add(const Duration(days: 30));
        state = NoticePermission.ask;
        expect(await make().due(), isFalse);
      },
    );

    test(
      'closed or refused once: asked once more, but not before 3 days',
      () async {
        answer = NoticePermission.ask;
        await make().ask();

        now = now.add(const Duration(days: 2));
        expect(await make().due(), isFalse, reason: 'too soon');

        now = now.add(const Duration(days: 2));
        final second = make();
        expect(await second.due(), isTrue);
        await second.ask();
        expect(asked, 2);

        now = now.add(const Duration(days: 10));
        expect(await make().due(), isFalse, reason: 'two asks at most');
      },
    );

    test('turned off in the system settings: the dialog cannot help, so the '
        'app stops asking', () async {
      answer = NoticePermission.denied;
      await make().ask();
      now = now.add(const Duration(days: 10));
      state = NoticePermission.ask;
      expect(await make().due(), isFalse);
    });

    test(
      'not due when notifications already show or are off in settings',
      () async {
        for (final s in [NoticePermission.granted, NoticePermission.denied]) {
          state = s;
          expect(await make().due(), isFalse, reason: s.name);
        }
      },
    );

    test('never on a TV', () async {
      expect(await make(tv: true).due(), isFalse);
      expect(permissionReads, 0);
    });

    test('once it says no, it says no for the rest of the run without asking '
        'Android again', () async {
      state = NoticePermission.granted;
      final prompt = make();
      expect(await prompt.due(), isFalse);
      expect(prompt.settledThisRun, isTrue);
      state = NoticePermission.ask;
      expect(await prompt.due(), isFalse);
      expect(permissionReads, 1);
    });

    test('the ask is counted before the dialog, so a killed app does not ask '
        'more often', () async {
      final prompt = NoticePermissionPrompt(
        permission: () async => NoticePermission.ask,
        ask: () => Future<NoticePermission>.error(StateError('killed')),
        rationale: () async => false,
        openSettings: () async => true,
        isTv: () => false,
        now: () => now,
      );
      await prompt.ask();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(NoticePermissionPrompt.asksKey), 1);
    });
  });

  group('turning them on from Settings or Messages', () {
    test('never asked: Android\'s dialog', () async {
      expect(await make().turnOn(), NoticePermission.granted);
      expect(asked, 1);
      expect(opened, 0);
    });

    test(
      'refused once: Android shows its dialog again, so it is used',
      () async {
        answer = NoticePermission.ask;
        await make().ask();
        rationale = true;
        answer = NoticePermission.granted;
        await make().turnOn();
        expect(asked, 2);
        expect(opened, 0);
      },
    );

    test('Android will not ask again, or they are off in settings: the system '
        'page opens', () async {
      answer = NoticePermission.ask;
      await make().ask();
      rationale = false;
      await make().turnOn();
      expect(asked, 1);
      expect(opened, 1);

      state = NoticePermission.denied;
      await make().turnOn();
      expect(opened, 2);
    });

    test('already on: nothing to do', () async {
      state = NoticePermission.granted;
      expect(await make().turnOn(), NoticePermission.granted);
      expect(asked + opened, 0);
    });

    test('a second tap while the dialog is up waits for the same answer: '
        'no second ask, no system page over the dialog', () async {
      final prompt = make();
      final first = prompt.turnOn();
      final second = prompt.turnOn();
      expect(await first, NoticePermission.granted);
      expect(await second, NoticePermission.granted);
      expect(asked, 1);
      expect(opened, 0);
    });

    test('a tap counts as the question for this run', () async {
      final prompt = make();
      await prompt.turnOn();
      expect(prompt.askedThisRun, isTrue);
    });
  });
}
