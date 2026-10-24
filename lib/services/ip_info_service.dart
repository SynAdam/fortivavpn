import '../api/api_client.dart';
import '../data/models/ip_info.dart';

/// Reports the address the internet currently sees for this device.
///
/// Asks our own backend, which answers with the address and country it
/// received the request from. It used to ask `ip-api.com` over plain HTTP,
/// which sent a VPN user's real address, unencrypted, to a third party
/// that has no relationship with them. Guideline 5.4 forbids exactly that,
/// and our published privacy policy already promised we did not do it.
///
/// The answer is still meaningful through the tunnel: connected, the
/// backend sees the exit server rather than the phone, which is what makes
/// this a check the user can trust.
class IpInfoService {
  const IpInfoService._();

  static Future<IpInfo?> fetchIpInfo() async {
    try {
      // Only on the phone's own network: through the tunnel or a relay the
      // backend would see another address, and this screen is about the
      // address the internet sees for this phone.
      final response = await ApiClient().get(
        '/api/v1/info/me',
        fallback: false,
      );
      if (response is! Map) return null;
      return IpInfo.fromBackend(response.cast<String, dynamic>());
    } catch (_) {
      // The screen shows its own retry, so a failure here is not worth
      // surfacing as anything more than "no answer yet".
      return null;
    }
  }
}
