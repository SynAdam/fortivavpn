import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/bootstrap.dart';
import 'package:fortiva_vpn/data/models/checklist_settings.dart';
import 'package:fortiva_vpn/data/models/variant_test.dart';
import 'package:fortiva_vpn/services/connect_diagnostics.dart';
import 'package:fortiva_vpn/services/invite_share.dart';
import 'package:fortiva_vpn/utils/state_platforms.dart';

/// Fortiva never uses an Iranian state platform (decided 2026-10-13). From
/// clients #270 (2026-10-13) to 2026-10-24 the home check asked
/// https://web.bale.ai/ when the sites abroad failed. These tests keep any
/// state platform out of every site the app asks by itself, and out of
/// the backend's site lists for the checklist (home_control_urls and
/// control_urls), its fallback mirrors and its variant test address.
void main() {
  tearDown(() => ChecklistSettings.current = null);

  group('StatePlatforms.names', () {
    test('finds a state platform, a subdomain and a bare name too', () {
      for (final url in [
        'https://web.bale.ai/',
        'https://BALE.AI',
        'https://ble.ir/x',
        'https://bale.ir/',
        'web.eitaa.com',
        'https://eitaa.ir/',
        'https://rubika.ir/',
        'https://messengerg2c1.iranlms.ir/',
        'https://web.splus.ir/',
        'http://sapp.ir',
        'https://shad.ir/',
        'https://igap.net/',
        'https://gap.im/',
        'https://web.bale.ai./',
        'https://web.bale.ai:443/',
      ]) {
        expect(StatePlatforms.names(url), isTrue, reason: url);
      }
    });

    test('leaves every other site alone', () {
      for (final url in [
        'https://www.digikala.com/',
        'https://divar.ir/',
        'https://notbale.ai/',
        'https://bale.ai.example.com/',
        'https://example.com/bale.ai',
        'http://connectivitycheck.gstatic.com/generate_204',
        '',
        'not a site',
      ]) {
        expect(StatePlatforms.names(url), isFalse, reason: url);
      }
    });

    test('finds every domain on the list', () {
      for (final d in StatePlatforms.domains) {
        for (final url in [
          'https://$d/',
          'https://web.$d/x',
          'http://${d.toUpperCase()}',
          d,
        ]) {
          expect(StatePlatforms.names(url), isTrue, reason: url);
          expect(StatePlatforms.mayAsk(url), isFalse, reason: url);
        }
      }
    });

    test('the share sheets hide the same packages', () {
      expect(InviteShare.builtInExclude, StatePlatforms.packages);
    });

    test('a backend share list never shows a state messenger again', () {
      for (final backend in <List<String>?>[
        null,
        const [],
        const ['ir.eitaa.messenger'],
        const ['com.example.other'],
      ]) {
        final hidden = InviteShare.excludeFor(backend);
        expect(
          hidden,
          containsAll(StatePlatforms.packages),
          reason: '$backend',
        );
        expect(hidden, containsAll(backend ?? const []), reason: '$backend');
      }
    });
  });

  // Other code reads these differently from Dart's Uri, so a host that
  // only looks harmless can still reach a state platform. The Go core
  // maps a fullwidth dot or letter to the plain one before it dials.
  const disguised = [
    'https://web.bale.ai\\@divar.ir/',
    'https://divar.ir\\@web.bale.ai/',
    'https://web.bale%2eai/',
    'https://web.bale\u3002ai/',
    'https://web.bale\uFF0Eai/',
    'https://web.bale\uFF61ai/',
    'https://\uFF57eb.bale.ai/',
    'https://web.bale.ai%00.divar.ir/',
  ];

  group('StatePlatforms.mayAsk', () {
    test('refuses a disguised host, whatever it names', () {
      for (final url in disguised) {
        expect(StatePlatforms.mayAsk(url), isFalse, reason: url);
      }
    });

    test('takes a plain site, an address and the built-in sites', () {
      for (final url in [
        'https://www.digikala.com/',
        'https://divar.ir/',
        'http://cp.cloudflare.com/generate_204',
        'https://192.0.2.1/x',
        'https://[2001:db8::1]/x',
        ...ConnectDiagnostics.homeUrls,
        ...ConnectDiagnostics.controlUrls,
      ]) {
        expect(StatePlatforms.mayAsk(url), isTrue, reason: url);
      }
    });

    test('refuses a site with no host', () {
      for (final url in ['', 'not a site', 'https://', '/path']) {
        expect(StatePlatforms.mayAsk(url), isFalse, reason: url);
      }
    });
  });

  group('the sites the app asks by itself', () {
    test('the home check and the control check name none', () {
      for (final url in [
        ...ConnectDiagnostics.homeUrls,
        ...ConnectDiagnostics.controlUrls,
      ]) {
        expect(StatePlatforms.names(url), isFalse, reason: url);
      }
    });

    test('the home check still has a site to ask', () {
      expect(ConnectDiagnostics.homeUrls, isNotEmpty);
    });

    // Every probe, check, mirror, fallback and link in the app's own code,
    // the Dart and the Android side, read from the source. A URL or a
    // quoted host name that names a state platform fails, wherever it is.
    test('no source file of the app names one in a URL or a host name', () {
      final url = RegExp(r'''https?://[^\s"'<>()`$\\]+''');
      final host = RegExp(r'''["']((?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,})\.?["']''');
      final found = <String>[];
      var read = 0;
      for (final root in [
        'lib',
        'android/app/src/main',
        'android/core',
        'windows/core',
        'assets',
      ]) {
        final dir = Directory(root);
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          final path = f.path.replaceAll('\\', '/');
          // The list itself.
          if (path.endsWith('lib/utils/state_platforms.dart')) continue;
          final String text;
          try {
            text = f.readAsStringSync(encoding: utf8);
          } on Exception {
            continue; // not text: an image, a font, a sealed file
          }
          read++;
          for (final m in url.allMatches(text)) {
            if (StatePlatforms.names(m.group(0)!)) {
              found.add('$path: ${m.group(0)}');
            }
          }
          for (final m in host.allMatches(text)) {
            if (StatePlatforms.names(m.group(1)!)) {
              found.add('$path: ${m.group(1)}');
            }
          }
        }
      }
      expect(read, greaterThan(100), reason: 'the scan read too few files');
      expect(found, isEmpty);
    });
  });

  group('a list from the backend that names a state platform', () {
    test('is refused for the home check, and the app keeps its own', () {
      for (final bad in [
        ['https://www.digikala.com/', 'https://web.bale.ai/'],
        ['https://web.eitaa.com/'],
        ['https://WEB.RUBIKA.IR/'],
      ]) {
        final s = ChecklistSettings.fromJson({
          'home_control_urls': bad,
          'retry_seconds': [5],
        })!;
        expect(s.homeControl, isNull, reason: '$bad');
        ChecklistSettings.current = s;
        expect(
          ConnectDiagnostics.currentHomeUrls,
          ConnectDiagnostics.homeUrls,
          reason: '$bad',
        );
      }
    });

    test('is refused for the control check, and the app keeps its own', () {
      for (final bad in [
        ['http://cp.cloudflare.com/generate_204', 'https://splus.ir/'],
        ['http://igap.net/'],
      ]) {
        final s = ChecklistSettings.fromJson({
          'control_urls': bad,
          'retry_seconds': [5],
        })!;
        expect(s.control, isNull, reason: '$bad');
        ChecklistSettings.current = s;
        expect(
          ConnectDiagnostics.currentControlUrls,
          ConnectDiagnostics.controlUrls,
          reason: '$bad',
        );
      }
    });

    test('is refused when a site in it hides its host', () {
      for (final url in disguised) {
        final s = ChecklistSettings.fromJson({
          'home_control_urls': ['https://divar.ir/', url],
          'control_urls': ['http://cp.cloudflare.com/generate_204', url],
          'retry_seconds': [5],
        })!;
        expect(s.homeControl, isNull, reason: url);
        expect(s.control, isNull, reason: url);
      }
    });

    test('a list without one is still taken', () {
      final s = ChecklistSettings.fromJson({
        'home_control_urls': ['https://divar.ir/'],
        'control_urls': ['http://cp.cloudflare.com/generate_204'],
      })!;
      expect(s.homeControl, ['https://divar.ir/']);
      expect(s.control, ['http://cp.cloudflare.com/generate_204']);
    });
  });
  group('the backend\'s other sites', () {
    Map<String, Object> params(String url) => {
      'test_url': url,
      'timeout_ms': 5000,
      'max_per_run': 3,
      'min_gap_minutes': 10,
      'only_when_tunnel_down': true,
    };

    test('a variant test address on a state platform runs no test', () {
      for (final url in [
        'https://web.bale.ai/',
        'http://eitaa.com/generate_204',
        ...disguised,
      ]) {
        expect(VariantTestParams.fromJson(params(url)), isNull, reason: url);
      }
      expect(
        VariantTestParams.fromJson(
          params('http://cp.cloudflare.com/generate_204'),
        )?.testUrl,
        'http://cp.cloudflare.com/generate_204',
      );
    });

    test('a fallback mirror on a state platform is dropped', () {
      expect(
        Bootstrap.httpsOnly([
          'https://example.com/a.txt',
          'https://web.bale.ai/a.txt',
          'https://cdn.rubika.ir/a.txt',
          ...disguised,
          'https://example.org/b.txt',
        ]),
        ['https://example.com/a.txt', 'https://example.org/b.txt'],
      );
    });
  });
}
