import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/services/invite_share.dart';

/// Sharing an invite with the state messengers hidden (clients #271).
/// Fortiva never uses a government platform: every share sheet hides the
/// backend's list, or the app's own copy of it.
void main() {
  const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
  late List<MethodCall> calls;
  late Object? answer;

  setUp(() {
    calls = [];
    answer = 'sheet';
    InviteShare.nativeForTest = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tunnel, (call) async {
          calls.add(call);
          return answer;
        });
  });

  tearDown(() {
    InviteShare.nativeForTest = null;
    InviteShare.sdkIntForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tunnel, null);
  });

  test(
    'the built-in list is the backend default, with no state app missing',
    () {
      expect(InviteShare.builtInExclude, [
        'ir.eitaa.messenger',
        'app.rbmain.a',
        'ir.resaneh1.iptv',
        'ir.nasim',
        'mobi.mmdt.ottplus',
        'mobi.mmdt.ott',
        'ir.medu.shad',
        'net.iGap',
      ]);
    },
  );

  test('the channel arguments for each target', () async {
    final expected = {
      InviteTarget.telegram: 'telegram',
      InviteTarget.whatsapp: 'whatsapp',
      InviteTarget.otherApps: 'sheet',
    };
    for (final entry in expected.entries) {
      calls.clear();
      final outcome = await InviteShare.send(
        text: 'hello',
        target: entry.key,
        exclude: const ['ir.eitaa.messenger'],
        title: 'Invite friends',
      );
      expect(outcome, InviteShareOutcome.sheet);
      final call = calls.single;
      expect(call.method, 'shareInvite');
      expect(call.arguments, {
        'text': 'hello',
        'target': entry.value,
        'exclude': InviteShare.builtInExclude,
        'title': 'Invite friends',
      });
    }
  });

  test('the built-in list when the status has none', () async {
    for (final exclude in <List<String>?>[null, const []]) {
      calls.clear();
      await InviteShare.send(
        text: 'hello',
        target: InviteTarget.otherApps,
        exclude: exclude,
      );
      expect(
        (calls.single.arguments as Map)['exclude'],
        InviteShare.builtInExclude,
      );
    }
  });

  test('what the native side opened', () async {
    answer = 'app';
    expect(
      await InviteShare.send(text: 'x', target: InviteTarget.telegram),
      InviteShareOutcome.app,
    );
    answer = 'none';
    expect(
      await InviteShare.send(text: 'x', target: InviteTarget.otherApps),
      InviteShareOutcome.none,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tunnel, (call) async {
          throw PlatformException(code: 'boom');
        });
    expect(
      await InviteShare.send(text: 'x', target: InviteTarget.whatsapp),
      InviteShareOutcome.none,
    );
  });

  group('the card link', () {
    test('gets s=card', () {
      expect(
        InviteShare.cardLink('https://fortivavpn.com/fa/i/AB3D7K'),
        'https://fortivavpn.com/fa/i/AB3D7K?s=card',
      );
    });

    test('keeps a query the link already has', () {
      final link = Uri.parse(
        InviteShare.cardLink('https://fortivavpn.com/i/AB3D7K?x=1&y=two'),
      );
      expect(link.path, '/i/AB3D7K');
      expect(link.queryParameters, {'x': '1', 'y': 'two', 's': 'card'});
    });

    test('replaces an s already there rather than adding a second', () {
      final link = Uri.parse(
        InviteShare.cardLink('https://fortivavpn.com/i/AB3D7K?s=other'),
      );
      expect(link.queryParametersAll['s'], ['card']);
    });
  });

  group('copy', () {
    late List<String> copied;

    setUp(() {
      copied = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> copyOn(WidgetTester tester, int sdk) async {
      InviteShare.sdkIntForTest = () async => sdk;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => InviteShare.copy(context, 'the message'),
                child: const Text('copy'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('copy'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('says so below Android 13', (tester) async {
      await copyOn(tester, 32);
      expect(copied, ['the message']);
      expect(find.text('Invite message copied'), findsOneWidget);
    });

    testWidgets('Android 13 and later show their own notice', (tester) async {
      await copyOn(tester, 33);
      expect(copied, ['the message']);
      expect(find.text('Invite message copied'), findsNothing);
    });
  });
}
