import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_client.dart';
import 'package:fortiva_vpn/api/referral_service.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/state/invite_events.dart';
import 'package:fortiva_vpn/core/state/invite_prompt.dart';
import 'package:fortiva_vpn/core/state/referral_state.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/invite_screen.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The invite screen's part of clients #271: where it was opened from,
/// Share invite and Copy code as invite events, the share sheet with the
/// state messengers hidden, and the Premium days of reward B in "How it
/// works", all from the backend's numbers.
ReferralStatus _status({
  List<String> exclude = const [],
  bool earns = false,
  int? rewardDays,
  int? maxDays,
}) => ReferralStatus(
  code: 'AB3D7K',
  shareUrl: 'https://fortivavpn.com/fa/i/AB3D7K',
  invitedCount: 0,
  confirmedCount: 0,
  bonusBytes: 0,
  shareExcludePackages: exclude,
  earns: earns,
  rewardPremiumDays: rewardDays,
  premiumDaysEach: rewardDays,
  premiumDaysMax: maxDays,
);

class _FakeReferral extends ReferralState {
  _FakeReferral(this._fixed);
  final ReferralStatus _fixed;

  @override
  ReferralStatus? get status => _fixed;

  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() async {}
}

/// A referral state whose claim waits for [answer], so the claim stays
/// under way until the test ends it.
class _ClaimingReferral extends _FakeReferral {
  _ClaimingReferral(super.fixed);

  final answer = Completer<ReferralClaimResult>();
  final claims = <String>[];
  bool _claiming = false;

  @override
  bool get isClaiming => _claiming;

  @override
  Future<ReferralClaimResult> claim(
    String code, {
    String source = 'manual',
  }) async {
    claims.add(code);
    _claiming = true;
    notifyListeners();
    final result = await answer.future;
    _claiming = false;
    notifyListeners();
    return result;
  }
}

/// A referral state with no status yet, whose first load waits for the
/// test to end it.
class _SlowReferral extends ReferralState {
  final loaded = Completer<void>();

  @override
  ReferralStatus? get status => null;

  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() => loaded.future;
}

/// Counts the calls that end the home screen's invite card.
class _Prompt extends InvitePrompt {
  int ended = 0;

  @override
  Future<void> shared() async => ended++;
}

void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  late List<MethodCall> shares;
  late String shareAnswer;
  late InviteEvents events;
  late _Prompt prompt;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shares = [];
    shareAnswer = 'sheet';
    InviteShare.nativeForTest = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tunnel, (call) async {
          if (call.method == 'shareInvite') shares.add(call);
          return shareAnswer;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
    events = InviteEvents(
      service: ReferralService.forTest(
        client: ApiClient.forTest(
          direct: MockClient((_) async => http.Response('', 204)),
        ),
      ),
      deviceId: () async => 'DEV-1',
      sharing: () async => true,
    );
    prompt = _Prompt();
  });

  tearDown(() {
    events.dispose();
    prompt.dispose();
    InviteShare.nativeForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tunnel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    ReferralStatus status, {
    InviteEntry entry = InviteEntry.settings,
    String locale = 'en',
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReferralState>.value(
            value: _FakeReferral(status),
          ),
          Provider<InviteEvents>.value(value: events),
          ChangeNotifierProvider<InvitePrompt>.value(value: prompt),
        ],
        child: MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: Locale(locale),
          home: InviteScreen(entry: entry),
        ),
      ),
    );
    await tester.pump();
  }

  /// A widget test that stops the events' send timer at its end, which
  /// the test binding requires.
  void testScreen(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      events.dispose();
    });
  }

  List<(String?, String?)> logged() => [
    for (final e in events.queued)
      (e['surface'] as String?, e['action'] as String?),
  ];

  group('opening the screen', () {
    const surfaces = {
      InviteEntry.homeButton: 'home_button',
      InviteEntry.limitSheet: 'limit_sheet',
      InviteEntry.settings: 'invite_screen',
    };
    for (final entry in surfaces.entries) {
      testScreen('from ${entry.key.name} logs shown on ${entry.value}', (
        tester,
      ) async {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await pump(tester, _status(), entry: entry.key);
        expect(logged(), [(entry.value, 'shown')]);
      });
    }
  });

  testScreen('Share invite hides the backend list, logs other_apps and '
      'ends the card', (tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await pump(
      tester,
      _status(exclude: const ['ir.eitaa.messenger', 'com.example.other']),
    );
    await tester.tap(find.text('Share invite'));
    await tester.pump();

    final args = shares.single.arguments as Map;
    expect(args['target'], 'sheet');
    expect(args['exclude'], [
      ...InviteShare.builtInExclude,
      'com.example.other',
    ]);
    // The link as the backend sent it: s=card is only for the card.
    expect(args['text'], contains('https://fortivavpn.com/fa/i/AB3D7K\n'));
    expect(args['text'], isNot(contains('s=card')));
    expect(logged().last, ('invite_screen', 'other_apps'));
    expect(prompt.ended, 1);
  });

  testScreen('Share invite hides the built-in list when the backend sent '
      'none', (tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await pump(tester, _status());
    await tester.tap(find.text('Share invite'));
    await tester.pump();
    expect(
      (shares.single.arguments as Map)['exclude'],
      InviteShare.builtInExclude,
    );
  });

  testScreen('a share sheet that did not open counts nothing', (tester) async {
    shareAnswer = 'none';
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await pump(tester, _status());
    await tester.tap(find.text('Share invite'));
    await tester.pump();
    expect(shares, hasLength(1));
    expect(logged(), [('invite_screen', 'shown')]);
    expect(prompt.ended, 0);
  });

  testScreen('Copy code logs copy_link and ends the card', (tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await pump(tester, _status());
    await tester.tap(find.text('Copy code'));
    await tester.pump();
    expect(logged().last, ('invite_screen', 'copy_link'));
    expect(prompt.ended, 1);
    await tester.pump(const Duration(seconds: 3));
  });

  group('How it works', () {
    testScreen('names the Premium days and the most, as the backend sends', (
      tester,
    ) async {
      await pump(tester, _status(earns: true, rewardDays: 3, maxDays: 30));
      expect(
        find.text(
          'Each friend who starts using Fortiva also gives you 3 days of '
          'Premium.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('You can earn up to 30 days of Premium from invites.'),
        findsOneWidget,
      );
    });

    testScreen('in Persian digits in Persian', (tester) async {
      await pump(
        tester,
        _status(earns: true, rewardDays: 3, maxDays: 30),
        locale: 'fa',
      );
      expect(find.textContaining('۳ روز پریمیوم هم بهت می‌ده'), findsOneWidget);
      expect(find.textContaining('تا ۳۰ روز پریمیوم'), findsOneWidget);
    });

    testScreen('at the cap only the most is named', (tester) async {
      await pump(tester, _status(earns: false, rewardDays: 3, maxDays: 30));
      expect(find.textContaining('Each friend who starts'), findsNothing);
      expect(
        find.text('You can earn up to 30 days of Premium from invites.'),
        findsOneWidget,
      );
    });

    testScreen('nothing about Premium days while reward B is off', (
      tester,
    ) async {
      await pump(tester, _status());
      expect(find.textContaining('of Premium'), findsNothing);
    });
  });

  group('the look', () {
    testScreen('counts read in the language\'s digits', (tester) async {
      await pump(
        tester,
        const ReferralStatus(
          code: 'AB3D7K',
          shareUrl: 'https://fortivavpn.com/fa/i/AB3D7K',
          invitedCount: 3,
          confirmedCount: 1,
          bonusBytes: 0,
        ),
        locale: 'fa',
      );
      expect(find.text('\u06F3'), findsOneWidget);
      expect(find.text('\u06F1'), findsOneWidget);
      expect(find.text('3'), findsNothing);
    });

    testScreen('the code reads left to right in a right to left language', (
      tester,
    ) async {
      await pump(tester, _status(), locale: 'fa');
      final code = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'AB3D7K',
      );
      expect(code, findsOneWidget);
      expect(
        tester
            .widget<Directionality>(
              find
                  .ancestor(of: code, matching: find.byType(Directionality))
                  .first,
            )
            .textDirection,
        TextDirection.ltr,
      );
    });

    // The code is Latin letters and digits in every language, so it keeps
    // its spacing and its face when the app is in Persian.
    testScreen('the code is spaced the same in every language', (tester) async {
      final code = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'AB3D7K',
      );
      await pump(tester, _status());
      final latin = tester.widget<SelectableText>(code).style!;

      AppDesign.activeLocale = const Locale('fa');
      addTearDown(() => AppDesign.activeLocale = const Locale('en'));
      await pump(tester, _status(), locale: 'fa');
      final persian = tester.widget<SelectableText>(code).style!;
      expect(persian.letterSpacing, greaterThan(0));
      expect(persian.letterSpacing, latin.letterSpacing);
      expect(persian.fontFamily, 'monospace');
      expect(persian.fontFamilyFallback, isEmpty);
      expect(persian.locale, const Locale('en'));
    });

    testScreen('Share invite is the one filled button, Copy code beside or '
        'under it', (tester) async {
      await pump(tester, _status());
      final filled = find.byWidgetPredicate((w) => w is FilledButton);
      expect(filled, findsOneWidget);
      expect(
        find.descendant(of: filled, matching: find.text('Share invite')),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Copy code'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
        findsOneWidget,
      );
    });

    testScreen('Copy code is as tall as Share invite beside it', (
      tester,
    ) async {
      await pump(tester, _status());
      final share = tester.getRect(
        find.ancestor(
          of: find.text('Share invite'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      final copy = tester.getRect(
        find.ancestor(
          of: find.text('Copy code'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      // Side by side at this width.
      expect(copy.top, share.top);
      expect(copy.height, share.height);
    });

    testScreen('the code dialog keeps its buttons enabled while a claim '
        'runs, and taps then do nothing', (tester) async {
      final referral = _ClaimingReferral(_status());
      await tester.pumpWidget(
        ChangeNotifierProvider<ReferralState>.value(
          value: referral,
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const InviteScreen(),
          ),
        ),
      );
      await tester.pump();
      // The tile is last on the screen, laid out below the fold.
      await tester.ensureVisible(
        find.text('Have an invite code?', skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text('Have an invite code?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invite-code-field')),
        'XY7K2Q',
      );
      await tester.pump();
      final dialog = find.byType(AlertDialog);
      final apply = find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );
      await tester.tap(apply);
      await tester.pump();
      expect(referral.claims, ['XY7K2Q']);
      expect(
        find.descendant(
          of: apply,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final paste = find.byKey(const Key('invite-paste'));
      final notNow = find.widgetWithText(TextButton, 'Not now');
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      expect(tester.widget<TextButton>(paste).onPressed, isNotNull);
      expect(tester.widget<TextButton>(notNow).onPressed, isNotNull);

      await tester.tap(apply);
      await tester.tap(paste);
      await tester.tap(notNow);
      await tester.pump();
      expect(referral.claims, ['XY7K2Q']);
      expect(dialog, findsOneWidget);

      referral.answer.complete(
        const ReferralClaimResult.failed(ReferralClaimFailure.unknownCode),
      );
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(
        find.text(
          "We could not find this code. Copy it again from your friend's "
          'message.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows that it is loading, not that loading failed, until '
        'the first load ends', (tester) async {
      final referral = _SlowReferral();
      await tester.pumpWidget(
        ChangeNotifierProvider<ReferralState>.value(
          value: referral,
          child: MaterialApp(
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            home: const InviteScreen(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Could not load your invite code'), findsNothing);
      await tester.pump();
      expect(find.text('Could not load your invite code'), findsNothing);

      referral.loaded.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Could not load your invite code'), findsOneWidget);
      events.dispose();
    });

    testScreen('the code field is monospace and its label is not', (
      tester,
    ) async {
      await pump(tester, _status());
      // The tile is last on the screen, laid out below the fold.
      await tester.ensureVisible(
        find.text('Have an invite code?', skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text('Have an invite code?'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('invite-code-field')),
      );
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.center);
      expect(field.style?.fontFamily, 'monospace');
      // What goes in the field is a label on its top edge, so the centred
      // caret does not draw through it, in the app's font and spacing.
      final decoration = field.decoration!;
      expect(decoration.hintText, isNull);
      expect(decoration.labelText, 'Invite code');
      expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
      expect(decoration.labelStyle?.fontFamily, isNotNull);
      expect(decoration.labelStyle?.fontFamily, isNot('monospace'));
      expect(decoration.labelStyle?.letterSpacing, 0);
    });
  });
}
