import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';

/// The check of a site inside the country (#269), against a server on this
/// machine. No Flutter binding here: with one, every request answers 400
/// without leaving the test.
void main() {
  late HttpServer server;
  late String up;

  /// A port nothing listens on.
  late String down;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      req.response
        ..statusCode = HttpStatus.forbidden
        ..close();
    });
    up = 'http://127.0.0.1:${server.port}/';
    final spare = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    down = 'http://127.0.0.1:${spare.port}/';
    await spare.close();
    ChecklistSettings.current = null;
  });

  tearDown(() async {
    await server.close(force: true);
    ChecklistSettings.current = null;
  });

  test('any answer counts, an error page too', () async {
    final out = await ConnectDiagnostics().homeCheck(urls: [up]);
    expect(out['control_home'], 'ok');
    expect(out['control_home_url'], up);
    expect(out['control_home_ms'], isA<int>());
  });

  test('one site that answers is enough', () async {
    final out = await ConnectDiagnostics().homeCheck(urls: [down, up]);
    expect(out['control_home'], 'ok');
    expect(out['control_home_url'], up);
  });

  test('none answering, or none to ask, fails', () async {
    expect(
      (await ConnectDiagnostics().homeCheck(urls: [down]))['control_home'],
      'fail',
    );
    expect(
      (await ConnectDiagnostics().homeCheck(urls: const []))['control_home'],
      'fail',
    );
  });

  test('the backend\'s sites are asked, else the app\'s own', () {
    expect(ConnectDiagnostics.currentHomeUrls, ConnectDiagnostics.homeUrls);
    ChecklistSettings.current = ChecklistSettings.fromJson({
      'home_control_urls': ['https://a.example/'],
    });
    expect(ConnectDiagnostics.currentHomeUrls, ['https://a.example/']);
    ChecklistSettings.current = ChecklistSettings.fromJson({
      'home_control_urls': <Object>[],
    });
    expect(ConnectDiagnostics.currentHomeUrls, isEmpty);
  });

  test('the app\'s own sites are https, so a captive portal or a block page '
      'cannot pass for them', () {
    for (final u in ConnectDiagnostics.homeUrls) {
      expect(Uri.parse(u).scheme, 'https', reason: u);
    }
  });
}
