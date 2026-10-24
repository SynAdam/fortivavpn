import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/tunnel_pipe.dart';
import 'package:fortiva_vpn/services/windows_tunnel.dart';

/// A stand-in for the Windows tunnel service: the same protocol
/// (windows/core/internal/control), served on a Unix socket, answering from
/// [answer]. Every request it got is kept in [requests].
class FakeService {
  FakeService._(this._server, this.path);

  static Future<FakeService> start(
    FutureOr<Object?> Function(String method, Map<String, dynamic> params)
    answer,
  ) async {
    final dir = await Directory.systemTemp.createTemp('fc');
    final path = '${dir.path}/s';
    final server = await ServerSocket.bind(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    final fake = FakeService._(server, path);
    server.listen((socket) async {
      final line = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first;
      final request = jsonDecode(line) as Map<String, dynamic>;
      fake.requests.add(request);
      Map<String, Object?> reply;
      try {
        final params =
            (request['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final result = await answer(request['method'] as String, params);
        reply = {'ok': true, 'result': ?result};
      } on TunnelCallException catch (e) {
        reply = {
          'ok': false,
          'error': {'code': e.code, 'message': e.message},
        };
      }
      socket.write('${jsonEncode(reply)}\n');
      await socket.flush();
      await socket.close();
    });
    return fake;
  }

  final ServerSocket _server;
  final String path;
  final requests = <Map<String, dynamic>>[];

  Future<void> close() => _server.close();
}

void main() {
  late FakeService service;

  tearDown(() async => service.close());

  group('TunnelClient', () {
    test('returns the result and sends the protocol version', () async {
      service = await FakeService.start((method, params) => {'echo': params});
      final client = TunnelClient(UnixSocketPipe(service.path));
      final result = await client.call('hello', params: {'x': 1});
      expect(result, {
        'echo': {'x': 1},
      });
      expect(service.requests.single['v'], TunnelClient.protocolVersion);
      expect(service.requests.single['method'], 'hello');
    });

    test('turns a refusal into the service\'s code', () async {
      service = await FakeService.start(
        (method, params) =>
            throw const TunnelCallException('INVALID_LINK', 'bad door'),
      );
      final client = TunnelClient(UnixSocketPipe(service.path));
      expect(
        client.call('connect'),
        throwsA(
          isA<TunnelCallException>().having(
            (e) => e.code,
            'code',
            'INVALID_LINK',
          ),
        ),
      );
    });

    test('says when nothing is listening', () async {
      service = await FakeService.start((m, p) => null);
      final client = TunnelClient(UnixSocketPipe('${service.path}-missing'));
      expect(
        client.call('status'),
        throwsA(
          isA<TunnelCallException>().having(
            (e) => e.code,
            'code',
            TunnelCallException.unavailable,
          ),
        ),
      );
    });
  });

  group('WindowsTunnel', () {
    test(
      'connect sends the doors, and the DNS screen\'s resolvers as a list',
      () async {
        service = await FakeService.start(
          (method, params) => {'seq': 1, 'state': 'connecting'},
        );
        final tunnel = WindowsTunnel(pipe: UnixSocketPipe(service.path));
        final result = await tunnel.method.invokeMethod('connect', {
          'link': 'vless://a',
          'alternates': ['vless://b'],
          'exits': ['10', ''],
          'penalties': [0, 1200],
          'dns': '8.8.8.8, 9.9.9.9,',
        });
        expect(result, isNull);
        expect(service.requests.single['method'], 'connect');
        expect(service.requests.single['params'], {
          'link': 'vless://a',
          'alternates': ['vless://b'],
          'exits': ['10', ''],
          'penalties': [0, 1200],
          'dns': ['8.8.8.8', '9.9.9.9'],
        });
      },
    );

    test(
      'connect without standby doors or resolvers sends only the link',
      () async {
        service = await FakeService.start((m, p) => {'seq': 1});
        final tunnel = WindowsTunnel(pipe: UnixSocketPipe(service.path));
        await tunnel.method.invokeMethod('connect', {'link': 'vless://a'});
        expect(service.requests.single['params'], {'link': 'vless://a'});
      },
    );

    test(
      'a refused link is a PlatformException with the service\'s code',
      () async {
        service = await FakeService.start(
          (m, p) => throw const TunnelCallException('INVALID_LINK', 'no'),
        );
        final tunnel = WindowsTunnel(pipe: UnixSocketPipe(service.path));
        expect(
          tunnel.method.invokeMethod('connect', {'link': 'vmess://x'}),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_LINK',
            ),
          ),
        );
      },
    );

    test('no service is a PlatformException the user can read', () async {
      service = await FakeService.start((m, p) => null);
      final tunnel = WindowsTunnel(
        pipe: UnixSocketPipe('${service.path}-missing'),
      );
      expect(
        tunnel.method.invokeMethod('connect', {'link': 'vless://a'}),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', TunnelCallException.unavailable)
              .having((e) => e.message, 'message', contains('not running')),
        ),
      );
      // Diagnostics answer anyway: a missing service is the finding.
      expect(await tunnel.method.invokeMethod('diagnostics'), {
        'tunnel_service': 'not_running',
      });
    });

    test('calls the service has pass through with their answer', () async {
      service = await FakeService.start(
        (method, params) => switch (method) {
          'realPing' => 120,
          'realPingDetail' => {'ms': -1, 'elapsedMs': 3001, 'tcp': 'timeout'},
          'tunnelStats' => {'bytes_up': 10, 'bytes_down': 20},
          'drainSiteStats' => {'example.org': 2},
          'place' => {'time_zone': 'Asia/Tehran'},
          _ => null,
        },
      );
      final channel = WindowsTunnel(pipe: UnixSocketPipe(service.path)).method;
      expect(await channel.invokeMethod<int>('realPing', {'link': 'l'}), 120);
      expect(service.requests.last['params'], {'link': 'l'});
      final detail = await channel.invokeMethod<Map<Object?, Object?>>(
        'realPingDetail',
        {'link': 'l'},
      );
      expect(detail!['tcp'], 'timeout');
      expect(await channel.invokeMethod<Map<Object?, Object?>>('tunnelStats'), {
        'bytes_up': 10,
        'bytes_down': 20,
      });
      expect(
        await channel.invokeMethod<Map<Object?, Object?>>('drainSiteStats'),
        {'example.org': 2},
      );
      expect(await channel.invokeMethod<Map<Object?, Object?>>('place'), {
        'time_zone': 'Asia/Tehran',
      });
    });

    test('getStatus answers in the mobile platforms\' words', () async {
      var status = <String, Object?>{'seq': 3, 'state': 'connected'};
      service = await FakeService.start((m, p) => status);
      final channel = WindowsTunnel(pipe: UnixSocketPipe(service.path)).method;
      expect(await channel.invokeMethod<String>('getStatus'), 'connected');
      status = {'seq': 4, 'state': 'disconnected', 'reason': 'killed'};
      expect(
        await channel.invokeMethod<String>('getStatus'),
        'disconnected:killed',
      );
    });

    test('a failure carries no reason, which the app would file as a drop', () {
      expect(
        WindowsTunnel.statusLine({'state': 'failed', 'reason': 'verify'}),
        'failed',
      );
      expect(WindowsTunnel.statusLine(null), 'disconnected');
    });

    test('Android-only calls are missing, as they are on iOS', () async {
      service = await FakeService.start((m, p) => null);
      final channel = WindowsTunnel(pipe: UnixSocketPipe(service.path)).method;
      for (final method in [
        'testConnection',
        'socksPort',
        'requestReview',
        'openPlayListing',
      ]) {
        expect(
          channel.invokeMethod(method),
          throwsA(isA<MissingPluginException>()),
          reason: method,
        );
      }
      expect(await channel.invokeMethod('privateDns'), isNull);
      expect(service.requests, isEmpty);
    });

    test('installId and throughputSample are answered on the PC', () async {
      service = await FakeService.start((m, p) => null);
      final channel = WindowsTunnel(
        pipe: UnixSocketPipe(service.path),
        installId: () async => 'machine-guid',
        throughputSample: (bytes, capMs) async => {'bytes': bytes, 'ms': capMs},
      ).method;
      expect(await channel.invokeMethod<String>('installId'), 'machine-guid');
      expect(
        await channel.invokeMethod('throughputSample', {
          'bytes': 256000,
          'capMs': 5000,
        }),
        {'bytes': 256000, 'ms': 5000},
      );
      expect(service.requests, isEmpty);
    });

    test('a throughput call without its sizes gets no sample', () async {
      service = await FakeService.start((m, p) => null);
      var sampled = false;
      final channel = WindowsTunnel(
        pipe: UnixSocketPipe(service.path),
        throughputSample: (bytes, capMs) async => sampled = true,
      ).method;
      expect(
        await channel.invokeMethod('throughputSample', {'bytes': 1}),
        isNull,
      );
      expect(sampled, isFalse);
    });
  });

  group('status stream', () {
    test('sends the current status, then each change', () async {
      final changes = StreamController<Map<String, Object?>>();
      final pending = StreamIterator(changes.stream);
      service = await FakeService.start((method, params) async {
        if (method == 'status') return {'seq': 1, 'state': 'disconnected'};
        expect(method, 'watch');
        expect(params['timeoutMs'], 25000);
        if (!await pending.moveNext()) return {'seq': params['after']};
        return pending.current;
      });
      final tunnel = WindowsTunnel(pipe: UnixSocketPipe(service.path));
      final lines = <String>[];
      final sub = tunnel.status.receiveBroadcastStream().listen(
        (line) => lines.add(line as String),
      );

      await _until(() => lines.length == 1);
      expect(lines, ['disconnected']);
      changes.add({'seq': 2, 'state': 'connecting'});
      changes.add({'seq': 3, 'state': 'connected'});
      await _until(() => lines.length == 3);
      expect(lines, ['disconnected', 'connecting', 'connected']);
      // Each watch asks for what comes after the last status it saw. The
      // third watch goes out after the third line, so wait until the
      // service has logged it.
      List<Object?> afters() => [
        for (final r in service.requests)
          if (r['method'] == 'watch') (r['params'] as Map)['after'],
      ];
      await _until(() => afters().length >= 3);
      expect(afters().take(3), [1, 2, 3]);

      await sub.cancel();
      await changes.close();
    });

    test('a service that goes away is a disconnect, said once', () async {
      service = await FakeService.start((m, p) => null);
      final tunnel = WindowsTunnel(
        pipe: UnixSocketPipe('${service.path}-missing'),
        retryDelay: const Duration(milliseconds: 20),
      );
      final lines = <String>[];
      final sub = tunnel.status.receiveBroadcastStream().listen(
        (line) => lines.add(line as String),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(lines, ['disconnected']);
      await sub.cancel();
    });

    test('a restarted service is news, though its number went down', () async {
      var restarted = false;
      service = await FakeService.start((method, params) {
        if (method == 'status') return {'seq': 7, 'state': 'connected'};
        if (!restarted) {
          restarted = true;
          return {'seq': 0, 'state': 'disconnected', 'reason': 'killed'};
        }
        return {'seq': params['after']};
      });
      final tunnel = WindowsTunnel(pipe: UnixSocketPipe(service.path));
      final lines = <String>[];
      final sub = tunnel.status.receiveBroadcastStream().listen(
        (line) => lines.add(line as String),
      );
      await _until(() => lines.length == 2);
      expect(lines, ['connected', 'disconnected:killed']);
      await sub.cancel();
    });
  });
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
