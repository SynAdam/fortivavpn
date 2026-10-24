import '../data/models/in_app_message.dart';
import 'api_client.dart';

/// The two calls behind in-app messages.
///
/// Both go through [ApiClient] with its fallback routes, because the phones
/// these messages matter most to are the ones whose network cuts our calls.
/// The language travels in the query string, which every route (direct,
/// tunnel and relay) passes on unchanged.
class MessageService {
  MessageService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// GET /api/v1/devices/{device_id}/messages?lang={lang}
  ///
  /// [background] marks a check made with the app off screen
  /// (NoticePull), so the backend does not count it as the user opening
  /// the app. The answer is the same.
  ///
  /// Throws [ApiException] for an answer that is not a 2xx (404 means the
  /// backend does not know this device), [FormatException] for a body that
  /// is not a messages answer, and whatever the routes threw when none of
  /// them reached us.
  Future<MessagesPage> fetch(
    String deviceId,
    String lang, {
    bool background = false,
  }) async {
    final response = await _client.get(
      '/api/v1/devices/$deviceId/messages'
      '?lang=${Uri.encodeQueryComponent(lang)}'
      '${background ? '&background=1' : ''}',
    );
    return MessagesPage.fromJson(response);
  }

  /// POST /api/v1/devices/{device_id}/messages/receipts
  Future<void> sendReceipts(String deviceId, Map<String, dynamic> body) async {
    await _client.post(
      '/api/v1/devices/$deviceId/messages/receipts',
      body: body,
    );
  }
}
