import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/data/repositories/server_repository.dart';
import 'package:fortiva_vpn/services/ping_service.dart';
import 'package:fortiva_vpn/utils/link_id.dart';
import 'package:fortiva_vpn/utils/shared_link.dart';
import 'package:fortiva_vpn/utils/vless_link.dart';
import 'package:fortiva_vpn/widgets/server_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The public list holds vless, vmess, trojan and ss links, and a few the
/// app cannot use. Until 2026-10-07 only vless links could be tested, a
/// vmess link had no host, every vmess link was one path, and a link with
/// allowInsecure was listed and dialled although the core refuses it.

String vmess(Map<String, dynamic> json, {bool url = false, String? label}) {
  final body = url
      ? base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '')
      : base64.encode(utf8.encode(jsonEncode(json)));
  return 'vmess://$body${label == null ? '' : '#$label'}';
}

final _vmessWs = vmess({
  'v': '2',
  'ps': '🇩🇪 Telegram @somechannel',
  'add': 'de.example.org',
  'port': '8080',
  'id': 'b831381d-6324-4d53-ad4f-8cda48b30811',
  'net': 'ws',
  'type': 'none',
  'host': 'cdn.example.org',
  'path': '/ws',
  'tls': 'tls',
  'sni': 'cdn.example.org',
});

class _Source implements ServerConfigSource {
  _Source(this.community);

  final List<String> community;

  @override
  Future<List<Server>> getOfficialConfigs() async => const [];

  @override
  Future<List<String>> getCommunityConfigs() async => community;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which links the app can use', () {
    test('vless, vmess, trojan and ss', () {
      expect(SharedLink.usable('vless://u@h:443?type=tcp#a'), isTrue);
      expect(SharedLink.usable(_vmessWs), isTrue);
      expect(SharedLink.usable('trojan://pw@h:443?security=tls#a'), isTrue);
      expect(
        SharedLink.usable('ss://YWVzLTEyOC1nY206cHc@1.2.3.4:8388'),
        isTrue,
      );
    });

    test('not hysteria2, hy2, wireguard or anything else', () {
      for (final link in [
        'hysteria2://pw@h:443?insecure=0#a',
        'hy2://pw@h:443#a',
        'wireguard://key@h:51820#a',
        'socks://dXNlcjpwdw@h:1080#a',
        'tuic://u:p@h:443#a',
        'garbage',
        '',
      ]) {
        expect(SharedLink.usable(link), isFalse, reason: link);
      }
    });

    test('on Windows, whose core reads vless only, vless alone', () {
      SharedLink.windowsOverride = true;
      addTearDown(() => SharedLink.windowsOverride = null);
      expect(SharedLink.usable('vless://u@h:443?type=tcp#a'), isTrue);
      expect(SharedLink.usable(_vmessWs), isFalse);
      expect(SharedLink.usable('trojan://pw@h:443#a'), isFalse);
      expect(SharedLink.usable('ss://YWVzLTEyOC1nY206cHc@h:8388'), isFalse);
    });

    test('not with allowInsecure 1 or true, in any case', () {
      for (final link in [
        'vless://u@h:443?security=tls&allowInsecure=1#a',
        'vless://u@h:443?security=tls&allowInsecure=true#a',
        'trojan://pw@h:443?allowinsecure=TRUE#a',
        'vless://u@h:443?security=tls&ALLOWINSECURE=1',
        'vless://u@h:443?security=tls&amp;allowInsecure=1#a',
      ]) {
        expect(SharedLink.insecure(link), isTrue, reason: link);
        expect(SharedLink.usable(link), isFalse, reason: link);
      }
    });

    test('allowInsecure 0, or in the label only, is fine', () {
      for (final link in [
        'vless://u@h:443?security=tls&allowInsecure=0#a',
        'vless://u@h:443?security=tls&allowInsecure=false#a',
        'vless://u@h:443?security=tls#allowInsecure=1',
        'vless://u@h:443?security=tls&notallowInsecure=1',
      ]) {
        expect(SharedLink.usable(link), isTrue, reason: link);
      }
    });
  });

  group('a vmess link', () {
    test('names its host and port from the JSON', () {
      expect(VlessLink.host(_vmessWs), 'de.example.org:8080');
      expect(VlessLink.hostname(_vmessWs), 'de.example.org');
      expect(VlessLink.port(_vmessWs), 8080);
    });

    test('never shows the id', () {
      expect(VlessLink.host(_vmessWs), isNot(contains('3f6fefec')));
    });

    test('reads in either base64 alphabet, padded or not', () {
      final json = {'add': '1.2.3.4', 'port': 443, 'id': 'x', 'net': 'tcp'};
      expect(VlessLink.host(vmess(json)), '1.2.3.4:443');
      expect(VlessLink.host(vmess(json, url: true)), '1.2.3.4:443');
      expect(VlessLink.host(vmess(json, label: 'Telegram @x')), '1.2.3.4:443');
    });

    test('an IPv6 address keeps its brackets', () {
      final link = vmess({'add': '2001:db8::1', 'port': '443', 'id': 'x'});
      expect(VlessLink.host(link), '[2001:db8::1]:443');
      expect(VlessLink.hostname(link), '2001:db8::1');
      expect(VlessLink.port(link), 443);
    });

    test('its settings are read like query parameters', () {
      expect(VlessLink.transport(_vmessWs), 'ws');
      expect(VlessLink.security(_vmessWs), 'tls');
      expect(VlessLink.sni(_vmessWs), 'cdn.example.org');
      final strategy = VlessLink.strategy(_vmessWs);
      expect(strategy['transport'], 'ws');
      expect(strategy['security'], 'tls');
      expect(strategy['port'], 8080);
      expect(strategy['path'], '/ws');
      expect(strategy.containsKey('id'), isFalse);
    });

    test('one that cannot be read has no host, and does not throw', () {
      expect(VlessLink.vmess('vmess://not base64 at all'), isNull);
      expect(VlessLink.host('vmess://bm90IGpzb24='), '');
      expect(VlessLink.host('vmess://'), '');
    });

    test('lists under the country it carries, without its host', () {
      final server = Server.fromConnectionUri(_vmessWs, index: 4);
      expect(server.isCommunity, isTrue);
      expect(server.country, 'Germany');
      expect(server.flagEmoji, '🇩🇪');
      expect(ServerCard.subtitleFor(server), 'TLS · 8080');
    });
  });

  group('the host of other links', () {
    test('an @ in the label is not the end of a credential', () {
      expect(
        VlessLink.host('vless://u@h.example:443?type=tcp#Telegram @chan'),
        'h.example:443',
      );
      expect(VlessLink.host('ss://YWVzOnB3#@chan'), '');
    });

    test('a path after the port is not part of it', () {
      expect(
        VlessLink.host('trojan://pw@h.example:443/?type=ws'),
        'h.example:443',
      );
      expect(VlessLink.port('trojan://pw@h.example:443/?type=ws'), 443);
    });

    test('a community trojan link keeps its host as the remark', () {
      final server = Server.fromConnectionUri('trojan://pw@t.example:443');
      expect(server.remark, 't.example');
      expect(server.name, 'Community 1');
    });
  });

  group('the path key of a community link', () {
    test('two links to one address are two paths', () {
      final a = Server.fromConnectionUri('vless://a@1.2.3.4:443?type=tcp#x');
      final b = Server.fromConnectionUri(
        'vless://b@1.2.3.4:443?type=tcp#x',
        index: 1,
      );
      expect(a.pathKey, isNot(b.pathKey));
    });

    test('every vmess link is its own path', () {
      final a = Server.fromConnectionUri(_vmessWs);
      final b = Server.fromConnectionUri(
        vmess({'add': 'other.example', 'port': '443', 'id': 'y'}),
        index: 1,
      );
      expect(a.pathKey, isNot(b.pathKey));
      expect(a.pathKey, isNot('|'));
    });

    test('is the lid, whatever the label or position', () {
      const link = 'vless://a@1.2.3.4:443?type=tcp';
      final a = Server.fromConnectionUri('$link#one');
      final b = Server.fromConnectionUri('$link#two', index: 7);
      expect(a.pathKey, b.pathKey);
      expect(a.pathKey, contains(LinkId.of(link)));
    });

    test('our own links keep their endpoint key', () {
      const own = Server(
        id: 'dedicated-1.2.3.4:443',
        name: 'x',
        country: '',
        city: '',
        connectionUri: 'vless://u@1.2.3.4:443?type=tcp#x',
        flagEmoji: '',
        isDedicated: true,
        door: 'tcp-reality',
      );
      expect(own.pathKey, '1.2.3.4:443|tcp-reality');
    });
  });

  group('the public list', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('leaves out what the app cannot use, and keeps the rest', () async {
      final repo = ServerRepository.withConfigSource(
        _Source([
          'vless://u@a.example:443?type=tcp#A',
          'hy2://pw@b.example:443#B',
          'vless://u@c.example:443?security=tls&allowInsecure=1#C',
          _vmessWs,
          'wireguard://k@d.example:51820#D',
          'trojan://pw@e.example:443#E',
          'ss://YWVzLTEyOC1nY206cHc@f.example:8388#F',
        ]),
      );

      final servers = (await repo.getCommunityServers()).servers;

      expect(servers.map((s) => VlessLink.hostname(s.connectionUri)), [
        'a.example',
        'de.example.org',
        'e.example',
        'f.example',
      ]);
      // The position the backend gave, so a link keeps its id when an
      // unusable one before it comes and goes.
      expect(servers.map((s) => s.id), [
        'telegram-0',
        'telegram-3',
        'telegram-5',
        'telegram-6',
      ]);
    });

    test('a saved list is read the same way', () async {
      SharedPreferences.setMockInitialValues({
        ServerRepository.savedCommunityKey: jsonEncode({
          'at': DateTime.now().toUtc().toIso8601String(),
          'links': [
            'vless://u@c.example:443?security=tls&allowInsecure=true#C',
            'vless://u@a.example:443?type=tcp#A',
          ],
        }),
      });
      final repo = ServerRepository.withConfigSource(_Source(const []));

      final saved = await repo.savedCommunityServers();

      expect(saved!.servers.single.remark, 'A');
    });
  });

  group('the ping path', () {
    const tunnel = MethodChannel('com.vpn.fortivavpn/tunnel');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(tunnel, (call) async {
        calls.add(call);
        return call.method == 'realPing' ? 180 : {'ms': 180};
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(tunnel, null));

    Server link(String uri) => Server.fromConnectionUri(uri);

    test('tests vmess, trojan and ss links, not only vless', () async {
      for (final uri in [
        _vmessWs,
        'trojan://pw@t.example:443?security=tls#t',
        'ss://YWVzLTEyOC1nY206cHc@s.example:8388#s',
      ]) {
        expect(await PingService().pingServer(link(uri)), 180, reason: uri);
        expect(await PingService().checkDoor(link(uri)), 180, reason: uri);
      }
      expect(calls, hasLength(6));
    });

    test('never sends one the core would refuse', () async {
      for (final uri in [
        'hy2://pw@h.example:443#h',
        'vless://b831381d-6324-4d53-ad4f-8cda48b30811@h.example:443'
            '?security=tls&allowInsecure=1#x',
      ]) {
        expect(PingService.canTest(uri), isFalse, reason: uri);
        expect(await PingService().pingServer(link(uri)), -1);
        await expectLater(
          PingService().checkDoor(link(uri)),
          throwsA(isA<DoorCheckFailed>()),
        );
      }
      expect(calls, isEmpty);
    });

    test('the core waits as long as the caller says', () async {
      await PingService().pingServer(
        link(_vmessWs),
        coreTimeout: const Duration(seconds: 8),
      );
      await PingService().checkDoor(
        link(_vmessWs),
        coreTimeout: const Duration(seconds: 6),
      );
      expect(calls[0].arguments['timeoutMs'], 8000);
      expect(calls[1].arguments['timeoutMs'], 6000);
    });

    test('and its own default when the caller says nothing', () async {
      await PingService().pingServer(link(_vmessWs));
      expect((calls.single.arguments as Map).containsKey('timeoutMs'), isFalse);
    });
  });
}
