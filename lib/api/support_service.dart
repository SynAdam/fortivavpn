import '../data/models/support_chat.dart';
import 'api_client.dart';

/// The calls behind the support chat.
///
/// All of them sit under /api/v1/devices/{device_id}/, which the relays
/// pass on, so the chat works with the tunnel off on a network that cuts
/// our calls. Every call goes through [ApiClient] with its fallback routes.
/// A POST can therefore reach the backend twice when an answer is lost on
/// the way back, which is why every message carries a client id the
/// backend uses to keep only the first.
///
/// No call ever waits for an answer to be written. The backend stores the
/// question and answers at once; the reply is fetched later.
class SupportService {
  SupportService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  String _base(String deviceId) => '/api/v1/devices/$deviceId/support';

  /// GET .../support/status
  ///
  /// Throws [ApiException] for an answer that is not a 2xx, a 503 with
  /// code `off` included, [FormatException] for a body that is not a
  /// status, and whatever the routes threw when none of them reached us.
  Future<SupportStatus> status(String deviceId) async {
    final response = await _client.get('${_base(deviceId)}/status');
    return SupportStatus.fromJson(response);
  }

  /// GET .../support?after={after}&lang={lang}
  Future<SupportPage> fetch(String deviceId, int after, String lang) async {
    final response = await _client.get(
      '${_base(deviceId)}?after=$after'
      '&lang=${Uri.encodeQueryComponent(lang)}',
    );
    return SupportPage.fromJson(response);
  }

  /// POST .../support/messages
  Future<SupportReply> send(String deviceId, Map<String, dynamic> body) async {
    final response = await _client.post(
      '${_base(deviceId)}/messages',
      body: body,
    );
    return SupportReply.fromJson(response);
  }

  /// POST .../support/messages/{id}/rating
  Future<void> rate(String deviceId, int messageId, String value) async {
    await _client.post(
      '${_base(deviceId)}/messages/$messageId/rating',
      body: {'value': value},
    );
  }

  /// POST .../support/new: end the conversation, so the assistant starts
  /// again without what was said before. The day's count stays.
  Future<SupportReply> startNew(String deviceId) async {
    final response = await _client.post('${_base(deviceId)}/new', body: {});
    return SupportReply.fromJson(response);
  }
}
