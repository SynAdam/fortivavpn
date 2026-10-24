import 'package:flutter_test/flutter_test.dart';
import 'package:fortiva_vpn/api/config_service.dart';
import 'package:fortiva_vpn/core/state/dedicated_state.dart';
import 'package:fortiva_vpn/data/models/server.dart';
import 'package:fortiva_vpn/utils/standby_doors.dart';
import 'package:fortiva_vpn/utils/vless_link.dart';
import 'package:fortiva_vpn/utils/vless_link_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two servers whose Cloudflare doors are dialled at one Cloudflare
/// address, the way the backend hands them out. Each door must still be
/// its own server's door.
///
/// On 2026-10-02 a phone dialling one server's Reality door got another
/// server's Cloudflare door as its only standby: both Cloudflare doors were
/// keyed by the shared address, so the picker kept the first and dropped
/// the first server's own. Every move between the two doors then moved the
/// user to another server.
const cloudflare = '104.16.0.1';

String cdnLink(String name) =>
    'vless://u@$cloudflare:443?type=ws&security=tls&sni=$name&host=$name'
    '&path=%2Fws#Fortiva%20DE%20Nuremberg';

const realityLink =
    'vless://u@203.0.113.10:443?type=xhttp&security=reality'
    '&sni=www.samsung.com&host=www.samsung.com#Fortiva%20DE%20Nuremberg';

Server path(String uri, String door, int serverId) => Server.fromDedicatedPath(
  uri: uri,
  door: door,
  doorLabel: door,
  serverId: serverId,
);

void main() {
  final tenReality = path(realityLink, 'xhttp-reality', 10);
  final tenCdn = path(cdnLink('media.example.site'), 'ws-tls', 10);
  final elevenCdn = path(cdnLink('cdn.example.site'), 'ws-tls', 11);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StandbyDoors.enabled = true;
    StandbyDoors.androidOverride = true;
  });

  tearDown(() {
    StandbyDoors.enabled = false;
    StandbyDoors.androidOverride = null;
  });

  test('a Cloudflare door is keyed by the server it reaches', () {
    expect(tenCdn.pathKey, 'media.example.site:443|ws-tls');
    expect(elevenCdn.pathKey, 'cdn.example.site:443|ws-tls');
  });

  test('a Reality door keeps the address it dials, not the borrowed name', () {
    expect(tenReality.pathKey, '203.0.113.10:443|xhttp-reality');
  });

  test('a TLS link that dials its own name keys on that name', () {
    const link =
        'vless://u@media.example.site:443?type=ws&security=tls'
        '&sni=media.example.site#x';
    expect(VlessLink.endpoint(link), 'media.example.site:443');
  });

  test('reports still name the address that was dialled', () {
    expect(VlessLinkHost.of(tenCdn), cloudflare);
    expect(VlessLinkHost.of(elevenCdn), cloudflare);
  });

  test('two servers behind one Cloudflare address are two servers', () {
    expect(tenCdn.id, isNot(elevenCdn.id));
    expect(tenCdn.sameServerAs(elevenCdn), isFalse);
    expect(tenReality.sameServerAs(tenCdn), isTrue);
  });

  test('without server ids, the name they present still tells them apart', () {
    final ten = Server.fromDedicatedUri(cdnLink('media.example.site'));
    final eleven = Server.fromDedicatedUri(cdnLink('cdn.example.site'));
    expect(ten.id, isNot(eleven.id));
    expect(ten.sameServerAs(eleven), isFalse);
  });

  test('the dialled server\'s own Cloudflare door stands by first', () {
    final picked = StandbyDoors.pick(tenReality, [
      elevenCdn,
      tenCdn,
      tenReality,
    ]);
    expect(
      [for (final p in picked) p.pathKey],
      [tenCdn.pathKey, elevenCdn.pathKey],
    );
  });

  test('the servers screen lists both servers, each with its own id', () async {
    DedicatedPath p(String uri, String door, int id) => DedicatedPath(
      serverId: id,
      inboundId: 1,
      door: door,
      label: door,
      uri: uri,
    );
    final state = DedicatedState();
    await state.adoptForTest(
      [cdnLink('media.example.site'), cdnLink('cdn.example.site')],
      [
        p(cdnLink('media.example.site'), 'ws-tls', 10),
        p(realityLink, 'xhttp-reality', 10),
        p(cdnLink('cdn.example.site'), 'ws-tls', 11),
      ],
    );
    final [ten, eleven] = state.servers;
    expect(ten.id, isNot(eleven.id));
    expect([ten.serverId, eleven.serverId], [10, 11]);

    // The server the user chose owns its Reality door, and does not own
    // the other server's Cloudflare door.
    final reality = state.paths.firstWhere((s) => s.door == 'xhttp-reality');
    final otherCdn = state.paths.firstWhere((s) => s.serverId == 11);
    expect(reality.sameServerAs(ten), isTrue);
    expect(otherCdn.sameServerAs(ten), isFalse);

    state.select(eleven);
    expect(state.selectedServer?.serverId, 11);

    // The core moved the session onto [ten]'s Reality door, and the flow
    // follows it: [ten] is the one marked, not the door.
    state.select(reality);
    expect(state.selectedServer?.id, ten.id);
  });
}
