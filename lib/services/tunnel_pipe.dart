import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// How the app talks to the Windows tunnel service (windows/core).
///
/// Every call is one connection: a line of JSON in, a line of JSON out, then
/// the service closes it (windows/core/internal/control). [TunnelClient]
/// speaks that protocol over a [TunnelPipe], which is the service's named
/// pipe on Windows and a Unix socket wherever the core is run by hand for
/// development and in the tests.
abstract interface class TunnelPipe {
  /// Sends [request], one line ending in a newline, and returns the answer
  /// without its newline. Throws [TunnelCallException] with
  /// [TunnelCallException.unavailable] when nothing is listening.
  Future<String> exchange(String request, Duration timeout);
}

/// A call the service refused, or could not be made.
class TunnelCallException implements Exception {
  const TunnelCallException(this.code, this.message);

  /// The service is not running, or not installed.
  static const unavailable = 'SERVICE_UNAVAILABLE';

  /// The service's error code (windows/core/internal/control/protocol.go),
  /// or [unavailable].
  final String code;
  final String message;

  @override
  String toString() => 'TunnelCallException($code: $message)';
}

/// The service's protocol. Bump with ProtocolVersion in
/// windows/core/internal/control/protocol.go.
class TunnelClient {
  TunnelClient(this.pipe);

  static const protocolVersion = 1;

  /// Long enough for the slowest call, a "watch" that waits 25 seconds for
  /// the tunnel to change.
  static const defaultTimeout = Duration(seconds: 35);

  final TunnelPipe pipe;

  /// Calls [method] and returns its result, decoded from JSON. Throws
  /// [TunnelCallException] when the service refuses the call.
  Future<Object?> call(
    String method, {
    Map<String, Object?>? params,
    Duration timeout = defaultTimeout,
  }) async {
    final request = jsonEncode({
      'v': protocolVersion,
      'method': method,
      'params': ?params,
    });
    final reply = await pipe.exchange('$request\n', timeout);
    final Object? decoded;
    try {
      decoded = jsonDecode(reply);
    } on FormatException {
      throw TunnelCallException('BAD_REPLY', _clip(reply));
    }
    if (decoded is! Map) throw TunnelCallException('BAD_REPLY', _clip(reply));
    if (decoded['ok'] == true) return decoded['result'];
    final error = decoded['error'];
    if (error is! Map) throw TunnelCallException('BAD_REPLY', _clip(reply));
    throw TunnelCallException('${error['code']}', '${error['message']}');
  }

  static String _clip(String s) => s.length > 200 ? s.substring(0, 200) : s;
}

/// The service's pipe on Windows.
///
/// The Win32 calls block, and "watch" blocks for up to 25 seconds on
/// purpose, so each exchange runs on an isolate of its own. Each one opens
/// the pipe, writes the request, reads to the newline and closes it.
class NamedPipe implements TunnelPipe {
  const NamedPipe([this.path = r'\\.\pipe\FortivaTunnel']);

  final String path;

  @override
  Future<String> exchange(String request, Duration timeout) {
    final path = this.path;
    final timeoutMs = timeout.inMilliseconds;
    return Isolate.run(() => _exchangeBlocking(path, request, timeoutMs));
  }
}

/// The largest answer read, far over any real one: the diagnostics with
/// their log tail are a few tens of kilobytes.
const _maxReply = 4 << 20;

String _exchangeBlocking(String path, String request, int timeoutMs) {
  return using((arena) {
    final name = arena.pcwstr(path);
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));

    // Busy means every instance of the pipe is taken; the service makes a
    // new one as soon as it accepts, so a short wait is enough.
    HANDLE handle;
    while (true) {
      final opened = CreateFile(
        name,
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_NONE,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
      );
      if (opened.value.isValid) {
        handle = opened.value;
        break;
      }
      if (opened.error == ERROR_PIPE_BUSY &&
          DateTime.now().isBefore(deadline)) {
        sleep(const Duration(milliseconds: 50));
        continue;
      }
      if (opened.error == ERROR_FILE_NOT_FOUND) {
        throw const TunnelCallException(
          TunnelCallException.unavailable,
          'the tunnel service is not running',
        );
      }
      throw TunnelCallException('PIPE', 'open: Win32 error ${opened.error}');
    }

    try {
      final bytes = utf8.encode(request);
      final out = arena<Uint8>(bytes.length);
      out.asTypedList(bytes.length).setAll(0, bytes);
      final count = arena<Uint32>();
      var sent = 0;
      while (sent < bytes.length) {
        final wrote = WriteFile(
          handle,
          out + sent,
          bytes.length - sent,
          count,
          null,
        );
        if (!wrote.value) {
          throw TunnelCallException(
            'PIPE',
            'write: Win32 error ${wrote.error}',
          );
        }
        sent += count.value;
      }

      final reply = BytesBuilder(copy: false);
      final chunk = arena<Uint8>(16 << 10);
      while (true) {
        final read = ReadFile(handle, chunk, 16 << 10, count, null);
        final n = count.value;
        if (n > 0) {
          final data = chunk.asTypedList(n);
          final newline = data.indexOf(10);
          reply.add(
            Uint8List.fromList(newline >= 0 ? data.sublist(0, newline) : data),
          );
          if (newline >= 0) break;
        }
        if (!read.value) {
          // The service closes the pipe after its answer.
          if (read.error == ERROR_BROKEN_PIPE) break;
          if (read.error != ERROR_MORE_DATA) {
            throw TunnelCallException(
              'PIPE',
              'read: Win32 error ${read.error}',
            );
          }
        }
        if (reply.length > _maxReply) {
          throw const TunnelCallException('PIPE', 'answer too large');
        }
      }
      return utf8.decode(reply.takeBytes());
    } finally {
      CloseHandle(handle);
    }
  });
}

/// The service's socket wherever "fortiva-core run" serves one: macOS and
/// Linux while developing, and the tests.
class UnixSocketPipe implements TunnelPipe {
  const UnixSocketPipe([this.path = '/tmp/fortiva-tunnel.sock']);

  final String path;

  @override
  Future<String> exchange(String request, Duration timeout) async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
        timeout: timeout,
      );
    } on SocketException catch (e) {
      throw TunnelCallException(TunnelCallException.unavailable, e.message);
    }
    try {
      socket.add(utf8.encode(request));
      await socket.flush();
      final reply = BytesBuilder(copy: false);
      await for (final chunk in socket.timeout(timeout)) {
        final newline = chunk.indexOf(10);
        reply.add(newline >= 0 ? chunk.sublist(0, newline) : chunk);
        if (newline >= 0) break;
        if (reply.length > _maxReply) {
          throw const TunnelCallException('PIPE', 'answer too large');
        }
      }
      return utf8.decode(reply.takeBytes());
    } finally {
      socket.destroy();
    }
  }
}
