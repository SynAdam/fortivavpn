import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/play_signature.dart';

/// Whether this copy is the one Google Play signed.
///
/// Google Play Billing sells only in a copy signed with Google Play's app
/// signing certificate. The APK posted in the Telegram channel runs the
/// same code but is signed with our upload key, so it must read as not
/// Google's, and so must anything that goes wrong while asking.

/// Google Play's app signing certificate, as Play Console shows it.
const _google =
    'E1:F5:F9:1D:AA:A7:F9:AE:07:FF:3B:02:06:0F:6E:33:BA:21:21:5C:16:F2:EA:70:'
    '9B:E0:B1:96:D7:C9:08:A5';

/// Our upload key, which signs the channel APK (tool/release.sh).
const _upload =
    'd4a0baf70a626654a63ff99ab7275d85b43d776a26854d2448ac2f6d10acb141';

const _channel = MethodChannel('test/signature');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var calls = 0;

  /// Answer `signingCertificates` with [answer], or throw it when it is an
  /// exception.
  void answerWith(Object? answer) {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'signingCertificates');
      calls++;
      if (answer is Exception) throw answer;
      return answer;
    });
  }

  setUp(() => calls = 0);
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  PlaySignature android() => PlaySignature(channel: _channel, android: true);

  group('the certificate', () {
    test('is the one Play Console shows', () {
      expect(PlaySignature.googleCertSha256, _google);
      expect(PlaySignature.normalise(_google), hasLength(64));
    });

    test('matches with or without colons, in either case', () {
      final bare = _google.replaceAll(':', '');
      for (final digest in [_google, bare, bare.toLowerCase()]) {
        expect(PlaySignature.isGoogle([digest]), isTrue, reason: digest);
      }
    });

    test('the upload key, nothing, and odd values are not Google\'s', () {
      expect(PlaySignature.isGoogle([_upload]), isFalse);
      expect(PlaySignature.isGoogle(const []), isFalse);
      expect(PlaySignature.isGoogle([null, 42, '']), isFalse);
      // One of several signers is enough, as Android lists them.
      expect(PlaySignature.isGoogle([_upload, _google]), isTrue);
    });
  });

  group('asking Android', () {
    test('the copy Google signed reads as Google\'s', () async {
      answerWith([_google.replaceAll(':', '').toLowerCase()]);
      expect(await android().read(), isTrue);
    });

    test('the channel APK, signed with the upload key, does not', () async {
      answerWith([_upload]);
      expect(await android().read(), isFalse);
    });

    test('is asked once and remembered', () async {
      answerWith([_google]);
      final signature = android();
      expect(await signature.read(), isTrue);
      expect(await signature.read(), isTrue);
      expect(calls, 1);
    });

    test('callers at the same moment share one question', () async {
      answerWith([_google]);
      final signature = android();
      expect(await Future.wait([signature.read(), signature.read()]), [
        true,
        true,
      ]);
      expect(calls, 1);
    });

    // PlaySignature.shared outlives every test. Its answer must reach a
    // test that runs on another fake clock, as the update prompt's and
    // BillingState's tests do.
    test('a remembered answer reaches a later fake clock', () {
      answerWith([_google]);
      final signature = android();
      fakeAsync((async) {
        unawaited(signature.read());
        async.flushMicrotasks();
      });
      fakeAsync((async) {
        bool? later;
        unawaited(signature.read().then((v) => later = v));
        async.flushMicrotasks();
        expect(later, isTrue);
      });
      expect(calls, 1);
    });

    test('a check that timed out is asked again', () {
      fakeAsync((async) {
        messenger.setMockMethodCallHandler(_channel, (call) {
          calls++;
          return Completer<Object?>().future;
        });
        final signature = android();
        bool? first;
        unawaited(signature.read().then((v) => first = v));
        async.elapse(PlaySignature.timeout);
        expect(first, isFalse);

        answerWith([_google]);
        bool? second;
        unawaited(signature.read().then((v) => second = v));
        async.flushMicrotasks();
        expect(second, isTrue);
        expect(calls, 2);
      });
    });

    for (final (name, answer) in <(String, Object?)>[
      ('no answer', null),
      ('an empty list', const <String>[]),
      ('an error', PlatformException(code: 'PM')),
      ('no native side', MissingPluginException()),
    ]) {
      test('$name reads as not Google\'s', () async {
        answerWith(answer);
        expect(await android().read(), isFalse);
      });
    }

    test('off Android nothing is asked, and it is not Google\'s', () async {
      answerWith([_google]);
      expect(
        await PlaySignature(channel: _channel, android: false).read(),
        isFalse,
      );
      expect(calls, 0);
    });
  });
}
