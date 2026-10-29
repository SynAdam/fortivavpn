import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/services/tunnel_pipe.dart';
import 'package:fortiva_vpn/services/windows_tunnel.dart';

/// The Windows bridge against a real core, to catch the app and the service
/// drifting apart. Opt-in, because it needs the core running:
///
///   cd windows/core && ./stage.sh && go build ./cmd/fortiva-core
///   ./fortiva-core run -assets .assets &
///   FORTIVA_CORE_SOCKET=/tmp/fortiva-tunnel.sock flutter test test/windows_tunnel_core_test.dart
void main() {
  final socket = Platform.environment['FORTIVA_CORE_SOCKET'];

  test(
    'the bridge and the core agree on every call',
    () async {
      final tunnel = WindowsTunnel(pipe: UnixSocketPipe(socket!));
      final client = TunnelClient(UnixSocketPipe(socket));
      final channel = tunnel.method;

      final hello = await client.call('hello') as Map;
      expect(hello['protocol'], TunnelClient.protocolVersion);

      expect(await channel.invokeMethod<String>('getStatus'), 'disconnected');

      await expectLater(
        channel.invokeMethod('connect', {'link': 'vmess://nope'}),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_LINK',
          ),
        ),
      );

      // Doors nothing listens on: the attempt starts and then fails, and the
      // stream says both, in the words the app reads. They go as a group,
      // with every field the app sends with one: the service refuses a
      // field it does not know.
      final lines = <String>[];
      final sub = tunnel.status.receiveBroadcastStream().listen(
        (line) => lines.add(line as String),
      );
      await _until(() => lines.isNotEmpty);
      await channel.invokeMethod('connect', {
        'link':
            'vless://11111111-2222-3333-4444-555555555555@127.0.0.1:9'
            '?type=tcp&security=none#dead',
        'alternates': [
          'vless://11111111-2222-3333-4444-555555555555@127.0.0.1:7'
              '?type=tcp&security=none#dead',
        ],
        'exits': ['10', '10'],
        'penalties': [0, 1200],
        'dns': '1.1.1.1',
      });
      await _until(() => lines.contains('failed'), seconds: 25);
      expect(lines, containsAllInOrder(['connecting', 'failed']));
      await sub.cancel();

      final diagnostics = await channel.invokeMethod<Map<Object?, Object?>>(
        'diagnostics',
      );
      expect(diagnostics!['failure'], 'verify');
      expect(diagnostics['core_log'], contains('[engine] failed verify'));

      final detail = await channel
          .invokeMethod<Map<Object?, Object?>>('realPingDetail', {
            'link':
                'vless://11111111-2222-3333-4444-555555555555@127.0.0.1:9'
                '?type=tcp&security=none#dead',
          });
      expect(detail!['ms'], -1);
      expect(detail['tcp'], 'refused');

      expect(await channel.invokeMethod('tunnelStats'), isNull);
      await channel.invokeMethod('disconnect');
      expect(await channel.invokeMethod<String>('getStatus'), 'disconnected');
    },
    skip: socket == null
        ? 'set FORTIVA_CORE_SOCKET to run against a running core'
        : false,
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

Future<void> _until(bool Function() done, {int seconds = 5}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
