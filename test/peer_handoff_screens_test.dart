import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/api_routes.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/api/peer_code.dart';
import 'package:fortiva_vpn/core/design_system.dart';
import 'package:fortiva_vpn/core/form_factor.dart';
import 'package:fortiva_vpn/l10n/generated/app_localizations.dart';
import 'package:fortiva_vpn/screens/peer_receive_screen.dart';
import 'package:fortiva_vpn/screens/peer_share_screen.dart';
import 'package:fortiva_vpn/services/peer_pick.dart';
import 'package:fortiva_vpn/widgets/outside_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap_file_test.dart' show payload, seal, sealKey, seed;

/// The two screens that pass the fallback file between phones: the one
/// that shows it (PeerShareScreen) and the one that takes it
/// (PeerReceiveScreen). See peer_handoff_test.dart for the logic below
/// them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> publicKey;
  final now = DateTime.utc(2026, 10, 12, 12);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiRelays.resetForTest();
    final pair = await Ed25519().newKeyPairFromSeed(seed);
    publicKey = (await pair.extractPublicKey()).bytes;
  });

  Bootstrap bootstrap({String? built}) => Bootstrap(
    builtIn: const [],
    publicKey: publicKey,
    sealKey: sealKey,
    now: () => now,
    seed: () async => built,
  );

  /// A file long enough to need several codes, like the real one: links
  /// whose ids do not compress.
  Future<String> bigFile(int issuedAt) {
    var x = 12345;
    String id() => [
      for (var i = 0; i < 32; i++)
        ((x = (x * 1103515245 + 12345) & 0x7fffffff) >> 16) % 16,
    ].map((d) => d.toRadixString(16)).join();
    return seal(
      payload(
        issuedAt: issuedAt,
        links: [
          for (var i = 0; i < 70; i++)
            'vless://${id()}@198.51.100.$i:443?type=tcp#${id()}',
        ],
      ),
    );
  }

  Widget app(Widget screen) => MaterialApp(
    theme: AppDesign.darkTheme,
    localizationsDelegates: S.localizationsDelegates,
    supportedLocales: S.supportedLocales,
    locale: const Locale('en'),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(app(screen));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<QrModules?> drawn(String text) async =>
      QrModules(21, Uint8List(21 * 21));

  group('the phone that has the file', () {
    testWidgets('shows it as codes one at a time, and copies it', (
      tester,
    ) async {
      final line = await tester.runAsync(() => bigFile(nowSeconds));
      final b = bootstrap(built: line);
      final codes = PeerCode.split(line!);
      expect(codes.length, greaterThan(1));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      // Tall enough that the buttons under the codes are built.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await open(tester, PeerShareScreen(bootstrap: b, draw: drawn));

      expect(find.text('Code 1 of ${codes.length}'), findsOneWidget);
      expect(find.byType(QrCode), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Code 2 of ${codes.length}'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Code 1 of ${codes.length}'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, line);
      expect(
        find.text('Copied. Paste it in a message to your friend.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'says it has nothing recent to pass on, without telling a connected user to connect',
      (tester) async {
        final old = await tester.runAsync(
          () => seal(
            payload(
              issuedAt:
                  nowSeconds -
                  (Bootstrap.shareFor + const Duration(days: 1)).inSeconds,
            ),
          ),
        );
        final b = bootstrap(built: old);

        await open(tester, PeerShareScreen(bootstrap: b, draw: drawn));

        expect(
          find.text(
            'This phone has nothing recent to pass on. Try again later.',
          ),
          findsOneWidget,
        );
        expect(find.byType(QrCode), findsNothing);
        expect(find.text('Copy'), findsNothing);
      },
    );
  });

  group('steps', () {
    test('both instructions cut into two steps in every language, and '
        'nothing is lost', () {
      for (final locale in S.supportedLocales) {
        final l10n = lookupS(locale);
        for (final text in [
          l10n.peerShareSteps(l10n.peerReceiveTitle),
          l10n.peerReceiveBody(l10n.peerShareTitle),
        ]) {
          final steps = peerSteps(text);
          expect(steps, hasLength(2), reason: '$locale: $text');
          String bare(String t) => t.replaceAll(RegExp(r'\s'), '');
          expect(bare(steps!.join()), bare(text), reason: '$locale');
        }
      }
    });

    test('text that does not cut into two is shown whole', () {
      expect(peerSteps('One sentence only.'), isNull);
      expect(peerSteps('One. Two. Three.'), isNull);
      expect(peerSteps('最初。次に。'), ['最初。', '次に。']);
    });

    testWidgets('the share screen numbers its steps in the language\'s '
        'digits', (tester) async {
      final line = await tester.runAsync(() => bigFile(nowSeconds));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesign.darkTheme,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('fa'),
          home: PeerShareScreen(
            bootstrap: bootstrap(built: line),
            draw: drawn,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PeerStep), findsNWidgets(2));
      expect(find.text('۱'), findsOneWidget);
      expect(find.text('۲'), findsOneWidget);
    });

    testWidgets('on a TV the code fits the short screen with room to spare', (
      tester,
    ) async {
      FormFactor.isTvForTest = true;
      addTearDown(() => FormFactor.isTvForTest = false);
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final line = await tester.runAsync(() => bigFile(nowSeconds));
      await open(
        tester,
        PeerShareScreen(
          bootstrap: bootstrap(built: line),
          draw: drawn,
        ),
      );
      final code = tester.getSize(find.byType(QrCode));
      expect(code.height, lessThanOrEqualTo(540 * 0.6));
      // A TV shows the codes and nothing to copy or send.
      expect(find.text('Copy'), findsNothing);
    });
  });

  group('the phone that needs it', () {
    testWidgets('photographs the codes one by one, then takes the file and '
        'closes', (tester) async {
      final line = await tester.runAsync(() => bigFile(nowSeconds));
      final codes = PeerCode.split(line!);
      final b = bootstrap();
      final photos = [
        (status: PeerPickStatus.noCode, text: null),
        for (final c in codes) (status: PeerPickStatus.ok, text: c),
      ];
      var taken = 0;
      Future<({PeerPickStatus status, String? text})> photograph() async =>
          photos[taken++];

      await open(
        tester,
        PeerReceiveScreen(bootstrap: b, photograph: photograph, canPick: true),
      );

      await tester.tap(find.text('Photograph their codes'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No code found in that photo. Hold the phone closer, with the '
          'whole code in view.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Photograph their codes'));
      await tester.pumpAndSettle();
      expect(find.text('1 of ${codes.length} codes read'), findsOneWidget);

      for (var i = 1; i < codes.length; i++) {
        await tester.tap(find.text('Photograph the next code'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      expect(b.file?.text, line);
      expect(find.byType(PeerReceiveScreen), findsNothing);
      expect(find.text('Done. Tap the button to connect.'), findsOneWidget);
    });

    testWidgets('pastes a whole file from a message, and says so when it is '
        'not one or is not newer', (tester) async {
      final line = await tester.runAsync(
        () => seal(payload(issuedAt: nowSeconds)),
      );
      final b = bootstrap(built: line);
      final clipboard = <String?>[null, 'hello', 'From my friend: $line'];
      var pasted = 0;

      await open(
        tester,
        PeerReceiveScreen(
          bootstrap: b,
          paste: () async => clipboard[pasted++],
          canPick: false,
        ),
      );
      expect(find.text('Photograph their codes'), findsNothing);
      expect(find.text('Open a file they sent'), findsNothing);

      await tester.tap(find.text('Paste what they sent'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Nothing copied yet. Copy what your friend sent, then tap here '
          'again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Paste what they sent'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'What you copied is not from Fortiva. Copy your friend\'s whole '
          'message, then try again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Paste what they sent'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'You already have this, or something newer. Try connecting '
          'again, or ask another friend.',
        ),
        findsOneWidget,
      );
      expect(find.byType(PeerReceiveScreen), findsOneWidget);
    });

    testWidgets('a code read twice, unrelated pasted text and a camera that '
        'hands back no photo each say what to do', (tester) async {
      final line = await tester.runAsync(() => bigFile(nowSeconds));
      final codes = PeerCode.split(line!);
      final photos = [
        (status: PeerPickStatus.ok, text: codes[0]),
        (status: PeerPickStatus.ok, text: codes[0]),
        (status: PeerPickStatus.noPhoto, text: null),
      ];
      var taken = 0;

      await open(
        tester,
        PeerReceiveScreen(
          bootstrap: bootstrap(),
          photograph: () async => photos[taken++],
          paste: () async => 'see you tomorrow',
          canPick: true,
        ),
      );

      await tester.tap(find.text('Photograph their codes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photograph the next code'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'You already have this code. Ask your friend to show the next one.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 of ${codes.length} codes read'), findsOneWidget);

      await tester.tap(find.text('Photograph the next code'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The camera did not hand the photo back. Take the photo with the '
          'camera app, then tap Open a file they sent.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Paste what they sent'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'What you copied is not from Fortiva. Copy your friend\'s whole '
          'message, then try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 of ${codes.length} codes read'), findsOneWidget);
    });

    testWidgets('after Android restarted the app mid-photo, the codes read '
        'before and the photo that came back are both used', (tester) async {
      final line = await tester.runAsync(() => bigFile(nowSeconds));
      final codes = PeerCode.split(line!);
      expect(codes.length, greaterThan(2));
      final before = PeerCodeReader();
      for (final c in codes.skip(1).take(codes.length - 2)) {
        before.add(c);
      }
      SharedPreferences.setMockInitialValues({
        PeerReceiveScreen.savedKey: jsonEncode({
          'at': now.millisecondsSinceEpoch,
          'codes': before.toJson(),
        }),
      });
      final b = bootstrap();
      final photos = [(status: PeerPickStatus.ok, text: codes.last)];

      await open(
        tester,
        PeerReceiveScreen(
          bootstrap: b,
          photograph: () async => photos.removeAt(0),
          canPick: true,
          now: () => now.add(const Duration(minutes: 5)),
          start: (status: PeerPickStatus.ok, text: codes.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${codes.length - 1} of ${codes.length} codes read'),
        findsOneWidget,
      );

      await tester.tap(find.text('Photograph the next code'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(b.file?.text, line);
      expect(find.text('Done. Tap the button to connect.'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PeerReceiveScreen.savedKey), isNull);
    });
  });
}
