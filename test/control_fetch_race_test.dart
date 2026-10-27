import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';

/// The control fetch races its sites (clients C5 of the plan of
/// 2026-10-23), against a server on this machine. No Flutter binding here:
/// with one, every request answers 400 without leaving the test.
///
/// Until 2.2.0 the two sites were asked one after the other, with 2.5
/// seconds for each step, so a slow line took up to 10 seconds to answer
/// and a site that needed 3 seconds failed.
void main() {
  setUp(() => ChecklistSettings.current = null);
  tearDown(() => ChecklistSettings.current = null);

  group('the control fetch', () {
    late HttpServer server;
    late String quick;
    late String slow;
    late String refused;
    late String hangs;
    late String portal;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        switch (request.uri.path) {
          case '/slow':
            await Future.delayed(const Duration(milliseconds: 3000));
            request.response.statusCode = 204;
          case '/hangs':
            await Future.delayed(const Duration(seconds: 6));
            request.response.statusCode = 204;
          case '/refused':
            request.response.statusCode = 403;
          case '/portal':
            // A captive portal: the 204 page sends the phone to its login.
            request.response.statusCode = 302;
            request.response.headers.set('location', '/login');
          case '/login':
            request.response.statusCode = 200;
          default:
            request.response.statusCode = 204;
        }
        try {
          await request.response.close();
        } catch (_) {}
      });
      final base = 'http://127.0.0.1:${server.port}';
      quick = '$base/quick';
      slow = '$base/slow';
      refused = '$base/refused';
      hangs = '$base/hangs';
      portal = '$base/portal';
    });
    tearDown(() => server.close(force: true));

    test('races the sites: the first to answer wins at once', () async {
      final clock = Stopwatch()..start();
      final out = await ConnectDiagnostics().controlCheck(urls: [hangs, quick]);
      expect(out['control'], 'ok');
      expect(out['control_url'], quick);
      expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('gives a site 4 seconds, where it had 2.5 for each step', () async {
      expect(ConnectDiagnostics.controlTimeout, const Duration(seconds: 4));
      final out = await ConnectDiagnostics().controlCheck(
        urls: [refused, slow],
      );
      expect(out['control'], 'ok');
      expect(out['control_url'], slow);
    });

    test('a captive portal passes the default check but not only204, which '
        'still takes a real 204', () async {
      expect(
        (await ConnectDiagnostics().controlCheck(urls: [portal]))['control'],
        'ok',
      );
      expect(
        await ConnectDiagnostics().controlCheck(urls: [portal], only204: true),
        {'control': 'fail'},
      );
      final out = await ConnectDiagnostics().controlCheck(
        urls: [portal, quick],
        only204: true,
      );
      expect(out['control'], 'ok');
      expect(out['control_url'], quick);
    });

    test('fails once every site failed or ran out of time', () async {
      final clock = Stopwatch()..start();
      final out = await ConnectDiagnostics().controlCheck(
        urls: [refused, hangs],
      );
      expect(out, {'control': 'fail'});
      expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
      expect(await ConnectDiagnostics().controlCheck(urls: const []), {
        'control': 'fail',
      });
    });

    test('asks the backend sites when it sent some, and its own two '
        'otherwise', () {
      expect(
        ConnectDiagnostics.currentControlUrls,
        ConnectDiagnostics.controlUrls,
      );
      ChecklistSettings.current = ChecklistSettings.fromJson({
        'control_urls': [quick],
      });
      expect(ConnectDiagnostics.currentControlUrls, [quick]);
    });
  });
}
